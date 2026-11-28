import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/ghazawat.dart';
import 'package:mawaqeety/data/hadith.dart';
import 'package:mawaqeety/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GhazawatData d;
  setUpAll(() async => d = await GhazawatData.load());

  test('parses the battles in chronological order', () {
    expect(d.list.length, 10);
    final years = [for (final g in d.list) g.year];
    expect(years, [...years]..sort());
    expect(d.byId('badr')!.year, 2);
    expect(d.byId('tabuk')!.year, 9);
    expect(d.byId('hudaybiya')!.isBattle, isFalse);
    for (final g in d.list) {
      expect(g.sections.length, inInclusiveRange(3, 8), reason: g.id);
      expect(g.lessons.length, inInclusiveRange(3, 5), reason: g.id);
      expect(g.lat, inInclusiveRange(20, 32), reason: g.id);
      expect(g.lng, inInclusiveRange(35, 41), reason: g.id);
    }
  });

  test('every Qur\'an passage exists', () async {
    final repo = Repository();
    await repo.load();
    for (final g in d.list) {
      for (final a in g.ayat) {
        expect(a.from, lessThanOrEqualTo(a.to), reason: g.id);
        expect(a.to, lessThanOrEqualTo(repo.surahs[a.surah - 1].verses.length), reason: '${g.id} ${a.surah}:${a.to}');
      }
    }
  });

  test('every hadith number is in the bundled Sahihs', () async {
    final cols = {for (final id in HadithCollection.ids) id: await HadithCollection.load(id)};
    for (final g in d.list) {
      for (final r in g.hadith) {
        final h = pickHadith(cols[r.collection]!, r);
        expect(h, isNotNull, reason: '${g.id} ${r.collection} ${r.number}');
        if (r.contains.isNotEmpty) {
          expect(HadithCollection.plain(h!.text), contains(HadithCollection.plain(r.contains)), reason: '${r.number}');
        }
      }
    }
    // Spot checks that the numbers point at the right story.
    String text(String c, int n, [String q = '']) => HadithCollection.plain(pickHadith(cols[c]!, GhazwaHadith(c, n, '', q))!.text);
    expect(text('bukhari', 3953), contains('بدر'));
    expect(text('bukhari', 4210), contains('خيبر'));
    expect(text('bukhari', 4261), contains('موته'));
    expect(text('muslim', 1775), contains('حنين'));
    expect(text('muslim', 1780, 'دار ابي سفيان'), contains('دار ابي سفيان'));
  });

  test('narration scripts fit one TTS request', () {
    for (final g in d.list) {
      final f = File('../tools/ghazawat_narration/${g.id}.txt');
      expect(f.existsSync(), isTrue, reason: g.id);
      final t = f.readAsStringSync();
      expect(t.length, lessThanOrEqualTo(3500), reason: g.id);
      expect(RegExp(r'[0-9٠-٩\[\]()]').hasMatch(t), isFalse, reason: g.id);
    }
  });
}
