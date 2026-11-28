package com.mawaqeety.mawaqeety

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * The full adhan at each prayer time, even when the app is closed.
 * Dart sends the coming adhans (time, title, file); they are kept so they can be re-armed after a reboot.
 * The adhan stops with its notification button, by turning the phone face down, or with the power button.
 */
object AdhanAlarms {
    private const val PREFS = "mawaqeety_adhan"
    private const val KEY = "items"
    const val EXTRA = "item"

    fun schedule(ctx: Context, items: List<Map<*, *>>) {
        cancelAll(ctx)
        val arr = JSONArray()
        for (m in items) arr.put(JSONObject(m.mapKeys { it.key.toString() }))
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
        arm(ctx)
    }

    /**
     * Each adhan's alarm is keyed by its own time (minutes since 1970), never by its position in the list:
     * re-planning can then never hand one prayer's alarm to another prayer.
     */
    private fun key(at: Long): Int = (at / 60_000L).toInt()

    /** Sets an alarm for every stored adhan still in the future. */
    fun arm(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val arr = JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
        val now = System.currentTimeMillis()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val at = o.getLong("at")
            if (at <= now) continue
            val pi = pending(ctx, key(at), o.toString())
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            else am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val arr = JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            am.cancel(pending(ctx, key(o.getLong("at")), null))
            // Alarms set by version 1.18 (keyed by position) are cleared too.
            if (o.has("id")) am.cancel(legacy(ctx, o.getInt("id")))
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }

    /** True when this phone lets the app ring at the exact minute (Android 12+ «المنبهات والتذكيرات»). */
    fun canExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        return (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
    }

    private const val FALLBACK_CHANNEL = "adhan_fallback_v1"

