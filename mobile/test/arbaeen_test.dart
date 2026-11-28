import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/arbaeen.dart';
import 'package:mawaqeety/data/hadith.dart';
import 'package:mawaqeety/ui/arbaeen_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final book = Arbaeen.fromJson(jsonDecode(File('assets/data/arbaeen.json').readAsStringSync()) as Map<String, dynamic>);

  test('42 hadiths in order, each with text and takhrij', () {
    expect(book.hadiths.length, 42);
    for (var i = 0; i < 42; i++) {
      final h = book.hadiths[i];
      expect(h.number, i + 1);
      expect(h.text, isNotEmpty);
      expect(h.takhrij, isNotEmpty);
      expect(h.title, isNotEmpty);
    }
    expect(book.hadiths.first.text, contains('بِالنِّيَّاتِ'));
    expect(book.hadiths[4].extra!.label, 'وفي رواية لمسلم');
    expect(book.about.length, 2);
  });

  test('grades only outside the Sahihs; every benefit has its source', () {
    for (final h in book.hadiths) {
      if (h.sahih.isNotEmpty) expect(h.grade, isNull, reason: '${h.number}');
      if (h.benefits.isNotEmpty) expect(h.benefitsUrl, startsWith('https://www.islamweb.net/'));
    }
    expect(book.hadiths[11].grade, 'حسن');
    expect(book.hadiths.where((h) => h.sahih.isEmpty && h.related.isEmpty).map((h) => h.number),
        [11, 12, 18, 19, 28, 29, 30, 31, 32, 39, 41, 42]);
  });

  test('Sahih references open the right hadith in the bundled data', () async {
    for (final h in book.hadiths) {
      for (final r in [...h.sahih, ...h.related]) {
        final x = await r.resolve();
        expect(x, isNotNull, reason: '${h.number} ${r.collection} ${r.number}');
        expect(x!.number, r.number);
        expect(x.index, r.index);
      }
    }
    final first = await book.hadiths.first.sahih.first.resolve();
    expect(HadithCollection.plain(first!.text), contains('انما الاعمال بالنيات'));
  });

  test('memorised set round trip', () {
    expect(ArbaeenMemory.decode(['3', '1', 'x', '99', '1']), {1, 3});
    expect(ArbaeenMemory.encode({12, 2, 40}), ['2', '12', '40']);
    expect(ArbaeenMemory.decode(null), isEmpty);
    expect(memorizedLabel(12, 42), 'حفظت ١٢ من ٤٢');
  });

  test('ordinals', () {
    expect(arbaeenOrdinal(1), 'الأول');
    expect(arbaeenOrdinal(11), 'الحادي عشر');
    expect(arbaeenOrdinal(12), 'الثاني عشر');
    expect(arbaeenOrdinal(19), 'التاسع عشر');
    expect(arbaeenOrdinal(20), 'العشرون');
    expect(arbaeenOrdinal(21), 'الحادي والعشرون');
    expect(arbaeenOrdinal(42), 'الثاني والأربعون');
  });
}
