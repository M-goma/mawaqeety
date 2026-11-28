import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/hifz.dart';
import 'package:mawaqeety/services/hifz.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final day0 = DateTime(2026, 11, 28);
  DateTime plus(int d) => DateTime(2026, 11, 28 + d);

  group('schedule', () {
    test('mastered ayah is reviewed after 1, 3, 7, 14, then every 30 days', () {
      final p = HifzProgress();
      var today = day0;
      final gaps = <int>[];
      for (var i = 0; i < 7; i++) {
        p.mastered(2, 255, today);
        final due = p.of(2, 255)!.due;
        gaps.add(due.difference(today).inDays);
        today = due;
      }
      expect(gaps, [1, 3, 7, 14, 30, 30, 30]);
    });

    test('«تحتاج مراجعة» restarts the schedule and stays due today', () {
      final p = HifzProgress()
        ..mastered(1, 1, day0)
        ..mastered(1, 1, plus(1))
        ..mastered(1, 1, plus(4));
      expect(p.of(1, 1)!.stage, 2);
      p.needsReview(1, 1, plus(11));
      expect(p.of(1, 1)!.weak, isTrue);
      expect(p.dueCount(plus(11)), 1);
      expect(p.memorized, 0);
      expect(p.weakCount, 1);
      p.mastered(1, 1, plus(11));
      expect(p.of(1, 1)!.stage, 0);
      expect(p.of(1, 1)!.due, plus(12));
    });

    test('due list holds today and overdue ayat, grouped into ranges', () {
      final p = HifzProgress();
      for (final a in [1, 2, 3, 5]) {
        p.mastered(2, a, day0); // due tomorrow
      }
      p.mastered(3, 7, plus(-5)); // overdue (was due 4 days ago)
      p.mastered(2, 10, plus(1)); // due the day after tomorrow
      expect(p.dueRanges(day0), [const HifzRange(3, 7, 7)]); // the overdue one only
      expect(p.dueRanges(plus(1)), [const HifzRange(2, 1, 3), const HifzRange(2, 5, 5), const HifzRange(3, 7, 7)]);
      expect(p.dueCount(plus(1)), 5);
      expect(p.memorizedIn(2), 5);
      expect(p.surahs, [2, 3]);
    });

    test('time of day does not matter', () {
      final p = HifzProgress()..mastered(1, 2, DateTime(2026, 11, 28, 23, 50));
      expect(p.of(1, 2)!.due, DateTime(2026, 11, 29));
      expect(p.isDue(p.of(1, 2)!, DateTime(2026, 11, 29, 0, 5)), isTrue);
    });

    test('json round trip', () {
      final p = HifzProgress()
        ..mastered(2, 255, day0)
        ..needsReview(18, 10, day0);
      final q = HifzProgress()..loadJson(p.toJson());
      expect(q.of(2, 255)!.stage, 0);
      expect(q.of(2, 255)!.due, plus(1));
      expect(q.of(18, 10)!.weak, isTrue);
      q.loadJson({'bad': [0, '2026-01-01'], '1001': 'x', '1002': [1, 'nope']});
      expect(q.entries, isEmpty);
    });
  });

  group('ranges', () {
    test('clamped: swapped ends and bounds of the surah', () {
      expect(HifzRange.clamped(1, 9, 3, 7), const HifzRange(1, 3, 7));
      expect(HifzRange.clamped(1, 0, 0, 7), const HifzRange(1, 1, 1));
      expect(HifzRange.clamped(112, 2, 99, 4), const HifzRange(112, 2, 4));
      expect(const HifzRange(2, 5, 9).length, 5);
      expect(const HifzRange(2, 5, 9).ayat.toList(), [5, 6, 7, 8, 9]);
      expect(const HifzRange(2, 5, 9).step(9, 1), 9);
      expect(const HifzRange(2, 5, 9).step(5, -1), 5);
      expect(const HifzRange(2, 5, 9).step(6, 1), 7);
    });

    test('groupRanges merges consecutive ayat in one surah only', () {
      expect(groupRanges([1007, 1006, 1005, 2001, 2002, 2004, 1006]),
          [const HifzRange(1, 5, 7), const HifzRange(2, 1, 2), const HifzRange(2, 4, 4)]);
      expect(groupRanges([1007, 2001]), [const HifzRange(1, 7, 7), const HifzRange(2, 1, 1)]);
      expect(groupRanges([]), isEmpty);
    });

    test('a repetition round plays each ayah N times before the next', () {
      expect(hifzRound(const HifzRange(1, 1, 3), 2), [(1, 1), (1, 2), (2, 1), (2, 2), (3, 1), (3, 2)]);
      expect(hifzRound(const HifzRange(1, 4, 4), 1), [(4, 1)]);
      expect(hifzRound(const HifzRange(1, 4, 5), 0), [(4, 1), (5, 1)]);
    });

    test('range json', () {
      expect(HifzRange.fromJson(const HifzRange(3, 1, 9).toJson()), const HifzRange(3, 1, 9));
      expect(HifzRange.fromJson(null), isNull);
      expect(HifzRange.fromJson({'s': 1}), isNull);
    });
  });

  group('words', () {
    test('first letter keeps its marks', () {
      expect(firstLetter('ٱلۡكِتَٰبُ'), ('ٱلۡكِ', 'تَٰبُ'));
      expect(firstLetter('ٱلۡمُلۡكُ'), ('ٱلۡمُ', 'لۡكُ'));
      expect(firstLetter('ٱللَّهِ'), ('ٱللَّ', 'هِ'));
      expect(firstLetter('ٱهۡدِنَا'), ('ٱهۡ', 'دِنَا'));
      expect(firstLetter('ٱ'), ('ٱ', ''));
      expect(firstLetter('رَيۡبَۛ'), ('رَ', 'يۡبَۛ'));
      expect(firstLetter('ءَآلۡـَٰٔنَ').$1, 'ءَ');
      expect(firstLetter('قُلۡ'), ('قُ', 'لۡ'));
      expect(hintJoins('ٱلۡمُ'), isTrue);
      expect(hintJoins('رَ'), isFalse);
      expect(hintJoins('بِ'), isTrue);
      expect(hintJoins('ٱ'), isFalse);
      expect(firstLetter('بِسۡمِ'), ('بِ', 'سۡمِ'));
      expect(firstLetter('لِّلۡمُتَّقِينَ').$1, 'لِّ');
      expect(firstLetter(''), ('', ''));
      expect(ayahWords(' ذَٰلِكَ  ٱلۡكِتَٰبُ '), ['ذَٰلِكَ', 'ٱلۡكِتَٰبُ']);
    });
  });

  test('store saves and restores (backup) its data', () async {
    SharedPreferences.setMockInitialValues({});
    final a = HifzStore();
    await a.load();
    await a.change((s) {
      s.each = 7;
      s.rounds = 3;
      s.lastRange = const HifzRange(67, 1, 5);
      s.firstLetters = true;
    });
    await a.mastered(67, 1, day0);
    final b = HifzStore();
    await b.load();
    expect(b.each, 7);
    expect(b.rounds, 3);
    expect(b.lastRange, const HifzRange(67, 1, 5));
    expect(b.firstLetters, isTrue);
    expect(b.progress.memorizedIn(67), 1);

    final c = HifzStore();
    await c.importJson({...a.toJson(), 'n': 4}); // a value that is not offered falls back
    expect(c.each, 3);
    expect(c.progress.of(67, 1)!.due, plus(1));
  });
}
