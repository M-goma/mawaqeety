import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/methods.dart';
import 'package:mawaqeety/core/prayer_calculator.dart';

void main() {
  final refs = (jsonDecode(File('test/reference_times.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

  group('matches independent astronomy reference (astral / NOAA)', () {
    for (final r in refs) {
      test('${r['City']} ${r['Date']}', () {
        final d = DateTime.parse(r['Date'] as String);
        final method = CalculationMethod.get(MethodId.custom)
            .withAngles((r['FajrAngle'] as num).toDouble(), ((r['IshaAngle'] ?? 17) as num).toDouble());
        if (r['Fajr'] == null || (r['Isha'] == null && r['IshaAngle'] != null)) {
          final t = PrayerCalculator.calculate(d.year, d.month, d.day, (r['Lat'] as num).toDouble(), (r['Lng'] as num).toDouble(),
              CalculationOptions(method));
          expect(t[Prayer.fajr].isBefore(t[Prayer.sunrise]), isTrue);
          return;
        }
        final t = PrayerCalculator.calculate(d.year, d.month, d.day, (r['Lat'] as num).toDouble(), (r['Lng'] as num).toDouble(),
            CalculationOptions(method, highLatitude: HighLatitudeRule.none));
        void close(String key, Prayer p) {
          final expected = DateTime.parse(r[key] as String).toUtc();
          final diff = expected.difference(t[p]).inSeconds.abs();
          expect(diff <= 90, isTrue, reason: '$key expected $expected got ${t[p]} (diff ${diff}s)');
        }
        close('Sunrise', Prayer.sunrise);
        close('Sunset', Prayer.maghrib);
        close('Noon', Prayer.dhuhr);
        close('Fajr', Prayer.fajr);
        if (r['Isha'] != null) close('Isha', Prayer.isha);
      });
    }
  });

  test('identical to the desktop C# engine (same inputs, minute precision)', () {
    const coords = {
      'Cairo': (30.0444, 31.2357), 'Makkah': (21.4225, 39.8262), 'London': (51.5072, -0.1276),
      'Jakarta': (-6.2088, 106.8456), 'Oslo': (59.9139, 10.7522),
    };
    for (final line in File('test/desktop_engine_times.txt').readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
      final parts = line.split(' ');
      final (lat, lng) = coords[parts[0]]!;
      final d = DateTime.parse(parts[1]);
      final method = MethodId.values.firstWhere((m) => m.name.toLowerCase() == parts[2].toLowerCase());
      final t = PrayerCalculator.calculate(d.year, d.month, d.day, lat, lng, CalculationOptions(CalculationMethod.get(method)));
      final got = Prayer.values
          .map((p) => '${t[p].hour.toString().padLeft(2, '0')}:${t[p].minute.toString().padLeft(2, '0')}')
          .join(' ');
      expect(got, parts.sublist(3).join(' '), reason: line);
    }
  });

  test('Umm al-Qura isha = maghrib + 90 / 120 in Ramadan', () {
    final m = CalculationOptions(CalculationMethod.get(MethodId.ummAlQura));
    final n = PrayerCalculator.calculate(2026, 11, 16, 21.4225, 39.8262, m);
    final r = PrayerCalculator.calculate(2026, 11, 16, 21.4225, 39.8262, m, isRamadan: true);
    expect(n[Prayer.isha].difference(n[Prayer.maghrib]).inMinutes, 90);
    expect(r[Prayer.isha].difference(r[Prayer.maghrib]).inMinutes, 120);
  });

  test('high latitude summer gives ordered times', () {
    for (final rule in [HighLatitudeRule.angleBased, HighLatitudeRule.oneSeventh, HighLatitudeRule.middleOfNight]) {
      final t = PrayerCalculator.calculate(2026, 6, 21, 59.9139, 10.7522,
          CalculationOptions(CalculationMethod.get(MethodId.muslimWorldLeague), highLatitude: rule));
      final list = Prayer.values.map((p) => t[p]).toList();
      for (var i = 1; i < list.length; i++) {
        expect(list[i].isAfter(list[i - 1]), isTrue, reason: '$rule');
      }
    }
  });
}
