package com.cacl2.ztransfer.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.mtp.MtpDevice
import android.mtp.MtpEvent
import android.mtp.MtpObjectInfo
import android.os.CancellationSignal
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.job
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// ──────────────────────────────────────────────────────────────────────────────
// Public state types exposed to the UI layer
// ──────────────────────────────────────────────────────────────────────────────

/** High-level connection state for the UI. */
sealed class PtpConnectionState {
    /** No camera connected, idle. */
    data object Disconnected : PtpConnectionState()

    /** Attempting to open the USB device and initialize the MTP session. */
    data object Connecting : PtpConnectionState()

    /** Successfully connected. [deviceName] is the camera model string. */
    data class Connected(val deviceName: String) : PtpConnectionState()

    /** Connection failed with a human-readable [reason]. */
    data class Error(val reason: String) : PtpConnectionState()
}

/** A single log entry displayed in the event feed. */
data class PtpLogEntry(
    val timestamp: Long = System.currentTimeMillis(),
    val level: PtpLogLevel = PtpLogLevel.INFO,
    val message: String
)

enum class PtpLogLevel { INFO, EVENT, ERROR }

// ──────────────────────────────────────────────────────────────────────────────
// PTP Manager — owns the MTP device, session, event loop, and image download
// ──────────────────────────────────────────────────────────────────────────────

/**
 * Manages the full lifecycle of a PTP connection to a Nikon camera over USB.
 *
 * ## Architecture
 * - USB device discovery and permission are handled *outside* this class
 *   (by [MainActivity]).  Once permission is granted, [connect] is called.
 * - A background coroutine polls [MtpDevice.readEvent] for PTP events.
 * - When `ObjectAdded` (0x4002) fires and the object is a JPEG, the image is
 *   downloaded, decoded, and exposed via [downloadedBitmap].
 *
 * All public [StateFlow]s are safe to collect from the main (UI) thread.
 */
class PtpManager(context: Context) {

    private val appContext: Context = context.applicationContext

    // ── public state ─────────────────────────────────────────────────────────

    private val _connectionState = MutableStateFlow<PtpConnectionState>(
        PtpConnectionState.Disconnected
    )
    val connectionState: StateFlow<PtpConnectionState> = _connectionState.asStateFlow()

    private val _downloadedBitmap = MutableStateFlow<Bitmap?>(null)
    val downloadedBitmap: StateFlow<Bitmap?> = _downloadedBitmap.asStateFlow()

    private val _eventLog = MutableStateFlow<List<PtpLogEntry>>(emptyList())
    val eventLog: StateFlow<List<PtpLogEntry>> = _eventLog.asStateFlow()

    private val _lastTransferInfo = MutableStateFlow<String?>(null)
    val lastTransferInfo: StateFlow<String?> = _lastTransferInfo.asStateFlow()

    /**
     * Optional callback invoked when a JPEG has been downloaded and saved to
     * disk.  The Flutter bridge uses this to forward the file path to the UI.
     */
    var onJpegSaved: ((
        filePath: String,
        objectHandle: Int,
        width: Int,
        height: Int,
        sizeBytes: Int,
        isRaw: Boolean
    ) -> Unit)? = null

    /**
     * Optional callback invoked when an object is deleted from the camera.
     * The Flutter bridge uses this to mark photos as off-camera.
     */
    var onObjectRemoved: ((objectHandle: Int) -> Unit)? = null

    /**
     * ID of the active project. Newly-synced photos are saved under
     * `Projects/{currentProjectId}/`.  Set this before connecting the camera.
     */
    /**
     * ID of the active project.  Read from SharedPreferences on every access
     * so it is always in sync with [ProjectStore.setActiveProjectId].
     */
    var currentProjectId: String?
        get() = appContext
            .getSharedPreferences("ztransfer", android.content.Context.MODE_PRIVATE)
            .getString("active_project_id", null)
        set(value) {
            appContext
                .getSharedPreferences("ztransfer", android.content.Context.MODE_PRIVATE)
                .edit().putString("active_project_id", value).apply()
        }

    // ── private fields ───────────────────────────────────────────────────────

    /**
     * Single-threaded dispatcher for ALL MtpDevice operations.
     *
     * MtpDevice is NOT thread-safe — calling readEvent() and getObject()
     * concurrently on the same USB connection causes native crashes (SIGSEGV).
     * By running everything on one dedicated thread we naturally serialise
     * access and eliminate the race.
     */
    private val mtpDispatcher = newSingleThreadContext("mtp-worker")

