import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/repository.dart';
import 'package:mawaqeety/data/sabeel.dart';
import 'package:mawaqeety/data/sabeel_library.dart';

/// «سبيل» must know every section of the app: a content asset that no [LibrarySource] lists breaks this test.
/// To fix it, register the new section in lib/data/sabeel_library.dart (SabeelLibrary.sources) — or, only if it
/// is not content to quote (audio lists, app data), add it to SabeelLibrary.notContent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repository repo;
  late SabeelLibrary lib;
  setUpAll(() async {
    repo = Repository();
    await repo.load();
    lib = await SabeelLibrary.load(repo);
  });

  test('every content asset in pubspec.yaml is registered with «سبيل»', () {
    final assets = [
      for (final l in File('pubspec.yaml').readAsLinesSync())
        if (RegExp(r'^\s*-\s*(assets/data/\S+)\s*$').firstMatch(l) case final m?) m[1]!,
    ];
    expect(assets, isNotEmpty);
    final covered = SabeelLibrary.coveredAssets;
    final missing = [for (final a in assets) if (!covered.contains(a) && !SabeelLibrary.notContent.contains(a)) a];
    expect(missing, isEmpty,
        reason: 'Register these in SabeelLibrary.sources (lib/data/sabeel_library.dart) so «سبيل» can answer from them');
    // Every registered asset exists in pubspec (no stale registrations).
    expect([for (final a in covered) if (!assets.contains(a)) a], isEmpty);
  });

  test('every source yields entries with unique ids', () {
    final ids = <String>{};
    for (final e in lib.entries) {
      expect(ids.add(e.id), isTrue, reason: 'duplicate id ${e.id}');
      expect(e.title, isNotEmpty);
    }
    for (final s in SabeelLibrary.sources) {
      expect(lib.entries.where((e) => e.section == s.section), isNotEmpty, reason: 'no entries for ${s.id}');
    }
  });

  List<String> top(String q, [int n = SabeelLibrary.shown]) => lib.search(q).entries.take(n).map((e) => e.id).toList();

  test('sample queries find the expected entries', () {
    for (final q in [
      'غزوة بدر', 'متى كانت غزوة بدر؟', 'المسح على الخفين', 'ما حكم المسح على الجوارب؟', 'إسلام عمر', 'كيف أسلم أبو بكر؟',
      'نصاب الزكاة', 'كم نصاب الزكاة', 'حاسبة الزكاة', 'الهجرة إلى الحبشة', 'كيف أحفظ القرآن', 'صيام عرفة', 'دعاء السفر',
      'معنى اسم الله اللطيف', 'قصة يوسف', 'نسب النبي', 'إنما الأعمال بالنيات',
    ]) {
      // ignore: avoid_print
      print('$q => ${top(q)}');
    }
    expect(top('غزوة بدر').first, 'ghazawat:badr');
    expect(top('متى كانت غزوة بدر؟'), contains('ghazawat:badr'));
    expect(top('المسح على الخفين').where((id) => id.startsWith('fiqh:')), isNotEmpty);
    expect(top('ما حكم المسح على الجوارب؟').first, startsWith('fiqh:'));
    expect(top('إسلام عمر'), contains('companions_islam:umar'));
    expect(top('كيف أسلم أبو بكر؟'), contains('companions_islam:abubakr'));
    expect(top('نصاب الزكاة'), contains('feature:zakat'));
    expect(top('حاسبة الزكاة').first, 'feature:zakat');
    expect(top('الهجرة إلى الحبشة'), contains('seerah:habasha1'));
    expect(top('كيف أحفظ القرآن'), contains('feature:hifz'));
    expect(top('صيام عرفة'), contains('occasions:arafah'));
    expect(top('قصة يوسف'), contains('prophets:yusuf'));
    expect(top('إنما الأعمال بالنيات'), contains('arbaeen:1'));
    // حصن المسلم: chapters and single adhkar.
    expect(top('دعاء السفر'), contains('hisn:96'));
    expect(top('دعاء الاستخارة'), contains('hisn:26'));
    expect(top('دعاء دخول المسجد').where((id) => id.startsWith('hisn:13')), isNotEmpty);
    expect(lib.search('xyzxyz').entries, isEmpty);
  });

  test('«سبيل» puts the app content first for fiqh and seerah questions', () async {
    final s = await Sabeel.load(repo);
    final fiqh = s.ask('ما حكم المسح على الجوارب؟');
    expect(fiqh.ruling, isTrue);
    expect(fiqh.libraryFirst, isTrue);
    expect(fiqh.library.entries.first.source, isNotEmpty);
    expect(s.ask('غزوة بدر').libraryFirst, isTrue);
    // A named ayah keeps its own answer and adds only entries that name every word.
    final kursi = s.ask('تفسير آية الكرسي');
    expect(kursi.ayat.single.ayah, 255);
    expect(kursi.libraryFirst, isFalse);
  });
}
