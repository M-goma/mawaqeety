import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'hadith.dart';

/// غزوات النبي ﷺ (assets/data/ghazawat.json): story sections, Qur'an passages, hadith numbers in the bundled Sahihs, lessons and references.
class GhazwaSection {
  final String heading, text;
  const GhazwaSection(this.heading, this.text);
}

/// A Qur'an passage: surah [surah], ayat [from]..[to].
class GhazwaAyat {
  final int surah, from, to;
  final String note;
  const GhazwaAyat(this.surah, this.from, this.to, this.note);
  int get count => to - from + 1;
}

/// A hadith in the bundled Sahihs: collection id + the number as in the data; [contains] picks one of
/// several entries that share that number (Muslim's sub-narrations).
class GhazwaHadith {
  final String collection, title, contains;
  final int number;
  const GhazwaHadith(this.collection, this.number, this.title, this.contains);
  String get collectionName => collection == 'bukhari' ? 'صحيح البخاري' : 'صحيح مسلم';
}

class GhazwaRef {
  final String title, url;
  const GhazwaRef(this.title, this.url);
}

class Ghazwa {
  final String id, name, kind, date, place, muslims, enemy, result, summary;
  final int year;
  final double lat, lng;
  /// The place is known only approximately (e.g. the valley of Hunayn).
  final bool approx;
  final List<GhazwaSection> sections;
  final List<GhazwaAyat> ayat;
  final List<GhazwaHadith> hadith;
  final List<String> lessons;
  final List<GhazwaRef> refs;
  const Ghazwa({
    required this.id, required this.name, required this.kind, required this.year, required this.date,
    required this.place, required this.lat, required this.lng, required this.muslims, required this.enemy,
    required this.result, required this.summary, required this.sections, required this.ayat,
    required this.hadith, required this.lessons, required this.refs, this.approx = false,
  });

  /// صلح الحديبية is listed with the battles but is not one.
  bool get isBattle => kind == 'ghazwa';

  factory Ghazwa.fromJson(Map<String, dynamic> j) => Ghazwa(
        id: j['id'], name: j['name'], kind: j['kind'] ?? 'ghazwa', year: j['year'], date: j['date'],
        place: j['place'], lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble(), approx: j['approx'] ?? false,
        muslims: j['muslims'] ?? '', enemy: j['enemy'] ?? '', result: j['result'] ?? '', summary: j['summary'] ?? '',
        sections: [for (final s in j['sections'] as List) GhazwaSection(s['h'], s['p'])],
        ayat: [
          for (final a in j['ayat'] as List) GhazwaAyat(a['s'], a['a'], a['b'] ?? a['a'], a['note'] ?? ''),
        ],
        hadith: [for (final h in j['hadith'] as List) GhazwaHadith(h['c'], h['n'], h['t'] ?? '', h['q'] ?? '')],
        lessons: [for (final l in j['lessons'] as List) l as String],
        refs: [for (final r in (j['refs'] ?? []) as List) GhazwaRef(r['t'], r['u'])],
      );
}

class GhazawatData {
  final String intro, note;
  final List<GhazwaRef> sources;
  final List<Ghazwa> list;
  const GhazawatData(this.intro, this.note, this.sources, this.list);

  static GhazawatData parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final list = [for (final g in j['items'] as List) Ghazwa.fromJson(g)]..sort((a, b) => a.year.compareTo(b.year));
    return GhazawatData(j['intro'] ?? '', j['note'] ?? '',
        [for (final r in (j['sources'] ?? []) as List) GhazwaRef(r['t'], r['u'])], list);
  }

  static GhazawatData? _cache;
  static Future<GhazawatData> load() async =>
      _cache ??= parse(await rootBundle.loadString('assets/data/ghazawat.json'));

  Ghazwa? byId(String id) {
    for (final g in list) {
      if (g.id == id) return g;
    }
    return null;
  }
}

/// Finds the cited hadith in the bundled collection (null if the number is not in the data).
Future<Hadith?> findGhazwaHadith(GhazwaHadith r) async => pickHadith(await HadithCollection.load(r.collection), r);

Hadith? pickHadith(HadithCollection col, GhazwaHadith r) {
  final same = col.all.where((h) => h.number == r.number).toList();
  if (same.isEmpty) return null;
  if (r.contains.isNotEmpty) {
    final q = HadithCollection.plain(r.contains);
    for (final h in same) {
      if (HadithCollection.plain(h.text).contains(q)) return h;
    }
  }
  return same.first;
}
