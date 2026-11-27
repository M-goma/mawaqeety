package com.mawaqeety.mawaqeety

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
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

    /** [hero]: the app's hero gradient (light → dark), [accent]: its highlight colour. */
    private data class Data(val place: String, val style: String, val use24h: Boolean, val days: List<Day>,
                            val hero: List<Int> = emptyList(), val accent: Int? = null)

    private fun load(context: Context): Data {
        val raw = HomeWidgetPlugin.getData(context).getString("mawaqeety_data", null)
            ?: return Data("", "clock", false, emptyList())
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
            val colors = root.optJSONObject("colors")
            val hero = colors?.optJSONArray("hero")?.let { a -> (0 until a.length()).mapNotNull { runCatching { Color.parseColor(a.getString(it)) }.getOrNull() } } ?: emptyList()
            val accent = colors?.optString("accent")?.takeIf { it.isNotEmpty() }?.let { runCatching { Color.parseColor(it) }.getOrNull() }
            Data(root.optString("place"), root.optString("style", "clock"), root.optBoolean("use24h", false), list, hero, accent)
        } catch (e: Exception) {
            Data("", "clock", false, emptyList())
        }
    }

    private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val data = load(context)
        val days = data.days
        val place = data.place
        // The 4x1 widget has no prayer cells, so the "cell" style falls back to the clock style there.
        val style = if (!large && data.style == "cell") "clock" else data.style
        val now = System.currentTimeMillis()
        val all = days.flatMap { it.items }.sortedBy { it.time }
        val nextIndex = all.indexOfFirst { it.time > now }
        val next = if (nextIndex >= 0) all[nextIndex] else null
        val base = SystemClock.elapsedRealtime() + ((next?.time ?: now) - now)

        for (id in ids) {
            val views = RemoteViews(context.packageName, layout)
            paint(context, manager, id, views, data)
            views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            val clockFormat = if (data.use24h) "HH:mm" else "h:mm"
            views.setCharSequence(R.id.clock, "setFormat12Hour", clockFormat)
            views.setCharSequence(R.id.clock, "setFormat24Hour", clockFormat)

            val bigCountdown = style == "countdown"
            views.setViewVisibility(R.id.clock_box, if (bigCountdown) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.countdown, if (bigCountdown && next != null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.badge, if (style == "clock" && next != null) View.VISIBLE else View.GONE)
            if (large) views.setViewVisibility(R.id.hijri_line, View.GONE)
            views.setViewVisibility(R.id.next_time, View.VISIBLE)

            if (next == null) {
                views.setTextViewText(R.id.next_name, "سبيل")
                views.setTextViewText(R.id.next_time, "افتح التطبيق لتحديث المواقيت")
            } else {
                if (bigCountdown) {
                    views.setChronometer(R.id.countdown, base, null, true)
                    views.setChronometerCountDown(R.id.countdown, true)
                } else {
                    views.setChronometer(R.id.countdown_small, base, null, true)
                    views.setChronometerCountDown(R.id.countdown_small, true)
                }
                if (!large && style == "clock") {
                    // One line: "الفجر  4:58 ص", the countdown badge below it.
                    views.setTextViewText(R.id.next_name, "${next.name}  ${next.label}")
                    views.setViewVisibility(R.id.next_time, View.GONE)
                } else {
                    views.setTextViewText(R.id.next_name, next.name)
                    views.setTextViewText(R.id.next_time, next.label + if (place.isNotEmpty()) "  •  $place" else "")
                }
            }
            if (large) renderDay(views, days, next, now, style, base, place)
            manager.updateAppWidget(id, views)
        }
        if (next != null) scheduleTick(context, next.time + 1500)
    }

    private fun renderDay(views: RemoteViews, days: List<Day>, next: Item?, now: Long, style: String, base: Long, place: String) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))
        val day = days.firstOrNull { it.date == today } ?: days.firstOrNull { d -> d.items.any { it == next } }
        val cols = listOf(R.id.c0, R.id.c1, R.id.c2, R.id.c3, R.id.c4, R.id.c5)
        val names = listOf(R.id.n0, R.id.n1, R.id.n2, R.id.n3, R.id.n4, R.id.n5)
        val times = listOf(R.id.t0, R.id.t1, R.id.t2, R.id.t3, R.id.t4, R.id.t5)
        val cds = listOf(R.id.cd0, R.id.cd1, R.id.cd2, R.id.cd3, R.id.cd4, R.id.cd5)
        for (i in 0 until 6) {
            val item = day?.items?.getOrNull(i)
            val isNext = item != null && item == next
            views.setTextViewText(names[i], item?.name ?: "")
            views.setTextViewText(times[i], item?.label?.substringBefore(' ') ?: "")
            views.setInt(cols[i], "setBackgroundResource",
                if (isNext) R.drawable.widget_cell_next else android.R.color.transparent)
            if (style == "cell" && isNext) {
                views.setViewVisibility(cds[i], View.VISIBLE)
                views.setChronometer(cds[i], base, null, true)
                views.setChronometerCountDown(cds[i], true)
            } else {
                views.setViewVisibility(cds[i], View.GONE)
            }
        }
        if (style == "cell" && day != null) {
            // Header shows the date; the countdown lives in the next prayer's cell.
            val parts = day.greg.split(' ', limit = 2)
            views.setTextViewText(R.id.next_name, parts.getOrNull(0) ?: day.greg)
            views.setTextViewText(R.id.next_time, (parts.getOrNull(1) ?: "") + if (place.isNotEmpty()) "  •  $place" else "")
            views.setTextViewText(R.id.hijri_line, day.hijri)
            views.setViewVisibility(R.id.hijri_line, View.VISIBLE)
            views.setViewVisibility(R.id.date_line, View.GONE)
        } else {
            views.setViewVisibility(R.id.date_line, View.VISIBLE)
            views.setTextViewText(R.id.date_line, if (day == null) "" else "${day.hijri}  •  ${day.greg}")
        }
    }

    /** Colours the widget like the app: its hero gradient as background and its accent for highlights. */
    private fun paint(context: Context, manager: AppWidgetManager, id: Int, views: RemoteViews, data: Data) {
        if (data.hero.size >= 2) {
            val dm = context.resources.displayMetrics
            val opts = manager.getAppWidgetOptions(id)
            val wDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).takeIf { it > 0 } ?: if (large) 320 else 300
            val hDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).takeIf { it > 0 } ?: if (large) 150 else 70
            // Keep the bitmap small: RemoteViews have a size limit.
            val scale = minOf(dm.density, 2f)
            val w = (wDp * scale).toInt().coerceIn(60, 900)
            val h = (hDp * scale).toInt().coerceIn(40, 600)
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            val colors = data.hero.reversed().toIntArray() // dark (top-left) → light (bottom-right), like the drawable
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), colors, null, Shader.TileMode.CLAMP)
            }
            val r = 22f * scale
            c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), r, r, p)
            views.setImageViewBitmap(R.id.widget_bg, bmp)
        }
        data.accent?.let { a ->
            val ids = mutableListOf(R.id.next_time, R.id.countdown_small)
            if (large) ids += listOf(R.id.cd0, R.id.cd1, R.id.cd2, R.id.cd3, R.id.cd4, R.id.cd5)
            for (v in ids) views.setTextColor(v, a)
        }
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
