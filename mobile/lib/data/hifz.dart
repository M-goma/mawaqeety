/// مساعد الحفظ: memorized ayat, their spaced review schedule and the ayah ranges the helper works on.
library;

/// A run of consecutive ayat in one surah (both ends included).
class HifzRange {
  final int surah, from, to;
  const HifzRange(this.surah, this.from, this.to);

  /// A valid range inside a surah of [length] ayat: ends swapped if reversed, clamped to 1..length.
  factory HifzRange.clamped(int surah, int from, int to, int length) {
    var a = from.clamp(1, length), b = to.clamp(1, length);
    if (a > b) (a, b) = (b, a);
    return HifzRange(surah, a, b);
  }

  int get length => to - from + 1;
  bool contains(int ayah) => ayah >= from && ayah <= to;
  Iterable<int> get ayat => Iterable.generate(length, (i) => from + i);

  /// [ayah] moved by [delta] ayat, kept inside the range.
  int step(int ayah, int delta) => (ayah + delta).clamp(from, to);

  Map<String, dynamic> toJson() => {'s': surah, 'f': from, 't': to};
  static HifzRange? fromJson(Object? j) =>
      j is Map && j['s'] is int && j['f'] is int && j['t'] is int ? HifzRange(j['s'], j['f'], j['t']) : null;

  @override
  bool operator ==(Object other) => other is HifzRange && other.surah == surah && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(surah, from, to);
  @override
  String toString() => 'HifzRange($surah:$from-$to)';
}

/// Groups ayat (surah*1000+ayah keys) into ranges of consecutive ayat, in Mushaf order.
List<HifzRange> groupRanges(Iterable<int> keys) {
  final sorted = keys.toSet().toList()..sort();
  final out = <HifzRange>[];
  for (final k in sorted) {
    final s = k ~/ 1000, a = k % 1000;
    if (out.isNotEmpty && out.last.surah == s && out.last.to == a - 1) {
      out[out.length - 1] = HifzRange(s, out.last.from, a);
    } else {
      out.add(HifzRange(s, a, a));
    }
  }
  return out;
}

/// One round of repetition: every ayah of [r] played [each] times before the next, as (ayah, repetition 1..each).
List<(int, int)> hifzRound(HifzRange r, int each) => [
      for (final a in r.ayat)
        for (var k = 1; k <= (each < 1 ? 1 : each); k++) (a, k),
    ];

/// The review schedule: an ayah is reviewed 1, 3, 7, 14 then every 30 days after it is mastered.
class HifzSchedule {
  static const intervals = [1, 3, 7, 14, 30];
  static int get lastStage => intervals.length - 1;

  /// Days until the next review once an ayah at [stage] (0..lastStage) is recited well.
  static int daysFor(int stage) => intervals[stage.clamp(0, lastStage)];
}

/// One memorized (or being memorized) ayah. [stage] −1 = needs review; 0..4 = index into [HifzSchedule.intervals].
class HifzEntry {
  final int stage;
  final DateTime due;
  const HifzEntry(this.stage, this.due);
  bool get weak => stage < 0;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Everything the helper remembers about the user's memorization.
class HifzProgress {
  final Map<int, HifzEntry> entries = {}; // surah*1000+ayah

  static int key(int surah, int ayah) => surah * 1000 + ayah;
  HifzEntry? of(int surah, int ayah) => entries[key(surah, ayah)];

  /// «أتقنتها»: a new or weak ayah starts the schedule (review tomorrow); a reviewed one moves a step further.
  void mastered(int surah, int ayah, DateTime today) {
    final e = of(surah, ayah);
    final stage = e == null || e.weak ? 0 : (e.stage + 1).clamp(0, HifzSchedule.lastStage);
    entries[key(surah, ayah)] = HifzEntry(stage, _day(today).add(Duration(days: HifzSchedule.daysFor(stage))));
  }

  /// «تحتاج مراجعة»: back to the start, and it stays on today's review list until it is mastered.
  void needsReview(int surah, int ayah, DateTime today) => entries[key(surah, ayah)] = HifzEntry(-1, _day(today));

  void forget(int surah, int ayah) => entries.remove(key(surah, ayah));

  bool isDue(HifzEntry e, DateTime today) => !e.due.isAfter(_day(today));

  /// Ayat to review today (due today or overdue), grouped into ranges.
  List<HifzRange> dueRanges(DateTime today) =>
      groupRanges([for (final e in entries.entries) if (isDue(e.value, today)) e.key]);

  int dueCount(DateTime today) => entries.values.where((e) => isDue(e, today)).length;

  /// Ayat of a surah the user has mastered (not counting the ones marked «تحتاج مراجعة»).
  int memorizedIn(int surah) =>
      entries.entries.where((e) => e.key ~/ 1000 == surah && !e.value.weak).length;
  int get memorized => entries.values.where((e) => !e.weak).length;
  int get weakCount => entries.values.where((e) => e.weak).length;

  /// Surahs with at least one tracked ayah, in Mushaf order.
  List<int> get surahs => (entries.keys.map((k) => k ~/ 1000).toSet().toList()..sort());

  Map<String, dynamic> toJson() => {for (final e in entries.entries) '${e.key}': [e.value.stage, _key(e.value.due)]};

  void loadJson(Map<String, dynamic> j) {
    entries.clear();
    for (final e in j.entries) {
      final k = int.tryParse(e.key);
      final v = e.value;
      if (k == null || v is! List || v.length < 2) continue;
      final due = DateTime.tryParse('${v[1]}');
      if (due == null || v[0] is! int) continue;
      entries[k] = HifzEntry(v[0] as int, _day(due));
    }
  }
}

bool _isMark(int c) =>
    (c >= 0x0610 && c <= 0x061A) || (c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x06D6 && c <= 0x06ED) ||
    (c >= 0x08D3 && c <= 0x08FF);

/// The words of an ayah, for the self-test.
List<String> ayahWords(String verse) => verse.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// A word split after its first letter (with that letter's marks): «ٱلۡكِتَٰبُ» → («ٱ», «لۡكِتَٰبُ»).
(String, String) firstLetter(String word) {
  final c = word.runes.toList();
  if (c.isEmpty) return ('', '');
  var i = 1;
  while (i < c.length && _isMark(c[i])) {
    i++;
  }
  return (String.fromCharCodes(c.take(i)), String.fromCharCodes(c.skip(i)));
}
