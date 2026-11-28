import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/arabic.dart';
import 'package:mawaqeety/core/settings.dart';
import 'package:mawaqeety/data/repository.dart';
import 'package:mawaqeety/data/sabeel_library.dart';
import 'package:mawaqeety/data/tafsir.dart';

/// The bundled tafsirs (التفسير الميسر، السعدي، المختصر) and «معاني الكلمات» (الميسر في غريب القرآن الكريم):
/// complete, aligned with quran.json, attributed, and the reader's choice of tafsir is remembered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repository repo;
  setUpAll(() async {
    repo = Repository();
    await repo.load();
  });

  /// Ayat a source lists without any commentary: islamweb's تفسير السعدي gives none for 6:105–107 (page 425).
  const unexplained = {'saadi': {(6, 105), (6, 106), (6, 107)}};

  test('every tafsir covers all 6236 ayat once, surah by surah, with text', () async {
    for (final b in Tafsir.books) {
      final t = await Tafsir.load(b.id);
      final none = unexplained[b.id] ?? const {};
      expect(t.book.id, b.id);
      expect(t.name, isNotEmpty);
      expect(t.source, isNotEmpty);
      expect(t.sections.length, 114, reason: b.id);
      var ayat = 0;
      for (final s in repo.surahs) {
        var next = 1;
        for (final sec in t.sections[s.number - 1]) {
          while (next < sec.from && none.contains((s.number, next))) {
            next++;
          }
          expect(sec.from, next, reason: '${b.id} ${s.number}:${sec.from}');
          expect(sec.to, greaterThanOrEqualTo(sec.from));
          expect(sec.text.trim(), isNotEmpty, reason: '${b.id} ${s.number}:${sec.from}');
          next = sec.to + 1;
        }
        expect(next - 1, s.verses.length, reason: '${b.id} surah ${s.number}');
        for (var a = 1; a <= s.verses.length; a++) {
          final sec = t.sectionOf(s.number, a);
          if (none.contains((s.number, a))) {
            expect(sec, isNull);
            expect(t.of(s.number, a), isEmpty);
          } else {
            expect(a, inInclusiveRange(sec!.from, sec.to), reason: '${b.id} ${s.number}:$a');
            ayat++;
          }
        }
      }
      expect(ayat + none.length, 6236);
      // Each tafsir is loaded once and shared.
      expect(identical(await Tafsir.load(b.id), t), isTrue);
    }
  });

  test('spot checks: the right book at the right ayah', () async {
    // تفسير السعدي is islamweb's edition (book 209), word for word; every section links to its page.
    final saadi = await Tafsir.load('saadi');
    expect(saadi.name, 'تفسير السعدي');
    expect(saadi.via, contains('islamweb'));
    // The book explains 2:8–9 together, on islamweb's page 4.
    final s8 = saadi.sectionOf(2, 9)!;
    expect((s8.from, s8.to), (8, 9));
    expect(s8.url, 'https://www.islamweb.net/ar/library/content/209/4');
    expect(s8.text, startsWith('واعلم أن النفاق هو: إظهار الخير وإبطان الشر، ويدخل في هذا التعريف النفاق الاعتقادي، والنفاق العملي، كالذي ذكر'));
    expect(saadi.of(2, 106), startsWith('النسخ: هو النقل، فحقيقة النسخ نقل المكلفين من حكم مشروع، إلى حكم آخر، أو إلى إسقاطه،'));
    expect(saadi.sectionOf(2, 106)!.url, 'https://www.islamweb.net/ar/library/content/209/46');
    for (final secs in saadi.sections) {
      for (final sec in secs) {
        expect(sec.url, matches(RegExp(r'^https://www\.islamweb\.net/ar/library/content/209/\d+$')));
        // No leftover page markup (links, tooltips, entities).
        expect(sec.text, isNot(matches(RegExp(r'nindex|WIDTH|[<>]|&[a-z]+;|[A-Za-z]{3,}'))));
      }
    }
    final mukhtasar = await Tafsir.load('mukhtasar');
    expect(mukhtasar.of(1, 1), startsWith('باسم الله أبدأ قراءة القرآن'));
    expect((mukhtasar.sectionOf(2, 4)!.from, mukhtasar.sectionOf(2, 4)!.to), (3, 4));
    expect((await Tafsir.load()).book.id, 'muyassar');
    expect(Tafsir.byId('unknown').id, 'muyassar');
  });

  test('word meanings are aligned with the ayat and placed on their words', () async {
    final w = await WordMeanings.load();
    expect(w.name, 'الميسر في غريب القرآن الكريم');
    expect(w.source, contains('مجمع الملك فهد'));
    expect(w.w.length, 114);
    var entries = 0, placed = 0;
    for (final s in repo.surahs) {
      expect(w.w[s.number - 1].length, s.verses.length, reason: 'surah ${s.number}');
      for (var a = 1; a <= s.verses.length; a++) {
        final words = s.verses[a - 1].split(' ').length;
        for (final m in w.of(s.number, a)) {
          entries++;
          expect(m.phrase, isNotEmpty);
          expect(m.meaning, isNotEmpty);
          if (m.word >= 0) {
            placed++;
            expect(m.word + m.count, lessThanOrEqualTo(words), reason: '${s.number}:$a ${m.phrase}');
          }
        }
      }
    }
    expect(entries, greaterThan(10500));
    expect(placed / entries, greaterThan(0.99));
    final f = w.of(1, 2);
    expect(Arabic.normalize(f.first.meaning), contains(Arabic.normalize('الثناء على الله بصفاته')));
    expect((f.first.word, f.first.count), (0, 1)); // «ٱلۡحَمۡدُ»: the ayah's first word
    expect(f.first.covers(0), isTrue);
    expect(f.first.covers(1), isFalse);
    // Only meanings both copies agree on: the two differ on «كفروا» in 2:6, so it is left out.
    expect(w.of(2, 6).map((m) => Arabic.normalize(m.phrase)), isNot(contains(Arabic.normalize('كَفَرُواْ'))));
    expect(w.of(2, 6), isNotEmpty);
  });

  test('every tafsir asset is attributed and known to «سبيل»', () {
    final assets = {for (final b in Tafsir.books) b.asset, WordMeanings.asset};
    expect(SabeelLibrary.tafsirAssets, assets);
    expect(SabeelLibrary.notContent.containsAll(assets), isTrue);
    final sources = File('assets/data/TAFSIR_SOURCES.txt').readAsStringSync();
    for (final a in assets) {
      expect(sources, contains(a.split('/').last), reason: 'attribution of $a');
    }
    for (final name in ['مجمع الملك فهد', 'السعدي', 'مركز تفسير', 'qul.tarteel.ai', 'spa5k/tafsir_api']) {
      expect(sources, contains(name));
    }
  });

  test('the chosen tafsir is saved with the settings', () {
    expect(Settings().tafsirId, 'muyassar');
    final s = Settings()..tafsirId = 'saadi';
    final back = Settings.fromJsonString(s.toJsonString());
    expect(back.tafsirId, 'saadi');
    expect(Tafsir.byId(back.tafsirId).label, 'السعدي');
    // Older settings without the key keep the default.
    expect(Settings.fromJsonString('{"placeChosen":true}').tafsirId, 'muyassar');
  });
}