    /**
     * Scope that lives as long as a PTP session is active.
     * Re-created on each [connect], cancelled on [disconnect].
     */
    private var mtpScope: CoroutineScope? = null

    private var mtpDevice: MtpDevice? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var connectedDevice: UsbDevice? = null
    private var eventPollJob: Job? = null

    /** Set of object handles we already know about (avoids re-downloading). */
    private val knownObjectHandles = mutableSetOf<Int>()

    // ── public API ───────────────────────────────────────────────────────────

    /**
     * Open the USB device and initialise the PTP session.
     *
     * @param context  Used to obtain [UsbManager].
     * @param device   The [UsbDevice] representing the camera (must already have
     *                 permission granted).
     * @return `true` if the session was opened successfully.
     */
    fun connect(context: Context, device: UsbDevice): Boolean {
        // Guard: already connected
        if (_connectionState.value is PtpConnectionState.Connected ||
            _connectionState.value is PtpConnectionState.Connecting
        ) {
            addLog(PtpLogLevel.INFO, "Already connected or connecting — ignoring duplicate request")
            return false
        }

        _connectionState.value = PtpConnectionState.Connecting
        val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager

        // (1) Verify permission
        if (!usbManager.hasPermission(device)) {
            transitionToError("No USB permission for ${device.productName}")
            return false
        }

        // (2) Open raw USB connection
        val conn = usbManager.openDevice(device)
        if (conn == null) {
            transitionToError("Failed to open USB device: ${device.productName}")
            return false
        }
        usbConnection = conn

        // (3) Open MTP device (this sends OpenSession internally)
        val mtp = MtpDevice(device)
        if (!mtp.open(conn)) {
            conn.close()
            usbConnection = null
            transitionToError("MTP open failed — is the camera in MTP/PTP mode?")
            return false
        }
        mtpDevice = mtp
        connectedDevice = device

        val deviceName = device.productName
            ?: mtp.deviceName
            ?: "Nikon Camera"

        addLog(PtpLogLevel.INFO, "PTP session opened: $deviceName")

        // (4) Seed known-object set with whatever is already on the camera
        seedKnownObjects(mtp)

        // (5) Create a fresh scope tied to the single-thread MTP dispatcher
        mtpScope?.cancel()
        mtpScope = CoroutineScope(mtpDispatcher + SupervisorJob())

        // (6) Start the event-polling loop
        startEventPolling(mtp, mtpScope!!)

        _connectionState.value = PtpConnectionState.Connected(deviceName)
        addLog(PtpLogLevel.INFO, "Listening for PTP events (ObjectAdded)…")
        return true
    }

    /**
     * Tear down the PTP session and release the USB connection.
     * Safe to call at any time (idempotent).
     */
    fun disconnect() {
        // Cancel the entire MTP scope — this cancels the event loop,
        // interrupts the CancellationSignal passed to readEvent(), and
        // prevents any in-flight download from touching the device.
        mtpScope?.cancel()
        mtpScope = null
        eventPollJob = null

        mtpDevice?.close()
        mtpDevice = null

        usbConnection?.close()
        usbConnection = null

        connectedDevice = null
        knownObjectHandles.clear()

        _connectionState.value = PtpConnectionState.Disconnected
        addLog(PtpLogLevel.INFO, "Disconnected")
    }

    /**
     * Clear the currently displayed image (e.g. user tapped "Clear").
     */
    fun clearImage() {
        _downloadedBitmap.value = null
        _lastTransferInfo.value = null
    }

    /** Directory where downloaded JPEGs are saved (project-scoped). */
    fun getDownloadDir(): File? {
        val ctx = appContext
        return currentProjectId?.let {
            File(File(ctx.getExternalFilesDir(null), "Projects"), it)
        } ?: File(ctx.getExternalFilesDir(null), "Downloads")
    }

