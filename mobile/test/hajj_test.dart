import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/arabic.dart';
import 'package:mawaqeety/data/ghazawat.dart';
import 'package:mawaqeety/data/hadith.dart';
import 'package:mawaqeety/data/hajj.dart';
import 'package:mawaqeety/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HajjData d;
  setUpAll(() async => d = await HajjData.load());

  test('json is well formed and complete', () {
    final j = jsonDecode(File('assets/data/hajj.json').readAsStringSync()) as Map<String, dynamic>;
    expect(j['collected'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(d.guides.map((g) => g.id), ['umrah', 'hajj']);
    expect(d.types.map((t) => t.id), ['tamattu', 'qiran', 'ifrad']);
    expect(d.types.where((t) => t.hady).map((t) => t.id), ['tamattu', 'qiran']);
    expect(d.rulings.keys, ['ركن', 'واجب', 'سنة']);
    expect(d.mawaqit.length, 5);
    expect(d.mahzurat, isNotEmpty);
    expect(d.packing, isNotEmpty);
    final ids = <String>{};
    for (final g in d.guides) {
      for (final s in g.steps) {
        expect(ids.add(s.id), isTrue, reason: 'duplicate ${s.id}');
        expect(d.rulings.keys, contains(s.ruling), reason: s.id);
        expect(s.what, isNotEmpty, reason: s.id);
        expect(s.checklist, isNotEmpty, reason: s.id);
        expect(s.refs, isNotEmpty, reason: s.id);
        expect(s.title.trim(), isNotEmpty);
        expect(s.place.isEmpty || s.place == 'miqat' || d.place(s.place) != null, isTrue, reason: s.place);
        if (s.khilaf) expect(s.rulingNote, isNotEmpty, reason: s.id);
      }
    }
  });

  test('steps are in order, Hajj follows the days of Dhul-Hijjah', () {
    for (final g in d.guides) {
      final orders = [for (final s in g.steps) s.order];
      expect(orders, [for (var i = 1; i <= g.steps.length; i++) i], reason: g.id);
      final days = [for (final s in g.steps) s.day];
      expect(days, [...days]..sort(), reason: g.id);
    }
    expect(d.guide('umrah').steps.map((s) => s.id), ['u-ihram', 'u-talbiya', 'u-tawaf', 'u-sai', 'u-halq']);
    final hajj = d.guide('hajj').steps;
    int dayOf(String id) => hajj.firstWhere((s) => s.id == id).day;
    expect(dayOf('h-tarwiya'), 8);
    expect(dayOf('h-arafah'), 9);
    expect(dayOf('h-aqabah'), 10);
    expect(dayOf('h-tashreeq'), 11);
    final order = [for (final s in hajj) s.id];
    for (final (a, b) in [
      ('h-ihram', 'h-tarwiya'),
      ('h-tarwiya', 'h-arafah'),
      ('h-arafah', 'h-muzdalifah'),
      ('h-muzdalifah', 'h-aqabah'),
      ('h-aqabah', 'h-hady'),
      ('h-hady', 'h-halq'),
      ('h-halq', 'h-ifadah'),
      ('h-ifadah', 'h-tashreeq'),
      ('h-tashreeq', 'h-wada'),
    ]) {
      expect(order.indexOf(a), lessThan(order.indexOf(b)), reason: '$a before $b');
    }
    // The pillars are marked as such.
    for (final id in ['h-ihram', 'h-arafah', 'h-ifadah']) {
      expect(hajj.firstWhere((s) => s.id == id).ruling, 'ركن', reason: id);
    }
  });

  test('every reference is https on an allowed host', () {
    const hosts = {'www.islamweb.net', 'islamqa.info', 'binbaz.org.sa', 'www.dar-alifta.org', 'www.azhar.eg'};
    final refs = d.allRefs.toList();
    expect(refs.length, greaterThan(40));
    for (final r in refs) {
      final u = Uri.parse(r.url);
      expect(u.scheme, 'https', reason: r.url);
      expect(hosts, contains(u.host), reason: r.url);
      expect(r.url, matches(RegExp(r'/\d+(/|$)')), reason: 'fatwa/article number: ${r.url}');
      expect(r.source.trim(), isNotEmpty);
    }
    for (final x in d.allDhikr.where((x) => x.via.isNotEmpty)) {
      expect(hosts, contains(Uri.parse(x.via).host), reason: x.via);
    }
  });

  test('coordinates are inside Saudi Arabia, near the right places', () {
    bool inSaudi(double lat, double lng) => lat > 16 && lat < 32.2 && lng > 34.5 && lng < 55.7;
    for (final p in d.places) {
      expect(inSaudi(p.lat, p.lng), isTrue, reason: p.id);
    }
    for (final m in d.mawaqit) {
      expect(inSaudi(m.lat, m.lng), isTrue, reason: m.id);
      expect(m.km, greaterThan(0));
    }
    // The holy sites are within ~25 km of the Kaaba; the mawaqit lie 60–450 km away.
    double km(double lat, double lng) {
      const r = 6371.0;
      final p = d.place('haram')!;
      final dLat = (lat - p.lat) * 0.0174533, dLng = (lng - p.lng) * 0.0174533;
      final x = dLng * cos((lat + p.lat) / 2 * 0.0174533);
      return r * sqrt(dLat * dLat + x * x);
    }

    for (final p in d.places.where((p) => !p.optional)) {
      expect(km(p.lat, p.lng), lessThan(25), reason: p.id);
    }
    for (final m in d.mawaqit) {
      expect(km(m.lat, m.lng), inInclusiveRange(55, 450), reason: m.id);
    }
    expect(d.mawaqit.firstWhere((m) => m.id == 'dhulhulayfah').lat, greaterThan(24)); // north, by Madinah
    expect(d.mawaqit.firstWhere((m) => m.id == 'yalamlam').lat, lessThan(21)); // south
  });

  test('every Qur\'an passage is in the bundled Mushaf', () async {
    final repo = Repository();
    await repo.load();
    // Uthmani spelling drops some long vowels (إبرٰهۧم), so compare without ي and spaces.
    String key(String s) => Arabic.searchKey(s).replaceAll(RegExp('[ي ]'), '');
    final quran = d.allDhikr.where((x) => x.isQuran).toList();
    expect(quran.length, greaterThanOrEqualTo(8));
    for (final x in quran) {
      expect(x.surah, inInclusiveRange(1, 114));
      final verses = repo.surahs[x.surah - 1].verses;
      expect(x.ayah, inInclusiveRange(1, verses.length), reason: '${x.surah}:${x.ayah}');
      expect(key(verses[x.ayah - 1]), contains(key(x.text)), reason: '${x.surah}:${x.ayah} ${x.text}');
    }
  });

  test('every hadith is sourced: found in the bundled Sahihs, or named with collection and number', () async {
    final cols = {for (final id in HadithCollection.ids) id: await HadithCollection.load(id)};
    final all = d.allDhikr.toList();
    expect(all.length, greaterThan(25));
    for (final x in all.where((x) => !x.isQuran)) {
      expect(x.source, matches(RegExp(r'(صحيح البخاري|صحيح مسلم|سنن أبي داود|سنن الترمذي) \d+')), reason: x.text);
      if (x.inSahihs) {
        final h = pickHadith(cols[x.collection]!, GhazwaHadith(x.collection, x.number, '', x.contains));
        expect(h, isNotNull, reason: '${x.collection} ${x.number}');
        expect(
          HadithCollection.plain(h!.text),
          contains(HadithCollection.plain(x.contains)),
          reason: '${x.collection} ${x.number} ${x.contains}',
        );
        expect(x.source, contains('${x.number}'));
      } else {
        expect(x.via, isNotEmpty, reason: 'a page that cites ${x.source}');
      }
    }
  });

  test('checklist keys are unique', () {
    final keys = [for (final g in d.guides) ...g.checkKeys];
    expect(keys.toSet().length, keys.length);
  });
}
