package com.cacl2.ztransfer.camera.transport

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.Socket
import java.util.concurrent.atomic.AtomicInteger

/**
 * Scans the local Wi-Fi subnet for a Nikon camera running PTP/IP.
 *
 * ## Use Case
 *
 * Phone creates a hotspot → Camera joins via "Connect to computer"
 * → Camera gets DHCP IP (e.g. 192.168.43.x) → Scanner finds it.
 *
 * ## Scanning Strategy
 *
 * 1. Determine the phone's IP on Wi-Fi (or hotspot) interface
 * 2. Derive the /24 subnet
 * 3. For each IP in the subnet, attempt a TCP connect to port 15740
 * 4. Return the first host accepting a TCP connection on the PTP/IP port
 *
 * Scanning 254 IPs sequentially would take minutes.  We scan in
 * parallel batches of 32 with a 500ms connect timeout per candidate,
 * so the entire scan completes in ~4 seconds.
 */
object CameraScanner {

    private const val TAG = "CameraScanner"
    private const val PTP_PORT = 15740
    private const val CONNECT_TIMEOUT_MS = 220
    private const val PROBE_TIMEOUT_MS = 500
    private const val PARALLEL_BATCH = 32

    /** Known hotspot gateway IPs — we skip these (they're the phone itself). */
    private val HOTSPOT_GATEWAYS = setOf(
        "192.168.43.1",   // Android default
        "192.168.42.1",   // Samsung
        "192.168.49.1",   // Custom Android hotspot
        "192.168.137.1",  // Windows hotspot
        "192.168.1.1",    // Common router
        "192.168.0.1",    // Common router
        "172.20.10.1",    // iOS hotspot (some versions)
        "10.0.0.1",
    )

    /**
     * Result of a camera scan.
     */
    data class ScanResult(
        val cameraIp: String,
        val cameraName: String,
        val sessionId: Int,
        val localIp: String?,
    )

    /**
     * Scan the local subnet for a Nikon PTP/IP camera.
     *
     * @param context      Android context
     * @param onProgress   Optional callback: (current, total, ipJustTried)
     * @return [ScanResult] if found, null otherwise.
     */
    suspend fun scan(
        context: Context,
        onProgress: ((current: Int, total: Int, ip: String) -> Unit)? = null
    ): ScanResult? = withContext(Dispatchers.IO) {
        val ipList = buildIpList(context)
        if (ipList.isEmpty()) {
            Log.w(TAG, "scan: no IP range determined — is Wi-Fi/hotspot on?")
            return@withContext null
        }

        val subnetCount = ipList.map { it.substringBeforeLast(".") }.distinct().size
        Log.d(TAG, "scan: probing ${ipList.size} IPs across $subnetCount subnet(s)")

        val total = ipList.size
        // Process in parallel batches
        val batches = ipList.chunked(PARALLEL_BATCH)
        val tried = AtomicInteger(0)

        for (batch in batches) {
            val results = batch.map { ip ->
                async {
                    val result = probeIp(ip)
                    onProgress?.invoke(tried.incrementAndGet(), total, ip)
                    result
                }
            }.awaitAll()

            // Return first match
            val found = results.filterNotNull().firstOrNull()
            if (found != null) {
                Log.i(TAG, "scan: found camera at $found")
                return@withContext found
            }
        }

        Log.d(TAG, "scan: no camera found on subnet")
        null
    }

    /**
     * Build the list of IPs to scan, excluding the phone itself and
     * known gateway addresses.
     */
    private fun buildIpList(context: Context): List<String> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
                as ConnectivityManager

        val localIps = linkedSetOf<String>()