    /**
     * List JPEGs currently on the camera.  Runs on [mtpDispatcher] so it is
     * serialised with the event loop — no concurrent MTP access.
     */
    fun listCameraPhotos(): List<Map<String, Any>> {
        val mtp = mtpDevice ?: return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        try {
            val storageIds = mtp.storageIds ?: intArrayOf()
            for (storageId in storageIds) {
                // 0x3801 = EXIF JPEG; 0 = all formats; 0 = root
                val handles = mtp.getObjectHandles(storageId, 0x3801, 0)
                    ?: continue
                for (handle in handles) {
                    val info = mtp.getObjectInfo(handle) ?: continue
                    result.add(mapOf(
                        "objectHandle" to handle,
                        "fileName" to (info.name ?: "unknown"),
                        "sizeBytes" to info.compressedSize,
                        "captureDate" to formatDate(info.dateCreated),
                        "formatCode" to info.format,
                    ))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "listCameraPhotos failed", e)
        }
        return result
    }

    /** List JPEGs already saved to local storage for a specific project or all. */
    fun listLocalPhotos(projectId: String? = null): List<Map<String, Any>> {
        val base = appContext.getExternalFilesDir(null) ?: return emptyList()
        val dir = projectId?.let {
            File(File(base, "Projects"), it)
        } ?: getDownloadDir() ?: return emptyList()
        Log.d(TAG, "listLocalPhotos: projectId=$projectId dir=${dir.absolutePath} exists=${dir.exists()}")
        if (!dir.exists()) return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        dir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".JPG", ignoreCase = true) ||
                file.name.endsWith(".JPEG", ignoreCase = true) ||
                file.name.endsWith(".NEF", ignoreCase = true)
            ) {
                result.add(mapOf(
                    "objectHandle" to file.absolutePath.hashCode(),
                    "localPath" to file.absolutePath,
                    "fileName" to file.name,
                    "sizeBytes" to file.length(),
                    "captureDate" to formatDate(file.lastModified()),
                    "isSynced" to true,
                ))
            }
        }
        result.sortByDescending { it["captureDate"] as? String ?: "" }
        return result
    }

    /** Scan ALL project directories + legacy Downloads for existing photos. */
    fun listAllLocalPhotos(): List<Map<String, Any>> {
        val base = appContext.getExternalFilesDir(null) ?: return emptyList()
        val result = mutableListOf<Map<String, Any>>()

        // Legacy Downloads
        val legacy = File(base, "Downloads")
        if (legacy.exists()) {
            legacy.listFiles()?.forEach { file ->
                if (file.name.endsWith(".JPG", true) || file.name.endsWith(".JPEG", true)) {
                    result.add(mapOf(
                        "objectHandle" to file.absolutePath.hashCode(),
                        "localPath" to file.absolutePath,
                        "fileName" to file.name,
                        "sizeBytes" to file.length(),
                        "captureDate" to formatDate(file.lastModified()),
                        "isSynced" to true,
                    ))
                }
            }
        }
        // Project dirs
        val projectsDir = File(base, "Projects")
        if (projectsDir.exists()) {
            projectsDir.listFiles()?.forEach { projectDir ->
                if (projectDir.isDirectory) {
                    projectDir.listFiles()?.forEach { file ->
                        if (file.name.endsWith(".JPG", true) || file.name.endsWith(".JPEG", true)) {
                            result.add(mapOf(
                                "objectHandle" to file.absolutePath.hashCode(),
                                "localPath" to file.absolutePath,
                                "fileName" to file.name,
                                "sizeBytes" to file.length(),
                                "captureDate" to formatDate(file.lastModified()),
                                "isSynced" to true,
                            ))
                        }
                    }
                }
            }
        }
        result.sortByDescending { it["captureDate"] as? String ?: "" }
        return result
    }

    /** Delete a locally-saved JPEG. */
    fun deleteLocalPhoto(filePath: String): Boolean {
        return try {
            File(filePath).delete()
        } catch (e: Exception) {
            Log.w(TAG, "deleteLocalPhoto failed", e)
            false
        }
    }

    /** Read EXIF tags from a local JPEG file. */
    fun getExifData(filePath: String): Map<String, String> {
        return try {
            val exif = android.media.ExifInterface(filePath)
            mapOf(
                "iso" to (exif.getAttribute("ISOSpeedRatings") ?: ""),
                "shutterSpeed" to (exif.getAttribute("ExposureTime") ?: ""),
                "aperture" to (exif.getAttribute("FNumber") ?: ""),
                "focalLength" to (exif.getAttribute("FocalLength") ?: ""),
                "dateTaken" to (exif.getAttribute("DateTime") ?: ""),
                "cameraModel" to (exif.getAttribute("Model") ?: ""),
                "imageWidth" to (exif.getAttribute("ImageWidth") ?: ""),
                "imageHeight" to (exif.getAttribute("ImageLength") ?: ""),
            )
        } catch (e: Exception) {
            Log.w(TAG, "getExifData failed", e)
            emptyMap()
        }
    }

    // ── private helpers ──────────────────────────────────────────────────────

    /** Record every object handle currently on the camera so we don't
     *  re-download them when ObjectAdded fires later. */
    private fun seedKnownObjects(mtp: MtpDevice) {
        try {
            val storageIds = mtp.storageIds ?: intArrayOf()
            for (storageId in storageIds) {
                val handles = mtp.getObjectHandles(storageId, 0, 0) ?: continue
                for (h in handles) {
                    knownObjectHandles.add(h)
                }
            }
            addLog(PtpLogLevel.INFO, "Seeded ${knownObjectHandles.size} existing object(s)")
        } catch (e: Exception) {
            Log.w(TAG, "seedKnownObjects failed", e)
        }
    }

    /**
     * Launch the long-running coroutine that polls [MtpDevice.readEvent].
     *
     * ALL MtpDevice operations happen on [mtpDispatcher] — the single-threaded
     * context created during [connect].  This eliminates the race condition
     * where [readEvent] and [getObject] contended for the USB bulk endpoint.
     */
    private fun startEventPolling(mtp: MtpDevice, scope: CoroutineScope) {
        eventPollJob?.cancel()
        eventPollJob = scope.launch {
            // CancellationSignal lets us interrupt the blocking readEvent()
            // call when disconnect() cancels this coroutine.
            val cancelSignal = CancellationSignal()
            coroutineContext.job.invokeOnCompletion { cancelSignal.cancel() }

            addLog(PtpLogLevel.INFO, "Event poller started")
            while (isActive) {
                try {
                    val event = mtp.readEvent(cancelSignal)
                    if (event != null) {
                        handleEvent(mtp, event)
                    }
                } catch (e: Exception) {
                    if (isActive) {
                        addLog(PtpLogLevel.ERROR, "readEvent error: ${e.message}")
                        Log.e(TAG, "readEvent exception", e)
                    }
                }
            }
            addLog(PtpLogLevel.INFO, "Event poller stopped")
        }
    }

    /** Dispatch a PTP event to the appropriate handler. */
    private suspend fun handleEvent(mtp: MtpDevice, event: MtpEvent) {
        val code = event.eventCode
        val p1 = event.parameter1

        when (code) {
            EVENT_OBJECT_ADDED -> {
                addLog(
                    PtpLogLevel.EVENT,
                    "ObjectAdded  handle=0x${p1.toString(16).uppercase()}  " +
                        "param2=0x${event.parameter2.toString(16)}  " +
                        "param3=0x${event.parameter3.toString(16)}"
                )
                onObjectAddedSync(mtp, p1)
            }

            EVENT_OBJECT_REMOVED -> {
                addLog(PtpLogLevel.EVENT, "ObjectRemoved  handle=0x${p1.toString(16).uppercase()}")
                knownObjectHandles.remove(p1)
                onObjectRemoved?.invoke(p1)
            }

            EVENT_STORE_ADDED -> {
                addLog(PtpLogLevel.EVENT, "StoreAdded  storageId=0x${p1.toString(16).uppercase()}")
            }

            EVENT_STORE_REMOVED -> {
                addLog(PtpLogLevel.EVENT, "StoreRemoved  storageId=0x${p1.toString(16).uppercase()}")
            }

            EVENT_DEVICE_PROP_CHANGED -> {
                addLog(
                    PtpLogLevel.EVENT,
                    "DevicePropChanged  property=0x${p1.toString(16).uppercase()}"
                )
            }

            else -> {
                addLog(
                    PtpLogLevel.EVENT,
                    "Event  code=0x${code.toString(16).uppercase()}  p1=0x${p1.toString(16).uppercase()}"
                )
            }
        }
    }

    /**
     * Handle ObjectAdded: if JPEG, download, downscale, display.
     *
     * Runs synchronously (suspend) on the MTP dispatcher thread — no nested
     * coroutine is launched, so the event loop naturally waits for the download
     * to finish before calling readEvent() again.  This guarantees MtpDevice
     * is never accessed concurrently.
     */
    private suspend fun onObjectAddedSync(mtp: MtpDevice, objectHandle: Int) {
        // Guard: already handled this object
        if (!knownObjectHandles.add(objectHandle)) {
            addLog(PtpLogLevel.INFO, "Object 0x${objectHandle.toString(16)} already known — skipping")
            return
        }

        try {
            // (A) Get object metadata
            val info: MtpObjectInfo = mtp.getObjectInfo(objectHandle)
                ?: run {
                    addLog(PtpLogLevel.ERROR,
                        "getObjectInfo(0x${objectHandle.toString(16)}) returned null")
                    return
                }

            val format = info.format
            val size = info.compressedSize
            val name = info.name ?: "untitled"

            addLog(
                PtpLogLevel.INFO,
                "Object info: name=$name  format=0x${format.toString(16).uppercase()}  " +
                    "size=${if (size > 0) "%,d bytes".format(size) else "unknown"}"
            )

            // (B) Filter: download JPEG and NEF raw
            val isNef = name.uppercase().endsWith(".NEF")
            if (format != FORMAT_EXIF_JPEG && format != FORMAT_JFIF_JPEG && !isNef) {
                addLog(PtpLogLevel.INFO,
                    "Skipping unsupported object (format=0x${format.toString(16).uppercase()})")
                return
            }
            val isRaw = isNef

            if (size <= 0) {
                addLog(PtpLogLevel.ERROR, "Invalid object size ($size) — cannot download")
                return
            }

            // (C) Download JPEG bytes over USB
            addLog(PtpLogLevel.INFO, "Downloading %,d bytes …".format(size))
            val jpegBytes: ByteArray? = mtp.getObject(objectHandle, size)

            if (jpegBytes == null || jpegBytes.isEmpty()) {
                addLog(PtpLogLevel.ERROR, "getObject returned empty data")
                return
            }

            // Smart cast: jpegBytes is now non-null ByteArray
            addLog(PtpLogLevel.INFO, "Received %,d bytes".format(jpegBytes.size))

            // (D) Decode or skip — NEF raw cannot be decoded by BitmapFactory
            val bitmap: Bitmap?
            val outWidth: Int
            val outHeight: Int
            if (isRaw) {
                bitmap = null
                outWidth = 0
                outHeight = 0
                addLog(PtpLogLevel.INFO, "NEF raw — saved without decoding")
            } else {
                bitmap = decodeSampledBitmap(jpegBytes, MAX_BITMAP_DIM)
                    ?: run {
                        addLog(PtpLogLevel.ERROR, "Bitmap decode failed")
                        return
                    }
                outWidth = bitmap.width
                outHeight = bitmap.height
            }

            // (E) Persist to app-private storage
            val savedPath = saveJpegToDisk(jpegBytes, name)

            // (F) Publish results on the main thread
            if (bitmap != null) {
                withContext(Dispatchers.Main) {
                    _downloadedBitmap.value = bitmap
                    _lastTransferInfo.value = buildString {
                        append("${bitmap.width} × ${bitmap.height}  ·  ")
                        append("%,d bytes".format(jpegBytes.size))
                        if (savedPath != null) append("  ·  saved")
                    }
                }
                addLog(PtpLogLevel.INFO,
                    "Displayed ${bitmap.width}×${bitmap.height} on screen")
            }

            // Notify Flutter bridge with the saved file path
            if (savedPath != null) {
                onJpegSaved?.invoke(
                    savedPath, objectHandle,
                    outWidth, outHeight, jpegBytes.size,
                    isRaw
                )
            }
        } catch (e: Exception) {
            addLog(PtpLogLevel.ERROR, "ObjectAdded handler error: ${e.message}")
            Log.e(TAG, "onObjectAddedSync failed", e)
        }
    }

    // ── Bitmap decoding with downscaling ─────────────────────────────────────

    /**
     * Decode a JPEG byte array into a [Bitmap], downscaling if necessary so
     * the longest side does not exceed [maxDim] pixels.
     *
     * High-resolution camera JPEGs easily exceed the per-process VM budget.
     * A two-pass approach is used: first decode-only-bounds to measure the
     * image, then compute [BitmapFactory.Options.inSampleSize] for the real
     * decode.  inSampleSize rounds *down* to the nearest power of two, which
     * is both fast (no interpolation at decode time) and memory-safe.
     */
    private fun decodeSampledBitmap(jpegBytes: ByteArray, maxDim: Int): Bitmap? {
        return try {
            val options = BitmapFactory.Options()

            // Pass 1: read dimensions only
            options.inJustDecodeBounds = true
            BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size, options)

            // Pass 2: compute sample size & decode for real
            options.inJustDecodeBounds = false
            options.inSampleSize = calculateInSampleSize(
                options.outWidth, options.outHeight, maxDim
            )

            BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size, options)
        } catch (e: OutOfMemoryError) {
            addLog(PtpLogLevel.ERROR, "OutOfMemoryError decoding JPEG — image too large")
            Log.e(TAG, "decodeSampledBitmap OOM", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "decodeSampledBitmap error", e)
            null
        }
    }

    /** Compute a power-of-two inSampleSize so (w/s, h/s) ≤ maxDim. */
    private fun calculateInSampleSize(
        width: Int, height: Int, maxDim: Int
    ): Int {
        var sampleSize = 1
        while (width / sampleSize > maxDim || height / sampleSize > maxDim) {
            sampleSize *= 2
        }
        return sampleSize
    }

    /**
     * Persist JPEG bytes to the app's private external files directory
     * (no extra permissions required).  Users can access these files via
     * the file manager under Android/data/com.cacl2.ztransfer/files/.
     */
    private fun saveJpegToDisk(jpegBytes: ByteArray, originalName: String): String? {
        return try {
            val ctx = appContext
            val projectId = currentProjectId
            Log.d(TAG, "saveJpegToDisk: currentProjectId=$projectId")
            // Save to project subdir if active; fall back to legacy Downloads
            val base = projectId?.let {
                File(File(ctx.getExternalFilesDir(null), "Projects"), it)
            } ?: File(ctx.getExternalFilesDir(null), "Downloads")
            if (!base.exists()) base.mkdirs()

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val ext = if (originalName.uppercase().endsWith(".NEF")) ".NEF" else ".JPG"
            val fileName = "NIKON_${timestamp}$ext"
            val file = File(base, fileName)

            FileOutputStream(file).use { it.write(jpegBytes) }
            SharedPhotoPublisher.publish(ctx, file)

            addLog(PtpLogLevel.INFO, "Saved: ${file.absolutePath} (%,d bytes)".format(file.length()))
            Log.d(TAG, "Saved JPEG to: ${file.absolutePath}")
            file.absolutePath
        } catch (e: Exception) {
            addLog(PtpLogLevel.ERROR, "Save to disk failed: ${e.message}")
            Log.e(TAG, "saveJpegToDisk error", e)
            null
        }
    }

    // ── utility ──────────────────────────────────────────────────────────────

    private fun transitionToError(reason: String) {
        addLog(PtpLogLevel.ERROR, reason)
        _connectionState.value = PtpConnectionState.Error(reason)
    }

    private fun addLog(level: PtpLogLevel, message: String) {
        Log.d(TAG, "[$level] $message")
        _eventLog.value = _eventLog.value + PtpLogEntry(level = level, message = message)
    }

    // ── PTP / MTP constants ──────────────────────────────────────────────────

    companion object {
        private const val TAG = "PtpManager"

        /** Nikon Corporation USB vendor ID. */
        const val NIKON_VENDOR_ID = 0x04B0

        // PTP Event codes (from USB PTP spec / MTP spec)
        private const val EVENT_OBJECT_ADDED          = 0x4002
        private const val EVENT_OBJECT_REMOVED        = 0x4003
        private const val EVENT_STORE_ADDED           = 0x4004
        private const val EVENT_STORE_REMOVED         = 0x4005
        private const val EVENT_DEVICE_PROP_CHANGED   = 0x4006

        // PTP Object Format codes
        private const val FORMAT_EXIF_JPEG = 0x3801   // JPEG (Exif) — most common
        private const val FORMAT_JFIF_JPEG = 0x3800   // JPEG (JFIF) — less common

        /** Longest edge in pixels for the displayed bitmap.
         *  Full 45 MP (8256×5504) decodes to ~180 MB uncompressed — fatal on
         *  most devices.  2048 px keeps memory under ~12 MB and looks sharp
         *  on the screen. */
        private const val MAX_BITMAP_DIM = 2048

        private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)

        private fun formatDate(millis: Long): String {
            return if (millis > 0) dateFormat.format(Date(millis)) else ""
        }
    }
}
