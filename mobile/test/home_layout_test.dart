import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/settings.dart';
import 'package:mawaqeety/ui/home_layout.dart';

void main() {
  test('home layout: defaults are known ids, planner is not on Home by default, choices are saved', () {
    final ids = {for (final h in homeSections) h.id};
    expect(ids.containsAll(Settings.defaultHomeSections), isTrue);
    expect(Settings.defaultHomeSections.contains('planner'), isFalse);
    for (final id in Settings.defaultHomeShortcuts) {
      expect(shortcutById(id), isNotNull, reason: id);
    }
    expect({for (final s in homeShortcuts) s.id}.length, homeShortcuts.length); // unique
    final s = Settings.fromJsonString(null);
    expect(s.homeSections, Settings.defaultHomeSections);
    s.homeSections = ['ask', 'prayer', 'planner'];
    s.homeShortcuts = ['planner', 'seerah'];
    final r = Settings.fromJsonString(jsonEncode(s.toJson()));
    expect(r.homeSections, ['ask', 'prayer', 'planner']);
    expect(r.homeShortcuts, ['planner', 'seerah']);
  });
}
