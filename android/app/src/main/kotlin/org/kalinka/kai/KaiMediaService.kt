package org.kalinka.kai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.VolumeProviderCompat
import androidx.media.app.NotificationCompat.MediaStyle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL

class KaiMediaService : Service() {

    companion object {
        const val CHANNEL_ID = "KAI_MEDIA_CHANNEL"
        const val NOTIFICATION_ID = 1001
        const val ACTION_PLAY = "org.kalinka.kai.ACTION_PLAY"
        const val ACTION_PAUSE = "org.kalinka.kai.ACTION_PAUSE"
        const val ACTION_NEXT = "org.kalinka.kai.ACTION_NEXT"
        const val ACTION_PREV = "org.kalinka.kai.ACTION_PREV"
        const val ACTION_STOP = "org.kalinka.kai.ACTION_STOP"
    }

    inner class LocalBinder : Binder() {
        fun getService(): KaiMediaService = this@KaiMediaService
    }

    private val binder = LocalBinder()
    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var volumeProvider: VolumeProviderCompat
    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    var actionListener: ((Map<String, Any>) -> Unit)? = null

    private var currentTitle: String = ""
    private var currentArtist: String = ""
    private var currentAlbumArtUrl: String? = null
    private var currentDurationMs: Long = 0
    private var currentPositionMs: Long = 0
    private var currentIsPlaying: Boolean = false
    private var currentVolume: Int = 50
    private var maxVolume: Int = 100
    private var currentAlbumArt: Bitmap? = null
    private var albumArtJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        setupMediaSession()
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> actionListener?.invoke(mapOf("type" to "play"))
            ACTION_PAUSE -> actionListener?.invoke(mapOf("type" to "pause"))
            ACTION_NEXT -> actionListener?.invoke(mapOf("type" to "next"))
            ACTION_PREV -> actionListener?.invoke(mapOf("type" to "prev"))
            ACTION_STOP -> actionListener?.invoke(mapOf("type" to "stop"))
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        mediaSession.release()
        albumArtJob?.cancel()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Kalinka media playback controls"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun setupMediaSession() {
        mediaSession = MediaSessionCompat(this, "KaiMediaSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    actionListener?.invoke(mapOf("type" to "play"))
                }
                override fun onPause() {
                    actionListener?.invoke(mapOf("type" to "pause"))
                }
                override fun onSkipToNext() {
                    actionListener?.invoke(mapOf("type" to "next"))
                }
                override fun onSkipToPrevious() {
                    actionListener?.invoke(mapOf("type" to "prev"))
                }
                override fun onStop() {
                    actionListener?.invoke(mapOf("type" to "stop"))
                }
                override fun onSeekTo(pos: Long) {
                    actionListener?.invoke(mapOf("type" to "seek", "positionMs" to pos))
                }
            })
            isActive = true
        }

        // Initialise with placeholder max; recreated when the server reports real maxVolume.
        setupVolumeProvider(maxVolume, currentVolume)
    }

    // Creates (or recreates) the VolumeProviderCompat with the server's actual scale.
    // Must be called whenever maxVolume changes, because the constructor arg is immutable.
    private fun setupVolumeProvider(maxVol: Int, currentVol: Int) {
        volumeProvider = object : VolumeProviderCompat(
            VOLUME_CONTROL_ABSOLUTE,
            maxVol,
            currentVol.coerceIn(0, maxVol)
        ) {
            override fun onAdjustVolume(direction: Int) {
                // Guard against ADJUST_MUTE (-100), ADJUST_UNMUTE (100), etc.
                if (direction != 1 && direction != -1) return
                val newVol = (currentVolume + direction).coerceIn(0, maxVol)
                currentVolume = newVol   // updates system volume UI immediately
                actionListener?.invoke(mapOf("type" to "volumeSet", "volume" to newVol))
            }
            override fun onSetVolumeTo(volume: Int) {
                val newVol = volume.coerceIn(0, maxVol)
                currentVolume = newVol
                actionListener?.invoke(mapOf("type" to "volumeSet", "volume" to newVol))
            }
        }
        mediaSession.setPlaybackToRemote(volumeProvider)
    }

    fun updatePlaybackInfo(
        title: String,
        artist: String,
        albumArtUrl: String?,
        durationMs: Long,
        positionMs: Long,
        isPlaying: Boolean,
        currentVol: Int,
        maxVol: Int,
    ) {
        currentTitle = title
        currentArtist = artist
        currentDurationMs = durationMs
        currentPositionMs = positionMs
        currentIsPlaying = isPlaying
        currentVolume = currentVol
        // Recreate the provider when maxVolume changes (constructor arg is immutable).
        if (maxVol != maxVolume) {
            maxVolume = maxVol
            setupVolumeProvider(maxVol, currentVol)
        } else {
            volumeProvider.currentVolume = currentVol
        }

        updateMediaSessionMetadata()
        updatePlaybackState()

        // Load album art if URL changed
        if (albumArtUrl != currentAlbumArtUrl) {
            currentAlbumArtUrl = albumArtUrl
            currentAlbumArt = null
            albumArtJob?.cancel()
            if (albumArtUrl != null) {
                albumArtJob = serviceScope.launch {
                    val bitmap = loadBitmapFromUrl(albumArtUrl)
                    currentAlbumArt = bitmap
                    updateMediaSessionMetadata()
                    postNotification()
                }
            }
        }

        postNotification()
    }

    fun updateVolumeOnly(currentVol: Int, maxVol: Int) {
        currentVolume = currentVol
        if (maxVol != maxVolume) {
            maxVolume = maxVol
            setupVolumeProvider(maxVol, currentVol)
        } else {
            volumeProvider.currentVolume = currentVol
        }
    }

    private fun updateMediaSessionMetadata() {
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDurationMs)
            .apply {
                currentAlbumArt?.let {
                    putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it)
                }
            }
            .build()
        mediaSession.setMetadata(metadata)
    }

    private fun updatePlaybackState() {
        val state = if (currentIsPlaying) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }
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
        val sessionToken = mediaSession.sessionToken

        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        fun actionIntent(action: String, requestCode: Int): PendingIntent =
            PendingIntent.getService(
                this,
                requestCode,
                Intent(this, KaiMediaService::class.java).apply { this.action = action },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        val prevAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous,
            "Previous",
            actionIntent(ACTION_PREV, 1)
        )
        val playPauseAction = if (currentIsPlaying) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause,
                "Pause",
                actionIntent(ACTION_PAUSE, 2)
            )
        } else {
            NotificationCompat.Action(
                android.R.drawable.ic_media_play,
                "Play",
                actionIntent(ACTION_PLAY, 3)
            )
        }
        val nextAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next,
            "Next",
            actionIntent(ACTION_NEXT, 4)
        )
        val stopAction = NotificationCompat.Action(
            android.R.drawable.ic_delete,
            "Stop",
            actionIntent(ACTION_STOP, 5)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentTitle.ifEmpty { "Kalinka" })
            .setContentText(currentArtist)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(currentAlbumArt)
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .addAction(stopAction)
            .setStyle(
                MediaStyle()
                    .setMediaSession(sessionToken)
                    .setShowActionsInCompactView(0, 1, 2) // prev, play/pause, next
                    .setShowCancelButton(true)
                    .setCancelButtonIntent(actionIntent(ACTION_STOP, 6))
            )
            .build()
    }

    fun postNotification() {
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)
    }

    fun hideNotification() {
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
                null
            }
        }
}
