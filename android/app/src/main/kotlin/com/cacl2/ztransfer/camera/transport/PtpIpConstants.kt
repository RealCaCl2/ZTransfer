package com.cacl2.ztransfer.camera.transport

/**
 * PTP/IP protocol constants shared between transport implementations.
 *
 * These are protocol-level definitions — the same codes are used
 * over USB PTP (MTP) and Wi-Fi PTP/IP.
 *
 * References:
 * - ISO 15740:2013 (PTP/IP transport)
 * - USB PTP / MTP specification
 */
object PtpIpConstants {

    // ── PTP/IP Packet Types ───────────────────────────────────────────────

    const val PKT_INIT_CMD_REQ  = 1
    const val PKT_INIT_CMD_ACK  = 2
    const val PKT_INIT_EVT_REQ  = 3
    const val PKT_INIT_EVT_ACK  = 4
    const val PKT_INIT_FAIL     = 5
    const val PKT_OP_REQ        = 6
    const val PKT_OP_RESP       = 7
    const val PKT_EVENT         = 8
    const val PKT_START_DATA    = 9
    const val PKT_DATA          = 10
    const val PKT_CANCEL        = 11
    const val PKT_END_DATA      = 12
    const val PKT_PROBE_REQ     = 13
    const val PKT_PROBE_RESP    = 14

    // ── PTP Operation Codes ───────────────────────────────────────────────

    const val OP_GetDeviceInfo       = 0x1001
    const val OP_OpenSession         = 0x1002
    const val OP_CloseSession        = 0x1003
    const val OP_GetStorageIDs       = 0x1004
    const val OP_GetStorageInfo      = 0x1005
    const val OP_GetNumObjects       = 0x1006
    const val OP_GetObjectHandles    = 0x1007
    const val OP_GetObjectInfo       = 0x1008
    const val OP_GetObject           = 0x1009
    const val OP_GetThumb            = 0x100A
    const val OP_DeleteObject        = 0x100B
    const val OP_GetDevicePropValue  = 0x1015
    const val OP_GetPartialObject    = 0x101B

    // Nikon vendor extension opcodes
    const val OP_NikonGetLargeThumb  = 0x90C4
    const val OP_NikonGetLssImage    = 0x9522

    // Nikon "Connect to computer" mode — opcodes provided by libztransfer_core.so
    // nativePrivateOpcode lookup table at offset 0xdfe0 (55 entries, 8 bytes each).
    // These are verified lookup values, not guesses. The previous
    // hardcoded values (0x9010, 0x9435, 0x935A, 0x952B, 0x9431, 0x9400) were ALL
    // wrong and caused the camera to reject every private operation.
    const val OP_AdvancedTransfer          = 0x907C
    const val OP_ChangeApplicationMode     = 0x9280
    const val OP_ConfirmPairing            = 0x93D4
    const val OP_GetEventEx                = 0x9714
    const val OP_GetPairingCode            = 0x9838
    const val OP_GetPartialObjectEx        = 0x9918
    const val OP_GetPartialObjectHighSpeed = 0x9A6C

    // ── PTP Event Codes ───────────────────────────────────────────────────

    const val EVT_ObjectAdded         = 0x4002
    const val EVT_ObjectRemoved       = 0x4003
    const val EVT_StoreAdded          = 0x4004
    const val EVT_StoreRemoved        = 0x4005
    const val EVT_DevicePropChanged   = 0x4006
    const val EVT_CaptureComplete     = 0x400D

    // ── PTP Response Codes ────────────────────────────────────────────────

    const val RC_OK = 0x2001
    const val RC_SessionNotOpen = 0x2003
    const val RC_OperationNotSupported = 0x2005    // Previously mislabelled RC_InvalidParam.
    /** The compatibility flow treats decimal 8207 (`0x200F`) as AccessDenied. */
    const val RC_AccessDenied = 0x200F
    const val RC_InvalidObjectHandle = 0x2009
    const val RC_DeviceBusy = 0x2019
    const val RC_TransactionCancelled = 0x201F

    // ── Device Property Codes ─────────────────────────────────────────────

    const val DPC_BatteryLevel = 0x5001
    const val DPC_NikonRetractableLensState = 0xD09C

    // ── Object Format Codes ───────────────────────────────────────────────

    const val FMT_EXIF_JPEG   = 0x3801
    const val FMT_JFIF_JPEG   = 0x3800
    const val FMT_RAW         = 0x3000
    const val FMT_ASSOCIATION = 0x3001  // folder

