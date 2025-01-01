package com.app.rtmp_publisher

import android.app.Activity
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.view.TextureRegistry

interface PermissionStuff {
    fun adddListener(listener: io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener)
}

class RtmppublisherPlugin : FlutterPlugin, ActivityAware {

    private val TAG = "RtmppublisherPlugin"

    private var methodCallHandler: MethodCallHandlerImplNew? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.v(TAG, "onAttachedToEngine $flutterPluginBinding")
        this.flutterPluginBinding = flutterPluginBinding
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.v(TAG, "onDetachedFromEngine $binding")
        flutterPluginBinding = null
    }

    private fun maybeStartListening(
        activity: Activity,
        messenger: BinaryMessenger,
        permissionsRegistry: PermissionStuff,
        flutterEngine: FlutterEngine
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        methodCallHandler = MethodCallHandlerImplNew(
            activity,
            messenger,
            CameraPermissions(),
            permissionsRegistry,
            flutterEngine
        )
    }

    override fun onDetachedFromActivity() {
        Log.v(TAG, "onDetachedFromActivity")
        methodCallHandler?.stopListening()
        methodCallHandler = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.v(TAG, "onAttachedToActivity $binding")
        flutterPluginBinding?.apply {
            maybeStartListening(
                binding.activity,
                binaryMessenger,
                object : PermissionStuff {
                    override fun adddListener(listener: io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener) {
                        binding.addRequestPermissionsResultListener(listener)
                    }
                },
                flutterEngine
            )
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}



/*



package com.app.rtmp_publisher

import android.app.Activity
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.view.TextureRegistry

interface PermissionStuff {
    fun adddListener(listener: io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener)
}

class RtmppublisherPlugin : FlutterPlugin, ActivityAware {

    private val TAG = "RtmppublisherPlugin"

    private var methodCallHandler: MethodCallHandlerImplNew? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.v(TAG, "onAttachedToEngine $flutterPluginBinding")
        this.flutterPluginBinding = flutterPluginBinding
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.v(TAG, "onDetachedFromEngine $binding")
        flutterPluginBinding = null
    }

    private fun maybeStartListening(
        activity: Activity,
        messenger: BinaryMessenger,
        permissionsRegistry: PermissionStuff,
        flutterEngine: FlutterEngine
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        methodCallHandler = MethodCallHandlerImplNew(
            activity,
            messenger,
            CameraPermissions(),
            permissionsRegistry,
            flutterEngine
        )
    }

    override fun onDetachedFromActivity() {
        Log.v(TAG, "onDetachedFromActivity")
        methodCallHandler?.stopListening()
        methodCallHandler = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.v(TAG, "onAttachedToActivity $binding")
        flutterPluginBinding?.apply {
            maybeStartListening(
                binding.activity,
                binaryMessenger,
                object : PermissionStuff {
                    override fun adddListener(listener: io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener) {
                        binding.addRequestPermissionsResultListener(listener)
                    }
                },
                flutterEngine
            )
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}



 */