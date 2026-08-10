package com.cacl2.ztransfer.camera.transport

import android.content.Context
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.util.Log
import com.cacl2.ztransfer.camera.PtpConnectionState
import com.cacl2.ztransfer.camera.PtpLogLevel
import com.cacl2.ztransfer.camera.PtpManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat

/**
 * Adapter that wraps the existing [PtpManager] (USB PTP via Android MTP API)
 * and exposes it through the [CameraTransport] interface.
 *
 * This is intentionally thin — [PtpManager] owns all USB protocol logic.
 * [UsbTransport] only maps between the PtpManager's APIs (StateFlows,
 * callbacks) and the unified transport types (TransportState, TransportEvent).
 *
 * USB device discovery and permission handling remain in [MainActivity].
 * This transport is called after permission is granted.
 */
class UsbTransport(
    private val context: Context
) : CameraTransport {

    override val transportType = TransportType.USB

    private val ptpManager = PtpManager(context)

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var forwardingJob: Job? = null

    // ── State ─────────────────────────────────────────────────────────────

    private val _connectionState =
        MutableStateFlow<TransportState>(TransportState.Disconnected)
    override val connectionState: StateFlow<TransportState> =
        _connectionState.asStateFlow()

    private val _events = MutableSharedFlow<TransportEvent>(
        replay = 0,
        extraBufferCapacity = 256
    )
    override val events: SharedFlow<TransportEvent> = _events.asSharedFlow()

    override val isConnected: Boolean
        get() = _connectionState.value is TransportState.Connected

    override var cameraName: String? = null
        private set

    // ══════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Connect to a Nikon camera over USB.
     *
     * USB device discovery and permission are handled externally (by
     * [MainActivity]). This method assumes a Nikon USB device is already
     * attached and permission has been granted.
     *
     * @return true if the PTP session was established.
     */
    override suspend fun connect(): Boolean {
        // Find a Nikon USB device
        val usbManager = context.getSystemService(Context.USB_SERVICE)
                as UsbManager
        val device = usbManager.deviceList.values.firstOrNull {
            it.vendorId == PtpManager.NIKON_VENDOR_ID
        }

        if (device == null) {
            _events.tryEmit(TransportEvent.Log("INFO", "未发现 Nikon USB 设备"))
            _connectionState.value = TransportState.Disconnected
            return false
        }

        return connectToDevice(device, usbManager)
    }

    /**
     * Connect to a specific USB device (called from MainActivity after
     * permission is granted).
     */
    fun connectToDevice(device: UsbDevice, usbManager: UsbManager): Boolean {
        if (!usbManager.hasPermission(device)) {
            _events.tryEmit(TransportEvent.Log("ERROR", "无 USB 权限: ${device.productName}"))
            return false
        }

        _connectionState.value = TransportState.Connecting
        _events.tryEmit(TransportEvent.ConnectionStateChanged(
            connected = false,
            deviceName = null,
            transportType = TransportType.USB
        ))

        val ok = ptpManager.connect(context, device)
        if (ok) {
            startForwarding()
            cameraName = (ptpManager.connectionState.value as? PtpConnectionState.Connected)?.deviceName
            _connectionState.value = TransportState.Connected(cameraName ?: "Nikon")
            _events.tryEmit(TransportEvent.ConnectionStateChanged(
                connected = true,
                deviceName = cameraName,
                transportType = TransportType.USB
            ))
        } else {
            val state = ptpManager.connectionState.value
            val reason = (state as? PtpConnectionState.Error)?.reason ?: "连接失败"
            _connectionState.value = TransportState.Error(reason)
            _events.tryEmit(TransportEvent.ConnectionStateChanged(
                connected = false,
                deviceName = null,
                transportType = TransportType.USB
            ))
        }
        return ok
    }

    /** Check if a Nikon USB device is currently attached. */
    fun hasUsbDevice(): Boolean {
        val usbManager = context.getSystemService(Context.USB_SERVICE)
                as UsbManager
        return usbManager.deviceList.values.any {
            it.vendorId == PtpManager.NIKON_VENDOR_ID
        }
    }

    override suspend fun disconnect() {
        forwardingJob?.cancel()
        ptpManager.disconnect()
        _connectionState.value = TransportState.Disconnected
        _events.tryEmit(TransportEvent.ConnectionStateChanged(
            connected = false,
            deviceName = null,
            transportType = TransportType.USB
        ))
        cameraName = null
    }

    // ── Event forwarding ──────────────────────────────────────────────────

    /**
     * Start forwarding PtpManager state changes and callbacks
     * to the unified [TransportEvent] [SharedFlow].
     */
    private fun startForwarding() {
        forwardingJob?.cancel()
        forwardingJob = scope.launch {
            // Connection state changes
            launch {
                ptpManager.connectionState.collect { ptpState ->
                    val transportState: TransportState = when (ptpState) {
                        is PtpConnectionState.Disconnected ->
                            TransportState.Disconnected
                        is PtpConnectionState.Connecting ->
                            TransportState.Connecting
                        is PtpConnectionState.Connected -> {
                            cameraName = ptpState.deviceName
                            TransportState.Connected(ptpState.deviceName)
                        }
                        is PtpConnectionState.Error ->
                            TransportState.Error(ptpState.reason)
                    }
                    _connectionState.value = transportState
                    _events.tryEmit(TransportEvent.ConnectionStateChanged(
                        connected = transportState is TransportState.Connected,
                        deviceName = cameraName,
                        transportType = TransportType.USB
                    ))
                }
            }

            // ObjectAdded events — driven by PtpManager.onJpegSaved callback
            ptpManager.onJpegSaved = { filePath, objectHandle, width,
                                        height, sizeBytes, isRaw ->
                Log.d(TAG, "onJpegSaved: $filePath handle=$objectHandle")
                _events.tryEmit(TransportEvent.ObjectAdded(
                    objectHandle = objectHandle,
                    formatCode = if (isRaw) 0x3000 else 0x3801,
                    fileName = filePath.substringAfterLast("/"),
                    sizeBytes = sizeBytes.toLong(),
                    localPath = filePath,
                    width = width,
                    height = height,
                    isRaw = isRaw
                ))
            }

            // ObjectRemoved events
            ptpManager.onObjectRemoved = { objectHandle ->
                Log.d(TAG, "onObjectRemoved: handle=$objectHandle")
                _events.tryEmit(TransportEvent.ObjectRemoved(
                    objectHandle = objectHandle
                ))
            }

            // Error log events
            launch {
                ptpManager.eventLog.collect { entries ->
                    val latest = entries.lastOrNull() ?: return@collect
                    if (latest.level == PtpLogLevel.ERROR) {
                        _events.tryEmit(TransportEvent.Log("ERROR", latest.message))
                    }
                }
            }
        }
    }

    // ── Photo Operations ──────────────────────────────────────────────────

    override suspend fun listPhotos(): List<PhotoMeta> {
        return ptpManager.listCameraPhotos().map { map ->
            PhotoMeta(
                objectHandle = (map["objectHandle"] as? Int) ?: 0,
                fileName = map["fileName"] as? String ?: "unknown",
                sizeBytes = ((map["sizeBytes"] as? Number)?.toLong()) ?: 0L,
                formatCode = (map["formatCode"] as? Int) ?: 0x3801,
                captureDate = try {
                    val dateStr = map["captureDate"] as? String ?: ""
                    if (dateStr.isNotEmpty()) {
                        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US)
                            .parse(dateStr)?.time
                    } else null
                } catch (e: Exception) { null }
            )
        }
    }

    override suspend fun getObject(handle: Int): ByteArray? {
        // PtpManager.getObject() returns the bytes directly but it's called
        // internally. We expose it through a helper approach:
        // The MTP device's getObject() can be called if we add a method.
        // For now, return null — manual download via USB is handled by
        // PtpManager's internal onObjectAddedSync which auto-downloads.
        //
        // The downloadAndSave method is used for manual download requests.
        Log.w(TAG, "getObject($handle): direct byte access not exposed by PtpManager")
        return null
    }

    override suspend fun getObjectInfo(handle: Int): ObjectInfo? {
        // PtpManager reads object info internally for ObjectAdded events.
        // Not directly exposed as a public method.
        Log.w(TAG, "getObjectInfo($handle): not exposed by PtpManager")
        return null
    }

    override suspend fun downloadAndSave(
        handle: Int,
        fileName: String,
        saveDir: File
    ): String? {
        // PtpManager handles download internally via onObjectAddedSync.
        // For manual downloads, we'd need to expose its getObject capability.
        // This is a future enhancement — the auto-download path already
        // covers the primary use case (photos are downloaded as they're shot).
        Log.w(TAG, "downloadAndSave($handle): manual download not exposed by PtpManager")
        return null
    }

    override suspend fun getBatteryLevel(): Int? {
        // Android MTP API does not expose battery level through MtpDevice.
        // This would require sending a PTP GetDevicePropValue command,
        // which the Android MTP abstraction does not support directly.
        return null
    }

    override suspend fun getStorageInfo(): StorageInfo? {
        // Information can be extracted from PtpManager's internal storage
        // enumeration. Not currently exposed as a public API.
        return null
    }

    override fun getSessionDiagnostics(): Map<String, Any> {
        return mapOf(
            "transportType" to "USB",
            "connected" to isConnected,
            "cameraName" to (cameraName ?: "")
        )
    }

    override fun onEventSinkReady() { /* events always flow */ }
    override fun onEventSinkCancelled() { /* events always flow */ }

    companion object {
        private const val TAG = "UsbTransport"
    }
}
