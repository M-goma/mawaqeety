import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/asbab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final a = Asbab.parse(File('assets/data/asbab.json').readAsStringSync());
  final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync()) as List;

  test('parses and every range lies inside its surah', () {
    expect(a.all.length, inInclusiveRange(100, 260));
    for (final s in a.all) {
      final n = (quran[s.surah - 1]['v'] as List).length;
      expect(s.from, inInclusiveRange(1, n), reason: '${s.surah}:${s.from}');
      expect(s.to, inInclusiveRange(s.from, n), reason: '${s.surah}:${s.from}-${s.to}');
      expect(s.collection, anyOf('bukhari', 'muslim'));
      expect(s.excerpt, isNotEmpty);
    }
  });

  test('hadith number and index agree with the bundled collections', () {
    for (final c in ['bukhari', 'muslim']) {
      final j = jsonDecode(utf8.decode(gzip.decode(File('assets/data/hadith_$c.json.gz').readAsBytesSync()))) as Map;
      final rows = j['h'] as List;
      for (final s in a.all.where((s) => s.collection == c)) {
        expect(rows[s.index][1], s.number, reason: '$c ${s.number}');
      }
    }
  });

  test('famous occasions are present', () {
    bool has(int surah, int ayah, String c, int n) => a.forAyah(surah, ayah).any((s) => s.collection == c && s.number == n);
    expect(has(111, 1, 'bukhari', 4971), isTrue); // تبت يدا أبي لهب
    expect(has(33, 53, 'bukhari', 4792), isTrue); // آية الحجاب
    expect(has(9, 84, 'bukhari', 1269), isTrue); // ولا تصل على أحد منهم مات أبدا
    expect(has(4, 95, 'bukhari', 2832), isTrue); // غير أولي الضرر
    expect(has(24, 11, 'bukhari', 4690), isTrue); // حديث الإفك
    expect(has(9, 113, 'bukhari', 1360), isTrue); // وفاة أبي طالب
  });

  test('forAyah covers ranges and refs read in Arabic digits', () {
    final r = a.forAyah(111, 1).firstWhere((s) => s.number == 4971);
    expect(r.ref, 'صحيح البخاري ٤٩٧١');
    expect(a.forAyah(1, 1), isEmpty);
    expect(a.inSurah(24).every((s) => s.surah == 24), isTrue);
  });
}
