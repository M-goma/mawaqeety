import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prayer_calculator.dart';

/// How a prayer was prayed.
enum PrayerLog { none, mosque, jamaah, alone, qada }

extension PrayerLogX on PrayerLog {
  String get label => const ['لم تُسجَّل', 'جماعة في المسجد', 'جماعة', 'منفردًا', 'قضاء'][index];
  String get longLabel => const ['', 'جماعة في المسجد', 'جماعة (في البيت أو العمل)', 'منفردًا في وقتها', 'قضاء (بعد خروج الوقت)'][index];
  String get emoji => const ['', '🕌', '👥', '🧍', '⏳'][index];
}

/// The confirmed sunnahs (رواتب، الضحى، الوتر).
enum Sunnah { fajr, dhuhr, maghrib, isha, duha, witr }

extension SunnahX on Sunnah {
  String get label => const ['سنة الفجر', 'سنة الظهر', 'سنة المغرب', 'سنة العشاء', 'الضحى', 'الوتر'][index];
  String get detail => const ['ركعتان قبل الفجر', '٤ قبل الظهر و٢ بعده', 'ركعتان بعد المغرب', 'ركعتان بعد العشاء', 'ركعتان أو أكثر', 'ركعة أو أكثر'][index];
}

const trackedPrayers = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

/// One day of worship: the five prayers, morning/evening adhkar and the tasbeeh count.
class DayLog {
  final Map<Prayer, PrayerLog> prayers = {};
  bool morning = false, evening = false;
  int tasbeeh = 0;
  /// Voluntary worship: a fast (Ramadan or the white days), the taraweeh (rak'ahs, 0 = none) and tahajjud.
  bool fast = false, tahajjud = false;
  int taraweeh = 0;
  /// Sunnah prayers done (bit per [Sunnah]) and Mushaf pages read.
  int sunan = 0, pages = 0;
  bool did(Sunnah s) => sunan & (1 << s.index) != 0;
  int get sunanDone => Sunnah.values.where(did).length;

  PrayerLog of(Prayer p) => prayers[p] ?? PrayerLog.none;
  int get prayersDone => trackedPrayers.where((p) => of(p) != PrayerLog.none).length;
  bool get allFiveOnTime => trackedPrayers.every((p) => of(p) != PrayerLog.none && of(p) != PrayerLog.qada);
  bool get isEmpty => prayers.isEmpty && !morning && !evening && tasbeeh == 0 && !fast && !tahajjud && taraweeh == 0 && sunan == 0 && pages == 0;

  Map<String, dynamic> toJson() => {
        if (prayers.isNotEmpty) 'p': {for (final e in prayers.entries) e.key.name: e.value.index},
        if (morning) 'm': 1,
        if (evening) 'e': 1,
        if (tasbeeh > 0) 't': tasbeeh,
        if (fast) 'f': 1,
        if (taraweeh > 0) 'tr': taraweeh,
        if (tahajjud) 'q': 1,
        if (sunan != 0) 'sn': sunan,
        if (pages > 0) 'qp': pages,
      };

  static DayLog fromJson(Map<String, dynamic> j) {
    final d = DayLog();
    for (final e in ((j['p'] ?? {}) as Map<String, dynamic>).entries) {
      final p = Prayer.values.where((x) => x.name == e.key).firstOrNull;
      final v = e.value as int;
      if (p != null && v > 0 && v < PrayerLog.values.length) d.prayers[p] = PrayerLog.values[v];
    }
    d.morning = j['m'] == 1;
    d.evening = j['e'] == 1;
    d.tasbeeh = (j['t'] ?? 0) as int;
    d.fast = j['f'] == 1;
    d.taraweeh = (j['tr'] ?? 0) as int;
    d.tahajjud = j['q'] == 1;
    d.sunan = (j['sn'] ?? 0) as int;
    d.pages = (j['qp'] ?? 0) as int;
    return d;
  }
}

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Prayers, adhkar and tasbeeh per day, kept on the device only (SharedPreferences, key `tracker.v1`).
class Tracker extends ChangeNotifier {
  static const _key = 'tracker.v1';
  SharedPreferences? _prefs;
  final _days = <String, DayLog>{};

