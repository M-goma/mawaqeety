import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/geomag.dart';
import 'package:mawaqeety/core/qibla.dart';

void main() {
  test('qibla bearings match published values', () {
    // Published great-circle qibla directions (true north): Cairo ≈ 136°, London ≈ 119°, Jakarta ≈ 295°, Riyadh ≈ 244°.
    expect(Qibla.bearing(30.0444, 31.2357), closeTo(136.1, 0.5));
    expect(Qibla.bearing(51.5074, -0.1278), closeTo(119.0, 0.5));
    expect(Qibla.bearing(-6.2088, 106.8456), closeTo(295.1, 0.5));
    expect(Qibla.bearing(24.7136, 46.6753), closeTo(244.0, 1.0));
    expect(Qibla.distanceKm(30.0444, 31.2357), closeTo(1287, 15));
  });

  test('magnetic declination comes from WMM-2025 (used to turn browser compasses to true north)', () {
    final cairo = GeoMag().calculate(30.0444, 31.2357, 0, DateTime(2026, 12, 1)).dec;
    expect(cairo, inInclusiveRange(4.0, 6.0)); // east, about 5°
    final london = GeoMag().calculate(51.5074, -0.1278, 0, DateTime(2026, 12, 1)).dec;
    expect(london, inInclusiveRange(0.0, 2.5));
  });
}
