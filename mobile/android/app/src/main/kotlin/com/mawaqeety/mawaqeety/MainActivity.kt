package com.mawaqeety.mawaqeety

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mawaqeety/compass")
            .setStreamHandler(CompassStream(applicationContext))
        // Full adhan at prayer times (see Adhan.kt).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mawaqeety/adhan").setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> { AdhanAlarms.schedule(applicationContext, (call.arguments as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()); result.success(null) }
                "cancel" -> { AdhanAlarms.cancelAll(applicationContext); result.success(null) }
                "notes" -> { NoteAlarms.schedule(applicationContext, (call.arguments as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()); result.success(null) }
                "canExact" -> result.success(AdhanAlarms.canExact(applicationContext))
                "requestExact" -> {
                    if (Build.VERSION.SDK_INT >= 31) {
                        try {
                            startActivity(Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                android.net.Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:$packageName")))
                        }
                    }
                    result.success(null)
                }
                "stop" -> { startService(Intent(applicationContext, AdhanService::class.java).setAction(AdhanService.STOP)); result.success(null) }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mawaqeety/flip")
            .setStreamHandler(FlipStream(applicationContext))
    }
}

/** Streams [azimuthDegrees, accuracy] from the rotation-vector sensor (falls back to accelerometer + magnetometer). */
private class CompassStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val ctx = context
    private val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private val rot = FloatArray(9)
    private val orient = FloatArray(3)
    private val upright = FloatArray(9)
    private var grav: FloatArray? = null
    private var mag: FloatArray? = null
    private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM
    private var last = 0L
    private var declination = 0f // magnetic -> true north

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        (arguments as? Map<*, *>)?.let { a ->
            val lat = (a["lat"] as? Number)?.toFloat()
            val lng = (a["lng"] as? Number)?.toFloat()
            if (lat != null && lng != null)
                declination = GeomagneticField(lat, lng, 0f, System.currentTimeMillis()).declination
        }
        val rv = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (rv != null) {
            sm.registerListener(this, rv, SensorManager.SENSOR_DELAY_UI)
        } else {
            val a = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            val m = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
            if (a == null || m == null) { events.error("no_sensor", "No compass sensor", null); return }
            sm.registerListener(this, a, SensorManager.SENSOR_DELAY_UI)
            sm.registerListener(this, m, SensorManager.SENSOR_DELAY_UI)
        }
        // Magnetometer accuracy is reported separately even when using the rotation vector.
        sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)?.let { if (rv != null) sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    override fun onCancel(arguments: Any?) {
        sm.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor, acc: Int) {
        if (sensor.type == Sensor.TYPE_MAGNETIC_FIELD) accuracy = acc
    }

    override fun onSensorChanged(e: SensorEvent) {
        when (e.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> SensorManager.getRotationMatrixFromVector(rot, e.values)
            Sensor.TYPE_ACCELEROMETER -> { grav = e.values.clone(); if (!fromPair()) return }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                if (sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) != null) return
                mag = e.values.clone(); if (!fromPair()) return
            }
            else -> return
        }
        val now = System.currentTimeMillis()
        if (now - last < 40) return
        last = now
        SensorManager.getOrientation(rot, orient)
        // Held upright (screen facing you): the flat azimuth becomes unstable near ±90° pitch, so use the
        // direction the back of the phone points instead.
        if (Math.abs(Math.toDegrees(orient[1].toDouble())) > 55) {
            SensorManager.remapCoordinateSystem(rot, SensorManager.AXIS_X, SensorManager.AXIS_Z, upright)
            SensorManager.getOrientation(upright, orient)
        }
        // The top of the screen, whichever way the screen is rotated.
        @Suppress("DEPRECATION")
        val turn = when ((ctx.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).defaultDisplay.rotation) {
            android.view.Surface.ROTATION_90 -> 90.0
            android.view.Surface.ROTATION_180 -> 180.0
            android.view.Surface.ROTATION_270 -> 270.0
            else -> 0.0
        }
        var deg = (Math.toDegrees(orient[0].toDouble()) + declination + turn) % 360.0
        if (deg >= 360) deg -= 360.0
        if (deg < 0) deg += 360.0
        sink?.success(listOf(deg, accuracy))
    }

    private fun fromPair(): Boolean {
        val g = grav ?: return false
        val m = mag ?: return false
        return SensorManager.getRotationMatrix(rot, null, g, m)
    }
}

/** Emits once each time the phone is turned face down (held for half a second). */
private class FlipStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private var since = 0L
    private var fired = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    override fun onCancel(arguments: Any?) {
        sm.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}

    override fun onSensorChanged(e: SensorEvent) {
        if (e.values[2] < -8.0f) {
            if (since == 0L) since = SystemClock.elapsedRealtime()
            else if (!fired && SystemClock.elapsedRealtime() - since > 500) { fired = true; sink?.success(1) }
        } else { since = 0L; fired = false }
    }
}
