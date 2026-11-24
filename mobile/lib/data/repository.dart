import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../core/settings.dart';

class Surah {
  final int number;
  final String name, nameEn;
  final bool meccan;
  final List<String> verses;
  Surah(this.number, this.name, this.nameEn, this.meccan, this.verses);
}

class SearchHit {
  final Surah surah;
  final int ayah;
  SearchHit(this.surah, this.ayah);
  String get text => surah.verses[ayah - 1];
}

class AyahRef {
  final int surah, from, to;
  final String note;
  AyahRef(this.surah, this.from, this.to, this.note);
}

class StorySection {
  final String heading, body;
  StorySection(this.heading, this.body);
}

class Prophet {
  final String id, nameAr, nameEn, title, summary;
  final int order;
  final List<StorySection> sections;
  final List<AyahRef> ayat;
  final List<String> lessons;
  final List<int> surahs;
  Prophet(this.id, this.order, this.nameAr, this.nameEn, this.title, this.summary, this.sections, this.ayat, this.lessons, this.surahs);
}

class AdhanVoice {
  final String id, nameAr, file;
  final bool fajr;
  AdhanVoice(this.id, this.nameAr, this.file, this.fajr);
  String get url => 'https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/${Uri.encodeComponent(file)}';
}

/// Loads bundled data once (Quran, prophets, cities, adhan voices).
class Repository {
  late final List<Surah> surahs;
  late final List<Prophet> prophets;
  late final List<Place> cities;
  late final List<AdhanVoice> voices;
  late final List<List<String>> _normalized;

  Future<void> load() async {
    final q = jsonDecode(await rootBundle.loadString('assets/data/quran.json')) as List;
    surahs = q.map((s) => Surah(s['n'], s['name'], s['en'], s['type'] == 'm', (s['v'] as List).cast<String>())).toList();
    _normalized = surahs.map((s) => s.verses.map(Arabic.searchKey).toList()).toList();

    final p = jsonDecode(await rootBundle.loadString('assets/data/prophets.json')) as List;
    prophets = p
        .map((e) => Prophet(
              e['id'], e['order'], e['nameAr'], e['nameEn'] ?? '', e['title'] ?? '', e['summary'] ?? '',
              ((e['sections'] ?? []) as List).map((s) => StorySection(s['heading'] ?? '', s['body'] ?? '')).toList(),
              ((e['ayat'] ?? []) as List).map((a) => AyahRef(a['surah'], a['from'], a['to'], a['note'] ?? '')).toList(),
              ((e['lessons'] ?? []) as List).cast<String>(),
              ((e['mentionedInSurahs'] ?? []) as List).cast<int>(),
            ))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final c = jsonDecode(await rootBundle.loadString('assets/data/cities.json')) as Map<String, dynamic>;
    final countries = c['Countries'] as Map<String, dynamic>;
    cities = (c['Cities'] as List)
        .map((r) => Place(
              nameAr: r['Ar'], nameEn: r['En'], countryCode: r['Cc'],
              countryAr: countries[r['Cc']]?['Ar'] ?? '', lat: (r['Lat'] as num).toDouble(),
              lng: (r['Lng'] as num).toDouble(), tz: r['Tz']))
        .toList();

    final v = jsonDecode(await rootBundle.loadString('assets/data/adhan_voices.json')) as List;
    voices = v.map((e) => AdhanVoice(e['id'], e['ar'], e['file'], e['fajr'] == true)).toList();
  }

  AdhanVoice? voice(String id) {
    for (final v in voices) {
      if (v.id == id) return v;
    }
    return null;
  }

  List<SearchHit> searchQuran(String query, {int limit = 200}) {
    final q = Arabic.searchKey(query);
    if (q.length < 2) return [];
    final hits = <SearchHit>[];
    for (var s = 0; s < surahs.length && hits.length < limit; s++) {
      final list = _normalized[s];
      for (var a = 0; a < list.length && hits.length < limit; a++) {
        if (list[a].contains(q)) hits.add(SearchHit(surahs[s], a + 1));
      }
    }
    return hits;
  }

  List<Place> searchCities(String query) {
    final q = Arabic.normalize(query);
    if (q.isEmpty) return cities.where((c) => c.countryCode == 'EG').toList();
    return cities
        .where((c) =>
            Arabic.normalize(c.nameAr).contains(q) ||
            c.nameEn.toLowerCase().contains(q) ||
            Arabic.normalize(c.countryAr).contains(q))
        .toList();
  }

  Place nearestCity(double lat, double lng) {
    Place best = cities.first;
    var bestD = double.infinity;
    for (final c in cities) {
      final d = (c.lat - lat) * (c.lat - lat) + (c.lng - lng) * (c.lng - lng);
      if (d < bestD) { bestD = d; best = c; }
    }
    return best;
  }
}
