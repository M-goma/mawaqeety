package com.mawaqeety.mawaqeety

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.app.Notification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Prayer reminders ("10 minutes to Fajr", "it is time for Dhuhr") posted by our own alarms, so each one is
 * checked when it fires: it is dropped if it comes late (phone asleep, off, or the app just updated) or if it
 * is no longer planned. Items: at (ms), title, body, late (ms it may still be shown after [at]), ttl (ms on screen).
 */
object NoteAlarms {
    private const val PREFS = "mawaqeety_notes"
    private const val KEY = "items"
    const val EXTRA = "note"
    const val CHANNEL = "prayer_reminders_v2"

    fun schedule(ctx: Context, items: List<Map<*, *>>) {
        cancelAll(ctx)
        val arr = JSONArray()
        for (m in items) arr.put(JSONObject(m.mapKeys { it.key.toString() }))
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
        arm(ctx)
    }

    private fun key(at: Long): Int = (at / 60_000L).toInt()

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
        for (i in 0 until arr.length()) am.cancel(pending(ctx, key(arr.getJSONObject(i).getLong("at")), null))
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }

    fun isPlanned(ctx: Context, at: Long): Boolean {
        val arr = JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
        return (0 until arr.length()).any { arr.getJSONObject(it).getLong("at") == at }
    }

    private fun pending(ctx: Context, key: Int, json: String?): PendingIntent {
        val i = Intent(ctx, NoteReceiver::class.java).setAction("com.mawaqeety.NOTE.T$key")
        if (json != null) i.putExtra(EXTRA, json)
        return PendingIntent.getBroadcast(ctx, key, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun post(ctx: Context, o: JSONObject) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "تنبيهات الصلاة", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "التذكير قبل الصلاة وعند دخول وقتها"
            })
        }
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        val tap = PendingIntent.getActivity(ctx, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val n = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else Notification.Builder(ctx).setPriority(Notification.PRIORITY_HIGH))
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(o.optString("title"))
            .setContentText(o.optString("body"))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setShowWhen(true)
            .setWhen(o.getLong("at"))
        val ttl = o.optLong("ttl", 0)
        if (ttl > 0 && Build.VERSION.SDK_INT >= 26) n.setTimeoutAfter(ttl)
        nm.notify(key(o.getLong("at")) and 0x0FFFFFFF, n.build())
    }
}

class NoteReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, "android.intent.action.QUICKBOOT_POWERON" -> NoteAlarms.arm(ctx)
            else -> {
                val json = intent.getStringExtra(NoteAlarms.EXTRA) ?: return
                val o = JSONObject(json)
                val at = o.getLong("at")
                val now = System.currentTimeMillis()
                // Never early, never stale, and only if still planned.
                if (now < at - 60_000 || now - at > o.optLong("late", 5 * 60_000) || !NoteAlarms.isPlanned(ctx, at)) return
                NoteAlarms.post(ctx, o)
            }
        }
    }
}
