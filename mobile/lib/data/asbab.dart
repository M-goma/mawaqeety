import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';
import 'hadith.dart';

/// A sahih occasion of revelation (سبب نزول): a narration in Sahih al-Bukhari or Sahih Muslim that
/// says verses [from]–[to] of [surah] came down for an event and quotes them
/// (assets/data/asbab.json, built by tools/build_asbab.py).
class Sabab {
  final int surah, from, to;

  /// 'bukhari' | 'muslim' — a [HadithCollection] id.
  final String collection;

  /// The common hadith number, and the position in the collection's data file ([Hadith.index]).
  final int number, index;

  /// The part of the narration that tells the occasion and quotes the verse.
  final String excerpt;

  const Sabab(this.surah, this.from, this.to, this.collection, this.number, this.index, this.excerpt);

  bool covers(int ayah) => ayah >= from && ayah <= to;

  String get collectionName => collection == 'bukhari' ? 'صحيح البخاري' : 'صحيح مسلم';

  /// «صحيح البخاري ٤٩٧١».
  String get ref => '$collectionName ${Arabic.digits(number)}';

  /// «الآية ٥» or «الآيات ١–٣».
  String get ayahLabel => from == to ? 'الآية ${Arabic.digits(from)}' : 'الآيات ${Arabic.digits(from)}–${Arabic.digits(to)}';

  /// The full hadith in the bundled collection.
  Future<Hadith?> hadith() async {
    final c = await HadithCollection.load(collection);
    if (index >= 0 && index < c.all.length && c.all[index].number == number) return c.all[index];
    for (final h in c.all) {
      if (h.number == number) return h;
    }
    return null;
  }
}

class Asbab {
  final List<Sabab> all;
  Asbab(this.all);

  static Asbab parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return Asbab([
      for (final r in j['a'] as List)
        Sabab(r['s'] as int, r['f'] as int, r['t'] as int, r['c'] as String, r['n'] as int, r['i'] as int, r['x'] as String),
    ]);
  }

  static Asbab? _cache;
  static Future<Asbab> load() async => _cache ??= parse(await rootBundle.loadString('assets/data/asbab.json'));

  late final Map<int, List<Sabab>> _bySurah = () {
    final m = <int, List<Sabab>>{};
    for (final s in all) {
      (m[s.surah] ??= []).add(s);
    }
    return m;
  }();

  /// Entries for a surah, in ayah order.
  List<Sabab> inSurah(int surah) => _bySurah[surah] ?? const [];

  /// Surahs that have at least one sahih occasion.
  Set<int> get surahs => _bySurah.keys.toSet();

  /// Entries whose range covers [ayah] of [surah].
  List<Sabab> forAyah(int surah, int ayah) => inSurah(surah).where((s) => s.covers(ayah)).toList();
}

/// The sahih occasions of revelation that cover [ayah] of [surah] (for «اسأل سبيل» and the reader).
Future<List<Sabab>> asbabFor(int surah, int ayah) async => (await Asbab.load()).forAyah(surah, ayah);
