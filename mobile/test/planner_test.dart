import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/prayer_calculator.dart';
import 'package:mawaqeety/data/planner.dart';

int hm(int h, int m) => h * 60 + m;

/// A typical day: Fajr 5:00, sunrise 6:20, Dhuhr 12:00, Asr 15:15, Maghrib 17:45, Isha 19:10.
final prayers = {
  Prayer.fajr: hm(5, 0),
  Prayer.sunrise: hm(6, 20),
  Prayer.dhuhr: hm(12, 0),
  Prayer.asr: hm(15, 15),
  Prayer.maghrib: hm(17, 45),
  Prayer.isha: hm(19, 10),
};

var _n = 0;
PlanTask task(String title, int minutes, [TaskPriority p = TaskPriority.normal, int? fixed]) =>
    PlanTask(id: 't${_n++}', title: title, date: '2026-11-28', minutes: minutes, priority: p, fixedStart: fixed, created: _n);

void expectNoOverlaps(DayPlan plan) {
  final b = plan.blocks.where((x) => !x.clash).toList()..sort((x, y) => x.start.compareTo(y.start));
  for (var i = 1; i < b.length; i++) {
    expect(b[i].start, greaterThanOrEqualTo(b[i - 1].end), reason: '${b[i - 1].task?.title ?? b[i - 1].prayer} overlaps ${b[i].task?.title ?? b[i].prayer}');
  }
}

