package com.cacl2.ztransfer.camera

import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.FileProvider
import com.cacl2.ztransfer.camera.transport.CameraTransport
import com.cacl2.ztransfer.camera.transport.PtpIpConstants
import com.cacl2.ztransfer.camera.transport.TransportEvent
import com.cacl2.ztransfer.camera.transport.TransportState
import com.cacl2.ztransfer.camera.transport.TransportType
import com.cacl2.ztransfer.camera.transport.UsbTransport
import com.cacl2.ztransfer.camera.transport.WifiTransport
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File

/**
 * Bridges Flutter's MethodChannel + EventChannel to the active
 * [CameraTransport] (USB or Wi-Fi).
 *
 * ## Responsibilities
 * - **MethodChannel** — dispatches method calls to the active transport
 *   or to local services (ProjectStore, EXIF, sharing)
 * - **EventChannel** — merges [TransportEvent]s from both transports
 *   and pushes them to Flutter in real time
 *
 * The transport is selected automatically on connect (USB first, then
 * Wi-Fi fallback) or explicitly via the `transportType` argument.
 */
class CameraChannelHandler(
    private val context: Context
) {
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())

    val projectStore = ProjectStore(context)
    val profileStore = CameraProfileStore(context)
    val usbTransport = UsbTransport(context)
    val wifiTransport = WifiTransport(context)


    private var eventSink: EventChannel.EventSink? = null
    private var eventCollectionJob: Job? = null
    private var transferJob: Job? = null
    private var channelRegistrationGeneration = 0L

    /** Currently active transport. Null when disconnected. */
    @Volatile
    private var activeTransport: CameraTransport? = null

    // ── Channel registration ──────────────────────────────────────────────

    fun register(
        methodBinaryMessenger: BinaryMessenger,
        eventBinaryMessenger: BinaryMessenger,
    ) {
        val registrationGeneration = ++channelRegistrationGeneration
        // Migrate legacy photos on first launch (non-blocking)
        scope.launch(Dispatchers.IO) {
            projectStore.migrateIfNeeded()
            SharedPhotoPublisher.publishExistingPhotos(context)
        }

        // ── MethodChannel ──────────────────────────────────────────────────
        val methodChannel = MethodChannel(
            methodBinaryMessenger, CHANNEL_NAME
        )
        methodChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        // ── EventChannel ───────────────────────────────────────────────────
        val eventChannel = EventChannel(
            eventBinaryMessenger, EVENT_CHANNEL_NAME
        )
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (registrationGeneration != channelRegistrationGeneration) return
                Log.d(TAG, "EventChannel onListen — sink=${events != null}")
                eventSink = events
                startEventForwarding()
            }

            override fun onCancel(arguments: Any?) {
                if (registrationGeneration != channelRegistrationGeneration) return
                Log.d(TAG, "EventChannel onCancel")
                eventSink = null
                eventCollectionJob?.cancel()
            }
        })
    }

    // ── Event forwarding (TransportEvent → EventSink) ────────────────────

    private fun startEventForwarding() {
        eventCollectionJob?.cancel()
        eventCollectionJob = scope.launch {
            merge(
                usbTransport.events,
                wifiTransport.events
            ).collect { event ->
                val map = transportEventToMap(event)
                mainHandler.post {
                    eventSink?.success(map)
                }
            }
        }
    }

    /** Convert a [TransportEvent] to the Map format expected by Flutter. */
    private fun transportEventToMap(event: TransportEvent): Map<String, Any?> {
        return when (event) {
            is TransportEvent.ObjectAdded -> mapOf(
                "type" to "objectAdded",
                "objectHandle" to event.objectHandle,
                "formatCode" to event.formatCode,
                "fileName" to event.fileName,
                "sizeBytes" to event.sizeBytes,
                "localPath" to event.localPath,
                "width" to event.width,
                "height" to event.height,
                "isRaw" to event.isRaw
            )
            is TransportEvent.ObjectRemoved -> mapOf(
                "type" to "objectRemoved",
                "objectHandle" to event.objectHandle
            )
            is TransportEvent.ConnectionStateChanged -> mapOf(
                "type" to "connectionStateChanged",
                "connected" to event.connected,
                "deviceName" to (event.deviceName ?: ""),
                "transportType" to event.transportType.name
            )
            is TransportEvent.BatteryChanged -> mapOf(
                "type" to "batteryChanged",
                "level" to event.level
            )
            is TransportEvent.StorageChanged -> mapOf(
                "type" to "storageChanged",
                "freeSpaceBytes" to event.freeSpaceBytes,
                "maxCapacityBytes" to event.maxCapacityBytes,
                "freeImages" to event.freeImages
            )
            is TransportEvent.TransferProgress -> mapOf(
                "type" to "transferProgress",
                "objectHandle" to event.objectHandle,
                "progress" to event.progress,
                "bytesTransferred" to event.bytesTransferred,
                "totalBytes" to event.totalBytes,
                "bytesPerSecond" to event.bytesPerSecond,
            )
            is TransportEvent.TransferStateChanged -> mapOf(
                "type" to "transferStateChanged",
                "listening" to event.listening,
            )
            is TransportEvent.Log -> mapOf(
                "type" to "log",
                "level" to event.level,
                "message" to event.message,
                "category" to event.category
            )
        }
    }

    // ── MethodCall dispatch ───────────────────────────────────────────────

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                if (call.method in PROJECT_REQUIRED_METHODS && !ensureProjectForConnection()) {
                    emitChannelLog(PROJECT_REQUIRED_MESSAGE, "PROJECT", "WARN")
                    result.error("PROJECT_REQUIRED", PROJECT_REQUIRED_MESSAGE, null)
                    return@launch
                }
                when (call.method) {

                    // ── Connection ─────────────────────────────────────────

                    "isConnected" -> {
                        val connected = activeTransport?.isConnected == true ||
                            usbTransport.isConnected || wifiTransport.isConnected
                        result.success(connected)
                    }

                    "connect" -> {
                        val transportTypeStr = call.argument<String>("transportType")
                        val transportType = transportTypeStr?.let {
                            try { TransportType.valueOf(it) }
                            catch (_: Exception) { null }
                        }
                        val r = connectAuto(prefer = transportType)
                        if (r.ok) {
                            result.success(mapOf(
                                "deviceName" to r.deviceName,
                                "transportType" to r.transportType.name,
                                "ipAddress" to (r.ipAddress ?: "")
                            ))
                        } else {
                            result.success(null)
                        }
                    }

                    "connectAuto" -> {
                        val r = connectAuto(prefer = null)
                        if (r.ok) {
                            result.success(mapOf(
                                "deviceName" to r.deviceName,
                                "transportType" to r.transportType.name,
                                "ipAddress" to (r.ipAddress ?: "")
                            ))
                        } else {
                            result.success(null)
                        }
                    }


                    "connectWifi" -> {
                        val host = call.argument<String>("host") ?: "192.168.1.1"
                        val profileId = call.argument<String>("profileId")
                        scope.launch(Dispatchers.IO) {
                            stopWirelessTransfer()
                            activeTransport?.disconnect(); activeTransport = null
                            var targetHost = host
                            if (host == "192.168.1.1" || host.isBlank()) {
                                val mdns = com.cacl2.ztransfer.camera.transport.CameraMdnsDiscovery.discover(context)
                                if (mdns != null) { targetHost = mdns.host }
                            }

                            // The reference flow reuses the active camera profile and its exact
                            // initiator GUID/name. Pair only when no matching profile exists.
                            val saved = findWifiProfile(targetHost, profileId)
                            if (saved != null) {
                                if (!profileId.isNullOrBlank()) {
                                    profileStore.setActiveProfile(saved.id)
                                }
                                loadWifiProfile(saved)
                                val ok = wifiTransport.connectForTransfer(targetHost)
                                if (ok) {
                                    profileStore.recordConnection(
                                        saved.id,
                                        targetHost,
                                        wifiTransport.cameraName,
                                    )
                                    activeTransport = wifiTransport
                                    syncProjectId()
                                    result.success(mapOf(
                                        "deviceName" to wifiTransport.cameraName,
                                        "transportType" to "WIFI",
                                        "ipAddress" to targetHost,
                                        "profileId" to saved.id,
                                        "needsPairing" to false,
                                    ))
                                } else {
                                    Log.w(TAG, "Saved Wi-Fi profile failed to reconnect: ${saved.id}")
                                    result.success(null)
                                }
                                return@launch
                            }

                            // First-time path: handshake → GetDeviceInfo → OpenSession → GetPairingCode.
                            val code = wifiTransport.startPairing(targetHost)
                            if (code != null) {
                                activeTransport = wifiTransport; syncProjectId()
                                result.success(mapOf(
                                    "deviceName" to wifiTransport.cameraName,
                                    "transportType" to "WIFI",
                                    "ipAddress" to targetHost,
                                    "needsPairing" to true,
                                    "pairingCode" to code
                                ))
                            } else {
                                result.success(null)
                            }
                        }
                    }

                    "connectTransfer" -> {
                        val host = call.argument<String>("host") ?: "192.168.1.1"
                        val profileId = call.argument<String>("profileId")
                        scope.launch(Dispatchers.IO) {
                            stopWirelessTransfer()
                            activeTransport?.disconnect(); activeTransport = null
                            var targetHost = host
                            if (host == "192.168.1.1" || host.isBlank()) {
                                val mdns = com.cacl2.ztransfer.camera.transport.CameraMdnsDiscovery.discover(context)
                                if (mdns != null) { targetHost = mdns.host }
                            }
                            val saved = findWifiProfile(targetHost, profileId)
                            if (saved == null) {
                                Log.w(TAG, "No pairing profile available for $targetHost")
                                result.success(null)
                                return@launch
                            }
                            loadWifiProfile(saved)
                            if (!profileId.isNullOrBlank()) {
                                profileStore.setActiveProfile(saved.id)
                            }
                            // Reference flow: fresh sockets → GetDeviceInfo → OpenSession.
                            // Application Mode is deliberately not changed in the transfer session.
                            val ok = wifiTransport.connectForTransfer(targetHost)
                            if (ok) {
                                profileStore.recordConnection(
                                    saved.id,
                                    targetHost,
                                    wifiTransport.cameraName,
                                )
                                activeTransport = wifiTransport; syncProjectId()
                                result.success(mapOf(
                                    "deviceName" to wifiTransport.cameraName,
                                    "transportType" to "WIFI",
                                    "ipAddress" to targetHost,
                                    "profileId" to saved.id,
                                    "needsPairing" to false
                                ))
                            } else {
                                result.success(null)
                            }
                        }
                    }

                    "completePairing" -> {
                        scope.launch(Dispatchers.IO) {
                            try {
                                val targetHost = wifiTransport.currentHost
                                val paired = wifiTransport.confirmPairingAndClose()
                                val profile = if (paired) buildCameraProfile(targetHost) else null
                                activeTransport = null
                                if (profile == null) {
                                    result.success(mapOf(
                                        "ok" to false,
                                        "connected" to false,
                                        "error" to "配对确认失败",
                                    ))
                                    return@launch
                                }

                                // Some cameras acknowledge the app request before
                                // their on-device OK is pressed. Keep the method call
                                // pending until the saved GUID opens a fresh transfer
                                // session, which is the authoritative completion signal.
                                val connected = connectWifiAfterPairing(profile, targetHost)
                                if (connected) {
                                    profileStore.saveProfile(profile)
                                    profileStore.recordConnection(
                                        profile.id,
                                        targetHost,
                                        wifiTransport.cameraName,
                                    )
                                    activeTransport = wifiTransport
                                    syncProjectId()
                                }
                                result.success(mapOf(
                                    "ok" to connected,
                                    "deviceName" to wifiTransport.cameraName,
                                    "connected" to connected,
                                    "error" to if (connected) "" else
                                        "等待相机确认超时，请重新配对并在相机上按 OK",
                                ))
                            } catch (e: Exception) {
                                Log.e(TAG, "completePairing error", e)
                                activeTransport = null
                                result.success(mapOf("ok" to false, "error" to e.message))
                            }
                        }
                    }

                    "listCameraProfiles" -> {
                        val activeProfileId = profileStore.getActiveProfile()?.id
                        result.success(
                            profileStore.loadAll()
                                .sortedByDescending { it.timestamp }
                                .map { profile ->
                                    mapOf(
                                        "id" to profile.id,
                                        "cameraName" to profile.cameraName,
                                        "lastIp" to profile.lastIp,
                                        "port" to profile.port,
                                        "timestamp" to profile.timestamp,
                                        "verified" to profile.verified,
                                        "active" to (profile.id == activeProfileId),
                                    )
                                },
                        )
                    }

                    "deleteCameraProfile" -> {
                        val id = call.argument<String>("id").orEmpty()
                        if (id.isBlank()) {
                            result.success(false)
                        } else {
                            profileStore.removeProfile(id)
                            result.success(true)
                        }
                    }

                    "runCompatibilityCheck" -> {
                        val profileIp = call.argument<String>("ip") ?: ""
                        scope.launch(Dispatchers.IO) {
                            try {
                                val profile = findWifiProfile(profileIp)
                                if (profile != null) loadWifiProfile(profile)
                                stopWirelessTransfer()
                                activeTransport?.disconnect(); activeTransport = null
                                mainHandler.post {
                                    eventSink?.success(mapOf("type" to "checkProgress", "status" to "正在连接相机..."))
                                }
                                val connected = profile != null &&
                                    connectWifiWithRetries(profile, profileIp)
                                if (!connected) {
                                    result.success(mapOf("ok" to false, "error" to "连接失败"))
                                    return@launch
                                }
                                mainHandler.post {
                                    eventSink?.success(mapOf("type" to "checkProgress", "status" to "正在检测兼容性..."))
                                }
                                if (profile != null) {
                                    profileStore.markVerified(profile.id)
                                    activeTransport = wifiTransport
                                    syncProjectId()
                                    result.success(mapOf(
                                        "ok" to true,
                                        "deviceName" to wifiTransport.cameraName
                                    ))
                                } else {
                                    result.success(mapOf("ok" to false, "error" to "无法进入传输模式"))
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "runCompatibilityCheck error", e)
                                result.success(mapOf("ok" to false, "error" to e.message))
                            }
                        }
                    }

                    "enableTransferMode" -> {
                        // Kept for older Flutter callers. The current transfer flow skips this
                        // operation in the wireless picture-transfer session.
                        result.success(wifiTransport.isConnected)
                    }

                    "startTransfer" -> {
                        if (activeTransport !== wifiTransport || !wifiTransport.isConnected) {
                            result.success(mapOf("count" to 0, "status" to "not_connected"))
                        } else if (transferJob?.isActive == true) {
                            result.success(mapOf("count" to 0, "status" to "already_running"))
                        } else {
                            val saveDir = getActiveSaveDir()
                            val newJob = scope.launch(Dispatchers.IO) {
                                runContinuousWifiTransfer(saveDir)
                            }
                            transferJob = newJob
                            newJob.invokeOnCompletion {
                                mainHandler.post {
                                    if (transferJob === newJob) transferJob = null
                                }
                            }
                            result.success(mapOf("count" to 0, "status" to "started"))
                        }
                    }

                    "stopTransfer" -> {
                        val wasRunning = transferJob?.isActive == true
                        val stopped = withContext(Dispatchers.IO) { stopWirelessTransfer() }
                        val status = when {
                            !wasRunning -> "not_running"
                            stopped -> "stopped"
                            else -> "stop_failed"
                        }
                        result.success(mapOf("status" to status))
                    }

                    "getTransferStatus" -> {
                        val diagnostics = wifiTransport.getSessionDiagnostics()
                        result.success(mapOf(
                            "listening" to (transferJob?.isActive == true),
                            "bytesPerSecond" to
                                (diagnostics["transferRateBytesPerSecond"] as? Double ?: 0.0),
                            "progress" to
                                (diagnostics["transferProgress"] as? Double ?: 0.0),
                            "bytesTransferred" to
                                (diagnostics["transferBytes"] as? Long ?: 0L),
                            "totalBytes" to
                                (diagnostics["transferTotalBytes"] as? Long ?: 0L),
                        ))
                    }

                    "getPairingCode" -> {
                        scope.launch(Dispatchers.IO) {
                            try {
                                val code = wifiTransport.getPairingCode()
                                result.success(mapOf("code" to code))
                            } catch (e: Exception) {
                                Log.e(TAG, "getPairingCode error", e)
                                result.success(null)
                            }
                        }
                    }

                    "confirmPairing" -> {
                        scope.launch(Dispatchers.IO) {
                            try {
                                val ok = wifiTransport.confirmPairingAndClose()
                                if (ok) saveCameraProfile()
                                activeTransport = null
                                result.success(ok)
                            } catch (e: Exception) {
                                Log.e(TAG, "confirmPairing error", e)
                                result.success(false)
                            }
                        }
                    }

                    "networkProbe" -> {
                        scope.launch(Dispatchers.IO) {
                            try {
                                val probeResult = com.cacl2.ztransfer.camera.transport.NetworkProbe.probe(
                                    context
                                ) { status ->
                                    mainHandler.post {
                                        eventSink?.success(mapOf(
                                            "type" to "probeProgress",
                                            "status" to status
                                        ))
                                    }
                                }
                                result.success(mapOf(
                                    "summary" to probeResult.toSummary(),
                                    "wifiSsid" to (probeResult.wifiSsid ?: ""),
                                    "localIp" to (probeResult.localIp ?: ""),
                                    "mdnsCount" to probeResult.mdnsServices.size,
                                    "portsCount" to probeResult.openPorts.size,
                                    "mdnsServices" to probeResult.mdnsServices.map {
                                        mapOf("name" to it.name, "type" to it.type,
                                              "host" to it.host, "port" to it.port)
                                    },
                                    "openPorts" to probeResult.openPorts.map {
                                        mapOf("host" to it.host, "port" to it.port,
                                              "protocol" to it.protocol)
                                    }
                                ))
                            } catch (e: Exception) {
                                Log.e(TAG, "networkProbe error", e)
                                result.success(null)
                            }
                        }
                    }

                    "scanCamera" -> {
                        scope.launch(Dispatchers.IO) {
                            try {
                                // Start mDNS and TCP subnet discovery together. Previously
                                // mDNS consumed the Flutter-side 15-second timeout before
                                // the subnet scanner was even started.
                                val mdnsDeferred = async {
                                    com.cacl2.ztransfer.camera.transport.CameraMdnsDiscovery.discover(
                                        context
                                    )
                                }
                                val scanned = com.cacl2.ztransfer.camera.transport.CameraScanner.scan(
                                    context
                                )
                                if (scanned != null) {
                                    mdnsDeferred.cancel()
                                    wifiTransport.rememberDiscoveredRoute(
                                        scanned.cameraIp,
                                        scanned.localIp,
                                    )
                                    result.success(mapOf(
                                        "ip" to scanned.cameraIp,
                                        "cameraName" to scanned.cameraName,
                                        "method" to "scan"
                                    ))
                                    return@launch
                                }

                                val mdns = mdnsDeferred.await()
                                if (mdns != null) {
                                    wifiTransport.rememberDiscoveredRoute(mdns.host, mdns.localIp)
                                }
                                result.success(
                                    mdns?.let {
                                        mapOf(
                                            "ip" to it.host,
                                            "cameraName" to it.name,
                                            "method" to "mdns"
                                        )
                                    }
                                )
                            } catch (e: Exception) {
                                Log.e(TAG, "scanCamera error", e)
                                result.success(null)
                            }
                        }
                    }

                    "disconnect" -> {
                        val disconnected = withContext(Dispatchers.IO) {
                            // The transfer coroutine is the only command-socket reader. Let it
                            // consume Nikon's TransactionCancelled response before CloseSession;
                            // stopWirelessTransfer force-releases an unresponsive session.
                            stopWirelessTransfer()
                            val transport = activeTransport
                                ?: wifiTransport.takeIf { it.isConnected }
                                ?: usbTransport.takeIf { it.isConnected }
                                ?: return@withContext true
                            transport.disconnect()
                            activeTransport = null
                            true
                        }
                        result.success(disconnected)
                    }

                    "getTransportType" -> {
                        result.success(activeTransport?.transportType?.name)
                    }

                    "getCameraName" -> {
                        result.success(activeTransport?.cameraName)
                    }

                    // ── Photo operations ───────────────────────────────────

                    "listCameraPhotos" -> {
                        scope.launch(Dispatchers.IO) {
                            val transport = activeTransport
                            if (transport != null) {
                                val photos = transport.listPhotos()
                                val maps = photos.map { p ->
                                    mapOf(
                                        "objectHandle" to p.objectHandle,
                                        "fileName" to p.fileName,
                                        "sizeBytes" to p.sizeBytes,
                                        "formatCode" to p.formatCode,
                                        "captureDate" to (p.captureDate?.let {
                                            // Format as same string format PtpManager used
                                            val sdf = java.text.SimpleDateFormat(
                                                "yyyy-MM-dd HH:mm:ss",
                                                java.util.Locale.US
                                            )
                                            sdf.format(java.util.Date(it))
                                        } ?: "")
                                    )
                                }
                                result.success(maps)
                            } else {
                                result.success(emptyList<Map<String, Any>>())
                            }
                        }
                    }

                    "downloadPhoto" -> {
                        val handle = call.argument<Int>("objectHandle") ?: 0
                        scope.launch(Dispatchers.IO) {
                            val transport = activeTransport
                            if (transport != null) {
                                val path = transport.downloadAndSave(
                                    handle = handle,
                                    fileName = "manual_download",
                                    saveDir = getActiveSaveDir()
                                )
                                result.success(path)
                            } else {
                                result.success(null)
                            }
                        }
                    }

                    // ── Local photo methods (unchanged) ────────────────────

                    "listLocalPhotos" -> {
                        val projectId = call.argument<String>("projectId")
                        scope.launch(Dispatchers.IO) {
                            val photos = listLocalPhotos(projectId)
                            result.success(photos)
                        }
                    }

                    "listAllLocalPhotos" -> {
                        scope.launch(Dispatchers.IO) {
                            val photos = listAllLocalPhotos()
                            result.success(photos)
                        }
                    }

                    "deleteLocalPhoto" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val ok = deleteLocalPhoto(filePath)
                        result.success(ok)
                    }

                    "getExifData" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val exif = getExifData(filePath)
                        result.success(exif)
                    }

                    "shareFile" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        Log.d(TAG, "shareFile called: $filePath")
                        shareSingleFile(filePath)
                        result.success(true)
                    }

                    "shareMultipleFiles" -> {
                        val paths = call.argument<List<String>>("filePaths")
                            ?: emptyList()
                        Log.d(TAG, "shareMultipleFiles called: ${paths.size} files")
                        shareMultipleFiles(paths)
                        result.success(true)
                    }

                    "deleteMultiplePhotos" -> {
                        val paths = call.argument<List<String>>("filePaths")
                            ?: emptyList()
                        val count = paths.count { deleteLocalPhoto(it) }
                        // Update project photo counts
                        val byProject = paths.groupBy { path ->
                            File(path).parentFile?.name ?: ""
                        }
                        byProject.forEach { (projectId, projectPaths) ->
                            if (projectId.isNotEmpty()) {
                                projectStore.onPhotoDeleted(projectId, projectPaths.size)
                            }
                        }
                        result.success(count)
                    }

                    // ── Project CRUD (unchanged) ───────────────────────────

                    "listProjects" -> {
                        val projects = projectStore.listProjects().map { p ->
                            mapOf(
                                "id" to p.id,
                                "name" to p.name,
                                "coverPhotoPath" to (p.coverPhotoPath ?: ""),
                                "createdAt" to p.createdAt,
                                "updatedAt" to p.updatedAt,
                                "photoCount" to p.photoCount,
                            )
                        }
                        result.success(projects)
                    }

                    "createProject" -> {
                        val name = call.argument<String>("name") ?: "Untitled"
                        val p = projectStore.createProject(name)
                        result.success(mapOf(
                            "id" to p.id, "name" to p.name,
                            "createdAt" to p.createdAt, "updatedAt" to p.updatedAt,
                            "photoCount" to p.photoCount,
                        ))
                    }

                    "updateProject" -> {
                        val id = call.argument<String>("id") ?: ""
                        val name = call.argument<String>("name") ?: ""
                        val p = projectStore.updateProject(id, name)
                        result.success(p != null)
                    }

                    "deleteProject" -> {
                        val id = call.argument<String>("id") ?: ""
                        val deletePhotos = call.argument<Boolean>("deletePhotos")
                            ?: false
                        val ok = projectStore.deleteProject(id, deletePhotos)
                        if (ok && projectStore.listProjects().isEmpty()) {
                            withContext(Dispatchers.IO) {
                                runCatching { stopWirelessTransfer() }
                                    .onFailure { Log.w(TAG, "Failed to stop transfer after deleting last project", it) }
                                val transport = activeTransport
                                activeTransport = null
                                runCatching { transport?.disconnect() }
                                    .onFailure { Log.w(TAG, "Failed to disconnect after deleting last project", it) }
                            }
                            syncProjectId()
                            emitChannelLog(
                                "最后一个项目已删除，相机连接已断开",
                                "PROJECT",
                                "WARN",
                            )
                        }
                        result.success(ok)
                    }

                    "setActiveProject" -> {
                        val id = call.argument<String>("id") ?: ""
                        val finalId = id.ifEmpty { null }
                        projectStore.setActiveProjectId(finalId)
                        // Sync to USB transport's save directory
                        context.getSharedPreferences("ztransfer", Context.MODE_PRIVATE)
                            .edit().putString("active_project_id", finalId).apply()
                        result.success(true)
                    }

                    "getActiveProject" -> {
                        val id = projectStore.getActiveProjectId()
                        if (id != null) {
                            val p = projectStore.getProject(id)
                            result.success(if (p != null) mapOf(
                                "id" to p.id, "name" to p.name,
                                "coverPhotoPath" to (p.coverPhotoPath ?: ""),
                                "createdAt" to p.createdAt,
                                "updatedAt" to p.updatedAt,
                                "photoCount" to p.photoCount,
                            ) else null)
                        } else {
                            result.success(null)
                        }
                    }

                    // ── Device properties ──────────────────────────────────

                    "getBatteryLevel" -> {
                        scope.launch(Dispatchers.IO) {
                            val level = activeTransport?.getBatteryLevel()
                            result.success(level)
                        }
                    }

                    "getStorageInfo" -> {
                        scope.launch(Dispatchers.IO) {
                            val info = activeTransport?.getStorageInfo()
                            if (info != null) {
                                result.success(mapOf(
                                    "freeSpaceBytes" to info.freeSpaceBytes,
                                    "maxCapacityBytes" to info.maxCapacityBytes,
                                    "freeImages" to info.freeImages
                                ))
                            } else {
                                result.success(null)
                            }
                        }
                    }

                    "getSessionDiagnostics" -> {
                        val diag = activeTransport?.getSessionDiagnostics()
                            ?: emptyMap()
                        result.success(diag)
                    }

                    // ── Wi-Fi specific ─────────────────────────────────────

                    "setWifiHost" -> {
                        val host = call.argument<String>("host") ?: ""
                        val port = call.argument<Int>("port") ?: 15740
                        // Recreate WifiTransport with custom host
                        // (wifiTransport is val — we update internal state)
                        Log.d(TAG, "setWifiHost: $host:$port — requires reconnect")
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "MethodCall error: ${call.method}", e)
                result.error("CHANNEL_ERROR", e.message, null)
            }
        }
    }

    // ── Connection logic ──────────────────────────────────────────────────

    /**
     * Ensures every camera session has a valid destination project.
     *
     * USB attach events call this directly; MethodChannel connection methods
     * are guarded in [handleMethodCall]. If projects exist but the saved active
     * ID is missing or stale, the newest project becomes active automatically.
     */
    fun ensureProjectForConnection(): Boolean {
        val projectIds = projectStore.listProjects().map { it.id }
        val currentProjectId = projectStore.getActiveProjectId()
        val selectedId = ProjectConnectionPolicy.selectActiveProjectId(
            projectIds,
            currentProjectId,
        ) ?: return false
        if (selectedId != currentProjectId) {
            projectStore.setActiveProjectId(selectedId)
        }
        syncProjectId()
        return true
    }

    private data class ConnectResult(
        val ok: Boolean,
        val deviceName: String?,
        val transportType: TransportType,
        val ipAddress: String? = null
    )

    /**
     * Auto-connect: try USB first, fall back to Wi-Fi.
     *
     * @param prefer If non-null, try this transport first instead of USB.
     */
    private suspend fun connectAuto(
        prefer: TransportType?
    ): ConnectResult {
        stopWirelessTransfer()
        // Disconnect any existing session
        activeTransport?.let {
            activeTransport = null
            kotlinx.coroutines.withContext(Dispatchers.IO) { it.disconnect() }
        }

        val first = prefer ?: TransportType.USB
        val second = if (first == TransportType.USB) TransportType.WIFI
                     else TransportType.USB

        fun buildResult(transport: CameraTransport, type: TransportType): ConnectResult {
            activeTransport = transport
            syncProjectId()
            val ip = if (type == TransportType.WIFI) {
                (transport as? WifiTransport)?.getSessionDiagnostics()?.get("host") as? String
            } else null
            return ConnectResult(true, transport.cameraName, type, ip)
        }

        suspend fun tryConnect(type: TransportType): Pair<CameraTransport, Boolean> {
            val transport: CameraTransport = when (type) {
                TransportType.USB -> usbTransport
                TransportType.WIFI -> wifiTransport
            }
            val connected = withContext(Dispatchers.IO) {
                if (type == TransportType.WIFI) {
                    val profile = profileStore.getActiveProfile()
                        ?.takeIf { isValidWifiProfile(it) }
                        ?: return@withContext false
                    loadWifiProfile(profile)
                    val profileHost = profile.lastIp.ifBlank { wifiTransport.currentHost }
                    wifiTransport.connectForTransfer(profileHost).also { ok ->
                        if (ok) {
                            profileStore.recordConnection(
                                profile.id,
                                profileHost,
                                wifiTransport.cameraName,
                            )
                        }
                    }
                } else {
                    transport.connect()
                }
            }
            return transport to connected
        }

        // Try first transport
        val (firstTransport, firstOk) = tryConnect(first)
        if (firstOk) {
            return buildResult(firstTransport, first)
        }

        // Try second transport
        val (secondTransport, secondOk) = tryConnect(second)
        if (secondOk) {
            return buildResult(secondTransport, second)
        }

        return ConnectResult(false, null, TransportType.USB)
    }

    private fun buildCameraProfile(
        host: String = wifiTransport.currentHost,
    ): CameraProfile {
        val clientGuidHex = wifiTransport.getClientGuidHex()
        return CameraProfile(
            id = wifiTransport.cameraGuid,
            cameraName = wifiTransport.cameraName ?: "Nikon",
            cameraGuidHex = wifiTransport.cameraGuid,
            lastIp = host,
            port = 15740,
            clientGuidHex = clientGuidHex,
            initiatorName = wifiTransport.currentInitiatorName,
            timestamp = System.currentTimeMillis()
        )
    }

    private fun saveCameraProfile(): CameraProfile {
        val profile = buildCameraProfile()
        profileStore.saveProfile(profile)
        Log.d(TAG, "Camera profile saved: ${profile.cameraName}, guid=${profile.clientGuidHex}")
        return profile
    }

    private fun findWifiProfile(host: String, profileId: String? = null): CameraProfile? {
        val valid = profileStore.loadAll().filter(::isValidWifiProfile)

        if (!profileId.isNullOrBlank()) {
            return valid.firstOrNull { it.id == profileId }
        }

        valid.firstOrNull { it.lastIp == host }?.let { return it }

        // A DHCP change is safe to handle automatically when there is only one
        // paired camera. With multiple profiles the caller must provide an id,
        // otherwise sending the wrong initiator GUID can force a new pairing.
        if (valid.size == 1) return valid.single()

        val activeId = profileStore.getActiveProfileId()
        return valid.firstOrNull { it.id == activeId && it.lastIp.isBlank() }
    }

    private fun isValidWifiProfile(profile: CameraProfile): Boolean {
        return profile.clientGuidHex.length == 32 &&
            profile.clientGuidHex.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' } &&
            profile.cameraGuidHex.length == 32
    }

    private fun loadWifiProfile(profile: CameraProfile) {
        wifiTransport.loadProfile(
            clientGuidHex = profile.clientGuidHex,
            savedInitiatorName = profile.initiatorName.ifBlank { "ZTransfer" },
            cameraGuidHex = profile.cameraGuidHex,
        )
    }

    private suspend fun connectWifiWithRetries(
        profile: CameraProfile,
        host: String,
    ): Boolean {
        loadWifiProfile(profile)
        repeat(PtpIpConstants.MAX_RECONNECT_ATTEMPTS) { attempt ->
            if (!currentCoroutineContext().isActive) return false
            if (attempt > 0) delay(PtpIpConstants.RECONNECT_BACKOFF_MS)
            if (wifiTransport.connectForTransfer(host)) {
                profileStore.recordConnection(profile.id, host, wifiTransport.cameraName)
                return true
            }
        }
        return false
    }

    private suspend fun connectWifiAfterPairing(
        profile: CameraProfile,
        host: String,
    ): Boolean {
        loadWifiProfile(profile)
        val deadline =
            System.currentTimeMillis() + PtpIpConstants.PAIRING_FINALIZE_TIMEOUT_MS
        var attempt = 0

        while (
            currentCoroutineContext().isActive &&
            System.currentTimeMillis() < deadline
        ) {
            if (attempt > 0) {
                delay(PtpIpConstants.PAIRING_RECONNECT_INTERVAL_MS)
            }
            attempt++
            val connected = wifiTransport.connectForTransfer(
                ip = host,
                reportFailure = false,
                connectTimeoutMs = PtpIpConstants.PAIRING_RECONNECT_CONNECT_TIMEOUT_MS,
                commandTimeoutMs = PtpIpConstants.PAIRING_RECONNECT_COMMAND_TIMEOUT_MS,
            )
            if (connected) {
                Log.d(TAG, "Camera-side pairing confirmed after $attempt transfer attempt(s)")
                return true
            }
        }

        Log.w(TAG, "Timed out waiting for camera-side pairing confirmation")
        return false
    }

    private suspend fun runContinuousWifiTransfer(saveDir: File) {
        var saved = 0
        var skipped = 0
        wifiTransport.beginContinuousTransfer()
        emitChannelLog("已开始无线图片监听；请在相机上选择发送到计算机", "TRANSFER")
        try {
            while (currentCoroutineContext().isActive) {
                try {
                    val record = wifiTransport.waitForNextPhoto()
                    if (record == null) {
                        delay(250)
                        continue
                    }
                    when (wifiTransport.downloadTransferRecord(record, saveDir)) {
                        is WifiTransport.DownloadOutcome.Saved -> saved++
                        is WifiTransport.DownloadOutcome.SkippedDuplicate -> skipped++
                    }
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (error: Exception) {
                    if (!currentCoroutineContext().isActive ||
                        wifiTransport.isTransferStopRequested
                    ) {
                        throw CancellationException("无线图片监听已取消")
                    }
                    if (!wifiTransport.isRecoverableConnectionFailure(error)) {
                        emitChannelLog(
                            "无线图片监听已停止：${error.message ?: error.javaClass.simpleName}",
                            "TRANSFER",
                            "ERROR",
                        )
                        break
                    }

                    emitChannelLog("无线连接中断，正在重连（最多3次）", "TRANSFER", "WARN")
                    val profile = findWifiProfile(wifiTransport.currentHost)
                    if (profile == null ||
                        !connectWifiWithRetries(profile, wifiTransport.currentHost)
                    ) {
                        emitChannelLog("无线重连失败，图片监听已停止", "TRANSFER", "ERROR")
                        break
                    }
                    activeTransport = wifiTransport
                    syncProjectId()
                    wifiTransport.beginContinuousTransfer()
                    emitChannelLog("无线重连成功，继续等待图片", "TRANSFER")
                }
            }
        } finally {
            wifiTransport.endContinuousTransfer()
            emitChannelLog("无线图片监听结束：已保存$saved 张，跳过重复$skipped 张", "TRANSFER")
            if (!wifiTransport.isConnected && activeTransport === wifiTransport) {
                activeTransport = null
            }
        }
    }

    private suspend fun stopWirelessTransfer(): Boolean {
        val job = transferJob ?: return true
        wifiTransport.requestStopAndCancelActiveTransferOperation()
        var stopped = withTimeoutOrNull(TRANSFER_STOP_JOIN_TIMEOUT_MS) {
            job.join()
            true
        } == true

        if (!stopped && !job.isCompleted) {
            emitChannelLog(
                "相机未确认取消接收事务；正在重置连接以确保停止并释放相机",
                "TRANSFER",
                "WARN",
            )
            job.cancel(CancellationException("相机未确认取消接收事务"))
            wifiTransport.forceDisconnectAfterTransferStopTimeout()
            stopped = withTimeoutOrNull(TRANSFER_FORCE_STOP_JOIN_TIMEOUT_MS) {
                job.join()
                true
            } == true
            if (!stopped) {
                emitChannelLog(
                    "接收任务已取消，但后台读取尚未完全退出",
                    "TRANSFER",
                    "WARN",
                )
            }
        }
        if (transferJob === job) transferJob = null
        if (!wifiTransport.isConnected && activeTransport === wifiTransport) {
            activeTransport = null
        }
        return true
    }

    private fun emitChannelLog(message: String, category: String, level: String = "INFO") {
        Log.d(TAG, "[$category/$level] $message")
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "type" to "log",
                    "level" to level,
                    "message" to message,
                    "category" to category,
                ),
            )
        }
    }

    /** Sync the active project ID so new photos go to the right directory. */

    private fun syncProjectId() {
        val projectId = projectStore.getActiveProjectId()
        context.getSharedPreferences("ztransfer", Context.MODE_PRIVATE)
            .edit().putString("active_project_id", projectId).apply()
    }

    private fun getActiveSaveDir(): File {
        val projectId = projectStore.getActiveProjectId()
        return projectId?.let {
            File(File(context.getExternalFilesDir(null), "Projects"), it)
        } ?: File(context.getExternalFilesDir(null), "Downloads")
    }

    // ── Local photo helpers (unchanged from original) ──────────────────────

    private fun listLocalPhotos(projectId: String?): List<Map<String, Any>> {
        val base = context.getExternalFilesDir(null) ?: return emptyList()
        val dir = projectId?.let {
            File(File(base, "Projects"), it)
        } ?: getActiveSaveDir()
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

    private fun listAllLocalPhotos(): List<Map<String, Any>> {
        val base = context.getExternalFilesDir(null) ?: return emptyList()
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

    private fun deleteLocalPhoto(filePath: String): Boolean {
        return try {
            File(filePath).delete()
        } catch (e: Exception) {
            Log.w(TAG, "deleteLocalPhoto failed", e)
            false
        }
    }

    private fun getExifData(filePath: String): Map<String, String> {
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

    // ── Share helpers ──────────────────────────────────────────────────────

    private fun shareSingleFile(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) return
        val uri = FileProvider.getUriForFile(
            context, "${context.packageName}.fileprovider", file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/jpeg"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(Intent.createChooser(intent, "Share photo"))
    }

    private fun shareMultipleFiles(paths: List<String>) {
        val uris = paths.mapNotNull { path ->
            val file = File(path)
            if (file.exists()) {
                FileProvider.getUriForFile(
                    context, "${context.packageName}.fileprovider", file
                )
            } else null
        }
        if (uris.isEmpty()) return
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "image/jpeg"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(Intent.createChooser(intent, "Share ${uris.size} photos"))
    }

    // ── Utility ────────────────────────────────────────────────────────────

    private fun formatDate(millis: Long): String {
        return if (millis > 0) {
            val sdf = java.text.SimpleDateFormat(
                "yyyy-MM-dd HH:mm:ss", java.util.Locale.US
            )
            sdf.format(java.util.Date(millis))
        } else ""
    }

    companion object {
        private const val TAG = "CameraChannel"
        private const val TRANSFER_STOP_JOIN_TIMEOUT_MS = 5_000L
        private const val TRANSFER_FORCE_STOP_JOIN_TIMEOUT_MS = 2_000L
        private const val PROJECT_REQUIRED_MESSAGE = "请先创建项目，再连接相机"
        private val PROJECT_REQUIRED_METHODS = setOf(
            "connect",
            "connectAuto",
            "connectWifi",
            "connectTransfer",
            "completePairing",
            "runCompatibilityCheck",
            "startTransfer",
        )
        const val CHANNEL_NAME = "com.cacl2.ztransfer/camera"
        const val EVENT_CHANNEL_NAME = "com.cacl2.ztransfer/camera/events"
    }
}
