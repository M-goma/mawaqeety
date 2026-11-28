import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/adhkar.dart';
import 'package:mawaqeety/data/hisn.dart';

/// «حصن المسلم» (assets/data/hisn.json, tools/build_hisn.py): the book's numbering, the Sahih references
/// checked against the app's own Bukhari and Muslim, and the Qur'an quotations against assets/data/quran.json.
void main() {
  Hisn.parse(File('assets/data/hisn.json').readAsStringSync());
  final dhikrs = [for (final c in Hisn.chapters) ...c.items];

  // Same normalisation as tools/build_hisn.py.
  final diac = RegExp('[ً-ٰٟۖ-ۭـ]');
  String plain(String s) => s
      .replaceAll(diac, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp('[^ء-ي ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  String skeleton(String s) => s
      .replaceAll(diac, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp('[ءؤئ]'), '')
      .replaceAll(RegExp('[^ب-ي]|[اويى]'), '')
      .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

  test('chapters and adhkar are numbered as in the book', () {
    expect([for (final c in Hisn.chapters) c.number], List.generate(133, (i) => i));
    final numbers = [for (final d in dhikrs) if (d.number != null) d.number!];
    expect(numbers.toSet().length, numbers.length, reason: 'a dhikr number twice');
    // أذكار الصباح والمساء (27) are the «الأذكار» tab's list; every other number of the 267 is here.
    final morning = Hisn.byNumber(27)!;
    expect(morning.link, 'adhkar');
    expect(morning.items, isEmpty);
    expect(adhkar, isNotEmpty);
    final missing = [for (var n = 1; n <= 267; n++) if (!numbers.contains(n)) n];
    expect(missing, List.generate(24, (i) => 75 + i));
    for (final c in Hisn.chapters) {
      expect(c.title, isNotEmpty);
      expect(c.urls, isNotEmpty);
      if (c.link == null) expect(c.items, isNotEmpty, reason: c.title);
      expect(Hisn.topics.map((t) => t.id), contains(c.topic));
    }
    for (final d in dhikrs) {
      expect(d.text, isNotEmpty);
      expect(d.count, greaterThanOrEqualTo(1));
      // Every dhikr carries the book's takhrij, or its chapter lists them.
      expect(d.takhrij.isNotEmpty || d.chapter.sources.isNotEmpty, isTrue, reason: '${d.chapter.title}: ${d.number}');
      expect(d.grade, isNot(contains('ضعيف')));
    }
  });

  test('every Bukhari/Muslim number exists in the app\'s Sahih and holds the dhikr\'s words', () {
    final rows = <String, List<List>>{
      for (final id in ['bukhari', 'muslim'])
        id: (jsonDecode(utf8.decode(const GZipDecoder().decodeBytes(File('assets/data/hadith_$id.json.gz').readAsBytesSync())))
            as Map<String, dynamic>)['h'].cast<List>(),
    };
    var n = 0;
    for (final d in dhikrs) {
      for (final r in d.refs) {
        final h = rows[r.col]!;
        final found = [
          for (final row in h)
            if (row[1] == r.number) plain(row[2] as String),
        ];
        expect(found, isNotEmpty, reason: '${r.col} ${r.number} not found');
        expect(found.any((t) => t.contains(r.key)), isTrue, reason: '${r.col} ${r.number} lacks «${r.key}» (${d.chapter.title})');
        expect(plain(d.text), contains(r.key));
        // The takhrij names that collection.
        expect(d.takhrij, contains(r.col == 'bukhari' ? 'البخاري' : 'مسلم'));
        n++;
      }
    }
    expect(n, greaterThan(100));
  });

  test('display: no bracket pair around a whole dhikr, Arabic-Indic numerals in the takhrij', () {
    const pairs = {'(': ')', '«': '»', '[': ']'};
    for (final d in dhikrs) {
      final t = d.text.trim().replaceAll(RegExp(r'[\s.]+$'), '');
      final close = t.isEmpty ? null : pairs[t[0]];
      if (close != null && t.endsWith(close)) {
        // A pair at both ends is fine only when they are two separate pairs («…» … «…»).
        var depth = 0, i = 0;
        for (; i < t.length; i++) {
          if (t[i] == t[0]) depth++;
          if (t[i] == close) depth--;
          if (depth == 0) break;
        }
        expect(i, lessThan(t.length - 1), reason: 'wrapped: ${d.number} ${d.chapter.title}');
      }
      expect(d.text, isNot(contains('((')));
      expect(d.source, isNot(contains(RegExp('[0-9]'))), reason: d.source);
      expect(d.source, isNot(contains(RegExp(r'[٠-٩]\s+/|/\s+[٠-٩]'))), reason: d.source);
    }
    for (final c in Hisn.chapters) {
      expect(c.sourcesText, isNot(contains(RegExp('[0-9]'))));
    }
    // The corrections in tools/build_hisn.py (TEXT_FIX) are in the data.
    String textOf(int n) => dhikrs.firstWhere((d) => d.number == n).text;
    expect(plain(textOf(224)), contains('لا تدخلون الجنه'));
    expect(plain(textOf(226)), contains('عبد الله بن عمرو'));
    expect(plain(textOf(55)), contains('من عذاب جهنم ومن عذاب القبر'));
    expect(textOf(1), isNot(startsWith('(')));
  });

  test('Qur\'an quotations match assets/data/quran.json', () {
    final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync()) as List;
    var n = 0;
    for (final d in dhikrs) {
      for (final p in d.parts) {
        final ref = p.quran;
        if (ref == null) continue;
        final (s, from, to) = ref;
        final verses = (quran[s - 1]['v'] as List).cast<String>();
        expect(to, lessThanOrEqualTo(verses.length));
        final q = skeleton(verses.sublist(from - 1, to).join(' '));
        final k = skeleton(p.text);
        expect(q, contains(k), reason: '$s:$from-$to «${p.text}»');
        if (!p.partial) expect(q.length - k.length, lessThanOrEqualTo(1), reason: '$s:$from-$to is quoted whole');
        n++;
      }
    }
    expect(n, greaterThanOrEqualTo(15));
  });

  test('search finds chapters and adhkar', () {
    expect(Hisn.search('الاستخارة').first.$1.number, 26);
    expect(Hisn.search('دعاء السفر').map((h) => h.$1.number), contains(96));
    expect(Hisn.search('اللهم اجعل في قلبي نورا').map((h) => h.$2?.number), contains(19));
    expect(Hisn.search('xyz'), isEmpty);
  });
}