void main() {
  test('prayer blocks: the five prayers with the buffer, a longer Jumu\'a on Friday, no sunrise', () {
    final c = PlannerConfig(buffer: 20, jumuaBuffer: 60);
    final normal = Planner.prayerBlocks(prayers, c);
    expect(normal.map((b) => b.prayer), [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha]);
    expect(normal.every((b) => b.end - b.start == 20), isTrue);
    final friday = Planner.prayerBlocks(prayers, c, friday: true);
    expect(friday.firstWhere((b) => b.prayer == Prayer.dhuhr).end - hm(12, 0), 60);
    expect(friday.firstWhere((b) => b.prayer == Prayer.asr).end - hm(15, 15), 20);
  });

  test('flexible tasks never overlap prayers or each other, and stay inside the day', () {
    final tasks = [
      for (var i = 0; i < 14; i++) task('t$i', const [15, 30, 45, 60, 90, 120][i % 6], TaskPriority.values[i % 4]),
    ];
    final plan = Planner.plan(tasks: tasks, prayers: prayers);
    expectNoOverlaps(plan);
    for (final b in plan.taskBlocks) {
      expect(b.start, greaterThanOrEqualTo(plan.dayStart));
      expect(b.end, lessThanOrEqualTo(plan.dayEnd));
      for (final p in plan.blocks.where((x) => x.isPrayer)) {
        expect(p.overlaps(b.start, b.end), isFalse);
      }
    }
    // Every task is either placed or listed as overflow, once.
    expect(plan.taskBlocks.length + plan.overflow.length, tasks.length);
  });

  test('the day runs from Fajr to 23:00 by default, and follows the settings', () {
    final plan = Planner.plan(tasks: [task('a', 30)], prayers: prayers);
    expect(plan.dayStart, hm(5, 0));
    expect(plan.dayEnd, hm(23, 0));
    final custom = Planner.plan(tasks: [task('a', 30, TaskPriority.urgent)], prayers: prayers, config: PlannerConfig(dayStart: hm(7, 0), dayEnd: hm(22, 0)));
    expect(custom.dayStart, hm(7, 0));
    expect(custom.taskBlocks.first.start, hm(7, 0));
  });

  test('higher priority first, then longer first; important work right after Fajr', () {
    final normal = task('normal', 30);
    final urgentImportant = task('ui', 30, TaskPriority.urgentImportant);
    final important = task('imp', 60, TaskPriority.important);
    final importantLong = task('impLong', 90, TaskPriority.important);
    final plan = Planner.plan(tasks: [normal, important, urgentImportant, importantLong], prayers: prayers);
    int startOf(PlanTask t) => plan.taskBlocks.firstWhere((b) => b.task == t).start;
    // Fajr block ends 5:20: the most pressing task takes it.
    expect(startOf(urgentImportant), hm(5, 20));
    expect(startOf(importantLong), lessThan(startOf(important)));
    expect(startOf(important), lessThan(hm(12, 0)));
    // «عادي» leaves the morning for important work.
    expect(startOf(normal), greaterThanOrEqualTo(hm(12, 0)));
  });

  test('a task is never split: it skips a gap too small for it', () {
    // Free gaps: 5:20–12:00 (400 min) is filled by a 6h40 fixed block, so a 60-min task must go after Dhuhr.
    final blocker = task('blocker', 400, TaskPriority.normal, hm(5, 20));
    final t = task('hour', 60, TaskPriority.urgentImportant);
    final plan = Planner.plan(tasks: [blocker, t], prayers: prayers);
    final b = plan.taskBlocks.firstWhere((x) => x.task == t);
    expect(b.start, hm(12, 20));
    expect(b.end - b.start, 60);
  });

  test('tasks that do not fit are listed as overflow', () {
    final big = [for (var i = 0; i < 12; i++) task('big$i', 120, TaskPriority.important)];
    final tiny = task('too long', 600, TaskPriority.urgentImportant);
    final plan = Planner.plan(tasks: [...big, tiny], prayers: prayers);
    expect(plan.overflow, contains(tiny));
    expect(plan.overflow.length + plan.taskBlocks.length, 13);
    expectNoOverlaps(plan);
  });

  test('fixed-time tasks stay where they are and a clash with a prayer is flagged', () {
    final meeting = task('meeting', 60, TaskPriority.normal, hm(11, 30)); // runs into Dhuhr
    final call = task('call', 30, TaskPriority.normal, hm(9, 0));
    final plan = Planner.plan(tasks: [meeting, call], prayers: prayers);
    final m = plan.taskBlocks.firstWhere((b) => b.task == meeting);
    final c = plan.taskBlocks.firstWhere((b) => b.task == call);
    expect(m.start, hm(11, 30));
    expect(m.clash, isTrue);
    expect(c.start, hm(9, 0));
    expect(c.clash, isFalse);
    // A flexible task never lands on a fixed one.
    final flex = task('flex', 30, TaskPriority.urgentImportant);
    final p2 = Planner.plan(tasks: [call, flex], prayers: prayers, notBefore: hm(8, 50));
    final f = p2.taskBlocks.firstWhere((b) => b.task == flex);
    expect(f.overlaps(hm(9, 0), hm(9, 30)), isFalse);
    expect(f.start, hm(9, 30));
  });

  test('today: nothing new is placed in the past', () {
    final t = task('later', 30, TaskPriority.urgentImportant);
    final plan = Planner.plan(tasks: [t], prayers: prayers, notBefore: hm(15, 0));
    // 15:00–15:15 is too short, Asr until 15:35.
    expect(plan.taskBlocks.single.start, hm(15, 35));
  });

  test('slots are kept until the day is re-planned; done tasks always keep theirs', () {
    final a = task('a', 30)..slot = hm(13, 0);
    final done = task('done', 30, TaskPriority.urgentImportant)
      ..slot = hm(8, 0)
      ..done = true;
    final kept = Planner.plan(tasks: [a, done], prayers: prayers);
    expect(kept.taskBlocks.firstWhere((b) => b.task == a).start, hm(13, 0));
    final full = Planner.plan(tasks: [a, done], prayers: prayers, keepSlots: false);
    expect(full.taskBlocks.firstWhere((b) => b.task == a).start, hm(12, 20));
    expect(full.taskBlocks.firstWhere((b) => b.task == done).start, hm(8, 0));
    // A kept slot that now overlaps a prayer (e.g. the times changed) is placed again.
    final moved = task('m', 30)..slot = hm(11, 50);
    final p = Planner.plan(tasks: [moved], prayers: prayers);
    expect(p.taskBlocks.single.overlaps(hm(12, 0), hm(12, 20)), isFalse);
  });

  test('carry-over moves undone tasks of past days to today', () {
    final old = PlanTask(id: '1', title: 'old', date: '2026-11-27', fixedStart: hm(9, 0), slot: hm(9, 0));
    final oldDone = PlanTask(id: '2', title: 'done', date: '2026-11-27', done: true);
    final today = PlanTask(id: '3', title: 'today', date: '2026-11-28');
    final n = Planner.carryOver([old, oldDone, today], '2026-11-28');
    expect(n, 1);
    expect(old.date, '2026-11-28');
    expect(old.carried, isTrue);
    expect(old.fixedStart, isNull);
    expect(old.slot, isNull);
    expect(oldDone.date, '2026-11-27');
    expect(today.carried, isFalse);
  });

  test('tasks and settings survive JSON', () {
    final t = PlanTask(
      id: 'x', title: 'مذاكرة', date: '2026-11-28', minutes: 45, priority: TaskPriority.important, fixedStart: hm(16, 0),
      category: TaskCategory.study, notes: 'الفصل ٣', done: true, carried: true, remind: 10, slot: hm(16, 0), created: 7,
    );
    final back = PlanTask.fromJson(t.toJson());
    expect(back.toJson(), t.toJson());
    final c = PlannerConfig(dayStart: hm(6, 0), dayEnd: hm(22, 30), buffer: 25, jumuaBuffer: 75, carryOver: false, eveningNote: true);
    expect(PlannerConfig.fromJson(c.toJson()).toJson(), c.toJson());
    final s = PlanStat.of([t, PlanTask(id: 'y', title: 'b', date: '2026-11-28')]);
    expect([s.total, s.done, s.minutes], [2, 1, 45]);
    expect(PlanStat.fromJson(s.toJson()).ratio, 0.5);
  });
}
