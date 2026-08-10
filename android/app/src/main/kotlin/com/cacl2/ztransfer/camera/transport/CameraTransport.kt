package com.cacl2.ztransfer.camera.transport

import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File

/**
 * Unified abstraction over camera connection transports.
 *
 * Implementations:
 * - [UsbTransport] — USB PTP via Android [android.mtp.MtpDevice] API
 * - [WifiTransport] — PTP/IP over TCP (dual-socket)
 *
 * All transports emit the same event types through the same [SharedFlow],
 * so the Flutter bridge layer is transport-agnostic.
 */
interface CameraTransport {

    // ── Identity ──────────────────────────────────────────────────────────

    /** Which transport type this implementation represents. */
    val transportType: TransportType

    /** Human-readable camera model name (e.g. "NIKON Z 8"), null before connection. */
    val cameraName: String?

    // ── Lifecycle ─────────────────────────────────────────────────────────

    /**
     * Establish connection to the camera.
     *
     * For USB: scans the USB bus for a Nikon device, opens the MTP session.
     * For Wi-Fi: establishes dual TCP sockets to the camera's PTP/IP port,
     * performs INIT_CMD_REQ/ACK + INIT_EVT_REQ/ACK handshake, then OpenSession.
     *
     * @return true if the session is fully established.
     */
    suspend fun connect(): Boolean

    /**
     * Tear down the session and release all resources.
     * Must be idempotent — safe to call even if not connected.
     */
    suspend fun disconnect()

    /** Whether a session is currently active. */
    val isConnected: Boolean

    // ── State ─────────────────────────────────────────────────────────────

    /** Observable connection state. */
    val connectionState: StateFlow<TransportState>

    // ── Events ────────────────────────────────────────────────────────────

    /**
     * Push-based stream of camera events.
     *
     * Event types:
     * - [TransportEvent.ObjectAdded] — new photo captured
     * - [TransportEvent.ConnectionStateChanged] — transport connected/disconnected
     * - [TransportEvent.BatteryChanged] — battery level updated
     * - [TransportEvent.StorageChanged] — storage info updated
     * - [TransportEvent.TransferStateChanged] — wireless receiver started/stopped
     * - [TransportEvent.TransferProgress] — download progress
     * - [TransportEvent.Log] — diagnostic log message
     */
    val events: SharedFlow<TransportEvent>

    // ── Photo Operations ──────────────────────────────────────────────────

    /** List JPEGs currently on the camera. */
    suspend fun listPhotos(): List<PhotoMeta>

    /**
     * Download a single object (JPEG/NEF) by its handle.
     * @return raw bytes of the file, or null on failure.
     */
    suspend fun getObject(handle: Int): ByteArray?

    /** Get metadata for a single object. */
    suspend fun getObjectInfo(handle: Int): ObjectInfo?

    /**
     * Download a JPEG/NEF by its handle and save to [saveDir].
     * @return the local file path on success, null on failure.
     */
    suspend fun downloadAndSave(
        handle: Int,
        fileName: String,
        saveDir: File
    ): String?

    // ── Device Properties ─────────────────────────────────────────────────

    /** Query battery level (0-100). Returns null if unsupported or disconnected. */
    suspend fun getBatteryLevel(): Int?

    /** Query storage information (capacity, free space, free images). */
    suspend fun getStorageInfo(): StorageInfo?

    /**
     * Return a diagnostic snapshot of the current transport session.
     * Returns an empty map if the transport doesn't support diagnostics.
     */
    fun getSessionDiagnostics(): Map<String, Any>

    // ── Lifecycle Callbacks ───────────────────────────────────────────────

    /**
     * Called when an EventChannel sink becomes available (Flutter starts
     * listening). The transport may begin forwarding events.
     */
    fun onEventSinkReady()

    /**
     * Called when the EventChannel sink is torn down (Flutter disposes
     * its subscription). The transport may throttle internal event
     * generation, but must NOT disconnect.
     */
    fun onEventSinkCancelled()
}

// ── Supporting Types ──────────────────────────────────────────────────────

/** Type of physical connection to the camera. */
enum class TransportType {
    USB,
    WIFI
}

/** High-level connection state. */
sealed class TransportState {
    /** No camera connected, idle. */
    data object Disconnected : TransportState()

    /** Attempting to establish a connection. */
    data object Connecting : TransportState()

    /** Successfully connected. [deviceName] is the camera model string. */
    data class Connected(val deviceName: String) : TransportState()

    /** Connection failed with a human-readable [reason]. */
    data class Error(val reason: String) : TransportState()
}

/** Unified event type emitted by all transports. */
sealed class TransportEvent {
    data class ObjectAdded(
        val objectHandle: Int,
        val formatCode: Int,
        val fileName: String,
        val sizeBytes: Long,
        val localPath: String?,
        val width: Int?,
        val height: Int?,
        val isRaw: Boolean
    ) : TransportEvent()

    data class ObjectRemoved(
        val objectHandle: Int
    ) : TransportEvent()

    data class ConnectionStateChanged(
        val connected: Boolean,
        val deviceName: String?,
        val transportType: TransportType
    ) : TransportEvent()

    data class BatteryChanged(
        val level: Int
    ) : TransportEvent()

    data class StorageChanged(
        val freeSpaceBytes: Long,
        val maxCapacityBytes: Long,
        val freeImages: Int
    ) : TransportEvent()

    data class TransferProgress(
        val objectHandle: Int,
        val progress: Double,
        val bytesTransferred: Long,
        val totalBytes: Long,
        val bytesPerSecond: Double,
    ) : TransportEvent()

    data class TransferStateChanged(
        val listening: Boolean,
    ) : TransportEvent()

    data class Log(
        val level: String,
        val message: String,
        val category: String = ""  // SOCKET, PTP, RECONNECT, EVENT, DOWNLOAD, PROBE
    ) : TransportEvent()
}

/** Lightweight photo metadata from the camera. */
data class PhotoMeta(
    val objectHandle: Int,
    val fileName: String,
    val sizeBytes: Long,
    val formatCode: Int,
    val captureDate: Long?
)

/** Detailed object information. */
data class ObjectInfo(
    val handle: Int,
    val format: Int,
    val size: Long,
    val filename: String,
    val captureDateMillis: Long?
) {
    val isJpeg: Boolean get() = format == 0x3801 || format == 0x3800
    val isRaw: Boolean get() = filename.uppercase().endsWith(".NEF")
    val isFolder: Boolean get() = format == 0x3001
}

/** Storage device information from the camera. */
data class StorageInfo(
    val storageId: Int,
    val maxCapacityBytes: Long,
    val freeSpaceBytes: Long,
    val freeImages: Int
)

/** Exception thrown for PTP/IP protocol errors. */
class PtpException(message: String, cause: Throwable? = null) : Exception(message, cause)
