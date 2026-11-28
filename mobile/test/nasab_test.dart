import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/companions_islam.dart';
import 'package:mawaqeety/data/hadith.dart';
import 'package:mawaqeety/data/nasab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ids = [
    for (final c in (jsonDecode(File('assets/data/companions.json').readAsStringSync()) as Map)['companions'] as List) c['id'] as String,
  ];

  test('the chain runs from Muhammad ﷺ to Adnan as in al-Bukhari', () {
    final names = Nasab.chain.map((a) => a.name.replaceAll(' ﷺ', '')).toList();
    expect(
      names.join(' بن '),
      'محمد بن عبد الله بن عبد المطلب بن هاشم بن عبد مناف بن قصي بن كلاب بن مرة بن كعب بن لؤي بن غالب بن فهر بن مالك بن النضر بن كنانة بن خزيمة بن مدركة بن إلياس بن مضر بن نزار بن معد بن عدنان',
    );
    expect(Nasab.intro, contains(names.skip(1).join(' بن ')));
  });

  test('each of the ten meets the chain at the ancestor named last in his own lineage', () {
    expect(Nasab.companions.map((c) => c.id).toList(), ids);
    final expected = {
      'abubakr': 'مرة',
      'umar': 'كعب',
      'uthman': 'عبد مناف',
      'ali': 'عبد المطلب',
      'talha': 'مرة',
      'zubayr': 'قصي',
      'awf': 'كلاب',
      'saad': 'كلاب',
      'said': 'كعب',
      'ubayda': 'فهر',
    };
    for (final c in Nasab.companions) {
      expect(Nasab.chain[c.meet].name, c.meetName, reason: c.id);
      expect(c.meetName, expected[c.id], reason: c.id);
      expect(Nasab.indexOf(c.meetName), c.meet, reason: c.id);
      expect(c.source.url, startsWith('https://'));
    }
  });

  test('companions islam: ids, and every quoted hadith is found in the bundled Bukhari', () async {
    expect(CompanionsIslam.list.map((c) => c.id).toList(), ids);
    final bukhari = await HadithCollection.load('bukhari');
    String key(String s) => HadithCollection.plain(
      s.replaceAll('ﷺ', 'صلى الله عليه وسلم'),
    ).replaceAll(RegExp('[^ء-ي ]'), ' ').replaceAll(RegExp(' +'), ' ').trim();
    for (final c in CompanionsIslam.list) {
      expect(c.sources, isNotEmpty, reason: c.id);
      final h = c.hadith;
      if (h == null) continue;
      final texts = bukhari.all.where((x) => x.number == h.number).map((x) => key(x.text)).toList();
      expect(texts, isNotEmpty, reason: '${c.id} #${h.number}');
      // The quote (without the narrator lead-in) must appear word for word, ignoring diacritics and punctuation.
      final quote = h.text.contains('«') ? h.text.substring(h.text.indexOf('«')) : h.text;
      final q = key(quote);
      expect(texts.any((t) => t.contains(q)), isTrue, reason: '${c.id}: "$q" not in Bukhari ${h.number}');
    }
  });
}
