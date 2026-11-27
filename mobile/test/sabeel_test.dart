import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/repository.dart';
import 'package:mawaqeety/data/sabeel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Sabeel s;
  setUpAll(() async {
    final repo = Repository();
    await repo.load();
    s = await Sabeel.load(repo);
  });

  void show(String q) {
    final a = s.ask(q);
    // ignore: avoid_print
    print('$q => ${a.title} | ayat ${a.ayat.map((x) => '${x.surah.number}:${x.ayah}').join(',')} | hadith ${a.hadith.length} | ruling ${a.ruling}');
  }

  test('named ayah', () {
    final a = s.ask('تفسير آية الكرسي');
    expect(a.ayat.single.surah.number, 2);
    expect(a.ayat.single.ayah, 255);
    expect(a.ayat.single.tafsir, contains('آية الكرسي'));
  });
  test('surah + number', () {
    final a = s.ask('سورة الكهف آية ١٠');
    expect((a.ayat.single.surah.number, a.ayat.single.ayah), (18, 10));
    expect(s.ask('2:255').ayat.single.ayah, 255);
    expect(s.ask('البقرة 285 - 286').ayat.length, 2);
  });
  test('keywords + hadith + ruling', () {
    for (final q in ['سورة الكهف آية ١٠', '2:255', 'البقرة 285 - 286', 'الصبر', 'بر الوالدين', 'حديث إنما الأعمال بالنيات', 'ما حكم الربا', 'سورة الملك', 'خواتيم البقرة', 'النور', 'الصدقة', 'xyz']) {
      show(q);
    }
    expect(s.ask('الصبر').ayat, isNotEmpty);
    expect(s.ask('حديث إنما الأعمال بالنيات').hadith, isNotEmpty);
    expect(s.ask('ما حكم الربا').ruling, isTrue);
  });
}