    // ── Nikon Vendor ID ───────────────────────────────────────────────────

    const val NIKON_VENDOR_ID = 0x04B0

    // ── LSS Image Sizes (NikonGetLssImage param) ──────────────────────────

    const val LSS_AUTO    = 0
    const val LSS_VGA     = 1
    const val LSS_FULL_HD = 3
    const val LSS_8MP     = 4

    // ── Timing ────────────────────────────────────────────────────────────

    /** Socket connect timeout kept for legacy callers (ms). */
    const val CONNECT_TIMEOUT_MS = 5_000

    /** Pairing-command socket connect timeout (ms). */
    const val PAIRING_CONNECT_TIMEOUT_MS = 8_000

    /** Pairing command timeout, including the camera/user confirmation window (ms). */
    const val PAIRING_COMMAND_TIMEOUT_MS = 120_000

    /** Maximum time the camera challenge waits for local confirmation (ms). */
    const val PAIRING_USER_TIMEOUT_MS = 180_000L

    /**
     * Some Nikon bodies acknowledge ConfirmPairing before the user presses OK,
     * but do not accept the saved GUID on a new socket until that camera-side
     * confirmation is complete.
     */
    const val PAIRING_FINALIZE_TIMEOUT_MS = 180_000L
    const val PAIRING_RECONNECT_INTERVAL_MS = 2_000L
    const val PAIRING_RECONNECT_CONNECT_TIMEOUT_MS = 5_000
    const val PAIRING_RECONNECT_COMMAND_TIMEOUT_MS = 10_000

    /** Best-effort CloseSession timeout after a successful pairing confirmation (ms). */
    const val PAIRING_CLOSE_TIMEOUT_MS = 3_000

    /** Graceful CloseSession timeout for an explicit user disconnect (ms). */
    const val DISCONNECT_CLOSE_TIMEOUT_MS = 3_000

    /** Give Nikon firmware time to release the old command/event socket association. */
    const val DISCONNECT_SETTLE_DELAY_MS = 750L

    /** Retry a fresh command socket when an old session event arrives before InitCommandAck. */
    const val INIT_COMMAND_MAX_ATTEMPTS = 3
    const val INIT_STALE_SESSION_RETRY_DELAY_MS = 500L

    /** Picture-transfer socket connect timeout (ms). */
    const val TRANSFER_CONNECT_TIMEOUT_MS = 15_000

    /** AdvancedTransfer may block while waiting for the next selected picture (ms). */
    const val TRANSFER_COMMAND_TIMEOUT_MS = 300_000

    /** Default command read timeout (ms). */
    const val CMD_TIMEOUT_MS = 30_000

    /** Extended timeout for large file downloads (ms). */
    const val DOWNLOAD_TIMEOUT_MS = 300_000

    /** Transfer chunks accepted by the 2.0.32 implementation: 64 KiB through 16 MiB. */
    const val MIN_TRANSFER_CHUNK_SIZE = 64 * 1024
    const val DEFAULT_TRANSFER_CHUNK_SIZE = 1024 * 1024
    const val MAX_TRANSFER_CHUNK_SIZE = 16 * 1024 * 1024

    /** Event socket read timeout (ms). Short to allow checking alive flag. */
    const val EVENT_READ_TIMEOUT_MS = 2_000

    /** Give AdvancedTransfer a chance to return the same object before cancelling it for event fallback. */
    const val OBJECT_EVENT_TRANSFER_GRACE_MS = 250L

    /** Maximum connection attempts used by the service flow. */
    const val MAX_RECONNECT_ATTEMPTS = 3

    /** Base backoff delay for reconnect (ms). Multiplied by attempt number. */
    const val RECONNECT_BACKOFF_MS = 2_000L

    // ── Network ───────────────────────────────────────────────────────────

    /** Default Nikon camera PTP/IP port. */
    const val DEFAULT_PTP_PORT = 15740

    /** Default Nikon Wi-Fi hotspot IP. */
    const val DEFAULT_CAMERA_HOST = "192.168.1.1"

    /** Default client GUID for PTP/IP identification. */
    val DEFAULT_CLIENT_GUID = java.util.UUID.fromString("00112233-4455-6677-8899-AABBCCDDEEFF")

    /** Default client device name sent to the camera. */
    const val DEFAULT_DEVICE_NAME = "ZTransfer"

    /** PTP/IP protocol version (1.0). */
    const val PROTOCOL_VERSION = 0x00010000
}
