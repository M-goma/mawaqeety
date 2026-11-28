import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';

/// السيرة النبوية على خط زمني (assets/data/seerah.json): events from the birth to the death of the Prophet ﷺ,
/// grouped into eras, each with its sources.
class SeerahRef {
  final String title, url;
  const SeerahRef(this.title, this.url);
}

class SeerahPlace {
  final String name;
  final double lat, lng;
  final bool approx;
  const SeerahPlace(this.name, this.lat, this.lng, this.approx);
}

/// A Qur'an passage: surah [surah], ayat [from]..[to].
class SeerahAyah {
  final int surah, from, to;
  const SeerahAyah(this.surah, this.from, this.to);
}

class SeerahEra {
  final String id, name, range, desc;
  const SeerahEra(this.id, this.name, this.range, this.desc);
}

class SeerahEvent {
  final String id, era, when, title, summary;
  /// Hijri year: 1..11 after the Hijra, 0 = the months just before it, -N = N years before it.
  final int hy;
  final int ce;
  final bool ceApprox;
  /// The Prophet's ﷺ age (lunar years) when known.
  final int? age;
  final String? disputed;
  final SeerahPlace? place;
  /// Id of the battle in ghazawat.json.
  final String? ghazwa;
  final SeerahAyah? ayah;
  final List<SeerahRef> refs;
  const SeerahEvent({
    required this.id, required this.era, required this.when, required this.hy, required this.ce,
    required this.ceApprox, required this.title, required this.summary, required this.refs,
    this.age, this.disputed, this.place, this.ghazwa, this.ayah,
  });

  factory SeerahEvent.fromJson(Map<String, dynamic> j) {
    final p = j['place'] as Map<String, dynamic>?;
    final a = j['ayah'] as Map<String, dynamic>?;
    return SeerahEvent(
      id: j['id'], era: j['era'], when: j['when'], hy: j['hy'], ce: j['ce'], ceApprox: j['ceApprox'] ?? false,
      title: j['title'], summary: j['summary'], age: j['age'], disputed: j['disputed'], ghazwa: j['ghazwa'],
      place: p == null
          ? null
          : SeerahPlace(p['name'], (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble(), p['approx'] ?? false),
      ayah: a == null ? null : SeerahAyah(a['s'], a['a'], a['b'] ?? a['a']),
      refs: [for (final r in j['refs'] as List) SeerahRef(r['t'], r['u'])],
    );
  }

  /// «قبل الهجرة بـ ٣ سنوات» / «قبيل الهجرة» / «سنة ٢ هـ».
  String get hijriLabel => hijriYearLabel(hy);

  /// «نحو ٥٧١م» or «٦٢٤م».
  String get ceLabel => '${ceApprox ? 'نحو ' : ''}${Arabic.digits(ce)}م';

  /// Short label for the timeline badge: «٥٣ ق.هـ», «١ هـ».
  String get badge => hy > 0 ? '${Arabic.digits(hy)} هـ' : hy == 0 ? 'قبيل الهجرة' : '${Arabic.digits(-hy)} ق.هـ';
}

String hijriYearLabel(int hy) {
  if (hy > 0) return 'سنة ${Arabic.digits(hy)} هـ';
  if (hy == 0) return 'قبيل الهجرة';
  final n = -hy;
  if (n == 1) return 'قبل الهجرة بسنة';
  if (n == 2) return 'قبل الهجرة بسنتين';
  if (n <= 10) return 'قبل الهجرة بـ ${Arabic.digits(n)} سنوات';
  return 'قبل الهجرة بـ ${Arabic.digits(n)} سنة';
}

/// «عمره ﷺ ٤٠ سنة».
String ageLabel(int age) => age == 0 ? 'يوم مولده ﷺ' : 'عمره ﷺ ${Arabic.digits(age)} ${age <= 10 ? 'سنين' : 'سنة'}';

class SeerahData {
  final String intro, note;
  final List<SeerahEra> eras;
  final List<SeerahRef> sources;
  final List<SeerahEvent> events;
  const SeerahData(this.intro, this.note, this.eras, this.sources, this.events);

  static SeerahData parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return SeerahData(
      j['intro'] ?? '',
      j['note'] ?? '',
      [for (final e in j['eras'] as List) SeerahEra(e['id'], e['name'], e['range'] ?? '', e['desc'] ?? '')],
      [for (final r in (j['sources'] ?? []) as List) SeerahRef(r['t'], r['u'])],
      [for (final e in j['events'] as List) SeerahEvent.fromJson(e)],
    );
  }

  static SeerahData? _cache;
  static Future<SeerahData> load() async => _cache ??= parse(await rootBundle.loadString('assets/data/seerah.json'));

  List<SeerahEvent> ofEra(String era) => [for (final e in events) if (e.era == era) e];

  /// Events with a place on the map (battles take their place from ghazawat.json).
  List<SeerahEvent> get placed => [for (final e in events) if (e.place != null) e];

  SeerahEvent? byId(String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }
}
