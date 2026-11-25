import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/qibla.dart';
import 'package:mawaqeety/data/adhkar.dart';

void main() {
  test('qibla bearing and distance from known cities', () {
    expect(Qibla.bearing(30.0444, 31.2357), closeTo(136.1, 0.5)); // Cairo
    expect(Qibla.bearing(51.5074, -0.1278), closeTo(118.99, 0.5)); // London
    expect(Qibla.bearing(40.7128, -74.0060), closeTo(58.5, 0.5)); // New York
    expect(Qibla.bearing(-6.2088, 106.8456), closeTo(295.15, 0.5)); // Jakarta
    expect(Qibla.distanceKm(30.0444, 31.2357), closeTo(1280, 15));
  });

  test('every dhikr is available in at least one session', () {
    for (final d in adhkar) {
      expect(d.availableAt(true) || d.availableAt(false), isTrue);
      expect(d.count, greaterThan(0));
    }
    expect(adhkar.where((d) => d.availableAt(true)).length, greaterThan(15));
    expect(adhkar.where((d) => d.availableAt(false)).length, greaterThan(15));
  });
}
