package com.cacl2.ztransfer

import android.app.Application
import com.cacl2.ztransfer.camera.CameraChannelHandler

/** Owns the camera session independently of Activity recreation. */
class ZTransferApplication : Application() {
    val cameraChannelHandler: CameraChannelHandler by lazy {
        CameraChannelHandler(applicationContext)
    }
}
