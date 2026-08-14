package com.app.rtmp_publisher

import android.app.Activity
import android.content.Context
import android.util.Log
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class NativeViewFactory(private val activity: Activity) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    var cameraNativeView: CameraNativeView? = null
    var cameraName: String = "0"
    var preset: ResolutionPreset = ResolutionPreset.low
    var enableAudio: Boolean = false
    var dartMessenger: DartMessenger? = null

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        cameraNativeView = CameraNativeView(activity, enableAudio, preset, cameraName, dartMessenger)
        return cameraNativeView!!
    }
}