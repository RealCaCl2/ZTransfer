package com.cacl2.ztransfer.camera.transport

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.PowerManager
import android.util.Log
import com.kw.ztransfer.NativePtpCore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.EOFException
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.net.ConnectException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NoRouteToHostException
import java.net.Socket
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Locale
import javax.net.SocketFactory

/**
 * Nikon PTP/IP transport matching the verified wire flow.
 *
 * Pairing and transfer intentionally use separate PTP/IP sessions. Pairing creates a fresh client
 * GUID, reads the camera challenge, submits ConfirmPairing after the user taps the app button, then
 * waits for the user to press OK on the camera. It persists the profile only after the camera
 * accepts, and closes both pairing sockets before creating the transfer connection.
 *
 * The picture-transfer session does not switch Application Mode. It opens one
 * command/event socket pair and repeatedly calls AdvancedTransfer with native value (1, 2). Each
 * selected object is streamed to disk with standard GetPartialObject first; AccessDenied on the
 * first standard read switches that object to native operation 24 with a 64-bit offset.
 */
class WifiTransport(
    private val context: Context,
    private var host: String = PtpIpConstants.DEFAULT_CAMERA_HOST,
    private var port: Int = PtpIpConstants.DEFAULT_PTP_PORT,
    private var initiatorName: String = PtpIpConstants.DEFAULT_DEVICE_NAME,
) : CameraTransport {

    data class DeviceInfo(
        val manufacturer: String,
        val model: String,
        val version: String,
        val serial: String,
        val supportedOperations: Set<Int>,
        val supportedEvents: Set<Int>,
        val supportedProperties: Set<Int>,
    )

    data class TransferRecord(
        val recordType: Int,
        val objectHandle: Int,
        val cameraPath: String,
        val reportedSize: Long,
        val captureDate: String,
        val modificationDate: String,
    ) {
        val filename: String
            get() = cameraPath.substringAfterLast('\\').substringAfterLast('/')
    }

    sealed class DownloadOutcome {
        data class Saved(val path: String, val bytes: Long) : DownloadOutcome()
        data class SkippedDuplicate(val path: String, val bytes: Long) : DownloadOutcome()
    }

    private data class CommandResult(
        val responseCode: Int,
        val parameters: List<Long>,
        val data: ByteArray,
    )

    private data class RemoteObjectInfo(
        val handle: Int,
        val format: Int,
        val size: Long,
        val filename: String,
        val captureDate: String,
        val width: Int,
        val height: Int,
    )

    private data class ChunkResult(val bytes: ByteArray, val mode: ReadMode)

    private enum class ReadMode { STANDARD, EXTENDED }
    private enum class SessionPhase { DISCONNECTED, HANDSHAKE, PAIRING, TRANSFER }

    override val transportType = TransportType.WIFI

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val connectionMutex = Mutex()
    private val commandMutex = Mutex()
    private val eventWriteMutex = Mutex()
    private val commandWriteLock = Any()
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val _connectionState =
        MutableStateFlow<TransportState>(TransportState.Disconnected)
    override val connectionState: StateFlow<TransportState> = _connectionState.asStateFlow()

    private val _events = MutableSharedFlow<TransportEvent>(extraBufferCapacity = 256)
    override val events: SharedFlow<TransportEvent> = _events.asSharedFlow()

    override val isConnected: Boolean
        get() = _connectionState.value is TransportState.Connected && sessionOpen && alive

    override var cameraName: String? = null
        private set

    var cameraGuid: String = ""
        private set

    private var expectedCameraGuid: String? = null
    private var clientGuid: ByteArray? = null
    private var nativeCore: NativePtpCore? = null
    private var commandSocket: Socket? = null
    private var eventSocket: Socket? = null
    private var commandInput: java.io.InputStream? = null
    private var commandOutput: java.io.OutputStream? = null
    private var eventJob: Job? = null
    private var pairingTimeoutJob: Job? = null
    private var fallbackTransactionId = 0L
    private var connectionNumber = 0L
    private var supportedOperations: Set<Int> = emptySet()
    @Volatile
    private var activeTransactionId: Long? = null
    @Volatile
    private var activeOperationCode: Int? = null
    private var phase = SessionPhase.DISCONNECTED
    private var lastError: String? = null

    @Volatile
    private var alive = false

    @Volatile
    private var sessionOpen = false

    @Volatile
    private var pairingActive = false

    @Volatile
    private var continuousTransferActive = false

    @Volatile
    private var transferStopRequested = false

    @Volatile
    private var currentTransferRateBytesPerSecond = 0.0

    @Volatile
    private var currentTransferProgress = 0.0

    @Volatile
    private var currentTransferBytes = 0L

    @Volatile
    private var currentTransferTotalBytes = 0L

    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    val currentHost: String
        get() = host

    val currentInitiatorName: String
        get() = initiatorName

    val isTransferStopRequested: Boolean
        get() = transferStopRequested

    val hasLoadedProfile: Boolean
        get() = clientGuid != null

    fun getClientGuidHex(): String = clientGuid?.toHex() ?: ""

    fun loadProfile(
        clientGuidHex: String,
        savedInitiatorName: String = PtpIpConstants.DEFAULT_DEVICE_NAME,
        cameraGuidHex: String? = null,
    ) {
        clientGuid = decodeGuid(clientGuidHex)
        require(savedInitiatorName.isNotBlank() && savedInitiatorName.length <= 39) {
            "Initiator name must contain 1 to 39 characters"
        }
        initiatorName = savedInitiatorName
        expectedCameraGuid = cameraGuidHex
            ?.lowercase(Locale.ROOT)
            ?.takeIf { it.matches(GUID_HEX) }
        log("已加载无线配对档案，后续连接将复用已授权 GUID", "PAIRING")
    }

    override suspend fun connect(): Boolean = connectForTransfer(host)

    suspend fun connectTo(ip: String): Boolean = connectForTransfer(ip)

    /** Open an already-paired picture-transfer session. */
    suspend fun connectForTransfer(
        ip: String,
        reportFailure: Boolean = true,
        connectTimeoutMs: Int = PtpIpConstants.TRANSFER_CONNECT_TIMEOUT_MS,
        commandTimeoutMs: Int = PtpIpConstants.TRANSFER_COMMAND_TIMEOUT_MS,
    ): Boolean = connectionMutex.withLock {
        if (clientGuid == null) {
            failWithoutConnection("没有可用的无线配对档案")
            return@withLock false
        }
        host = ip
        cleanupConnection(emitDisconnected = isConnected)
        _connectionState.value = TransportState.Connecting
        lastError = null
        try {
            openNativeCore()
            initHandshake(
                connectTimeoutMs = connectTimeoutMs,
                commandTimeoutMs = commandTimeoutMs,
            )
            validateExpectedCameraGuid()
            val info = getDeviceInfo()
            openSession()
            logRetractableLensCondition(info)

            val advancedTransfer = privateOpcode(PRIVATE_OP_ADVANCED_TRANSFER)
            if (advancedTransfer !in info.supportedOperations) {
                throw PtpException("相机未报告 AdvancedTransfer 能力")
            }

            phase = SessionPhase.TRANSFER
            pairingActive = false
            markConnected()
            log("保持单一 PTP/IP Session，不切换 Application Mode", "PTP")
            true
        } catch (cancelled: CancellationException) {
            cleanupConnection(emitDisconnected = true)
            throw cancelled
        } catch (error: Exception) {
            if (reportFailure) {
                failConnection("无线传输连接失败", error)
            } else {
                // ConfirmPairing can be acknowledged before the camera operator
                // presses OK. A rejected reconnect is expected during that window.
                lastError = error.message ?: error.javaClass.simpleName
                Log.d(TAG, "[PAIRING] 正式连接尚未就绪：$lastError")
                cleanupConnection(emitDisconnected = false)
            }
            false
        }
    }

    /**
     * Start a new pairing session and return the camera-generated challenge.
     * The generated client GUID is retained only so the channel can save it after confirmation.
     */
    suspend fun startPairing(ip: String? = null): String? = connectionMutex.withLock {
        if (ip != null) host = ip
        cleanupConnection(emitDisconnected = isConnected)
        _connectionState.value = TransportState.Connecting
        lastError = null
        expectedCameraGuid = null
        clientGuid = ByteArray(16).also { SecureRandom().nextBytes(it) }
        log("开始独立无线配对；新 GUID 仅在确认成功后保存", "PAIRING")

        try {
            openNativeCore()
            initHandshake(
                connectTimeoutMs = PtpIpConstants.PAIRING_CONNECT_TIMEOUT_MS,
                commandTimeoutMs = PtpIpConstants.PAIRING_COMMAND_TIMEOUT_MS,
            )
            val info = getDeviceInfo()
            val pairingCodeOperation = privateOpcode(PRIVATE_OP_GET_PAIRING_CODE)
            val confirmOperation = privateOpcode(PRIVATE_OP_CONFIRM_PAIRING)
            if (pairingCodeOperation !in info.supportedOperations) {
                throw PtpException("相机未报告配对码读取能力")
            }
            if (confirmOperation !in info.supportedOperations) {
                throw PtpException("相机未报告配对确认能力")
            }
            openSession()
            val code = getPairingCode()
            phase = SessionPhase.PAIRING
            pairingActive = true
            // A pairing socket is not yet a reusable picture-transfer connection.
            _connectionState.value = TransportState.Connecting
            schedulePairingTimeout()
            code
        } catch (cancelled: CancellationException) {
            cleanupConnection(emitDisconnected = true)
            throw cancelled
        } catch (error: Exception) {
            failConnection("无线配对启动失败", error)
            null
        }
    }

    suspend fun getPairingCode(): String {
        val result = command(
            opcode = privateOpcode(PRIVATE_OP_GET_PAIRING_CODE),
            timeoutMs = PtpIpConstants.PAIRING_COMMAND_TIMEOUT_MS,
        )
        checkOk(result, "GetPairingCode")
        val cursor = Cursor(result.data, "PairingCode")
        val count = cursor.u32AsInt("配对码位数")
        if (count !in 4..16) {
            throw PtpException("相机返回的配对码位数无效：$count")
        }
        if (cursor.remaining < count) {
            throw PtpException("配对码数据不足：需要$count 字节，剩余${cursor.remaining}字节")
        }
        val code = buildString(count) {
            repeat(count) {
                val digit = cursor.u8()
                if (digit !in 0..9) {
                    throw PtpException("配对码包含非法数字：$digit")
                }
                append(digit)
            }
        }
        log("已从相机读取${code.length}位配对挑战（内容不写入日志）", "PAIRING")
        return code
    }

    suspend fun confirmPairing(): Boolean {
        val confirmValue = privateValue(PRIVATE_VALUE_GROUP_TRANSFER, PRIVATE_VALUE_PAIRING_ACCEPT)
        val result = command(
            opcode = privateOpcode(PRIVATE_OP_CONFIRM_PAIRING),
            parameters = listOf(confirmValue),
            timeoutMs = PtpIpConstants.PAIRING_COMMAND_TIMEOUT_MS,
        )
        checkOk(result, "ConfirmPairing")
        log("相机已接受配对确认", "PAIRING")
        return true
    }

    /** Submit pairing confirmation, then close this pairing session without reusing its sockets. */
    suspend fun confirmPairingAndClose(): Boolean = connectionMutex.withLock {
        if (!pairingActive || !sessionOpen) {
            throw PtpException("当前没有等待确认的配对会话")
        }
        pairingTimeoutJob?.cancel()
        pairingTimeoutJob = null
        try {
            confirmPairing()
            pairingActive = false
            runCatching {
                closeSession(timeoutMs = PtpIpConstants.PAIRING_CLOSE_TIMEOUT_MS)
            }.onFailure {
                log("配对确认后相机已结束会话：${it.message}", "PAIRING")
            }
            cleanupConnection(emitDisconnected = false)
            true
        } catch (cancelled: CancellationException) {
            pairingActive = false
            cleanupConnection(emitDisconnected = false)
            throw cancelled
        } catch (error: Exception) {
            pairingActive = false
            log("配对确认未完成：${error.message}", "PAIRING", "WARN")
            cleanupConnection(emitDisconnected = false)
            throw error
        }
    }

    /** Explicit compatibility hook; picture transfer itself does not call this. */
    suspend fun enableTransferMode(enable: Boolean = true): Boolean = try {
        val result = command(
            opcode = privateOpcode(PRIVATE_OP_CHANGE_APPLICATION_MODE),
            parameters = listOf(if (enable) 1L else 0L),
        )
        checkOk(result, "ChangeApplicationMode")
        requireNativeCore().setApplicationMode(enable)
        log("Application Mode ${if (enable) "已开启" else "已关闭"}", "PTP")
        true
    } catch (error: Exception) {
        log("ChangeApplicationMode 失败：${error.message}", "PTP", "ERROR")
        false
    }

    suspend fun waitForNextPhoto(
        timeoutMs: Int = PtpIpConstants.TRANSFER_COMMAND_TIMEOUT_MS,
    ): TransferRecord {
        val selectedTransferMode = privateValue(
            PRIVATE_VALUE_GROUP_TRANSFER,
            PRIVATE_VALUE_SELECTED_TRANSFER,
        )
        val result = command(
            opcode = privateOpcode(PRIVATE_OP_ADVANCED_TRANSFER),
            parameters = listOf(selectedTransferMode),
            timeoutMs = timeoutMs,
        )
        checkOk(result, "AdvancedTransfer")
        if (result.data.isEmpty()) {
            throw PtpException("AdvancedTransfer 返回空记录")
        }
        val cursor = Cursor(result.data, "AdvancedTransfer")
        val record = TransferRecord(
            recordType = cursor.u8(),
            objectHandle = cursor.u32().toInt(),
            cameraPath = cursor.ptpString(),
            reportedSize = cursor.u32(),
            captureDate = cursor.ptpString(),
            modificationDate = cursor.ptpString(),
        )
        log(
            "收到待传对象：${record.filename.ifBlank { handleName(record.objectHandle) }} " +
                "handle=0x${record.objectHandle.toUInt().toString(16)} size=${record.reportedSize}",
            "TRANSFER",
        )
        return record
    }

    /** Resolve authoritative metadata, deduplicate, and stream the selected object to disk. */
    suspend fun downloadTransferRecord(
        record: TransferRecord,
        saveDir: File,
        chunkSize: Int = PtpIpConstants.DEFAULT_TRANSFER_CHUNK_SIZE,
    ): DownloadOutcome = withContext(Dispatchers.IO) {
        require(chunkSize in PtpIpConstants.MIN_TRANSFER_CHUNK_SIZE..PtpIpConstants.MAX_TRANSFER_CHUNK_SIZE) {
            "分块大小必须在64KiB到16MiB之间"
        }
        val remoteInfo = runCatching { readRemoteObjectInfo(record.objectHandle) }
            .onFailure { log("GetObjectInfo 失败，使用 AdvancedTransfer 记录：${it.message}", "DOWNLOAD", "WARN") }
            .getOrNull()

        val totalSize = remoteInfo?.size?.takeIf { it > 0 }
            ?: record.reportedSize.takeIf { it > 0 }
            ?: throw PtpException("相机未返回有效文件大小")
        val format = remoteInfo?.format ?: formatFromName(record.filename)
        val requestedName = remoteInfo?.filename
            ?.takeIf { it.isNotBlank() }
            ?: record.filename
        val safeName = sanitizeFilename(requestedName, record.objectHandle, format)

        if (!saveDir.exists() && !saveDir.mkdirs()) {
            throw PtpException("无法创建保存目录：${saveDir.absolutePath}")
        }

        val sameName = File(saveDir, safeName)
        if (sameName.isFile && sameName.length() == totalSize &&
            fingerprintsMatch(record.objectHandle, totalSize, sameName)
        ) {
            log("重复文件已通过首尾指纹确认，跳过完整传输：$safeName", "DOWNLOAD")
            return@withContext DownloadOutcome.SkippedDuplicate(sameName.absolutePath, totalSize)
        }

        val finalFile = uniqueFile(saveDir, safeName)
        val tempFile = File.createTempFile(
            ".ztransfer_${record.objectHandle.toUInt().toString(16)}_",
            ".part",
            saveDir,
        )

        try {
            FileOutputStream(tempFile).use { output ->
                streamObject(
                    handle = record.objectHandle,
                    totalSize = totalSize,
                    output = output,
                    chunkSize = chunkSize,
                )
                output.fd.sync()
            }
            if (tempFile.length() != totalSize) {
                throw PtpException("下载大小不一致：${tempFile.length()} != $totalSize")
            }
            if (!tempFile.renameTo(finalFile)) {
                tempFile.inputStream().use { input ->
                    finalFile.outputStream().use { output -> input.copyTo(output) }
                }
                if (!tempFile.delete()) {
                    log("临时文件未能删除：${tempFile.absolutePath}", "DOWNLOAD", "WARN")
                }
            }

            val isRaw = finalFile.extension.equals("NEF", true) || format == PtpIpConstants.FMT_RAW
            _events.emit(
                TransportEvent.ObjectAdded(
                    objectHandle = record.objectHandle,
                    formatCode = format,
                    fileName = finalFile.name,
                    sizeBytes = totalSize,
                    localPath = finalFile.absolutePath,
                    width = remoteInfo?.width?.takeIf { it > 0 },
                    height = remoteInfo?.height?.takeIf { it > 0 },
                    isRaw = isRaw,
                ),
            )
            log("文件保存完成：${finalFile.name} ($totalSize bytes)", "DOWNLOAD")
            DownloadOutcome.Saved(finalFile.absolutePath, totalSize)
        } catch (error: Throwable) {
            if (tempFile.exists() && !tempFile.delete()) {
                log("失败后的临时文件未能删除：${tempFile.absolutePath}", "DOWNLOAD", "WARN")
            }
            if (finalFile.exists() && finalFile.length() != totalSize && !finalFile.delete()) {
                log("失败后的不完整目标文件未能删除：${finalFile.absolutePath}", "DOWNLOAD", "WARN")
            }
            throw error
        }
    }

    suspend fun downloadAndSavePhoto(record: TransferRecord, saveDir: File): String? =
        when (val outcome = downloadTransferRecord(record, saveDir)) {
            is DownloadOutcome.Saved -> outcome.path
            is DownloadOutcome.SkippedDuplicate -> outcome.path
        }

    fun beginContinuousTransfer() {
        transferStopRequested = false
        continuousTransferActive = true
        currentTransferRateBytesPerSecond = 0.0
        currentTransferProgress = 0.0
        currentTransferBytes = 0L
        currentTransferTotalBytes = 0L
        acquireTransferLocks()
        _events.tryEmit(TransportEvent.TransferStateChanged(listening = true))
    }

    fun endContinuousTransfer() {
        continuousTransferActive = false
        transferStopRequested = false
        currentTransferRateBytesPerSecond = 0.0
        currentTransferProgress = 0.0
        currentTransferBytes = 0L
        currentTransferTotalBytes = 0L
        releaseTransferLocks()
        _events.tryEmit(TransportEvent.TransferStateChanged(listening = false))
    }

    /**
     * Cancel the command currently blocking the continuous-transfer worker.
     *
     * PTP/IP Cancel (packet type 11) ends the active transaction without closing
     * the command/event sockets or the PTP session. This lets the UI stop waiting
     * for AdvancedTransfer while keeping the paired camera connected.
     */
    fun requestStopAndCancelActiveTransferOperation(): Boolean {
        if (!continuousTransferActive) return false
        transferStopRequested = true
        return try {
            var sent = false
            var cancelledTransactionId: Long? = null
            var cancelledOperationCode: Int? = null
            synchronized(commandWriteLock) {
                val transactionId = activeTransactionId
                val operationCode = activeOperationCode
                val output = commandOutput
                if (alive && transactionId != null && operationCode != null && output != null) {
                    val payload = ByteArrayOutputStream().apply {
                        writeUInt32(transactionId)
                    }.toByteArray()
                    sendPacket(output, PtpIpConstants.PKT_CANCEL, payload)
                    cancelledTransactionId = transactionId
                    cancelledOperationCode = operationCode
                    sent = true
                }
            }
            if (sent) {
                log(
                    "已取消传输事务 tx=$cancelledTransactionId " +
                        "op=0x${cancelledOperationCode?.toString(16)}，PTP/IP 会话保持连接",
                    "TRANSFER",
                )
            }
            sent
        } catch (error: Exception) {
            log("取消传输事务失败：${error.message}", "TRANSFER", "WARN")
            false
        }
    }

    fun isRecoverableConnectionFailure(error: Throwable): Boolean {
        var current: Throwable? = error
        while (current != null) {
            when (current) {
                is EOFException,
                is ConnectException,
                is NoRouteToHostException,
                is UnknownHostException,
                is SocketTimeoutException,
                -> return true
                is SocketException -> {
                    val message = current.message.orEmpty().lowercase(Locale.ROOT)
                    if (RECOVERABLE_SOCKET_WORDS.any(message::contains)) return true
                }
            }
            current = current.cause
        }
        return false
    }

    override suspend fun disconnect() {
        connectionMutex.withLock {
            cleanupConnection(emitDisconnected = isConnected || phase != SessionPhase.DISCONNECTED)
        }
    }

    override suspend fun listPhotos(): List<PhotoMeta> = emptyList()

    override suspend fun getObject(handle: Int): ByteArray? {
        val info = readRemoteObjectInfo(handle)
        if (info.size <= 0 || info.size > MAX_IN_MEMORY_OBJECT_SIZE) return null
        val output = ByteArrayOutputStream(info.size.toInt())
        streamObject(handle, info.size, output, PtpIpConstants.DEFAULT_TRANSFER_CHUNK_SIZE)
        return output.toByteArray()
    }

    override suspend fun getObjectInfo(handle: Int): ObjectInfo? {
        val info = readRemoteObjectInfo(handle)
        return ObjectInfo(
            handle = handle,
            format = info.format,
            size = info.size,
            filename = info.filename,
            captureDateMillis = parsePtpDate(info.captureDate),
        )
    }

    override suspend fun downloadAndSave(
        handle: Int,
        fileName: String,
        saveDir: File,
    ): String? {
        val info = readRemoteObjectInfo(handle)
        val record = TransferRecord(
            recordType = info.format,
            objectHandle = handle,
            cameraPath = fileName.ifBlank { info.filename },
            reportedSize = info.size,
            captureDate = info.captureDate,
            modificationDate = "",
        )
        return downloadAndSavePhoto(record, saveDir)
    }

    override suspend fun getBatteryLevel(): Int? = null
    override suspend fun getStorageInfo(): StorageInfo? = null

    override fun getSessionDiagnostics(): Map<String, Any> = mapOf(
        "host" to host,
        "port" to port,
        "connected" to isConnected,
        "phase" to phase.name,
        "sessionOpen" to sessionOpen,
        "pairingActive" to pairingActive,
        "listening" to continuousTransferActive,
        "transferRateBytesPerSecond" to currentTransferRateBytesPerSecond,
        "transferProgress" to currentTransferProgress,
        "transferBytes" to currentTransferBytes,
        "transferTotalBytes" to currentTransferTotalBytes,
        "cameraGuid" to cameraGuid,
        "profileLoaded" to (clientGuid != null),
        "supportedOperationCount" to supportedOperations.size,
        "lastError" to (lastError ?: ""),
    )

    override fun onEventSinkReady() = Unit
    override fun onEventSinkCancelled() = Unit

    private fun openNativeCore() {
        nativeCore?.close()
        nativeCore = try {
            NativePtpCore()
        } catch (error: Throwable) {
            throw PtpException("ZTransfer native PTP core unavailable", error)
        }
        fallbackTransactionId = 0L
    }

    private fun requireNativeCore(): NativePtpCore =
        nativeCore ?: throw PtpException("Native PTP core is not initialized")

    private fun privateOpcode(operationId: Int): Int {
        val opcode = requireNativeCore().privateOpcode(operationId)
        if (opcode == 0) throw PtpException("Native operation mapping is missing for id=$operationId")
        return opcode
    }

    private fun privateValue(groupId: Int, valueId: Int): Long =
        requireNativeCore().privateValue(groupId, valueId).toLong() and UINT32_MASK

    private suspend fun initHandshake(connectTimeoutMs: Int, commandTimeoutMs: Int) {
        val guid = clientGuid ?: throw PtpException("Client GUID is not configured")
        if (initiatorName.isBlank() || initiatorName.length > 39) {
            throw PtpException("Initiator Name 必须为1到39个字符")
        }
        val core = requireNativeCore()
        log("连接 $host:$port", "SOCKET")

        val command = createSocket(connectTimeoutMs, commandTimeoutMs)
        commandSocket = command
        commandInput = command.getInputStream()
        commandOutput = command.getOutputStream()
        sendPacket(
            commandOutput!!,
            PtpIpConstants.PKT_INIT_CMD_REQ,
            core.buildInitCommandPayload(guid, initiatorName),
        )
        val commandAck = receivePacket(commandInput!!)
        if (commandAck.first == PtpIpConstants.PKT_INIT_FAIL) {
            throw initFailure(commandAck.second)
        }
        if (commandAck.first != PtpIpConstants.PKT_INIT_CMD_ACK) {
            throw PtpException("期望 InitCommandAck，实际包类型=0x${commandAck.first.toString(16)}")
        }
        if (commandAck.second.size < 20) {
            throw PtpException("InitCommandAck 数据不足：${commandAck.second.size}")
        }
        core.onCommandAccepted()
        connectionNumber = readUInt32(commandAck.second, 0)
        cameraGuid = commandAck.second.copyOfRange(4, 20).toHex()
        cameraName = decodeNullTerminatedUtf16(commandAck.second, 20).ifBlank { "Nikon" }
        log("相机已接受连接：$cameraName，GUID=$cameraGuid", "SOCKET")

        val event = createSocket(connectTimeoutMs, minOf(commandTimeoutMs, 10_000))
        eventSocket = event
        sendPacket(
            event.getOutputStream(),
            PtpIpConstants.PKT_INIT_EVT_REQ,
            core.buildInitEventPayload(connectionNumber),
        )
        val eventAck = receivePacket(event.getInputStream())
        if (eventAck.first != PtpIpConstants.PKT_INIT_EVT_ACK) {
            throw PtpException("期望 InitEventAck，实际包类型=0x${eventAck.first.toString(16)}")
        }
        core.onEventAccepted()
        event.soTimeout = PtpIpConstants.EVENT_READ_TIMEOUT_MS
        alive = true
        phase = SessionPhase.HANDSHAKE
        eventJob = scope.launch { eventLoop(event) }
        log("PTP/IP Command 与 Event 通道已建立", "SOCKET")
    }

    private suspend fun getDeviceInfo(): DeviceInfo {
        val result = command(PtpIpConstants.OP_GetDeviceInfo)
        checkOk(result, "GetDeviceInfo")
        val cursor = Cursor(result.data, "DeviceInfo")
        cursor.u16() // StandardVersion
        cursor.u32() // VendorExtensionID
        cursor.u16() // VendorExtensionVersion
        cursor.ptpString() // VendorExtensionDescription
        cursor.u16() // FunctionalMode
        val operations = cursor.u16Set()
        val events = cursor.u16Set()
        val properties = cursor.u16Set()
        cursor.u16Set() // CaptureFormats
        cursor.u16Set() // ImageFormats
        val manufacturer = cursor.ptpString()
        val model = cursor.ptpString()
        val version = cursor.ptpString()
        val serial = cursor.ptpString()

        supportedOperations = operations
        cameraName = model.ifBlank { cameraName ?: "Nikon" }

        // The reference service receives a signed camera_manifest. ZTransfer is offline,
        // so it applies the native defaults with no disabled operation IDs.
        requireNativeCore().applyRules(intArrayOf(), true, true)
        log("设备：$manufacturer $model $version，支持${operations.size}个操作", "PTP")
        return DeviceInfo(manufacturer, model, version, serial, operations, events, properties)
    }

    private suspend fun openSession() {
        val result = command(PtpIpConstants.OP_OpenSession, listOf(1L))
        checkOk(result, "OpenSession")
        sessionOpen = true
        requireNativeCore().onSessionOpened()
        log("PTP Session 已打开", "PTP")
    }

    private suspend fun logRetractableLensCondition(info: DeviceInfo) {
        val property = PtpIpConstants.DPC_NikonRetractableLensState
        if (property !in info.supportedProperties) {
            log("D09C retractable-lens condition=PROPERTY_UNSUPPORTED", "PTP")
            return
        }
        runCatching {
            val result = command(
                opcode = PtpIpConstants.OP_GetDevicePropValue,
                parameters = listOf(property.toLong()),
            )
            checkOk(result, "GetDevicePropValue(D09C)")
            val raw = result.data.singleOrNull()?.toInt()?.and(0xff)
            val state = when (raw) {
                null -> "UNKNOWN(length=${result.data.size})"
                0 -> "EXTENDED_OR_NOT_APPLICABLE"
                1 -> "RETRACTED"
                else -> "UNKNOWN(raw=$raw)"
            }
            log("D09C retractable-lens condition=$state", "PTP")
        }.onFailure {
            log("D09C retractable-lens condition=UNKNOWN (${it.message})", "PTP", "WARN")
        }
    }

    private suspend fun closeSession(timeoutMs: Int = PtpIpConstants.CMD_TIMEOUT_MS) {
        if (!sessionOpen) return
        val result = command(PtpIpConstants.OP_CloseSession, timeoutMs = timeoutMs)
        checkOk(result, "CloseSession")
        sessionOpen = false
        requireNativeCore().onSessionClosed()
        log("PTP Session 已关闭", "PTP")
    }

    private suspend fun command(
        opcode: Int,
        parameters: List<Long> = emptyList(),
        outboundData: ByteArray? = null,
        timeoutMs: Int = PtpIpConstants.CMD_TIMEOUT_MS,
    ): CommandResult = commandMutex.withLock {
        val core = requireNativeCore()
        val transactionId = runCatching { core.nextTransactionId() }
            .getOrElse { ++fallbackTransactionId }
        core.beforeOperation(opcode)
        executeOperation(opcode, transactionId, parameters, outboundData, timeoutMs)
    }

    private fun executeOperation(
        opcode: Int,
        transactionId: Long,
        parameters: List<Long>,
        outboundData: ByteArray?,
        timeoutMs: Int,
    ): CommandResult {
        if (!alive) throw SocketException("PTP/IP连接已关闭")
        val socket = commandSocket ?: throw SocketException("Command socket不可用")
        val input = commandInput ?: throw SocketException("Command输入流不可用")
        val output = commandOutput ?: throw SocketException("Command输出流不可用")
        socket.soTimeout = timeoutMs

        try {
            val request = ByteArrayOutputStream().apply {
                writeUInt32(if (outboundData == null) DATA_PHASE_NO_OUTBOUND_DATA else DATA_PHASE_HOST_TO_CAMERA)
                writeUInt16(opcode)
                writeUInt32(transactionId)
                parameters.forEach { writeUInt32(it) }
            }.toByteArray()
            synchronized(commandWriteLock) {
                if (continuousTransferActive && transferStopRequested) {
                    throw CancellationException("无线图片监听已请求停止")
                }
                activeTransactionId = transactionId
                activeOperationCode = opcode
                sendPacket(output, PtpIpConstants.PKT_OP_REQ, request)

                if (outboundData != null) {
                    val start = ByteArrayOutputStream().apply {
                        writeUInt32(transactionId)
                        writeUInt64(outboundData.size.toLong())
                    }.toByteArray()
                    sendPacket(output, PtpIpConstants.PKT_START_DATA, start)
                    val end = ByteArrayOutputStream().apply {
                        writeUInt32(transactionId)
                        write(outboundData)
                    }.toByteArray()
                    sendPacket(output, PtpIpConstants.PKT_END_DATA, end)
                }
            }

            val receivedData = ByteArrayOutputStream()
            var expectedDataLength: Long? = null
            while (true) {
                val (packetType, payload) = receivePacket(input)
                when (packetType) {
                    PtpIpConstants.PKT_OP_RESP -> {
                        val cursor = Cursor(payload, "OperationResponse")
                        val responseCode = cursor.u16()
                        val responseTransaction = cursor.u32()
                        requireTransaction("Response", responseTransaction, transactionId)
                        val responseParameters = buildList {
                            while (cursor.remaining >= 4) add(cursor.u32())
                        }
                        val data = receivedData.toByteArray()
                        expectedDataLength?.let { expected ->
                            if (expected != data.size.toLong()) {
                                throw PtpException("数据长度不一致：期望=$expected，实际=${data.size}")
                            }
                        }
                        return CommandResult(responseCode, responseParameters, data)
                    }
                    PtpIpConstants.PKT_START_DATA -> {
                        val cursor = Cursor(payload, "StartData")
                        requireTransaction("StartData", cursor.u32(), transactionId)
                        val announcedLength = cursor.u64()
                        if (announcedLength < 0 || announcedLength > MAX_OPERATION_DATA_SIZE) {
                            throw PtpException("操作数据过大：$announcedLength")
                        }
                        expectedDataLength = announcedLength
                        receivedData.reset()
                    }
                    PtpIpConstants.PKT_DATA,
                    PtpIpConstants.PKT_END_DATA,
                    -> {
                        val cursor = Cursor(payload, "Data")
                        requireTransaction("Data", cursor.u32(), transactionId)
                        receivedData.write(cursor.bytes(cursor.remaining))
                        if (receivedData.size().toLong() > MAX_OPERATION_DATA_SIZE) {
                            throw PtpException("操作数据超过上限")
                        }
                    }
                    PtpIpConstants.PKT_PROBE_REQ -> synchronized(commandWriteLock) {
                        sendPacket(output, PtpIpConstants.PKT_PROBE_RESP, ByteArray(0))
                    }
                    PtpIpConstants.PKT_INIT_FAIL -> throw PtpException("操作过程中收到 InitFail")
                    else -> throw PtpException(
                        "操作0x${opcode.toString(16)}收到未知包类型0x${packetType.toString(16)}",
                    )
                }
            }
        } finally {
            if (activeTransactionId == transactionId) {
                activeTransactionId = null
                activeOperationCode = null
            }
        }
    }

    private suspend fun eventLoop(socket: Socket) {
        val input = socket.getInputStream()
        val output = socket.getOutputStream()
        while (alive) {
            try {
                val packet = receivePacket(input)
                when (packet.first) {
                    PtpIpConstants.PKT_EVENT -> handleEventPacket(packet.second)
                    PtpIpConstants.PKT_PROBE_REQ -> eventWriteMutex.withLock {
                        sendPacket(output, PtpIpConstants.PKT_PROBE_RESP, ByteArray(0))
                    }
                    PtpIpConstants.PKT_PROBE_RESP -> Unit
                    else -> log(
                        "Event通道收到包类型0x${packet.first.toString(16)}",
                        "EVENT",
                        "WARN",
                    )
                }
            } catch (_: SocketTimeoutException) {
                continue
            } catch (_: CancellationException) {
                break
            } catch (error: Exception) {
                if (alive) {
                    lastError = error.message
                    log("Event通道结束：${error.message}", "EVENT", "WARN")
                    alive = false
                    runCatching { commandSocket?.close() }
                    _connectionState.value = TransportState.Error(error.message ?: "Event通道已断开")
                    _events.tryEmit(
                        TransportEvent.ConnectionStateChanged(false, cameraName, TransportType.WIFI),
                    )
                }
                break
            }
        }
    }

    private fun handleEventPacket(payload: ByteArray) {
        val cursor = Cursor(payload, "Event")
        if (cursor.remaining < 6) return
        val code = cursor.u16()
        val transactionId = cursor.u32()
        val parameters = buildList {
            while (cursor.remaining >= 4) add(cursor.u32())
        }
        val suffix = if (parameters.isEmpty()) "" else " 参数=${parameters.joinToString()}"
        log(
            "相机事件 0x${code.toString(16)} tx=$transactionId$suffix",
            "EVENT",
        )
    }

    private suspend fun readRemoteObjectInfo(handle: Int): RemoteObjectInfo {
        val result = command(
            PtpIpConstants.OP_GetObjectInfo,
            listOf(handle.toLong() and UINT32_MASK),
        )
        checkOk(result, "GetObjectInfo")
        val cursor = Cursor(result.data, "ObjectInfo")
        cursor.u32() // StorageID
        val format = cursor.u16()
        cursor.u16() // ProtectionStatus
        val size = cursor.u32()
        cursor.u16() // ThumbFormat
        cursor.u32() // ThumbCompressedSize
        cursor.u32() // ThumbPixWidth
        cursor.u32() // ThumbPixHeight
        val width = cursor.u32AsInt("ImagePixWidth")
        val height = cursor.u32AsInt("ImagePixHeight")
        cursor.u32() // ImageBitDepth
        cursor.u32() // ParentObject
        cursor.u16() // AssociationType
        cursor.u32() // AssociationDesc
        cursor.u32() // SequenceNumber
        val filename = cursor.ptpString()
        val captureDate = cursor.ptpString()
        cursor.ptpString() // ModificationDate
        if (cursor.remaining > 0) cursor.ptpString() // Keywords
        return RemoteObjectInfo(handle, format, size, filename, captureDate, width, height)
    }

    private suspend fun streamObject(
        handle: Int,
        totalSize: Long,
        output: java.io.OutputStream,
        chunkSize: Int,
    ) {
        if (totalSize <= 0) throw PtpException("文件大小必须大于0")
        var offset = 0L
        var mode = ReadMode.STANDARD
        val startedAtNanos = System.nanoTime()
        while (offset < totalSize) {
            val requested = minOf(chunkSize.toLong(), totalSize - offset).toInt()
            val chunk = readChunk(handle, offset, requested, mode)
            mode = chunk.mode
            if (chunk.bytes.isEmpty()) {
                throw PtpException("相机在 offset=$offset 返回了0字节")
            }
            if (offset + chunk.bytes.size > totalSize) {
                throw PtpException("相机返回数据超过文件大小")
            }
            output.write(chunk.bytes)
            offset += chunk.bytes.size
            val elapsedNanos = (System.nanoTime() - startedAtNanos).coerceAtLeast(1L)
            val bytesPerSecond = offset.toDouble() * 1_000_000_000.0 / elapsedNanos.toDouble()
            val progress = offset.toDouble() / totalSize.toDouble()
            currentTransferRateBytesPerSecond = bytesPerSecond
            currentTransferProgress = progress
            currentTransferBytes = offset
            currentTransferTotalBytes = totalSize
            _events.emit(
                TransportEvent.TransferProgress(
                    objectHandle = handle,
                    progress = progress,
                    bytesTransferred = offset,
                    totalBytes = totalSize,
                    bytesPerSecond = bytesPerSecond,
                ),
            )
        }
        output.flush()
        if (offset != totalSize) throw PtpException("下载大小不一致：$offset != $totalSize")
    }

    private suspend fun readChunk(
        handle: Int,
        offset: Long,
        length: Int,
        preferredMode: ReadMode,
    ): ChunkResult {
        if (offset < 0) throw PtpException("读取偏移不能为负数")
        if (length !in 1..PtpIpConstants.MAX_TRANSFER_CHUNK_SIZE) {
            throw PtpException("读取长度无效：$length")
        }
        if (preferredMode == ReadMode.STANDARD) {
            if (offset > UINT32_MASK) {
                throw PtpException("标准分片读取无法表示64位偏移：$offset")
            }
            val standard = command(
                opcode = PtpIpConstants.OP_GetPartialObject,
                parameters = listOf(
                    handle.toLong() and UINT32_MASK,
                    offset,
                    length.toLong(),
                ),
                timeoutMs = PtpIpConstants.DOWNLOAD_TIMEOUT_MS.toInt(),
            )
            if (standard.responseCode == PtpIpConstants.RC_OK) {
                validateChunk(standard, length, "GetPartialObject", extendedResponse = false)
                return ChunkResult(standard.data, ReadMode.STANDARD)
            }
            if (standard.responseCode != PtpIpConstants.RC_AccessDenied || offset != 0L) {
                checkOk(standard, "GetPartialObject")
            }
            log("相机以 AccessDenied(0x200F) 拒绝首个标准分片，切换扩展64位偏移读取", "DOWNLOAD", "WARN")
        }

        val extended = command(
            opcode = privateOpcode(PRIVATE_OP_EXTENDED_PARTIAL_OBJECT),
            parameters = listOf(
                handle.toLong() and UINT32_MASK,
                offset and UINT32_MASK,
                (offset ushr 32) and UINT32_MASK,
                length.toLong() and UINT32_MASK,
                0L,
            ),
            timeoutMs = PtpIpConstants.DOWNLOAD_TIMEOUT_MS.toInt(),
        )
        validateChunk(extended, length, "ExtendedPartialObject", extendedResponse = true)
        return ChunkResult(extended.data, ReadMode.EXTENDED)
    }

    private fun validateChunk(
        result: CommandResult,
        requested: Int,
        operation: String,
        extendedResponse: Boolean,
    ) {
        checkOk(result, operation)
        if (result.data.isEmpty()) throw PtpException("$operation 返回空数据")
        val reportedLength = when {
            extendedResponse && result.parameters.size >= 2 ->
                (result.parameters[0] and UINT32_MASK) or
                    ((result.parameters[1] and UINT32_MASK) shl 32)
            result.parameters.isNotEmpty() -> result.parameters[0] and UINT32_MASK
            else -> 0L
        }
        if (reportedLength > 0 && reportedLength != result.data.size.toLong()) {
            throw PtpException(
                "$operation 响应长度不一致：响应=$reportedLength，数据=${result.data.size}",
            )
        }
        if (result.data.size > requested) {
            throw PtpException("$operation 返回数据超过请求长度：${result.data.size} > $requested")
        }
    }

    private suspend fun fingerprintsMatch(handle: Int, size: Long, localFile: File): Boolean {
        if (size <= 0 || localFile.length() != size) return false
        return runCatching {
            val remote = remoteFingerprint(handle, size)
            val local = localFingerprint(localFile, size)
            MessageDigest.isEqual(remote, local)
        }.onFailure {
            log("重复文件指纹确认失败，将保留为新文件：${it.message}", "DOWNLOAD", "WARN")
        }.getOrDefault(false)
    }

    private suspend fun remoteFingerprint(handle: Int, size: Long): ByteArray {
        val firstLength = minOf(FINGERPRINT_BLOCK_SIZE.toLong(), size).toInt()
        var mode = if (size > UINT32_MASK) ReadMode.EXTENDED else ReadMode.STANDARD
        val first = readChunk(handle, 0L, firstLength, mode)
        mode = first.mode
        val tailOffset = maxOf(0L, size - FINGERPRINT_BLOCK_SIZE)
        val tailLength = (size - tailOffset).toInt()
        val tail = if (tailOffset == 0L && tailLength == first.bytes.size) {
            first.bytes
        } else {
            readChunk(handle, tailOffset, tailLength, mode).bytes
        }
        return fingerprint(size, first.bytes, tail)
    }

    private fun localFingerprint(file: File, size: Long): ByteArray {
        val firstLength = minOf(FINGERPRINT_BLOCK_SIZE.toLong(), size).toInt()
        val first = ByteArray(firstLength)
        val tailOffset = maxOf(0L, size - FINGERPRINT_BLOCK_SIZE)
        val tailLength = (size - tailOffset).toInt()
        val tail = ByteArray(tailLength)
        RandomAccessFile(file, "r").use { input ->
            input.readFully(first)
            if (tailOffset == 0L && tailLength == firstLength) {
                System.arraycopy(first, 0, tail, 0, tailLength)
            } else {
                input.seek(tailOffset)
                input.readFully(tail)
            }
        }
        return fingerprint(size, first, tail)
    }

    private fun fingerprint(size: Long, first: ByteArray, tail: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").apply {
            update(ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putLong(size).array())
            update(first)
            update(tail)
        }.digest()

    private fun createSocket(connectTimeoutMs: Int, readTimeoutMs: Int): Socket {
        val network = findNetworkForHost(host)
        val factory = network?.socketFactory ?: SocketFactory.getDefault()
        if (network == null) {
            Log.d(
                TAG,
                "[SOCKET] No registered Wi-Fi route covers $host; using system routing " +
                    "(required for phone-hotspot clients on many Android devices)",
            )
        } else {
            Log.d(TAG, "[SOCKET] Binding $host to routed Android network $network")
        }
        return factory.createSocket().apply {
            tcpNoDelay = true
            keepAlive = true
            receiveBufferSize = 4 * 1024 * 1024
            soTimeout = readTimeoutMs
            connect(
                InetSocketAddress(
                    this@WifiTransport.host,
                    this@WifiTransport.port,
                ),
                connectTimeoutMs,
            )
        }
    }

    private fun findNetworkForHost(targetHost: String): Network? {
        val targetAddress: InetAddress? = runCatching { InetAddress.getByName(targetHost) }.getOrNull()
        val wifiNetworks = connectivityManager.allNetworks.filter { network ->
            connectivityManager.getNetworkCapabilities(network)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        }
        return NetworkRouteSelector.select(
            candidates = wifiNetworks,
            active = connectivityManager.activeNetwork,
            targetResolved = targetAddress != null,
        ) { network ->
            targetAddress != null &&
                connectivityManager.getLinkProperties(network)
                    ?.routes
                    ?.any { route -> route.matches(targetAddress) } == true
        }
    }

    private fun sendPacket(output: java.io.OutputStream, type: Int, payload: ByteArray) {
        val totalLength = payload.size + 8
        val packet = ByteArrayOutputStream(totalLength).apply {
            writeUInt32(totalLength.toLong())
            writeUInt32(type.toLong())
            write(payload)
        }.toByteArray()
        output.write(packet)
        output.flush()
    }

    private fun receivePacket(input: java.io.InputStream): Pair<Int, ByteArray> {
        val header = readFully(input, 8)
        val totalLength = readUInt32(header, 0)
        val type = readUInt32(header, 4)
        if (totalLength !in 8L..MAX_PACKET_SIZE) {
            throw PtpException("非法PTP/IP包长度：$totalLength")
        }
        val payloadLength = (totalLength - 8).toInt()
        val payload = if (payloadLength == 0) ByteArray(0) else readFully(input, payloadLength)
        return type.toInt() to payload
    }

    private fun readFully(input: java.io.InputStream, length: Int): ByteArray {
        val data = ByteArray(length)
        var offset = 0
        while (offset < length) {
            val count = input.read(data, offset, length - offset)
            if (count < 0) {
                throw EOFException("连接在读取$length 字节时关闭，已读取$offset 字节")
            }
            offset += count
        }
        return data
    }

    private fun initFailure(payload: ByteArray): PtpException {
        val reason = if (payload.size >= 4) readUInt32(payload, 0) else -1L
        return PtpException(
            when (reason) {
                1L -> "相机拒绝客户端GUID：配对时请确认相机处于配对模式；普通传输必须使用已授权GUID和主机名"
                2L -> "相机忙，可能已有其他客户端连接"
                else -> "PTP/IP初始化失败，原因码=0x${reason.toString(16)}"
            },
        )
    }

    private fun validateExpectedCameraGuid() {
        val expected = expectedCameraGuid ?: return
        if (!cameraGuid.equals(expected, ignoreCase = true)) {
            throw PtpException("发现的相机GUID与当前档案不一致，请切换正确的相机档案")
        }
    }

    private fun markConnected() {
        val name = cameraName ?: "Nikon"
        _connectionState.value = TransportState.Connected(name)
        _events.tryEmit(TransportEvent.ConnectionStateChanged(true, name, TransportType.WIFI))
    }

    private fun failWithoutConnection(message: String) {
        lastError = message
        _connectionState.value = TransportState.Error(message)
        log(message, "SOCKET", "ERROR")
    }

    private fun failConnection(prefix: String, error: Exception) {
        val message = "$prefix：${error.message ?: error.javaClass.simpleName}"
        lastError = message
        log(message, "SOCKET", "ERROR")
        cleanupConnection(emitDisconnected = true)
        _connectionState.value = TransportState.Error(message)
    }

    private fun cleanupConnection(emitDisconnected: Boolean) {
        alive = false
        pairingActive = false
        transferStopRequested = false
        pairingTimeoutJob?.cancel()
        pairingTimeoutJob = null
        eventJob?.cancel()
        eventJob = null
        runCatching { eventSocket?.close() }
        runCatching { commandSocket?.close() }
        eventSocket = null
        commandSocket = null
        commandInput = null
        commandOutput = null
        activeTransactionId = null
        activeOperationCode = null

        nativeCore?.let { core ->
            if (sessionOpen) runCatching { core.onSessionClosed() }
            runCatching {
                if (core.isApplicationModeEnabled()) core.setApplicationMode(false)
            }
            runCatching { core.close() }
        }
        nativeCore = null
        sessionOpen = false
        supportedOperations = emptySet()
        phase = SessionPhase.DISCONNECTED
        releaseTransferLocks()
        _connectionState.value = TransportState.Disconnected
        if (emitDisconnected) {
            _events.tryEmit(
                TransportEvent.ConnectionStateChanged(false, cameraName, TransportType.WIFI),
            )
        }
    }

    private fun schedulePairingTimeout() {
        pairingTimeoutJob?.cancel()
        pairingTimeoutJob = scope.launch {
            delay(PtpIpConstants.PAIRING_USER_TIMEOUT_MS)
            connectionMutex.withLock {
                if (!pairingActive) return@withLock
                val message = "等待确认相机配对码超时"
                lastError = message
                log(message, "PAIRING", "WARN")
                cleanupConnection(emitDisconnected = false)
                _connectionState.value = TransportState.Error(message)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun acquireTransferLocks() {
        if (wifiLock?.isHeld != true) {
            runCatching {
                val manager = context.applicationContext
                    .getSystemService(Context.WIFI_SERVICE) as WifiManager
                wifiLock = manager.createWifiLock(
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                    "${context.packageName}:ZTransferWifiLock",
                ).apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }.onFailure { log("无法获取 Wi-Fi 高性能锁：${it.message}", "TRANSFER", "WARN") }
        }
        if (wakeLock?.isHeld != true) {
            runCatching {
                val manager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = manager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "${context.packageName}:ZTransferReceiveLock",
                ).apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }.onFailure { log("无法获取接收唤醒锁：${it.message}", "TRANSFER", "WARN") }
        }
    }

    private fun releaseTransferLocks() {
        runCatching { if (wifiLock?.isHeld == true) wifiLock?.release() }
        runCatching { if (wakeLock?.isHeld == true) wakeLock?.release() }
        wifiLock = null
        wakeLock = null
    }

    private fun checkOk(result: CommandResult, operation: String) {
        if (result.responseCode == PtpIpConstants.RC_OK) return
        val name = when (result.responseCode) {
            PtpIpConstants.RC_SessionNotOpen -> "SessionNotOpen"
            PtpIpConstants.RC_OperationNotSupported -> "OperationNotSupported"
            PtpIpConstants.RC_InvalidObjectHandle -> "InvalidObjectHandle"
            PtpIpConstants.RC_AccessDenied -> "AccessDenied"
            PtpIpConstants.RC_DeviceBusy -> "DeviceBusy"
            PtpIpConstants.RC_TransactionCancelled -> "TransactionCancelled"
            else -> "UnknownResponse"
        }
        throw PtpException(
            "$operation 失败：0x${result.responseCode.toString(16)} $name",
        )
    }

    private fun log(categoryMessage: String, category: String, level: String = "INFO") {
        when (level) {
            "ERROR" -> Log.e(TAG, "[$category] $categoryMessage")
            "WARN" -> Log.w(TAG, "[$category] $categoryMessage")
            else -> Log.d(TAG, "[$category] $categoryMessage")
        }
        _events.tryEmit(TransportEvent.Log(level, categoryMessage, category))
    }

    private fun requireTransaction(label: String, actual: Long, expected: Long) {
        if ((actual and UINT32_MASK) != (expected and UINT32_MASK)) {
            throw PtpException("$label TransactionID不匹配：$actual != $expected")
        }
    }

    private fun decodeNullTerminatedUtf16(data: ByteArray, start: Int): String {
        var end = start
        while (end + 1 < data.size) {
            if (data[end] == 0.toByte() && data[end + 1] == 0.toByte()) {
                return String(data, start, end - start, Charsets.UTF_16LE)
            }
            end += 2
        }
        throw PtpException("InitCommandAck 中未找到 UTF-16LE 结尾空字符")
    }

    private fun sanitizeFilename(name: String, handle: Int, format: Int): String {
        val leaf = name.substringAfterLast('\\').substringAfterLast('/')
        val cleaned = leaf.replace(INVALID_FILENAME_CHARS, "_").trim().trim('.')
        if (cleaned.isNotBlank()) {
            if (cleaned.length <= MAX_FILENAME_LENGTH) return cleaned
            val dot = cleaned.lastIndexOf('.')
            val suffix = if (dot > 0) cleaned.substring(dot).take(16) else ""
            return cleaned.substring(0, dot.takeIf { it > 0 } ?: cleaned.length)
                .take(MAX_FILENAME_LENGTH - suffix.length) + suffix
        }
        val extension = if (format == PtpIpConstants.FMT_RAW) "NEF" else "JPG"
        return "NIKON_${handle.toUInt().toString(16)}.$extension"
    }

    private fun uniqueFile(directory: File, name: String): File {
        val original = File(directory, name)
        if (!original.exists()) return original
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val extension = if (dot > 0) name.substring(dot) else ""
        var index = 1
        while (true) {
            val candidate = File(directory, "${base}_$index$extension")
            if (!candidate.exists()) return candidate
            index++
        }
    }

    private fun formatFromName(filename: String): Int =
        if (filename.endsWith(".NEF", true)) PtpIpConstants.FMT_RAW
        else PtpIpConstants.FMT_EXIF_JPEG

    private fun handleName(handle: Int): String = "NIKON_${handle.toUInt().toString(16)}"

    private fun parsePtpDate(value: String): Long? {
        if (value.isBlank()) return null
        return runCatching {
            SimpleDateFormat("yyyyMMdd'T'HHmmss", Locale.US).parse(value)?.time
        }.getOrNull()
    }

    private fun decodeGuid(value: String): ByteArray {
        val normalized = value.trim().replace("-", "").lowercase(Locale.ROOT)
        require(normalized.matches(GUID_HEX)) { "Client GUID must be 16-byte hexadecimal" }
        return ByteArray(16) { index ->
            normalized.substring(index * 2, index * 2 + 2).toInt(16).toByte()
        }
    }

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    private fun readUInt32(data: ByteArray, offset: Int): Long =
        (data[offset].toLong() and 0xffL) or
            ((data[offset + 1].toLong() and 0xffL) shl 8) or
            ((data[offset + 2].toLong() and 0xffL) shl 16) or
            ((data[offset + 3].toLong() and 0xffL) shl 24)

    private fun ByteArrayOutputStream.writeUInt16(value: Int) {
        write(value and 0xff)
        write((value ushr 8) and 0xff)
    }

    private fun ByteArrayOutputStream.writeUInt32(value: Long) {
        repeat(4) { index -> write(((value ushr (index * 8)) and 0xff).toInt()) }
    }

    private fun ByteArrayOutputStream.writeUInt64(value: Long) {
        repeat(8) { index -> write(((value ushr (index * 8)) and 0xff).toInt()) }
    }

    private class Cursor(private val data: ByteArray, private val label: String) {
        private var offset = 0
        val remaining: Int get() = data.size - offset

        fun u8(): Int {
            requireBytes(1)
            return data[offset++].toInt() and 0xff
        }

        fun u16(): Int {
            requireBytes(2)
            val value = (data[offset].toInt() and 0xff) or
                ((data[offset + 1].toInt() and 0xff) shl 8)
            offset += 2
            return value
        }

        fun u32(): Long {
            requireBytes(4)
            val value = (data[offset].toLong() and 0xffL) or
                ((data[offset + 1].toLong() and 0xffL) shl 8) or
                ((data[offset + 2].toLong() and 0xffL) shl 16) or
                ((data[offset + 3].toLong() and 0xffL) shl 24)
            offset += 4
            return value
        }

        fun u64(): Long {
            requireBytes(8)
            var value = 0L
            repeat(8) { index ->
                value = value or ((data[offset + index].toLong() and 0xffL) shl (index * 8))
            }
            offset += 8
            return value
        }

        fun u32AsInt(field: String): Int {
            val value = u32()
            if (value > Int.MAX_VALUE) throw PtpException("$label.$field 超出整数范围：$value")
            return value.toInt()
        }

        fun bytes(length: Int): ByteArray {
            requireBytes(length)
            return data.copyOfRange(offset, offset + length).also { offset += length }
        }

        fun ptpString(): String {
            val characterCount = u8()
            if (characterCount == 0) return ""
            val encoded = bytes(characterCount * 2)
            val contentLength = if (
                encoded.size >= 2 &&
                encoded[encoded.lastIndex] == 0.toByte() &&
                encoded[encoded.lastIndex - 1] == 0.toByte()
            ) encoded.size - 2 else encoded.size
            return String(encoded, 0, contentLength, Charsets.UTF_16LE)
        }

        fun u16Set(): Set<Int> {
            val count = u32AsInt("arrayCount")
            if (count > remaining / 2) {
                throw PtpException("$label 数组长度无效：$count，剩余$remaining 字节")
            }
            return buildSet(count) { repeat(count) { add(u16()) } }
        }

        private fun requireBytes(length: Int) {
            if (length < 0 || remaining < length) {
                throw PtpException("$label 数据不足：需要$length 字节，剩余$remaining 字节")
            }
        }
    }

    companion object {
        private const val TAG = "WifiTransport"
        private const val PRIVATE_OP_ADVANCED_TRANSFER = 1
        private const val PRIVATE_OP_CHANGE_APPLICATION_MODE = 7
        private const val PRIVATE_OP_CONFIRM_PAIRING = 10
        private const val PRIVATE_OP_GET_PAIRING_CODE = 23
        private const val PRIVATE_OP_EXTENDED_PARTIAL_OBJECT = 24
        private const val PRIVATE_VALUE_GROUP_TRANSFER = 1
        private const val PRIVATE_VALUE_PAIRING_ACCEPT = 1
        private const val PRIVATE_VALUE_SELECTED_TRANSFER = 2
        private const val DATA_PHASE_NO_OUTBOUND_DATA = 1L
        private const val DATA_PHASE_HOST_TO_CAMERA = 2L
        private const val UINT32_MASK = 0xffff_ffffL
        private const val MAX_PACKET_SIZE = 512L * 1024L * 1024L
        private const val MAX_OPERATION_DATA_SIZE = 32L * 1024L * 1024L
        private const val MAX_IN_MEMORY_OBJECT_SIZE = 64L * 1024L * 1024L
        private const val FINGERPRINT_BLOCK_SIZE = 64 * 1024
        private const val MAX_FILENAME_LENGTH = 180
        private val GUID_HEX = Regex("^[0-9a-f]{32}$")
        private val INVALID_FILENAME_CHARS = Regex("[\\\\/:*?\"<>|\\u0000-\\u001f]")
        private val RECOVERABLE_SOCKET_WORDS = listOf(
            "closed",
            "reset",
            "broken pipe",
            "abort",
            "unreachable",
            "refused",
            "network",
            "socket",
        )
    }
}
