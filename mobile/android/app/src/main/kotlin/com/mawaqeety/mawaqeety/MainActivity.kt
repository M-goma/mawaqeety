package com.mawaqeety.mawaqeety

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mawaqeety/compass")
            .setStreamHandler(CompassStream(applicationContext))
    }
}

/** Streams [azimuthDegrees, accuracy] from the rotation-vector sensor (falls back to accelerometer + magnetometer). */
private class CompassStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private val rot = FloatArray(9)
    private val orient = FloatArray(3)
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
        var deg = Math.toDegrees(orient[0].toDouble()) + declination
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
