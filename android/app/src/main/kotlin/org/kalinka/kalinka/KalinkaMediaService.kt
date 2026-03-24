package org.kalinka.kalinka

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.VolumeProviderCompat
import androidx.media.app.NotificationCompat.MediaStyle
import android.util.Log
import androidx.media.session.MediaButtonReceiver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.net.URL
import java.util.concurrent.TimeUnit

class KalinkaMediaService : Service() {

    companion object {
        private const val TAG = "KalinkaMedia"
        const val CHANNEL_ID = "KAI_MEDIA_CHANNEL"
        const val NOTIFICATION_ID = 1001
        const val ACTION_PLAY = "org.kalinka.kalinka.ACTION_PLAY"
        const val ACTION_PAUSE = "org.kalinka.kalinka.ACTION_PAUSE"
        const val ACTION_NEXT = "org.kalinka.kalinka.ACTION_NEXT"
        const val ACTION_PREV = "org.kalinka.kalinka.ACTION_PREV"

        private const val VOLUME_ECHO_SUPPRESS_MS = 1_500L
    }

    inner class LocalBinder : Binder() {
        fun getService(): KalinkaMediaService = this@KaiMediaService
    }

    private val binder = LocalBinder()
    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var volumeProvider: VolumeProviderCompat
    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())
    private val mainHandler = Handler(Looper.getMainLooper())

    // --- Connection config ---
    private var host: String = ""
    private var port: Int = 0
    private var isEnabled = false

    // --- WebSocket connections ---
    private val okHttpClient = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .build()
    private var queueWs: WebSocket? = null
    private var deviceWs: WebSocket? = null

    // Commands queued while WS is not yet open (e.g. user taps button before first connection).
    private var pendingQueueCommand: String? = null

    // --- Playback state ---
    private var currentTitle: String = ""
    private var currentArtist: String = ""
    private var currentAlbumArtUrl: String? = null
    private var currentDurationMs: Long = 0
    private var currentPositionMs: Long = 0
    private var currentIsPlaying: Boolean = false
    private var currentPlayerState: String = "STOPPED"  // PLAYING, PAUSED, BUFFERING, STOPPED, ERROR
    private var currentVolume: Int = 50
    private var maxVolume: Int = 100
    private var currentAlbumArt: Bitmap? = null
    private var albumArtJob: Job? = null

    // --- Volume echo suppression ---
    private var volumeChangeModeActive = false
    private val clearVolumeModeRunnable = Runnable { volumeChangeModeActive = false }

    // --- Volume send debounce ---
    private var pendingVolumeToSend: Int? = null
    private val sendVolumeRunnable = Runnable {
        pendingVolumeToSend?.let { vol ->
            pendingVolumeToSend = null
            sendDeviceCommand("""{"command":"set_volume","volume":$vol}""")
        }
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")
        createNotificationChannel()
        setupMediaSession()
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand action=${intent?.action}")
        // Forward hardware media button events (headphones, etc.) to the session callback.
        MediaButtonReceiver.handleIntent(mediaSession, intent)

        when (intent?.action) {
            ACTION_PLAY -> sendResumeOrPlay()
            ACTION_PAUSE -> sendQueueCommand("""{"command":"pause","paused":true}""")
            ACTION_NEXT -> sendQueueCommand("""{"command":"next"}""")
            ACTION_PREV -> sendQueueCommand("""{"command":"prev"}""")
            else -> {
                // Initial start: must call startForeground() within 5 seconds.
                postNotification()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        closeConnections()
        mediaSession.release()
        albumArtJob?.cancel()
        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // Public API (called from KaiMediaPlugin)
    // -------------------------------------------------------------------------

    fun enable(newHost: String, newPort: Int) {
        Log.d(TAG, "enable: host=$newHost port=$newPort")
        if (newHost != host || newPort != port) {
            closeConnections()
        }
        host = newHost
        port = newPort
        isEnabled = true
        connectQueueWs()
        connectDeviceWs()
    }

    fun disable() {
        Log.d(TAG, "disable")
        isEnabled = false
        closeConnections()
        hideNotification()
    }

    // -------------------------------------------------------------------------
    // WebSocket connections
    // -------------------------------------------------------------------------

    private fun connectQueueWs() {
        val url = "ws://$host:$port/queue/ws"
        Log.d(TAG, "connectQueueWs: $url")
        val old = queueWs; queueWs = null; old?.close(1000, null)

        val request = Request.Builder().url(url).build()
        val ws = okHttpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "queueWs onOpen")
                mainHandler.post {
                    if (webSocket !== queueWs) return@post
                    pendingQueueCommand?.let { cmd ->
                        Log.d(TAG, "queueWs flushing pendingCommand: $cmd")
                        pendingQueueCommand = null
                        webSocket.send(cmd)
                    }
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "queueWs message: ${text.take(120)}")
                mainHandler.post { if (webSocket === queueWs) handleQueueEvent(text) }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "queueWs onFailure: ${t.message} response=${response?.code}")
                mainHandler.post { if (webSocket === queueWs) disable() }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "queueWs onClosed: code=$code reason=$reason")
                mainHandler.post { if (webSocket === queueWs && isEnabled) disable() }
            }
        })
        queueWs = ws
    }

    private fun connectDeviceWs() {
        val url = "ws://$host:$port/device/ws"
        Log.d(TAG, "connectDeviceWs: $url")
        val old = deviceWs; deviceWs = null; old?.close(1000, null)

        val request = Request.Builder().url(url).build()
        val ws = okHttpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "deviceWs onOpen")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "deviceWs message: ${text.take(120)}")
                mainHandler.post { if (webSocket === deviceWs) handleDeviceEvent(text) }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "deviceWs onFailure: ${t.message} response=${response?.code}")
                mainHandler.post { if (webSocket === deviceWs) disable() }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "deviceWs onClosed: code=$code reason=$reason")
                mainHandler.post { if (webSocket === deviceWs && isEnabled) disable() }
            }
        })
        deviceWs = ws
    }

    private fun closeConnections() {
        val q = queueWs; queueWs = null; q?.close(1000, null)
        val d = deviceWs; deviceWs = null; d?.close(1000, null)
    }

    private fun sendQueueCommand(json: String) {
        val ws = queueWs
        if (ws != null) ws.send(json) else pendingQueueCommand = json
    }

    private fun sendDeviceCommand(json: String) {
        deviceWs?.send(json)
    }

    private fun sendResumeOrPlay() {
        if (currentPlayerState == "PAUSED") {
            sendQueueCommand("""{"command":"pause","paused":false}""")
        } else {
            sendQueueCommand("""{"command":"play"}""")
        }
    }

    // -------------------------------------------------------------------------
    // Event handling
    // -------------------------------------------------------------------------

    private fun handleQueueEvent(text: String) {
        try {
            val json = JSONObject(text)
            val eventType = json.optString("event_type")
            Log.d(TAG, "handleQueueEvent: event_type=$eventType")
            when (eventType) {
                "state_changed" -> {
                    val state = json.optJSONObject("state") ?: run {
                        Log.w(TAG, "state_changed: missing 'state' field")
                        return
                    }
                    updateFromPlaybackState(state, serverTimeNs = null)
                }
                "replay_event" -> {
                    val stateType = json.optString("state_type")
                    Log.d(TAG, "replay_event: state_type=$stateType")
                    if (stateType == "PlayQueueState") {
                        val outerState = json.optJSONObject("state") ?: run {
                            Log.w(TAG, "replay_event: missing 'state' field")
                            return
                        }
                        val playbackState = outerState.optJSONObject("playback_state") ?: run {
                            Log.w(TAG, "replay_event: missing 'playback_state' field; keys=${outerState.keys().asSequence().toList()}")
                            return
                        }
                        val serverTimeNs = if (json.has("server_time_ns")) json.getLong("server_time_ns") else null
                        updateFromPlaybackState(playbackState, serverTimeNs)
                    }
                }
                else -> Log.d(TAG, "handleQueueEvent: ignoring event_type=$eventType")
            }
        } catch (e: Exception) {
            Log.e(TAG, "handleQueueEvent exception: $e")
        }
    }

    private fun updateFromPlaybackState(stateJson: JSONObject, serverTimeNs: Long?) {
        val stateStr = stateJson.optString("state", "")
        val newIsPlaying = stateStr == "PLAYING" || stateStr == "BUFFERING"
        val isStopped = stateStr == "STOPPED" || stateStr == "ERROR"
        currentPlayerState = stateStr
        val trackJson0 = stateJson.optJSONObject("current_track")
        Log.d(TAG, "updateFromPlaybackState: state=$stateStr isPlaying=$newIsPlaying isStopped=$isStopped hasTrack=${trackJson0 != null} title=${trackJson0?.optString("title")}")

        val reportedPositionMs = stateJson.optLong("position", 0L)
        val adjustedPositionMs = if (serverTimeNs != null && newIsPlaying) {
            val timestampNs = stateJson.optLong("timestamp_ns", 0L)
            val ageMs = ((serverTimeNs - timestampNs) / 1_000_000L).coerceAtLeast(0L)
            reportedPositionMs + ageMs
        } else {
            reportedPositionMs
        }

        currentIsPlaying = newIsPlaying
        currentPositionMs = adjustedPositionMs

        val trackJson = stateJson.optJSONObject("current_track")
        if (trackJson != null) {
            currentTitle = trackJson.optString("title", "")
            currentDurationMs = (trackJson.optDouble("duration", 0.0) * 1000).toLong()
            currentArtist = when {
                !trackJson.isNull("performer") ->
                    trackJson.optJSONObject("performer")?.optString("name", "")
                        ?.takeIf { it.isNotEmpty() }
                        ?: trackJson.optJSONObject("album")?.optString("title", "") ?: ""
                !trackJson.isNull("album") ->
                    trackJson.optJSONObject("album")?.optString("title", "") ?: ""
                else -> ""
            }

            val newArtUrl = trackJson.optJSONObject("album")
                ?.takeIf { !it.isNull("image") }
                ?.optJSONObject("image")
                ?.optString("small", "")
                ?.takeIf { it.isNotEmpty() }
                ?.let { path ->
                    if (path.startsWith("http")) path
                    else {
                        val sep = if (path.startsWith("/")) "" else "/"
                        "http://$host:$port$sep$path"
                    }
                }

            Log.d(TAG, "albumArt: newArtUrl=$newArtUrl currentAlbumArtUrl=$currentAlbumArtUrl changed=${newArtUrl != currentAlbumArtUrl}")
            if (newArtUrl != currentAlbumArtUrl) {
                currentAlbumArtUrl = newArtUrl
                currentAlbumArt = null
                albumArtJob?.cancel()
                if (newArtUrl != null) {
                    albumArtJob = serviceScope.launch {
                        Log.d(TAG, "albumArt: loading $newArtUrl")
                        currentAlbumArt = loadBitmapFromUrl(newArtUrl)
                        Log.d(TAG, "albumArt: loaded=${currentAlbumArt != null}")
                        updateMediaSessionMetadata()
                        if (!isStopped) postNotification()
                    }
                }
            }
        }

        if (isStopped) { hideNotification(); return }

        updateMediaSessionMetadata()
        updatePlaybackState()
        postNotification()
    }

    private fun handleDeviceEvent(text: String) {
        try {
            val json = JSONObject(text)
            val volume = when (json.optString("event_type")) {
                "volume_changed" -> json.optJSONObject("volume")
                "replay_event" -> if (json.optString("state_type") == "ExtDeviceState")
                    json.optJSONObject("state")?.optJSONObject("volume") else null
                else -> null
            } ?: return

            if (volumeChangeModeActive) return
            applyVolume(volume.optInt("current_volume", currentVolume), volume.optInt("max_volume", maxVolume))
        } catch (_: Exception) {}
    }

    private fun applyVolume(newCurrent: Int, newMax: Int) {
        currentVolume = newCurrent
        if (newMax != maxVolume) {
            maxVolume = newMax
            setupVolumeProvider(newMax, newCurrent)
        } else {
            volumeProvider.currentVolume = newCurrent
        }
    }

    // -------------------------------------------------------------------------
    // MediaSession & notification
    // -------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Media Playback", NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Kalinka media playback controls"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun setupMediaSession() {
        val mediaButtonReceiver = ComponentName(this, MediaButtonReceiver::class.java)
        mediaSession = MediaSessionCompat(this, "KaiMediaSession", mediaButtonReceiver, null).apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() { sendResumeOrPlay() }
                override fun onPause() { sendQueueCommand("""{"command":"pause","paused":true}""") }
                override fun onSkipToNext() { sendQueueCommand("""{"command":"next"}""") }
                override fun onSkipToPrevious() { sendQueueCommand("""{"command":"prev"}""") }
                override fun onStop() { sendQueueCommand("""{"command":"stop"}""") }
                override fun onSeekTo(pos: Long) {
                    sendQueueCommand("""{"command":"seek","position_ms":$pos}""")
                }
            })
            isActive = true
        }
        setupVolumeProvider(maxVolume, currentVolume)
    }

    private fun setupVolumeProvider(maxVol: Int, currentVol: Int) {
        volumeProvider = object : VolumeProviderCompat(
            VOLUME_CONTROL_ABSOLUTE, maxVol, currentVol.coerceIn(0, maxVol)
        ) {
            override fun onAdjustVolume(direction: Int) {
                if (direction != 1 && direction != -1) return
                val newVol = (currentVolume + direction).coerceIn(0, maxVol)
                currentVolume = newVol
                enterVolumeSuppressMode()
                scheduleVolumeCommand(newVol)
            }
            override fun onSetVolumeTo(volume: Int) {
                val newVol = volume.coerceIn(0, maxVol)
                currentVolume = newVol
                enterVolumeSuppressMode()
                scheduleVolumeCommand(newVol)
            }
        }
        mediaSession.setPlaybackToRemote(volumeProvider)
    }

    private fun scheduleVolumeCommand(volume: Int) {
        pendingVolumeToSend = volume
        mainHandler.removeCallbacks(sendVolumeRunnable)
        mainHandler.postDelayed(sendVolumeRunnable, 50L)
    }

    private fun enterVolumeSuppressMode() {
        volumeChangeModeActive = true
        mainHandler.removeCallbacks(clearVolumeModeRunnable)
        mainHandler.postDelayed(clearVolumeModeRunnable, VOLUME_ECHO_SUPPRESS_MS)
    }

    private fun updateMediaSessionMetadata() {
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDurationMs)
            .apply { currentAlbumArt?.let { putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it) } }
            .build()
        mediaSession.setMetadata(metadata)
    }

    private fun updatePlaybackState() {
        val state = if (currentIsPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_STOP or
                PlaybackStateCompat.ACTION_SEEK_TO
            )
            .setState(state, currentPositionMs, if (currentIsPlaying) 1f else 0f)
            .build()
        mediaSession.setPlaybackState(playbackState)
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        fun serviceIntent(action: String, code: Int) = PendingIntent.getService(
            this, code,
            Intent(this, KalinkaMediaService::class.java).apply { this.action = action },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val prevAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous, "Previous", serviceIntent(ACTION_PREV, 1)
        )
        val playPauseAction = if (currentIsPlaying) {
            NotificationCompat.Action(android.R.drawable.ic_media_pause, "Pause", serviceIntent(ACTION_PAUSE, 2))
        } else {
            NotificationCompat.Action(android.R.drawable.ic_media_play, "Play", serviceIntent(ACTION_PLAY, 3))
        }
        val nextAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next, "Next", serviceIntent(ACTION_NEXT, 4)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentTitle.ifEmpty { "Kalinka" })
            .setContentText(currentArtist)
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(currentAlbumArt)
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()
    }

    fun postNotification() {
        Log.d(TAG, "postNotification: title=$currentTitle artist=$currentArtist isPlaying=$currentIsPlaying positionMs=$currentPositionMs durationMs=$currentDurationMs hasArt=${currentAlbumArt != null}")
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    fun hideNotification() {
        Log.d(TAG, "hideNotification")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private suspend fun loadBitmapFromUrl(url: String): Bitmap? =
        withContext(Dispatchers.IO) {
            try {
                val connection = URL(url).openConnection()
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                connection.connect()
                BitmapFactory.decodeStream(connection.getInputStream())
            } catch (e: Exception) {
                Log.e(TAG, "albumArt: failed to load $url: $e")
                null
            }
        }
}
