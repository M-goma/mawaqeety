import 'dart:math' as math;

/// Great-circle direction and distance to the Kaaba.
class Qibla {
  static const kaabaLat = 21.422487, kaabaLng = 39.826206;

  /// Bearing from true north, clockwise, in degrees [0, 360).
  static double bearing(double lat, double lng) {
    final p1 = _rad(lat), p2 = _rad(kaabaLat), dl = _rad(kaabaLng - lng);
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  /// Distance in kilometres.
  static double distanceKm(double lat, double lng) {
    final p1 = _rad(lat), p2 = _rad(kaabaLat), dp = p2 - p1, dl = _rad(kaabaLng - lng);
    final a = math.pow(math.sin(dp / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
}
