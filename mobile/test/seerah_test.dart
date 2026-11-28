import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/ghazawat.dart';
import 'package:mawaqeety/data/repository.dart';
import 'package:mawaqeety/data/seerah.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SeerahData d;
  late GhazawatData g;
  setUpAll(() async {
    d = await SeerahData.load();
    g = await GhazawatData.load();
  });

  test('JSON is well formed and the asset is registered', () {
    final raw = File('assets/data/seerah.json').readAsStringSync();
    expect(() => jsonDecode(raw), returnsNormally);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/data/seerah.json'));
  });

  test('timeline from the birth to the death, in four eras and in order', () {
    expect(d.events.length, inInclusiveRange(40, 60));
    expect(d.eras.map((e) => e.name).toList(), ['قبل البعثة', 'العهد المكي', 'الهجرة', 'العهد المدني']);
    expect(d.events.first.id, 'birth');
    expect(d.events.first.when, contains('عام الفيل'));
    expect(d.events.last.id, 'wafat');
    expect(d.events.last.when, contains('١٢ ربيع الأول سنة ١١'));
    expect(d.events.last.age, 63);
    final eraIds = d.eras.map((e) => e.id).toList();
    var lastEra = 0, lastHy = -100, lastCe = 0;
    for (final e in d.events) {
      final era = eraIds.indexOf(e.era);
      expect(era, greaterThanOrEqualTo(lastEra), reason: e.id);
      expect(e.hy, greaterThanOrEqualTo(lastHy), reason: e.id);
      expect(e.ce, greaterThanOrEqualTo(lastCe), reason: e.id);
      expect(e.ce, inInclusiveRange(571, 632), reason: e.id);
      expect(e.hy, inInclusiveRange(-53, 11), reason: e.id);
      lastEra = era;
      lastHy = e.hy;
      lastCe = e.ce;
      expect(e.title.trim(), isNotEmpty);
      final sentences = e.summary.split(RegExp(r'[.!؟]\s*')).where((s) => s.trim().isNotEmpty).length;
      expect(sentences, inInclusiveRange(1, 3), reason: e.id);
      // Before the Hijra the year is told relative to it.
      if (e.hy < 0) expect(e.hijriLabel, startsWith('قبل الهجرة'), reason: e.id);
    }
    for (final era in eraIds) {
      expect(d.ofEra(era), isNotEmpty, reason: era);
    }
    expect(d.events.map((e) => e.id).toSet().length, d.events.length);
  });

  test('every event is sourced from an allowed site over https', () {
    const hosts = {
      'www.islamweb.net', 'islamweb.net', 'islamqa.info', 'binbaz.org.sa', 'www.alukah.net', 'dorar.net',
      'www.dar-alifta.org', 'www.azhar.eg',
    };
    for (final e in [...d.events.expand((e) => e.refs), ...d.sources]) {
      final u = Uri.parse(e.url);
      expect(u.scheme, 'https', reason: e.url);
      expect(hosts, contains(u.host), reason: e.url);
      expect(e.title.trim(), isNotEmpty);
    }
    for (final e in d.events) {
      expect(e.refs, isNotEmpty, reason: e.id);
    }
  });

  test('battle links resolve to ghazawat.json and every battle is on the timeline', () {
    final linked = <String>{};
    for (final e in d.events) {
      if (e.ghazwa == null) continue;
      final b = g.byId(e.ghazwa!);
      expect(b, isNotNull, reason: e.ghazwa);
      expect(e.hy, b!.year, reason: e.id);
      linked.add(e.ghazwa!);
    }
    expect(linked, {for (final b in g.list) b.id});
  });

  test('places are plausible and ayat exist', () async {
    for (final e in d.events) {
      final p = e.place;
      if (p == null) continue;
      expect(p.lat, inInclusiveRange(12, 33), reason: e.id);
      expect(p.lng, inInclusiveRange(34, 42), reason: e.id);
      expect(p.name.trim(), isNotEmpty);
    }
    final repo = Repository();
    await repo.load();
    for (final e in d.events) {
      final a = e.ayah;
      if (a == null) continue;
      expect(a.from, lessThanOrEqualTo(a.to), reason: e.id);
      expect(a.to, lessThanOrEqualTo(repo.surahs[a.surah - 1].verses.length), reason: '${e.id} ${a.surah}:${a.to}');
    }
  });

  test('disputed dates are flagged', () {
    for (final id in ['birth', 'wahy', 'isra', 'quba', 'mustaliq', 'wafat']) {
      expect(d.byId(id)!.disputed, isNotNull, reason: id);
    }
  });

  test('year labels', () {
    expect(hijriYearLabel(-53), 'قبل الهجرة بـ ٥٣ سنة');
    expect(hijriYearLabel(-3), 'قبل الهجرة بـ ٣ سنوات');
    expect(hijriYearLabel(-1), 'قبل الهجرة بسنة');
    expect(hijriYearLabel(0), 'قبيل الهجرة');
    expect(hijriYearLabel(2), 'سنة ٢ هـ');
    expect(ageLabel(40), 'عمره ﷺ ٤٠ سنة');
  });

  test('battle coordinates are plausible', () {
    // Expected places (approx.) of the battles; Hunayn and Banu Qurayza are marked approximate.
    const expected = {
      'badr': (23.78, 38.79), 'uhud': (24.50, 39.61), 'khandaq': (24.47, 39.61), 'qurayza': (24.45, 39.62),
      'hudaybiya': (21.44, 39.62), 'khaybar': (25.70, 39.29), 'mutah': (31.09, 35.69), 'fath': (21.42, 39.83),
      'hunayn': (21.5, 40.1), 'tabuk': (28.38, 36.57),
    };
    for (final b in g.list) {
      final (lat, lng) = expected[b.id]!;
      expect((b.lat - lat).abs(), lessThan(0.1), reason: b.id);
      expect((b.lng - lng).abs(), lessThan(0.1), reason: b.id);
    }
    expect(g.byId('hunayn')!.approx, isTrue);
    expect(g.byId('qurayza')!.approx, isTrue);
    expect(g.byId('badr')!.approx, isFalse);
  });
}
