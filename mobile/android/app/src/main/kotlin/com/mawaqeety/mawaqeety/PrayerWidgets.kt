package com.mawaqeety.mawaqeety

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen widgets (4x1 and 4x2) showing the next prayer with a live countdown.
 * The app stores the prayer timeline for the coming days (key "mawaqeety_data"); the widget picks the
 * next prayer itself, so it keeps working for days without opening the app, and wakes up at each prayer
 * time to move on to the next one.
 */
abstract class PrayerWidgetBase(private val layout: Int, private val large: Boolean) : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, ACTION_TICK -> {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
                if (ids.isNotEmpty()) render(context, manager, ids)
            }
        }
    }

    private data class Item(val name: String, val time: Long, val label: String)
    private data class Day(val date: String, val greg: String, val hijri: String, val items: List<Item>)

    private fun load(context: Context): Pair<String, List<Day>> {
        val raw = HomeWidgetPlugin.getData(context).getString("mawaqeety_data", null) ?: return "" to emptyList()
        return try {
            val root = JSONObject(raw)
            val days = root.getJSONArray("days")
            val list = (0 until days.length()).map { i ->
                val d = days.getJSONObject(i)
                val p = d.getJSONArray("p")
                Day(d.getString("d"), d.optString("g"), d.optString("h"),
                    (0 until p.length()).map { j ->
                        val o = p.getJSONObject(j)
                        Item(o.getString("n"), o.getLong("t"), o.getString("l"))
                    })
            }
            root.optString("place") to list
        } catch (e: Exception) {
            "" to emptyList()
        }
    }

    private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val (place, days) = load(context)
        val now = System.currentTimeMillis()
        val all = days.flatMap { it.items }.sortedBy { it.time }
        val nextIndex = all.indexOfFirst { it.time > now }
        val next = if (nextIndex >= 0) all[nextIndex] else null

        for (id in ids) {
            val views = RemoteViews(context.packageName, layout)
            views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            if (next == null) {
                views.setTextViewText(R.id.next_name, "مواقيتي")
                views.setTextViewText(R.id.next_time, "افتح التطبيق لتحديث المواقيت")
                views.setViewVisibility(R.id.countdown, View.GONE)
            } else {
                views.setTextViewText(R.id.next_name, next.name)
                views.setTextViewText(R.id.next_time, next.label + if (place.isNotEmpty()) "  •  $place" else "")
                views.setViewVisibility(R.id.countdown, View.VISIBLE)
                views.setChronometer(R.id.countdown, SystemClock.elapsedRealtime() + (next.time - now), null, true)
                views.setChronometerCountDown(R.id.countdown, true)
            }
            if (large) renderDay(views, days, next, now)
            manager.updateAppWidget(id, views)
        }
        if (next != null) scheduleTick(context, next.time + 1500)
    }

    private fun renderDay(views: RemoteViews, days: List<Day>, next: Item?, now: Long) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))
        val day = days.firstOrNull { it.date == today } ?: days.firstOrNull { d -> d.items.any { it == next } }
        val cols = listOf(R.id.c0, R.id.c1, R.id.c2, R.id.c3, R.id.c4, R.id.c5)
        val names = listOf(R.id.n0, R.id.n1, R.id.n2, R.id.n3, R.id.n4, R.id.n5)
        val times = listOf(R.id.t0, R.id.t1, R.id.t2, R.id.t3, R.id.t4, R.id.t5)
        for (i in 0 until 6) {
            val item = day?.items?.getOrNull(i)
            views.setTextViewText(names[i], item?.name ?: "")
            views.setTextViewText(times[i], item?.label?.substringBefore(' ') ?: "")
            views.setInt(cols[i], "setBackgroundResource",
                if (item != null && item == next) R.drawable.widget_cell_next else android.R.color.transparent)
        }
        views.setTextViewText(R.id.date_line, if (day == null) "" else "${day.hijri}  •  ${day.greg}")
    }

    /** Wakes the widget right after the next prayer time so it moves on to the following prayer. */
    private fun scheduleTick(context: Context, atMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, javaClass).setAction(ACTION_TICK)
        val pi = PendingIntent.getBroadcast(context, javaClass.name.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC, atMillis, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC, atMillis, pi)
            }
        } catch (e: SecurityException) {
            am.set(AlarmManager.RTC, atMillis, pi)
        }
    }

    companion object {
        const val ACTION_TICK = "com.mawaqeety.widget.TICK"
    }
}

class PrayerWidgetSmall : PrayerWidgetBase(R.layout.widget_small, large = false)
class PrayerWidgetLarge : PrayerWidgetBase(R.layout.widget_large, large = true)
