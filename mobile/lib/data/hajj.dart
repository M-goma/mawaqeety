import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// دليل الحج والعمرة (assets/data/hajj.json): the steps of Umrah and Hajj (تمتع) in order, each with its
/// ruling, adhkar with their sources, common mistakes, a checklist and the fatwas it was condensed from.
class HajjRef {
  final String source, ref, url;
  const HajjRef(this.source, this.ref, this.url);
  factory HajjRef.fromJson(Map<String, dynamic> j) => HajjRef(j['source'], j['ref'], j['url']);
  static List<HajjRef> list(Object? l) => [for (final r in (l ?? const []) as List) HajjRef.fromJson(r)];
}

/// A dua/dhikr or a text: from the Qur'an ([surah]:[ayah]), from the bundled Sahihs ([collection] + [number],
/// [contains] picks the narration), or another collection named in [source] (with [via], the page that cites it).
class HajjDhikr {
  final String kind, text, note, source, collection, contains, via;
  final int number, surah, ayah;
  const HajjDhikr({
    required this.kind,
    required this.text,
    this.note = '',
    this.source = '',
    this.collection = '',
    this.contains = '',
    this.via = '',
    this.number = 0,
    this.surah = 0,
    this.ayah = 0,
  });
  bool get isQuran => kind == 'quran';
  bool get inSahihs => collection.isNotEmpty;

  factory HajjDhikr.fromJson(Map<String, dynamic> j) => HajjDhikr(
    kind: j['k'],
    text: j['t'],
    note: j['note'] ?? '',
    source: j['src'] ?? '',
    collection: j['c'] ?? '',
    contains: j['q'] ?? '',
    via: j['via'] ?? '',
    number: j['n'] ?? 0,
    surah: j['s'] ?? 0,
    ayah: j['a'] ?? 0,
  );
  static List<HajjDhikr> list(Object? l) => [for (final d in (l ?? const []) as List) HajjDhikr.fromJson(d)];
}

class HajjStep {
  final String id, dayLabel, title, place, ruling, rulingNote, others;
  final int order, day; // day: 0 = before the days of Hajj, else the day of Dhul-Hijjah
  final bool khilaf;
  final List<String> what, mistakes, checklist;
  final List<HajjDhikr> duas;
  final List<HajjRef> refs;
  const HajjStep({
    required this.id,
    required this.order,
    required this.day,
    required this.dayLabel,
    required this.title,
    required this.place,
    required this.ruling,
    required this.rulingNote,
    required this.khilaf,
    required this.what,
    required this.duas,
    required this.mistakes,
    required this.checklist,
    required this.others,
    required this.refs,
  });

  factory HajjStep.fromJson(Map<String, dynamic> j) => HajjStep(
    id: j['id'],
    order: j['order'],
    day: j['day'],
    dayLabel: j['dayLabel'],
    title: j['title'],
    place: j['place'] ?? '',
    ruling: j['ruling'],
    rulingNote: j['rulingNote'] ?? '',
    khilaf: j['khilaf'] == true,
    what: [for (final w in j['what'] as List) w as String],
    duas: HajjDhikr.list(j['duas']),
    mistakes: [for (final m in (j['mistakes'] ?? const []) as List) m as String],
    checklist: [for (final c in (j['checklist'] ?? const []) as List) c as String],
    others: j['others'] ?? '',
    refs: HajjRef.list(j['refs']),
  );

  /// Checklist keys are stable per step and item: «hajj-arafah:0».
  String checkKey(int i) => '$id:$i';
}

class HajjGuide {
  final String id, name, icon, intro;
  final List<HajjStep> steps;
  final List<HajjRef> refs;
  const HajjGuide(this.id, this.name, this.icon, this.intro, this.steps, this.refs);
  factory HajjGuide.fromJson(Map<String, dynamic> j) => HajjGuide(
    j['id'],
    j['name'],
    j['icon'] ?? '',
    j['intro'],
    [for (final s in j['steps'] as List) HajjStep.fromJson(s)]..sort((a, b) => a.order.compareTo(b.order)),
    HajjRef.list(j['refs']),
  );

  Iterable<String> get checkKeys => [
    for (final s in steps)
      for (var i = 0; i < s.checklist.length; i++) s.checkKey(i),
  ];
}

class HajjType {
  final String id, name, talbiya, text;
  final bool hady;
  const HajjType(this.id, this.name, this.talbiya, this.text, this.hady);
}

class HajjMiqat {
  final String id, name, modern, forWhom, note;
  final int km;
  final double lat, lng;
  final bool approx;
  const HajjMiqat(this.id, this.name, this.modern, this.forWhom, this.km, this.lat, this.lng, this.note, this.approx);
}

