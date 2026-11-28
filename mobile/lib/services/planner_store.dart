import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prayer_calculator.dart';
import '../data/planner.dart';
import 'tracker.dart' show dayKey;

/// The daily planner's tasks, settings and day summaries, kept on the device (SharedPreferences, key `planner.v1`).
class PlannerStore extends ChangeNotifier {
  static const key = 'planner.v1';
  SharedPreferences? _prefs;
  final tasks = <PlanTask>[];
  PlannerConfig config = PlannerConfig();

  /// Frozen summaries of past days (today's is computed live).
  final stats = <String, PlanStat>{};
  String _lastDay = '';

  // Wired by AppState: the local day, the prayers of a day in minutes of that day, and the minute now.
  DateTime Function() today = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  };
  Map<Prayer, int> Function(DateTime date) prayers = (_) => const {};
  int Function() nowMinute = () => DateTime.now().hour * 60 + DateTime.now().minute;

  /// Called after every change (the reminders are re-planned).
  VoidCallback? onChanged;

  bool get hasTasks => tasks.isNotEmpty;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _read(_prefs!.getString(key));
    if (!rollover()) _place(today()); // tasks without a slot yet get one (saved with the next change)
    notifyListeners();
  }

  void _read(String? raw) {
    tasks.clear();
    stats.clear();
    try {
      final j = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      _fromJson(j);
    } catch (e) {
      debugPrint('planner load failed: $e');
    }
  }

  void _fromJson(Map<String, dynamic> j) {
    tasks
      ..clear()
      ..addAll([for (final t in (j['tasks'] ?? const []) as List) PlanTask.fromJson((t as Map).cast<String, dynamic>())]);
    config = PlannerConfig.fromJson(((j['config'] ?? const {}) as Map).cast<String, dynamic>());
    stats
      ..clear()
      ..addAll({for (final e in ((j['stats'] ?? const {}) as Map).entries) '${e.key}': PlanStat.fromJson(e.value)});
    _lastDay = '${j['day'] ?? ''}';
  }

  Map<String, dynamic> toJson() => {
        'tasks': [for (final t in tasks) t.toJson()],
        'config': config.toJson(),
        'stats': {for (final e in stats.entries) e.key: e.value.toJson()},
        'day': _lastDay,
      };

  Future<void> _save() async {
    // Done tasks of old days are only needed for their summary.
    final cutoff = dayKey(today().subtract(const Duration(days: 60)));
    tasks.removeWhere((t) => t.date.compareTo(cutoff) < 0);
    stats.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    await _prefs?.setString(key, jsonEncode(toJson()));
    notifyListeners();
    onChanged?.call();
  }

  /// Backup: replaces everything with a backup's planner data.
  Future<void> importJson(Map<String, dynamic> j) async {
    _fromJson(j);
    rollover(force: true);
    await _save();
  }

  /// On a new day: freezes the summaries of the past days, then rolls their undone tasks over to today.
  /// Returns true if something changed.
  bool rollover({bool force = false}) {
    final key = dayKey(today());
    if (!force && key == _lastDay) return false;
    final past = <String>{for (final t in tasks) if (t.date.compareTo(key) < 0) t.date};
    for (final d in past) {
      stats[d] = PlanStat.of(tasks.where((t) => t.date == d));
    }
    if (config.carryOver) {
      Planner.carryOver(tasks, key);
    }
    _lastDay = key;
    _place(today());
    if (_prefs != null) {
      _save();
    }
    return true;
  }

  List<PlanTask> of(DateTime date) {
    final k = dayKey(date);
    return tasks.where((t) => t.date == k).toList();
  }

  bool _isToday(DateTime date) => dayKey(date) == dayKey(today());

  /// The day's timeline (prayers and tasks) as the scheduler places it now.
  DayPlan plan(DateTime date, {bool keepSlots = true}) => Planner.plan(
        tasks: of(date),
        prayers: prayers(date),
        config: config,
        friday: date.weekday == DateTime.friday,
        notBefore: _isToday(date) ? (nowMinute() + 4) ~/ 5 * 5 : null,
        keepSlots: keepSlots,
      );

  /// Saves the scheduler's placements as the tasks' slots.
  void _place(DateTime date, {bool full = false}) {
    final p = plan(date, keepSlots: !full);
    for (final b in p.taskBlocks) {
      if (b.task!.fixedStart == null) b.task!.slot = b.start;
    }
    for (final t in p.overflow) {
      t.slot = null;
    }
  }

  DateTime _dateOf(PlanTask t) => DateTime.tryParse(t.date) ?? today();

  /// «رتّب يومي»: re-plans the rest of the day from scratch (done tasks stay where they were).
  Future<void> arrange(DateTime date) async {
    _place(date, full: true);
    await _save();
  }

  Future<void> add(PlanTask t) async {
    tasks.add(t);
    _place(_dateOf(t));
    await _save();
  }

  /// After editing a task: its old slot is dropped and it is placed again.
  Future<void> edited(PlanTask t) async {
    t.slot = null;
    _place(_dateOf(t));
    await _save();
  }

  Future<void> remove(PlanTask t) async {
    tasks.remove(t);
    await _save();
  }

  Future<void> setDone(PlanTask t, bool done) async {
    t.done = done;
    // Done before its slot (or without one): it ends now, and the time it had is freed for the others.
    if (done && t.fixedStart == null && _isToday(_dateOf(t))) {
      final now = nowMinute();
      if (t.slot == null || t.slot! > now) t.slot = (now - t.minutes).clamp(0, 24 * 60);
    }
    if (!done && t.fixedStart == null) t.slot = null;
    _place(_dateOf(t));
    await _save();
  }

  Future<void> moveToTomorrow(Iterable<PlanTask> list) async {
    final dates = <String>{};
    for (final t in list.toList()) {
      final d = _dateOf(t).add(const Duration(days: 1));
      dates.add(dayKey(d));
      t
        ..date = dayKey(d)
        ..slot = null
        ..fixedStart = null;
    }
    for (final d in dates) {
      _place(DateTime.parse(d));
    }
    await _save();
  }

  Future<void> setConfig(void Function(PlannerConfig c) change) async {
    change(config);
    _place(today());
    await _save();
  }

  /// Summary of a day: live for today and later, frozen for the past.
  PlanStat statOf(DateTime date) {
    final k = dayKey(date);
    if (k.compareTo(dayKey(today())) >= 0 || !stats.containsKey(k)) return PlanStat.of(tasks.where((t) => t.date == k));
    return stats[k]!;
  }

  /// The next undone task of today (the one running now, or the next one).
  PlanBlock? nextBlock() {
    final now = nowMinute();
    for (final b in plan(today()).taskBlocks) {
      if (!b.task!.done && b.end > now) return b;
    }
    return null;
  }
}
