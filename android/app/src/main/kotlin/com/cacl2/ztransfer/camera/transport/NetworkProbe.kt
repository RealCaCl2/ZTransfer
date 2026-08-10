package com.cacl2.ztransfer.camera.transport

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import kotlinx.coroutines.*
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Comprehensive network probe for discovering Nikon cameras in
 * "Connect to computer" mode.
 *
 * ## Strategy
 *
 * 1. **mDNS scan** — discover ALL services on the local network,
 *    not just PTP types.  The camera may register as
 *    `_maid3._tcp`, `_nikon-control._tcp`, or something unexpected.
 *
 * 2. **Port scan** — on any discovered host (or common IPs),
 *    scan ports 15740, 5353, 8080, 80, 443, 9000-9010.
 *
 * 3. **Protocol probe** — on each open port, try:
 *    - PTP/IP INIT_CMD_REQ
 *    - HTTP GET /
 *    - Raw byte to check for response
 *
 * 4. **Results** — return everything found, including service
 *    names, IPs, ports, and protocol identifiers.
 *
 * This is a diagnostic tool.  Once we know what the camera
 * exposes, the connection logic can be updated.
 */
object NetworkProbe {

    private const val TAG = "NetworkProbe"

    /** Ports commonly used by Nikon cameras and PTP/IP services. */
    private val PROBE_PORTS = intArrayOf(
        15740,  // PTP/IP standard
        5353,   // mDNS
        8080,   // HTTP (some cameras)
        80,     // HTTP
        443,    // HTTPS
        9001, 9002, 9003, 9004, 9005,  // Possible MAID3 ports
    )

    data class MdnsService(
        val name: String,
        val type: String,
        val host: String,
        val port: Int
    )

    data class OpenPort(
        val host: String,
        val port: Int,
        val protocol: String  // "PTP_IP", "HTTP", "UNKNOWN"
    )

    data class ProbeResult(
        val wifiSsid: String?,
        val localIp: String?,
        val mdnsServices: List<MdnsService>,
        val openPorts: List<OpenPort>,
        val durationMs: Long
    ) {
        fun toSummary(): String = buildString {
            appendLine("=== Network Probe Results ===")
            appendLine("Wi-Fi: $wifiSsid")
            appendLine("Local IP: $localIp")
            appendLine()
            appendLine("--- mDNS Services (${mdnsServices.size}) ---")
            mdnsServices.forEach {
                appendLine("  ${it.name} | ${it.type} | ${it.host}:${it.port}")
            }
            appendLine()
            appendLine("--- Open Ports (${openPorts.size}) ---")
            openPorts.forEach {
                appendLine("  ${it.host}:${it.port} [${it.protocol}]")
            }
            appendLine()
            appendLine("Duration: ${durationMs}ms")
        }
    }