  /// Daily tasbeeh goal (from the settings), used for the "wird" item of the day.
  int Function() wirdGoal = () => 100;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.reload(); // a notification button may have saved something in the background
    _days.clear();
    try {
      final j = jsonDecode(_prefs!.getString(_key) ?? '{}') as Map<String, dynamic>;
      for (final e in j.entries) {
        _days[e.key] = DayLog.fromJson(e.value as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('tracker load failed: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    _days.removeWhere((_, d) => d.isEmpty);
    await _prefs?.setString(_key, jsonEncode({for (final e in _days.entries) e.key: e.value.toJson()}));
    notifyListeners();
  }

  DayLog day(DateTime date) => _days[dayKey(date)] ?? DayLog();
  DayLog _edit(DateTime date) => _days.putIfAbsent(dayKey(date), DayLog.new);

  Future<void> setPrayer(DateTime date, Prayer p, PrayerLog log) async {
    final d = _edit(date);
    if (log == PrayerLog.none) {
      d.prayers.remove(p);
    } else {
      d.prayers[p] = log;
    }
    await _save();
  }

  Future<void> setAdhkar(DateTime date, {required bool morning, bool done = true}) async {
    final d = _edit(date);
    if (morning) {
      d.morning = done;
    } else {
      d.evening = done;
    }
    await _save();
  }

  Future<void> addTasbeeh(DateTime date, [int n = 1]) async {
    _edit(date).tasbeeh += n;
    await _save();
  }

  Future<void> setFast(DateTime date, bool v) async {
    _edit(date).fast = v;
    await _save();
  }

  Future<void> setTaraweeh(DateTime date, int rakahs) async {
    _edit(date).taraweeh = rakahs;
    await _save();
  }

  Future<void> setTahajjud(DateTime date, bool v) async {
    _edit(date).tahajjud = v;
    await _save();
  }

  Future<void> setSunnah(DateTime date, Sunnah s, bool v) async {
    final d = _edit(date);
    d.sunan = v ? d.sunan | (1 << s.index) : d.sunan & ~(1 << s.index);
    await _save();
  }

  Future<void> setPages(DateTime date, int n) async {
    _edit(date).pages = n;
    await _save();
  }

  /// Raw data for the backup file.
  String exportJson() => jsonEncode({for (final e in _days.entries) e.key: e.value.toJson()});

  /// Replaces all days with a backup's data.
  Future<void> importJson(Map<String, dynamic> j) async {
    _days
      ..clear()
      ..addAll({for (final e in j.entries) e.key: DayLog.fromJson(e.value as Map<String, dynamic>)});
    await _save();
  }

  // ---------------- statistics ----------------
  /// 0..1: the five prayers, morning and evening adhkar, and the daily wird.
  double completion(DateTime date) {
    final d = day(date);
    final goal = wirdGoal();
    final items = 7 + (goal > 0 ? 1 : 0);
    var done = d.prayersDone + (d.morning ? 1 : 0) + (d.evening ? 1 : 0);
    if (goal > 0 && d.tasbeeh >= goal) done++;
    return done / items;
  }

  /// Consecutive days (ending today, or yesterday if today is not done yet) that satisfy [test].
  int streak(DateTime today, bool Function(DayLog d) test) {
    var date = today;
    if (!test(day(date))) date = date.subtract(const Duration(days: 1));
    var n = 0;
    while (n < 3650 && test(day(date))) {
      n++;
      date = date.subtract(const Duration(days: 1));
    }
    return n;
  }

  int prayersStreak(DateTime today) => streak(today, (d) => d.allFiveOnTime);
  int fajrMosqueStreak(DateTime today) => streak(today, (d) => d.of(Prayer.fajr) == PrayerLog.mosque);
  int morningStreak(DateTime today) => streak(today, (d) => d.morning);

  /// How the logged prayers of a period were prayed.
  Map<PrayerLog, int> distribution(DateTime from, DateTime to) {
    final m = {for (final l in PrayerLog.values.skip(1)) l: 0};
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      for (final p in trackedPrayers) {
        final l = day(d).of(p);
        if (l != PrayerLog.none) m[l] = m[l]! + 1;
      }
    }
    return m;
  }

  int tasbeehBetween(DateTime from, DateTime to) {
    var n = 0;
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      n += day(d).tasbeeh;
    }
    return n;
  }
}

/// Records a prayer from a notification button when the app is not running (background isolate).
Future<void> logPrayerFromBackground(String payload, String actionId) async {
  // payload: "pt|2026-11-26|asr", action: "pt_1" (mosque) / "pt_2" (jamaah) / "pt_3" (alone)
  final parts = payload.split('|');
  final v = int.tryParse(actionId.replaceFirst('pt_', ''));
  if (parts.length != 3 || v == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final j = jsonDecode(prefs.getString(Tracker._key) ?? '{}') as Map<String, dynamic>;
  final d = (j[parts[1]] ?? <String, dynamic>{}) as Map<String, dynamic>;
  final p = Map<String, dynamic>.from((d['p'] ?? {}) as Map);
  p[parts[2]] = v;
  d['p'] = p;
  j[parts[1]] = d;
  await prefs.setString(Tracker._key, jsonEncode(j));
}
