package com.cacl2.ztransfer

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.cacl2.ztransfer.camera.CameraChannelHandler
import com.cacl2.ztransfer.camera.PtpManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Flutter host Activity for ZTransfer.
 *
 * Owns the [CameraChannelHandler] lifecycle and bridges PTP events to the
 * Flutter UI via MethodChannel + EventChannel.
 *
 * USB attach/detach broadcasts are handled here so the camera is detected
 * regardless of whether the app was launched by the USB event or opened
 * manually. When a Nikon USB device is found, the connection is routed
 * through [CameraChannelHandler.usbTransport] for a unified transport
 * experience (USB + Wi-Fi).
 */
class MainActivity : FlutterActivity() {

    private lateinit var channelHandler: CameraChannelHandler
    private lateinit var usbManager: UsbManager

    // ── Flutter engine configuration ───────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channelHandler = CameraChannelHandler(this)

        // Restore active project so new photos go to the right folder
        val activeId = channelHandler.projectStore.getActiveProjectId()
        if (activeId != null) {
            getSharedPreferences("ztransfer", Context.MODE_PRIVATE)
                .edit().putString("active_project_id", activeId).apply()
        }

        channelHandler.register(
            methodBinaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            eventBinaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    // ── Activity lifecycle ─────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            addAction(ACTION_USB_PERMISSION)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Context.RECEIVER_NOT_EXPORTED
        } else {
            0
        }
        registerReceiver(usbReceiver, filter, flags)

        // Handle launch-by-USB-attach
        intent?.let { handleIntent(it) }

        // Check for already-connected camera
        findAndConnectCamera()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(usbReceiver) } catch (_: Exception) {}
        // Disconnect any active transport
        if (::channelHandler.isInitialized) {
            channelHandler.usbTransport.runCatching { }
            channelHandler.wifiTransport.runCatching { }
        }
    }

    // ── USB discovery ──────────────────────────────────────────────────────

    private fun handleIntent(intent: Intent) {
        if (UsbManager.ACTION_USB_DEVICE_ATTACHED == intent.action) {
            val device = intent.getParcelableExtra<UsbDevice>(
                UsbManager.EXTRA_DEVICE
            ) ?: return
            if (device.vendorId == PtpManager.NIKON_VENDOR_ID) {
                onNikonFound(device)
            }
        }
    }

    private fun findAndConnectCamera() {
        for (device in usbManager.deviceList.values) {
            if (device.vendorId == PtpManager.NIKON_VENDOR_ID) {
                onNikonFound(device)
                return
            }
        }
    }

    private fun onNikonFound(device: UsbDevice) {
        if (usbManager.hasPermission(device)) {
            Log.i(TAG, "Permission already granted — connecting via USB transport")
            channelHandler.usbTransport.connectToDevice(device, usbManager)
        } else {
            Log.i(TAG, "Requesting USB permission")
            requestPermission(device)
        }
    }

    // ── USB permission ─────────────────────────────────────────────────────

    private fun requestPermission(device: UsbDevice) {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pi = PendingIntent.getBroadcast(
            this, 42,
            Intent(ACTION_USB_PERMISSION).apply {
                putExtra(UsbManager.EXTRA_DEVICE, device)
            },
            flags
        )
        usbManager.requestPermission(device, pi)
    }

    // ── BroadcastReceiver ───────────────────────────────────────────────────

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device = intent.getParcelableExtra<UsbDevice>(
                        UsbManager.EXTRA_DEVICE
                    ) ?: return
                    Log.i(TAG, "USB attached: ${device.productName}")
                    if (device.vendorId == PtpManager.NIKON_VENDOR_ID) {
                        onNikonFound(device)
                    }
                }

                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = intent.getParcelableExtra<UsbDevice>(
                        UsbManager.EXTRA_DEVICE
                    ) ?: return
                    Log.i(TAG, "USB detached: ${device.productName}")
                    if (device.vendorId == PtpManager.NIKON_VENDOR_ID) {
                        // Disconnect USB transport (fire-and-forget)
                        CoroutineScope(Dispatchers.IO).launch {
                            channelHandler.usbTransport.disconnect()
                        }
                    }
                }

                ACTION_USB_PERMISSION -> {
                    val granted = intent.getBooleanExtra(
                        UsbManager.EXTRA_PERMISSION_GRANTED, false
                    )
                    val device = intent.getParcelableExtra<UsbDevice>(
                        UsbManager.EXTRA_DEVICE
                    )
                    Log.i(TAG, "Permission result: granted=$granted")
                    if (granted && device != null) {
                        channelHandler.usbTransport.connectToDevice(
                            device, usbManager
                        )
                    }
                }
            }
        }
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val ACTION_USB_PERMISSION =
            "com.cacl2.ztransfer.action.USB_PERMISSION"
    }

    init {
        try {
            System.loadLibrary("ztransfer_core")
            Log.i(TAG, "libztransfer_core.so loaded")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "libztransfer_core.so not available: ${e.message}")
        }
    }
}