    /**
     * Run a full network probe.
     *
     * @param onProgress called with status updates
     */
    suspend fun probe(
        context: Context,
        onProgress: ((String) -> Unit)? = null
    ): ProbeResult = withContext(Dispatchers.IO) {
        val startTime = System.currentTimeMillis()

        // ── Wi-Fi info ──
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
                as ConnectivityManager
        val wifiNet = findWifiNetwork(cm)
        val localIp = wifiNet?.let { cm.getLinkProperties(it)?.linkAddresses?.firstOrNull()?.address?.hostAddress }
        // SSID not directly available from NetworkCapabilities in all API levels
        val ssid: String? = null

        onProgress?.invoke("Wi-Fi: $ssid, Local IP: $localIp")

        // ── 1. mDNS: discover ALL service types ──
        onProgress?.invoke("Scanning mDNS services...")
        val mdnsServices = discoverAllServices(context)

        // Collect unique hosts from mDNS discovery
        val hostsToScan = mutableSetOf<String>()
        mdnsServices.forEach { hostsToScan.add(it.host) }

        // If no mDNS results, try common hotspot IPs
        if (hostsToScan.isEmpty() && localIp != null) {
            val base = localIp.substringBeforeLast(".")
            for (i in 2..20) {
                hostsToScan.add("$base.$i")
            }
        }

        onProgress?.invoke("Probing ${hostsToScan.size} hosts on ${PROBE_PORTS.size} ports...")

        // ── 2. Port scan ──
        val openPorts = mutableListOf<OpenPort>()
        var scanned = 0
        val total = hostsToScan.size * PROBE_PORTS.size

        for (host in hostsToScan) {
            for (port in PROBE_PORTS) {
                scanned++
                if (scanned % 20 == 0) {
                    onProgress?.invoke("Port scan: $scanned/$total")
                }
                val proto = probePort(host, port)
                if (proto != null) {
                    openPorts.add(OpenPort(host, port, proto))
                    onProgress?.invoke("FOUND: $host:$port [$proto]")
                }
            }
        }

        val durationMs = System.currentTimeMillis() - startTime
        onProgress?.invoke("Done. Found ${mdnsServices.size} services, ${openPorts.size} open ports.")

        ProbeResult(
            wifiSsid = ssid,
            localIp = localIp,
            mdnsServices = mdnsServices,
            openPorts = openPorts,
            durationMs = durationMs
        )
    }

    // ── mDNS: discover ALL service types ────────────────────────────────

    private val ALL_SERVICE_TYPES = listOf(
        "_ptp._tcp",
        "_nikon-ptp._tcp",
        "_nikon._tcp",
        "_maid3._tcp",
        "_http._tcp",
        "_scanner._tcp",
        "_privet._tcp",
        "_pdl-datastream._tcp",
        "_uscan._tcp",
    )

    private suspend fun discoverAllServices(context: Context): List<MdnsService> {
        val nsdManager = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
            ?: return emptyList()

        val results = mutableListOf<MdnsService>()

        for (svcType in ALL_SERVICE_TYPES) {
            try {
                val services = discoverServiceType(nsdManager, svcType)
                results.addAll(services)
            } catch (e: Exception) {
                Log.d(TAG, "mDNS $svcType: ${e.message}")
            }
        }

        return results.distinctBy { "${it.host}:${it.port}" }
    }

    private suspend fun discoverServiceType(
        nsdManager: NsdManager,
        serviceType: String
    ): List<MdnsService> = withTimeoutOrNull(3000L) {
        suspendCancellableCoroutine<List<MdnsService>> { cont ->
            val found = mutableListOf<MdnsService>()

            val listener = object : NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(type: String) {}
                override fun onDiscoveryStopped(type: String) {
                    if (cont.isActive) cont.resume(found.toList()) {}
                }
                override fun onStartDiscoveryFailed(type: String, code: Int) {
                    if (cont.isActive) cont.resume(emptyList()) {}
                }
                override fun onStopDiscoveryFailed(type: String, code: Int) {}

                override fun onServiceFound(info: NsdServiceInfo) {
                    // Resolve to get host:port
                    nsdManager.resolveService(info, object : NsdManager.ResolveListener {
                        override fun onResolveFailed(info: NsdServiceInfo, code: Int) {}
                        override fun onServiceResolved(info: NsdServiceInfo) {
                            val host = info.host?.hostAddress ?: return
                            found.add(MdnsService(
                                name = info.serviceName,
                                type = info.serviceType,
                                host = host,
                                port = info.port
                            ))
                        }
                    })
                }

                override fun onServiceLost(info: NsdServiceInfo) {}
            }

            nsdManager.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, listener)

