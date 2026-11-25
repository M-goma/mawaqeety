import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/prayer_calculator.dart';
import 'app_state.dart';

/// Feeds the Android home-screen widgets with the prayer timeline of the coming days.
/// The widgets pick the next prayer and count down by themselves (see PrayerWidgets.kt).
class WidgetService {
  static const _key = 'mawaqeety_data';

  Future<void> update(AppState app) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final s = app.settings;
      String fmt(DateTime t) {
        if (s.use24h) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
        return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
      }

      final days = <Map<String, dynamic>>[];
      for (var d = -1; d < 10; d++) {
        final date = app.today.add(Duration(days: d));
        final times = app.day(date);
        days.add({
          'd': DateFormat('yyyy-MM-dd').format(date),
          'g': DateFormat('EEEE d MMMM', 'ar').format(date),
          'h': app.hijri(date),
          'p': [
            for (final p in Prayer.values)
              {
                'n': p == Prayer.dhuhr && date.weekday == DateTime.friday ? 'الجمعة' : p.nameAr,
                't': times[p].millisecondsSinceEpoch,
                'l': fmt(app.local(times[p])),
              }
          ],
        });
      }
      await HomeWidget.saveWidgetData<String>(_key, jsonEncode({'place': s.place.nameAr, 'days': days}));
      await HomeWidget.updateWidget(androidName: 'PrayerWidgetSmall');
      await HomeWidget.updateWidget(androidName: 'PrayerWidgetLarge');
    } catch (e) {
      debugPrint('widget update failed: $e');
    }
  }
}