        // ConnectivityManager is reliable while the phone is a Wi-Fi client.
        // Explicitly select IPv4: LinkProperties commonly lists IPv6 first.
        for (network in cm.allNetworks) {
            val capabilities = cm.getNetworkCapabilities(network) ?: continue
            if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
            ) {
                continue
            }
            cm.getLinkProperties(network)?.linkAddresses
                ?.mapNotNull { it.address as? Inet4Address }
                ?.filter(::isUsableLanAddress)
                ?.mapNotNullTo(localIps) { it.hostAddress }
        }

        // Android hotspot interfaces are not always exposed as a Network.
        // Enumerate common Wi-Fi/AP interfaces so addresses such as
        // 10.35.102.166 still yield the complete 10.35.102.0/24 range.
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces != null && interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val name = networkInterface.name.lowercase()
                val isLanInterface = name.startsWith("wlan") ||
                    name.startsWith("wifi") ||
                    name.startsWith("ap") ||
                    name.startsWith("swlan") ||
                    name.startsWith("softap") ||
                    name.startsWith("eth")
                if (!isLanInterface || !networkInterface.isUp || networkInterface.isLoopback) {
                    continue
                }
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (address is Inet4Address && isUsableLanAddress(address)) {
                        address.hostAddress?.let(localIps::add)
                    }
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "buildIpList: failed to enumerate hotspot interfaces", error)
        }

        if (localIps.isEmpty()) return getFallbackRanges()

        val candidates = linkedSetOf<String>()
        for (localIp in localIps) {
            val baseIp = localIp.substringBeforeLast(".")
            for (i in 1..254) {
                val ip = "$baseIp.$i"
                if (ip !in localIps && ip !in HOTSPOT_GATEWAYS) {
                    candidates.add(ip)
                }
            }
        }

        Log.d(
            TAG,
            "buildIpList: ${candidates.size} candidates from local IPv4 addresses $localIps",
        )
        return candidates.toList()
    }

    /**
     * Fallback IP ranges when we can't determine the exact subnet.
     * Covers common Android, iOS, Windows and home-network subnets. Previous versions omitted the
     * 192.168.49 / 192.168.1 / 192.168.0 / 10.0.0 subnets, causing scan
     * failures on common home Wi-Fi and Samsung customised hotspots.
     */
    private fun getFallbackRanges(): List<String> {
        val ranges = listOf(
            "192.168.43",   // Android 原生热点
            "192.168.49",   // 定制 ROM 热点
            "192.168.137",  // Windows 热点
            "192.168.1",    // 家庭 Wi-Fi 常见网段
            "192.168.0",    // 家庭 Wi-Fi 常见网段
            "172.20.10",    // iOS 热点
            "10.0.0",       // 企业网
        )
        val list = mutableListOf<String>()
        for (base in ranges) {
            // DHCP leases are not guaranteed to be low addresses. Nikon cameras
            // can appear at addresses such as .200, so scan the full /24.
            for (i in 2..254) {
                list.add("$base.$i")
            }
        }
        Log.d(TAG, "buildIpList: using fallback ranges (${list.size} candidates)")
        return list
    }

    /**
     * Probe a single IP: TCP connect to :15740 and immediately close.
     *
     * Uses a pure TCP connect probe, with no INIT_CMD_REQ.
     * Sending INIT_CMD_REQ during scanning was slow (3s per IP) and consumed
     * the camera's pairing slot on every probe.  TCP-only is 10× faster and
     * side-effect free.
     */
    private suspend fun probeIp(ip: String): ScanResult? {
        return withTimeoutOrNull(PROBE_TIMEOUT_MS.toLong()) {
            withContext(Dispatchers.IO) {
                val socket = Socket()
                try {
                    socket.connect(InetSocketAddress(ip, PTP_PORT), CONNECT_TIMEOUT_MS)
                    val localIp = socket.localAddress?.hostAddress
                    Log.i(TAG, "probeIp $ip: ✓ port 15740 open via $localIp")
                    ScanResult(ip, "Nikon", 0, localIp)
                } catch (e: Exception) {
                    null
                } finally {
                    try { socket.close() } catch (_: Exception) {}
                }
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun isUsableLanAddress(address: Inet4Address): Boolean {
        return address.isSiteLocalAddress &&
            !address.isLoopbackAddress &&
            !address.isLinkLocalAddress
    }
}