            cont.invokeOnCancellation {
                try { nsdManager.stopServiceDiscovery(listener) } catch (_: Exception) {}
            }
        }
    } ?: emptyList()

    // ── Port probe ──────────────────────────────────────────────────────

    private suspend fun probePort(host: String, port: Int): String? {
        return withTimeoutOrNull(2000L) {
            withContext(Dispatchers.IO) {
                val socket = Socket()
                try {
                    socket.connect(InetSocketAddress(host, port), 1500)
                    socket.soTimeout = 2000

                    // Try PTP/IP INIT_CMD_REQ
                    val isPtp = tryPtpInit(socket)
                    if (isPtp) return@withContext "PTP_IP"

                    // Try HTTP
                    val isHttp = tryHttpGet(socket, host, port)
                    if (isHttp) return@withContext "HTTP"

                    // Port is open but protocol unknown
                    "OPEN"
                } catch (e: Exception) {
                    null
                } finally {
                    try { socket.close() } catch (_: Exception) {}
                }
            }
        }
    }

    private fun tryPtpInit(socket: Socket): Boolean {
        return try {
            val guid = PtpIpConstants.DEFAULT_CLIENT_GUID
            val nameBytes = ("ZTransfer" + 0.toChar()).toByteArray(Charsets.UTF_16LE)
            val payload = ByteBuffer.allocate(16 + nameBytes.size + 4).apply {
                order(ByteOrder.BIG_ENDIAN)
                putLong(guid.mostSignificantBits)
                putLong(guid.leastSignificantBits)
                order(ByteOrder.LITTLE_ENDIAN)
                put(nameBytes)
                putInt(0x00010000)
            }.array()

            val totalLen = 8 + payload.size
            val buf = ByteBuffer.allocate(totalLen)
                .order(ByteOrder.LITTLE_ENDIAN)
                .putInt(totalLen)
                .putInt(PtpIpConstants.PKT_INIT_CMD_REQ)
                .put(payload)

            socket.getOutputStream().write(buf.array())
            socket.getOutputStream().flush()

            val header = ByteArray(8)
            readFully(socket.getInputStream(), header)
            val type = ByteBuffer.wrap(header, 4, 4).order(ByteOrder.LITTLE_ENDIAN).int

            type == PtpIpConstants.PKT_INIT_CMD_ACK || type == PtpIpConstants.PKT_INIT_FAIL
        } catch (e: Exception) {
            false
        }
    }

    private fun tryHttpGet(socket: Socket, host: String, port: Int): Boolean {
        return try {
            val req = "GET / HTTP/1.0\r\nHost: $host\r\n\r\n"
            socket.getOutputStream().write(req.toByteArray())
            socket.getOutputStream().flush()
            val buf = ByteArray(128)
            val n = socket.getInputStream().read(buf)
            n > 0 && String(buf, 0, n).startsWith("HTTP/")
        } catch (e: Exception) {
            false
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun findWifiNetwork(cm: ConnectivityManager): android.net.Network? {
        val active = cm.activeNetwork
        if (active != null) {
            val caps = cm.getNetworkCapabilities(active)
            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI))
                return active
        }
        @Suppress("DEPRECATION")
        for (net in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(net) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return net
        }
        return null
    }

    private fun readFully(input: java.io.InputStream, buf: ByteArray) {
        var read = 0
        while (read < buf.size) {
            val n = input.read(buf, read, buf.size - read)
            if (n < 0) throw java.io.EOFException("socket closed")
            read += n
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // Subnet enumeration (for when mDNS doesn't work)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Enumerate common hotspot subnets.  Useful when mDNS is unavailable
     * (e.g., some phones block multicast on hotspot interfaces).
     *
     * Covers the static subnet list used by common Android and iOS hotspots.
     */
    fun enumerateSubnets(): List<String> {
        return listOf(
            "192.168.43",   // Android 原生热点
            "192.168.49",   // 定制 ROM 热点
            "192.168.137",  // Windows 热点
            "192.168.1",    // 家庭 Wi-Fi
            "192.168.0",    // 家庭 Wi-Fi
            "172.20.10",    // iOS 热点
            "10.0.0",       // 企业网
        )
    }
}
