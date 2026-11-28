import '../core/prayer_calculator.dart';

/// Smart daily planner: tasks and the pure scheduling logic that places them around the prayers.
///
/// Times are minutes from the local midnight of the task's day (0 = 00:00, 1380 = 23:00; a time after midnight,
/// such as a late Isha, is above 1440).

/// Eisenhower priority, most pressing first.
enum TaskPriority { urgentImportant, important, urgent, normal }

extension TaskPriorityX on TaskPriority {
  String get label => const ['مهم وعاجل', 'مهم غير عاجل', 'عاجل غير مهم', 'عادي'][index];

  /// Important tasks are the deep work: they are scheduled first and early in the day.
  bool get isImportant => this == TaskPriority.urgentImportant || this == TaskPriority.important;

  /// ARGB colour of its chip.
  int get color => const [0xFFE5484D, 0xFF22A06B, 0xFFF59E0B, 0xFF8B98A9][index];
}

enum TaskCategory { work, study, family, worship, personal }

extension TaskCategoryX on TaskCategory {
  String get label => const ['عمل', 'دراسة', 'أسرة', 'عبادة', 'شخصي'][index];
  String get emoji => const ['💼', '📚', '👨‍👩‍👧', '🕌', '🙂'][index];
}

/// Durations offered in the editor (minutes); any other value is a custom one.
const plannerDurations = [15, 30, 45, 60, 90, 120];

/// Reminder offsets offered (minutes before the start; 0 = at the start).
const plannerReminders = [0, 5, 10, 15];

class PlanTask {
  final String id;
  String title;
  int minutes;
  TaskPriority priority;

  /// A start the user fixed (minutes of the day); null = placed automatically.
  int? fixedStart;
  TaskCategory? category;
  String notes;
  bool done;

  /// The day it belongs to (yyyy-mm-dd).
  String date;

  /// Rolled over from an earlier day without being done.
  bool carried;

  /// Reminder minutes before the start (null = no reminder).
  int? remind;

  /// The start the scheduler gave it (kept until «رتّب يومي» re-plans the day).
  int? slot;

  /// Creation time (ms), the last tie-breaker of the order.
  final int created;

  PlanTask({
    required this.id,
    required this.title,
    required this.date,
    this.minutes = 30,
    this.priority = TaskPriority.normal,
    this.fixedStart,
    this.category,
    this.notes = '',
    this.done = false,
    this.carried = false,
    this.remind,
    this.slot,
    int? created,
  }) : created = created ?? DateTime.now().millisecondsSinceEpoch;

  int? get start => fixedStart ?? slot;

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'd': date,
        'm': minutes,
        'p': priority.index,
        if (fixedStart != null) 'f': fixedStart,
        if (category != null) 'c': category!.index,
        if (notes.isNotEmpty) 'n': notes,
        if (done) 'x': 1,
        if (carried) 'r': 1,
        if (remind != null) 'a': remind,
        if (slot != null) 's': slot,
        'k': created,
      };

  static PlanTask fromJson(Map<String, dynamic> j) {
    final p = (j['p'] ?? 3) as int;
    final c = j['c'] as int?;
    return PlanTask(
      id: '${j['id']}',
      title: '${j['t'] ?? ''}',
      date: '${j['d'] ?? ''}',
      minutes: ((j['m'] ?? 30) as int).clamp(5, 24 * 60),
      priority: TaskPriority.values[p.clamp(0, TaskPriority.values.length - 1)],
      fixedStart: j['f'] as int?,
      category: c != null && c >= 0 && c < TaskCategory.values.length ? TaskCategory.values[c] : null,
      notes: '${j['n'] ?? ''}',
      done: j['x'] == 1,
      carried: j['r'] == 1,
      remind: j['a'] as int?,
      slot: j['s'] as int?,
      created: j['k'] as int?,
    );
  }
}

/// The planner's own settings (saved with the tasks).
class PlannerConfig {
  /// Start of the planned day (null = at Fajr) and its end (minutes of the day).
  int? dayStart;
  int dayEnd;

  /// Minutes kept for each prayer from its time, and for the Friday prayer.
  int buffer, jumuaBuffer;
  bool carryOver, reminders, morningNote, eveningNote;