class HajjPlace {
  final String id, name, desc;
  final double lat, lng;
  final bool optional;
  const HajjPlace(this.id, this.name, this.lat, this.lng, this.desc, this.optional);
}

class HajjGroup {
  final String name;
  final List<String> items;
  const HajjGroup(this.name, this.items);
}

class HajjData {
  final String title, collected, note, typesIntro, mahzuratIntro, mawaqitIntro, packingNote;
  final List<HajjRef> sources, typesRefs, mahzuratRefs, mawaqitRefs, packingRefs;
  final HajjRef rulingsRef;
  final Map<String, String> rulings;
  final bool typesKhilaf;
  final List<HajjType> types;
  final List<HajjDhikr> typesDuas, mahzuratDuas, mawaqitDuas;
  final List<HajjGuide> guides;
  final List<HajjGroup> mahzurat;
  final List<HajjMiqat> mawaqit;
  final List<HajjPlace> places;
  final List<String> packing;

  HajjData.fromJson(Map<String, dynamic> j)
    : title = j['title'],
      collected = j['collected'],
      note = j['note'],
      sources = [for (final s in j['sources'] as List) HajjRef(s['name'], s['name'], s['url'])],
      rulings = (j['rulings'] as Map).cast<String, String>(),
      rulingsRef = HajjRef.fromJson(j['rulingsRef']),
      typesIntro = j['types']['intro'],
      typesKhilaf = j['types']['khilaf'] == true,
      types = [for (final t in j['types']['items'] as List) HajjType(t['id'], t['name'], t['talbiya'], t['text'], t['hady'] == true)],
      typesDuas = HajjDhikr.list(j['types']['duas']),
      typesRefs = HajjRef.list(j['types']['refs']),
      guides = [for (final g in j['guides'] as List) HajjGuide.fromJson(g)],
      mahzuratIntro = j['mahzurat']['intro'],
      mahzurat = [for (final g in j['mahzurat']['groups'] as List) HajjGroup(g['name'], (g['items'] as List).cast<String>())],
      mahzuratDuas = HajjDhikr.list(j['mahzurat']['duas']),
      mahzuratRefs = HajjRef.list(j['mahzurat']['refs']),
      mawaqitIntro = j['mawaqit']['intro'],
      mawaqit = [
        for (final m in j['mawaqit']['items'] as List)
          HajjMiqat(
            m['id'],
            m['name'],
            m['modern'],
            m['for'],
            m['km'],
            (m['lat'] as num).toDouble(),
            (m['lng'] as num).toDouble(),
            m['note'] ?? '',
            m['approx'] == true,
          ),
      ],
      mawaqitDuas = HajjDhikr.list(j['mawaqit']['duas']),
      mawaqitRefs = HajjRef.list(j['mawaqit']['refs']),
      places = [
        for (final p in j['places'] as List)
          HajjPlace(p['id'], p['name'], (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble(), p['desc'], p['optional'] == true),
      ],
      packingNote = j['packing']['note'],
      packing = [for (final p in j['packing']['items'] as List) p['t'] as String],
      packingRefs = HajjRef.list(j['packing']['refs']);

  HajjGuide guide(String id) => guides.firstWhere((g) => g.id == id);
  HajjPlace? place(String id) => places.where((p) => p.id == id).firstOrNull;

  /// Every reference in the data (steps, sections and the general sources).
  Iterable<HajjRef> get allRefs sync* {
    yield* sources;
    yield rulingsRef;
    yield* typesRefs;
    yield* mahzuratRefs;
    yield* mawaqitRefs;
    yield* packingRefs;
    for (final g in guides) {
      yield* g.refs;
      for (final s in g.steps) {
        yield* s.refs;
      }
    }
  }

  /// Every dua/dhikr/text with a source.
  Iterable<HajjDhikr> get allDhikr sync* {
    yield* typesDuas;
    yield* mahzuratDuas;
    yield* mawaqitDuas;
    for (final g in guides) {
      for (final s in g.steps) {
        yield* s.duas;
      }
    }
  }

  static HajjData? _cache;
  static Future<HajjData> load() async =>
      _cache ??= HajjData.fromJson(jsonDecode(await rootBundle.loadString('assets/data/hajj.json')) as Map<String, dynamic>);
}

/// Ticked checklist items (steps and packing list), kept on the device (SharedPreferences key `hajj.checks`).
class HajjChecks {
  static const key = 'hajj.checks';

  static Future<Set<String>> load() async {
    final p = await SharedPreferences.getInstance();
    return {...?p.getStringList(key)};
  }

  static Future<void> save(Set<String> s) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, s.toList()..sort());
  }

  static String packKey(int i) => 'pack:$i';
}
