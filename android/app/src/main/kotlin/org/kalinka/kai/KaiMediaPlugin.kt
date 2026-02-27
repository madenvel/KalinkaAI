package org.kalinka.kai

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.VibrationEffect.Composition.DELAY_TYPE_PAUSE
import android.os.VibrationEffect.Composition.PRIMITIVE_CLICK
import android.os.VibrationEffect.Composition.PRIMITIVE_QUICK_FALL
import android.os.VibrationEffect.Composition.PRIMITIVE_QUICK_RISE
import android.os.VibrationEffect.Composition.PRIMITIVE_TICK
import android.os.Vibrator
import android.os.VibratorManager
import androidx.annotation.RequiresApi
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
            "hapticCorkPop" -> {
                hapticCorkPop()
                result.success(null)
            }
            "hapticDelete" -> {
                hapticDelete()
                result.success(null)
            }
            "hapticTick" -> {
                hapticTick()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun hapticTick() {
        val ctx = context ?: return
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ctx.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            ctx.getSystemService(Vibrator::class.java)
        }

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(PRIMITIVE_TICK)
                    .compose()
                vibrator.vibrate(effect)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                val effect = VibrationEffect.createOneShot(15, 80)
                vibrator.vibrate(effect)
            }
            else -> {
                vibrator.vibrate(15)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.BAKLAVA)
    @Suppress("DEPRECATION")
    private fun hapticCorkPop() {
        val ctx = context ?: return
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ctx.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            ctx.getSystemService(Vibrator::class.java)
        }

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                // Best — Composition API: THUD for the body, faint TICK for resonance tail
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(PRIMITIVE_QUICK_FALL)
                    .addPrimitive(PRIMITIVE_CLICK, 0.7F, 50, DELAY_TYPE_PAUSE)
                    .compose()
                vibrator.vibrate(effect)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                // Good — stepped waveform envelope approximating attack→sustain→decay
                val effect = VibrationEffect.createWaveform(
                    longArrayOf(0, 5, 5, 15, 10),
                    intArrayOf(0, 180, 220, 80, 0),
                    -1
                )
                vibrator.vibrate(effect)
            }
            else -> {
                // Pre-Oreo fallback — single pulse
                vibrator.vibrate(30)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun hapticDelete() {
        val ctx = context ?: return
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ctx.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            ctx.getSystemService(Vibrator::class.java)
        }

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                // Reversed: crisp TICK forewarning, then THUD landing
                val effect = VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.4f, 0)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_THUD, 0.9f, 30)
                    .compose()
                vibrator.vibrate(effect)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                // Reversed envelope: light tap → heavy thud
                val effect = VibrationEffect.createWaveform(
                    longArrayOf(0, 8, 20, 30),
                    intArrayOf(0, 80, 0, 220),
                    -1
                )
                vibrator.vibrate(effect)
            }
            else -> {
                // Pre-Oreo fallback — single pulse
                vibrator.vibrate(30)
            }
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