  PlannerConfig({
    this.dayStart,
    this.dayEnd = 23 * 60,
    this.buffer = 20,
    this.jumuaBuffer = 60,
    this.carryOver = true,
    this.reminders = true,
    this.morningNote = true,
    this.eveningNote = false,
  });

  Map<String, dynamic> toJson() => {
        if (dayStart != null) 'ds': dayStart,
        'de': dayEnd,
        'b': buffer,
        'jb': jumuaBuffer,
        'co': carryOver,
        'rm': reminders,
        'mn': morningNote,
        'en': eveningNote,
      };

  static PlannerConfig fromJson(Map<String, dynamic> j) => PlannerConfig(
        dayStart: j['ds'] as int?,
        dayEnd: (j['de'] ?? 23 * 60) as int,
        buffer: (j['b'] ?? 20) as int,
        jumuaBuffer: (j['jb'] ?? 60) as int,
        carryOver: (j['co'] ?? true) as bool,
        reminders: (j['rm'] ?? true) as bool,
        morningNote: (j['mn'] ?? true) as bool,
        eveningNote: (j['en'] ?? false) as bool,
      );
}

/// One block of the day's timeline: a prayer or a task.
class PlanBlock {
  final int start, end;
  final Prayer? prayer;
  final PlanTask? task;

  /// A fixed-time task that overlaps a prayer or another fixed task.
  final bool clash;
  const PlanBlock(this.start, this.end, {this.prayer, this.task, this.clash = false});
  bool get isPrayer => prayer != null;
  bool overlaps(int s, int e) => s < end && start < e;
}

class DayPlan {
  final int dayStart, dayEnd;

  /// Prayers and placed tasks, by start time.
  final List<PlanBlock> blocks;

  /// Undone tasks that found no free gap («لم يتسع لها اليوم»), in priority order.
  final List<PlanTask> overflow;
  const DayPlan(this.dayStart, this.dayEnd, this.blocks, this.overflow);

  Iterable<PlanBlock> get taskBlocks => blocks.where((b) => b.task != null);
}

class Planner {
  /// The five prayers' blocks: from the prayer time for [PlannerConfig.buffer] minutes
  /// ([PlannerConfig.jumuaBuffer] for Dhuhr on Friday).
  static List<PlanBlock> prayerBlocks(Map<Prayer, int> times, PlannerConfig c, {bool friday = false}) => [
        for (final p in Prayer.values)
          if (p.isObligatory && times[p] != null)
            PlanBlock(times[p]!, times[p]! + (friday && p == Prayer.dhuhr ? c.jumuaBuffer : c.buffer), prayer: p),
      ];