    /** A plain notification with the default alarm-like sound, used when the adhan service cannot start. */
    fun fallback(ctx: Context, o: JSONObject) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(FALLBACK_CHANNEL) == null) {
            nm.createNotificationChannel(android.app.NotificationChannel(FALLBACK_CHANNEL, "تنبيه وقت الصلاة",
                android.app.NotificationManager.IMPORTANCE_HIGH).apply { description = "يظهر إذا تعذّر تشغيل الأذان" })
        }
        val open = PendingIntent.getActivity(ctx, 0, ctx.packageManager.getLaunchIntentForPackage(ctx.packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, FALLBACK_CHANNEL)
            else @Suppress("DEPRECATION") Notification.Builder(ctx).setDefaults(Notification.DEFAULT_SOUND)
        b.setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(o.optString("title"))
            .setContentText(o.optString("body"))
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(open)
            .setAutoCancel(true)
        nm.notify(7299, b.build())
    }

    /** True when [at] is still one of the planned adhans (it was not re-planned or turned off). */
    fun isPlanned(ctx: Context, at: Long): Boolean {
        val arr = JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
        return (0 until arr.length()).any { arr.getJSONObject(it).getLong("at") == at }
    }

    private fun pending(ctx: Context, key: Int, json: String?): PendingIntent {
        val i = Intent(ctx, AdhanReceiver::class.java).setAction("com.mawaqeety.ADHAN.T$key")
        if (json != null) i.putExtra(EXTRA, json)
        return PendingIntent.getBroadcast(ctx, key, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun legacy(ctx: Context, id: Int): PendingIntent =
        PendingIntent.getBroadcast(ctx, 7300 + id, Intent(ctx, AdhanReceiver::class.java).setAction("com.mawaqeety.ADHAN.$id"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, "android.intent.action.QUICKBOOT_POWERON",
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" -> AdhanAlarms.arm(ctx)
            else -> {
                val json = intent.getStringExtra(AdhanAlarms.EXTRA) ?: return
                val at = JSONObject(json).getLong("at")
                val now = System.currentTimeMillis()
                // Only at its own time: never early, not more than 10 minutes late (phone was off),
                // and only if it is still planned (not re-planned or turned off meanwhile).
                if (now < at - 60_000 || now - at > 10 * 60_000 || !AdhanAlarms.isPlanned(ctx, at)) return
                val s = Intent(ctx, AdhanService::class.java).putExtra(AdhanAlarms.EXTRA, json)
                try {
                    if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(s) else ctx.startService(s)
                } catch (e: Exception) {
                    // Android may refuse to start the adhan from the background (e.g. the alarm was not exact):
                    // at least show the prayer notification with a sound, so the prayer is never silent.
                    AdhanAlarms.fallback(ctx, JSONObject(json))
                }
            }
        }
    }
}

class AdhanService : Service(), SensorEventListener {
    companion object {
        const val CHANNEL = "adhan_full_v1"
        const val STOP = "com.mawaqeety.ADHAN_STOP"
        private const val NOTE_ID = 7299
    }

    private var player: MediaPlayer? = null
    private var sensors: SensorManager? = null
    private var startedAt = 0L
    private var faceDownSince = 0L
    private var wake: PowerManager.WakeLock? = null

    private val screen = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            // Power button: the screen turns off, or on (if it was off when the adhan started).
            if (i.action == Intent.ACTION_SCREEN_OFF || SystemClock.elapsedRealtime() - startedAt > 2500) stopAdhan()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) { stopAdhan(); return START_NOT_STICKY }
        val o = JSONObject(intent?.getStringExtra(AdhanAlarms.EXTRA) ?: return START_NOT_STICKY.also { stopSelf() })
        ensureChannel()
        val note = notification(o.optString("title", "حان وقت الصلاة"), o.optString("body", ""))
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        else startForeground(NOTE_ID, note)

        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Silent or vibrate mode: the notification alone, unless the user wants the adhan anyway
        // (it plays on the alarm stream, which silent mode does not mute).
        val muted = audio.ringerMode != AudioManager.RINGER_MODE_NORMAL && !o.optBoolean("silent", true)
        // Something is already playing (a recitation, story, the radio or another app): don't cut it off.
        if (muted || audio.isMusicActive) {
            getSystemService(NotificationManager::class.java)
                .notify(NOTE_ID + 1, notification(o.optString("title", "حان وقت الصلاة"), o.optString("body", ""), playing = false))
            stopForegroundCompat(true)
            stopSelf()
            return START_NOT_STICKY
        }

        startedAt = SystemClock.elapsedRealtime()
        wake = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "mawaqeety:adhan").apply { acquire(6 * 60_000L) }
        play(o.optString("path", ""), if (o.optBoolean("short", false)) 10_000L else 50_000L)
        if (o.optBoolean("power", true)) {
            val f = IntentFilter(Intent.ACTION_SCREEN_OFF).apply { addAction(Intent.ACTION_SCREEN_ON) }
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(screen, f, RECEIVER_NOT_EXPORTED) else registerReceiver(screen, f)
        }
        if (o.optBoolean("flip", true)) {
            sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            sensors?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sensors?.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        }
        return START_NOT_STICKY
    }

    private fun play(path: String, minSize: Long = 50_000L) {
        try {
            val p = MediaPlayer()
            p.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            val f = File(path)
            if (path.isNotEmpty() && f.exists() && f.length() > minSize) p.setDataSource(path)
            else p.setDataSource(this, Uri.parse("android.resource://$packageName/raw/chime"))
            p.setOnCompletionListener { stopAdhan() }
            p.setOnErrorListener { _, _, _ -> stopAdhan(); true }
            p.prepare()
            p.start()
            player = p
        } catch (e: Exception) {
            stopAdhan()
        }
    }

    override fun onSensorChanged(e: SensorEvent) {
        // Face down: gravity points out of the screen (z ≈ −9.8) for half a second.
        if (e.values[2] < -8.0f) {
            if (faceDownSince == 0L) faceDownSince = SystemClock.elapsedRealtime()
            else if (SystemClock.elapsedRealtime() - faceDownSince > 500) stopAdhan()
        } else faceDownSince = 0L
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun stopAdhan() {
        try { player?.stop() } catch (_: Exception) {}
        player?.release()
        player = null
        sensors?.unregisterListener(this)
        sensors = null
        try { unregisterReceiver(screen) } catch (_: Exception) {}
        wake?.let { if (it.isHeld) it.release() }
        stopForegroundCompat(true)
        stopSelf()
    }

    override fun onDestroy() {
        if (player != null) stopAdhan()
        super.onDestroy()
    }

    private fun stopForegroundCompat(remove: Boolean) {
        if (Build.VERSION.SDK_INT >= 24) stopForeground(if (remove) STOP_FOREGROUND_REMOVE else STOP_FOREGROUND_DETACH)
        else @Suppress("DEPRECATION") stopForeground(remove)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "الأذان", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "الأذان كاملًا في وقت الصلاة"
            setSound(null, null) // the adhan itself is the sound
        })
    }

    private fun notification(title: String, body: String, playing: Boolean = true): Notification {
        val open = PendingIntent.getActivity(this, 0, packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, AdhanService::class.java).setAction(STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(open)
            .setAutoCancel(!playing)
        if (playing) b.setStyle(Notification.BigTextStyle().bigText("$body\nاقلب الهاتف على وجهه أو اضغط زر التشغيل لإسكات الأذان."))
            .setDeleteIntent(stop)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "إيقاف الأذان", stop).build())
        return b.build()
    }
}
