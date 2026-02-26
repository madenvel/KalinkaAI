package org.kalinka.kai

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class KaiMediaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var mediaService: KaiMediaService? = null
    private var serviceBound = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val localBinder = binder as? KaiMediaService.LocalBinder ?: return
            mediaService = localBinder.getService()
            mediaService?.actionListener = { event ->
                eventSink?.success(event)
            }
            serviceBound = true
            // Process any pending info that arrived before bind completed
            pendingInfo?.let { info ->
                pendingInfo = null
                applyPlaybackInfo(info)
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            mediaService = null
            serviceBound = false
        }
    }

    private var pendingInfo: Map<*, *>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "org.kalinka.kai/media_session")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "org.kalinka.kai/media_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        unbindAndStop()
        context = null
    }

    // --- MethodCallHandler ---

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updatePlaybackInfo" -> {
                val args = call.arguments as? Map<*, *>
                if (args != null) {
                    if (!serviceBound) {
                        pendingInfo = args
                        startAndBindService()
                    } else {
                        applyPlaybackInfo(args)
                    }
                }
                result.success(null)
            }
            "updateVolumeOnly" -> {
                val args = call.arguments as? Map<*, *> ?: return result.success(null)
                val currentVol = (args["currentVolume"] as? Int) ?: 50
                val maxVol = (args["maxVolume"] as? Int) ?: 100
                mediaService?.updateVolumeOnly(currentVol, maxVol)
                result.success(null)
            }
            "stopService" -> {
                unbindAndStop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun applyPlaybackInfo(args: Map<*, *>) {
        val title = (args["title"] as? String) ?: ""
        val artist = (args["artist"] as? String) ?: ""
        val albumArtUrl = args["albumArtUrl"] as? String
        val durationMs = ((args["durationMs"] as? Int)?.toLong())
            ?: ((args["durationMs"] as? Long) ?: 0L)
        val positionMs = ((args["positionMs"] as? Int)?.toLong())
            ?: ((args["positionMs"] as? Long) ?: 0L)
        val isPlaying = (args["isPlaying"] as? Boolean) ?: false
        val currentVol = (args["currentVolume"] as? Int) ?: 50
        val maxVol = (args["maxVolume"] as? Int) ?: 100

        mediaService?.updatePlaybackInfo(
            title, artist, albumArtUrl,
            durationMs, positionMs, isPlaying,
            currentVol, maxVol
        )
    }

    private fun startAndBindService() {
        val ctx = context ?: return
        requestNotificationPermissionIfNeeded()
        val intent = Intent(ctx, KaiMediaService::class.java)
        ContextCompat.startForegroundService(ctx, intent)
        ctx.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    private fun unbindAndStop() {
        val ctx = context ?: return
        if (serviceBound) {
            mediaService?.hideNotification()
            mediaService?.actionListener = null
            ctx.unbindService(serviceConnection)
            serviceBound = false
            mediaService = null
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val activity = activityBinding?.activity ?: return
            if (ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    9001
                )
            }
        }
    }

    // --- EventChannel.StreamHandler ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        mediaService?.actionListener = { event -> eventSink?.success(event) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }
}
