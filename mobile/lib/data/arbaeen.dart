import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'hadith.dart';

/// Where a hadith of the Forty is found in the bundled Sahih data: collection id, the common hadith number
/// and the row in the data file (checked at build time; [resolve] falls back to the number).
class SahihRef {
  final String collection;
  final int number, index;
  const SahihRef(this.collection, this.number, this.index);

  factory SahihRef.fromJson(Map<String, dynamic> j) => SahihRef(j['c'] as String, j['n'] as int, j['i'] as int);

  String get name => collection == 'bukhari' ? 'صحيح البخاري' : 'صحيح مسلم';

  Future<Hadith?> resolve() async {
    final c = await HadithCollection.load(collection);
    if (index >= 0 && index < c.all.length && c.all[index].number == number) return c.all[index];
    for (final h in c.all) {
      if (h.number == number) return h;
    }
    return null;
  }
}

/// A second narration an-Nawawi gives after the hadith (e.g. «وفي رواية لمسلم»).
class ArbaeenExtra {
  final String label, text, takhrij;
  const ArbaeenExtra(this.label, this.text, this.takhrij);
}

class ArbaeenHadith {
  final int number;
  final String title, narrator, text, takhrij;
  /// an-Nawawi's grading for hadiths outside the two Sahihs (e.g. «حسن صحيح»), else null.
  final String? grade;
  final ArbaeenExtra? extra;
  /// an-Nawawi's own remark after the hadith.
  final String? note;
  /// Ibn Rajab's remark where he differs on the chain (verbatim from Jami' al-Ulum).
  final String? isnadNote;
  final List<SahihRef> sahih;
  /// Narrations in the Sahihs that hold part of the hadith («وبعضه في الصحيحين»).
  final List<SahihRef> related;
  final List<String> benefits;
  final String? benefitsUrl;

  const ArbaeenHadith({
    required this.number,
    required this.title,
    required this.narrator,
    required this.text,
    required this.takhrij,
    this.grade,
    this.extra,
    this.note,
    this.isnadNote,
    this.sahih = const [],
    this.related = const [],
    this.benefits = const [],
    this.benefitsUrl,
  });

  factory ArbaeenHadith.fromJson(Map<String, dynamic> j) {
    final e = j['extra'] as Map<String, dynamic>?;
    List<SahihRef> refs(Object? l) => [for (final r in (l as List?) ?? const []) SahihRef.fromJson(r as Map<String, dynamic>)];
    return ArbaeenHadith(
      number: j['n'] as int,
      title: j['title'] as String,
      narrator: j['narrator'] as String,
      text: j['text'] as String,
      takhrij: j['takhrij'] as String,
      grade: j['grade'] as String?,
      extra: e == null ? null : ArbaeenExtra(e['label'] as String, e['text'] as String, (e['takhrij'] as String?) ?? ''),
      note: j['note'] as String?,
      isnadNote: j['isnadNote'] as String?,
      sahih: refs(j['sahih']),
      related: refs(j['related']),
      benefits: [for (final b in (j['benefits'] as List?) ?? const []) b as String],
      benefitsUrl: j['benefitsUrl'] as String?,
    );
  }

  /// Plain text for copying: the hadith, the extra narration and the takhrij.
  String get copyText {
    final b = StringBuffer(text);
    if (extra != null) b.write('\n\n${extra!.label}: ${extra!.text}');
    b.write('\n\n[$takhrij]');
    return b.toString();
  }
}

/// الأربعون النووية (assets/data/arbaeen.json).
class Arbaeen {
  final String title, author, aboutSource;
  /// Two sentences from an-Nawawi's introduction.
  final List<String> about;
  final Map<String, String> sources;
  final List<ArbaeenHadith> hadiths;
  const Arbaeen(this.title, this.author, this.about, this.aboutSource, this.sources, this.hadiths);

  factory Arbaeen.fromJson(Map<String, dynamic> j) => Arbaeen(
        j['title'] as String,
        j['author'] as String,
        [for (final a in j['about'] as List) a as String],
        j['aboutSource'] as String,
        (j['sources'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
        [for (final h in j['hadiths'] as List) ArbaeenHadith.fromJson(h as Map<String, dynamic>)],
      );

  static Arbaeen? _cache;
  static Future<Arbaeen> load() async =>
      _cache ??= Arbaeen.fromJson(jsonDecode(await rootBundle.loadString('assets/data/arbaeen.json')) as Map<String, dynamic>);
}

/// The hadiths the user has marked as memorised, kept on the device (SharedPreferences key `arbaeen.memorized`).
class ArbaeenMemory {
  static const key = 'arbaeen.memorized';

  static Future<Set<int>> load() async {
    final p = await SharedPreferences.getInstance();
    return decode(p.getStringList(key));
  }

  static Future<void> save(Set<int> s) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, encode(s));
  }

  static Set<int> decode(List<String>? l) => {
        for (final x in l ?? const <String>[])
          if (int.tryParse(x) case final n? when n >= 1 && n <= 42) n,
      };

  static List<String> encode(Set<int> s) => [for (final n in (s.toList()..sort())) '$n'];
}
