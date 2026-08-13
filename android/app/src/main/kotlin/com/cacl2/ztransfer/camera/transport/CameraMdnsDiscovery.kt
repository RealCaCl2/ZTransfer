package com.cacl2.ztransfer.camera.transport

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Discovers Nikon cameras on the local Wi-Fi network using mDNS/Bonjour.
 *
 * Matches the role of `EnumDevices` in the Nikon MAID3 SDK — finds all
 * available cameras regardless of transport.  Uses Android's built-in
 * [NsdManager] (Network Service Discovery), which implements the same
 * DNS-SD protocol as Nikon's own `dnssd.dll`.
 *
 * ## Service Types
 *
 * Nikon cameras running PTP/IP typically advertise one of:
 * - `_ptp._tcp`          — Standard PTP/IP service
 * - `_nikon-ptp._tcp`    — Nikon-specific PTP
 * - `_nikon._tcp`        — Generic Nikon service
 *
 * We discover ALL of them and then probe port 15740 on any found host
 * to confirm it's actually a PTP/IP camera.
 *
 * ## Usage
 *
 * ```kotlin
 * val camera = CameraMdnsDiscovery.discover(context)
 * if (camera != null) {
 *     wifiTransport.connectTo(camera.ip, camera.port)
 * }
 * ```
 */
object CameraMdnsDiscovery {

    private const val TAG = "CameraMdns"
    private const val PROBE_TIMEOUT_MS = 3000L
    private const val CAMERA_PORT = 15740

    /**
     * Service types to try.  [NsdManager] discovers one type at a time,
     * so we try them sequentially until we find a camera.
     */
    private val SERVICE_TYPES = listOf(
        "_ptp._tcp",
        "_nikon-ptp._tcp",
        "_nikon._tcp",
    )

    data class DiscoveredCamera(
        val name: String,
        val host: String,
        val port: Int,
        val serviceType: String,
        val localIp: String?,
    )

    /**
     * Discover a Nikon PTP/IP camera on the local network.
     *
     * Returns the first camera found, or null after scanning all
     * known service types (timeout ~15s total).
     */
    suspend fun discover(context: Context): DiscoveredCamera? =
        withContext(Dispatchers.IO) {
            val nsdManager = context.getSystemService(Context.NSD_SERVICE)
                    as? NsdManager ?: return@withContext null

            Log.d(TAG, "开始 mDNS 发现...")

            for (svcType in SERVICE_TYPES) {
                Log.d(TAG, "尝试发现: $svcType")
                val result = discoverServiceType(nsdManager, svcType)
                if (result != null) {
                    // Verify it's actually a PTP/IP camera
                    val camera = verifyCamera(result, svcType)
                    if (camera != null) {
                        Log.i(TAG, "✓ 发现相机: ${camera.name} @ ${camera.host}:${camera.port} (${camera.serviceType})")
                        return@withContext camera
                    }
                    Log.d(TAG, "发现 $svcType 服务但验证失败，继续尝试...")
                }
            }

            Log.d(TAG, "mDNS 发现: 未找到 Nikon 相机")
            null
        }

    // ── Service discovery per type ──────────────────────────────────────

    private suspend fun discoverServiceType(
        nsdManager: NsdManager,
        serviceType: String
    ): NsdServiceInfo? {
        val deferred = CompletableDeferred<NsdServiceInfo?>()
        val listener = NsdDiscoveryListener(nsdManager, serviceType, deferred)
        var started = false
        return try {
            nsdManager.discoverServices(
                serviceType,
                NsdManager.PROTOCOL_DNS_SD,
                listener,
            )
            started = true
            // Wait up to 5 seconds per service type.
            withTimeoutOrNull(5000L) { deferred.await() }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            Log.w(TAG, "mDNS 启动异常: $serviceType", error)
            null
        } finally {
            // Also runs when the parallel TCP scanner wins and cancels mDNS.
            if (started) {
                try {
                    nsdManager.stopServiceDiscovery(listener)
                } catch (_: Exception) {
                }
            }
        }
    }

    // ── Camera verification ────────────────────────────────────────────

    /**
     * Verify that a discovered mDNS service is actually a Nikon PTP/IP
     * camera by connecting to port 15740.
     *
     * This mirrors how [CameraScanner] verifies IPs, but starts from
     * an mDNS discovery rather than a brute-force scan.
     */
    private suspend fun verifyCamera(
        info: NsdServiceInfo,
        serviceType: String,
    ): DiscoveredCamera? {
        return withTimeoutOrNull(PROBE_TIMEOUT_MS) {
            val host = info.host?.hostAddress ?: return@withTimeoutOrNull null
            val socket = Socket()
            try {
                // A pure TCP probe does not consume a pairing
                // session by sending INIT_CMD_REQ during discovery.
                socket.connect(InetSocketAddress(host, CAMERA_PORT), 1200)
                DiscoveredCamera(
                    name = info.serviceName.ifBlank { "Nikon" },
                    host = host,
                    port = CAMERA_PORT,
                    serviceType = serviceType,
                    localIp = socket.localAddress?.hostAddress,
                )
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (e: Exception) {
                null
            } finally {
                try { socket.close() } catch (_: Exception) {}
            }
        }
    }

    // ── NsdManager.DiscoveryListener ───────────────────────────────────

    private class NsdDiscoveryListener(
        private val nsdManager: NsdManager,
        private val targetType: String,
        private val deferred: CompletableDeferred<NsdServiceInfo?>,
    ) : NsdManager.DiscoveryListener {
        private val resolving = AtomicBoolean(false)

        override fun onDiscoveryStarted(serviceType: String) {
            Log.d(TAG, "mDNS 发现已启动: $serviceType")
        }

        override fun onServiceFound(info: NsdServiceInfo) {
            if (CameraMdnsDiscovery.normalizeServiceType(info.serviceType) !=
                CameraMdnsDiscovery.normalizeServiceType(targetType) ||
                deferred.isCompleted ||
                !resolving.compareAndSet(false, true)
            ) {
                return
            }
            Log.d(TAG, "mDNS 发现服务，正在解析: ${info.serviceName}")
            try {
                @Suppress("DEPRECATION")
                nsdManager.resolveService(info, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                        Log.d(TAG, "mDNS 解析失败: ${serviceInfo.serviceName} code=$errorCode")
                        resolving.set(false)
                    }

                    override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                        Log.d(
                            TAG,
                            "mDNS 已解析: ${serviceInfo.serviceName} @ ${serviceInfo.host}:${serviceInfo.port}",
                        )
                        deferred.complete(serviceInfo)
                    }
                })
            } catch (error: Exception) {
                resolving.set(false)
                Log.d(TAG, "mDNS 解析异常: ${error.message}")
            }
        }

        override fun onServiceLost(info: NsdServiceInfo) {
            Log.d(TAG, "mDNS 服务丢失: ${info.serviceName}")
        }

        override fun onDiscoveryStopped(serviceType: String) {
            Log.d(TAG, "mDNS 发现已停止: $serviceType")
            if (!deferred.isCompleted) {
                deferred.complete(null)
            }
        }

        override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
            Log.w(TAG, "mDNS 启动失败: $serviceType code=$errorCode")
            if (!deferred.isCompleted) {
                deferred.complete(null)
            }
        }

        override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
            Log.w(TAG, "mDNS 停止失败: $serviceType code=$errorCode")
        }
    }

    private fun normalizeServiceType(serviceType: String): String {
        return serviceType.trimEnd('.').lowercase()
    }
}