  /// Places a day's tasks around its prayers.
  ///
  /// Rules: prayer blocks and fixed-time tasks are placed as given (a fixed task overlapping a prayer is
  /// flagged [PlanBlock.clash]). With [keepSlots], tasks already given a [PlanTask.slot] keep it while it is still
  /// free; done tasks always keep theirs. The other undone tasks go, one by one, into the first free gap that holds
  /// them whole (never split): the most pressing priority first, then the longer task first. «عادي» tasks prefer
  /// the time after Dhuhr so the morning stays for important work. [notBefore] (now, for today) keeps new
  /// placements out of the past. Tasks that fit nowhere are returned as [DayPlan.overflow].
  static DayPlan plan({
    required List<PlanTask> tasks,
    required Map<Prayer, int> prayers,
    PlannerConfig? config,
    bool friday = false,
    int? notBefore,
    bool keepSlots = true,
  }) {
    final c = config ?? PlannerConfig();
    final dayStart = c.dayStart ?? prayers[Prayer.fajr] ?? 5 * 60;
    var dayEnd = c.dayEnd;
    if (dayEnd <= dayStart) dayEnd = 24 * 60;
    final blocks = <PlanBlock>[
      for (final b in prayerBlocks(prayers, c, friday: friday))
        if (b.end > dayStart && b.start < dayEnd) b,
    ];
    final busy = <(int, int)>[for (final b in blocks) (b.start, b.end)];
    bool free(int s, int e) => !busy.any((x) => s < x.$2 && x.$1 < e);

    // 1. Fixed-time tasks, as given.
    final fixed = tasks.where((t) => t.fixedStart != null).toList()..sort((a, b) => a.fixedStart!.compareTo(b.fixedStart!));
    for (final t in fixed) {
      final s = t.fixedStart!, e = s + t.minutes;
      final clash = !free(s, e);
      blocks.add(PlanBlock(s, e, task: t, clash: clash));
      busy.add((s, e));
    }

    // 2. Tasks that keep their slot.
    final flexible = <PlanTask>[];
    final kept = tasks.where((t) => t.fixedStart == null && t.slot != null && (t.done || keepSlots)).toList()
      ..sort((a, b) => a.slot!.compareTo(b.slot!));
    for (final t in kept) {
      final s = t.slot!, e = s + t.minutes;
      final inDay = s >= dayStart && e <= dayEnd;
      if (t.done || (inDay && free(s, e))) {
        blocks.add(PlanBlock(s, e, task: t));
        busy.add((s, e));
      } else {
        flexible.add(t);
      }
    }
    flexible.addAll(tasks.where((t) => t.fixedStart == null && !t.done && !kept.contains(t)));

    // 3. The rest into the free gaps.
    flexible.sort((a, b) {
      final p = a.priority.index.compareTo(b.priority.index);
      if (p != 0) return p;
      final m = b.minutes.compareTo(a.minutes);
      return m != 0 ? m : a.created.compareTo(b.created);
    });
    final from = notBefore != null && notBefore > dayStart ? notBefore : dayStart;
    var gaps = _gaps(from, dayEnd, busy);
    final afternoon = prayers[Prayer.dhuhr] ?? 12 * 60;
    final overflow = <PlanTask>[];
    for (final t in flexible) {
      final fits = gaps.where((g) => g.$2 - g.$1 >= t.minutes).toList();
      if (fits.isEmpty) {
        overflow.add(t);
        continue;
      }
      var g = fits.first;
      if (t.priority == TaskPriority.normal) g = fits.where((x) => x.$1 >= afternoon).firstOrNull ?? g;
      final s = g.$1, e = s + t.minutes;
      blocks.add(PlanBlock(s, e, task: t));
      busy.add((s, e));
      gaps = _gaps(from, dayEnd, busy);
    }
    blocks.sort((a, b) {
      final s = a.start.compareTo(b.start);
      return s != 0 ? s : (a.isPrayer ? -1 : (b.isPrayer ? 1 : 0));
    });
    return DayPlan(dayStart, dayEnd, blocks, overflow);
  }

  /// Free intervals of [from, to) outside [busy].
  static List<(int, int)> _gaps(int from, int to, List<(int, int)> busy) {
    final b = [...busy]..sort((x, y) => x.$1.compareTo(y.$1));
    final out = <(int, int)>[];
    var cur = from;
    for (final (s, e) in b) {
      if (e <= cur) continue;
      if (s >= to) break;
      if (s > cur) out.add((cur, s));
      if (e > cur) cur = e;
    }
    if (cur < to) out.add((cur, to));
    return out;
  }

  /// Rolls the undone tasks of the days before [today] over to it, marked [PlanTask.carried], with their slot
  /// (and any fixed time, which belonged to that day) cleared. Returns how many moved.
  static int carryOver(List<PlanTask> tasks, String today) {
    var n = 0;
    for (final t in tasks) {
      if (t.done || t.date.compareTo(today) >= 0) continue;
      t
        ..date = today
        ..carried = true
        ..slot = null
        ..fixedStart = null;
      n++;
    }
    return n;
  }
}

/// A day's planner summary (kept for past days, live for today).
class PlanStat {
  final int total, done, minutes;
  const PlanStat(this.total, this.done, this.minutes);
  double get ratio => total == 0 ? 0 : done / total;

  static PlanStat of(Iterable<PlanTask> tasks) {
    var total = 0, done = 0, minutes = 0;
    for (final t in tasks) {
      total++;
      if (t.done) {
        done++;
        minutes += t.minutes;
      }
    }
    return PlanStat(total, done, minutes);
  }

  List<int> toJson() => [total, done, minutes];
  static PlanStat fromJson(Object? j) {
    final l = j is List ? j : const [];
    int at(int i) => l.length > i && l[i] is int ? l[i] as int : 0;
    return PlanStat(at(0), at(1), at(2));
  }
}
