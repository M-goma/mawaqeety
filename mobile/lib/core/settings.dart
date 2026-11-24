import 'dart:convert';

import 'methods.dart';
import 'prayer_calculator.dart';

class Place {
  final String nameAr, nameEn, countryAr, countryCode, tz;
  final double lat, lng;
  const Place({required this.nameAr, required this.nameEn, required this.countryAr, required this.countryCode,
      required this.lat, required this.lng, required this.tz});

  static const cairo = Place(nameAr: 'القاهرة', nameEn: 'Cairo', countryAr: 'مصر', countryCode: 'EG',
      lat: 30.0444, lng: 31.2357, tz: 'Africa/Cairo');

  String get display => countryAr.isEmpty ? nameAr : '$nameAr، $countryAr';

  Map<String, dynamic> toJson() =>
      {'nameAr': nameAr, 'nameEn': nameEn, 'countryAr': countryAr, 'cc': countryCode, 'lat': lat, 'lng': lng, 'tz': tz};

  factory Place.fromJson(Map<String, dynamic> j) => Place(
      nameAr: j['nameAr'] ?? '', nameEn: j['nameEn'] ?? '', countryAr: j['countryAr'] ?? '', countryCode: j['cc'] ?? '',
      lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble(), tz: j['tz'] ?? '');
}

enum ThemeChoice { dark, light, system }

class Bookmark {
  final int surah, ayah;
  const Bookmark(this.surah, this.ayah);
  Map<String, dynamic> toJson() => {'s': surah, 'a': ayah};
  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(j['s'], j['a']);
  @override
  bool operator ==(Object o) => o is Bookmark && o.surah == surah && o.ayah == ayah;
  @override
  int get hashCode => Object.hash(surah, ayah);
}

/// All user settings, persisted as one JSON document.
class Settings {
  Place place = Place.cairo;
  bool placeChosen = false;
  MethodId method = MethodId.egyptian;
  AsrMadhab madhab = AsrMadhab.shafii;
  HighLatitudeRule highLat = HighLatitudeRule.angleBased;
  double customFajr = 18, customIsha = 17;
  Map<Prayer, int> adjust = {for (final p in Prayer.values) p: 0};
  Map<Prayer, bool> notify = {for (final p in Prayer.values) p: p != Prayer.sunrise};
  int preAlertMinutes = 10; // 0 = off
  bool adhanEnabled = true;
  String adhanId = 'alafasy';
  String fajrAdhanId = 'alafasy-fajr';
  int hijriAdjust = 0;
  bool use24h = false;
  ThemeChoice theme = ThemeChoice.dark;
  double quranFontSize = 26;
  String reciterId = 'Alafasy_128kbps';
  bool continueNextSurah = true;
  Bookmark? lastRead;
  List<Bookmark> bookmarks = [];

  CalculationOptions get options {
    var m = CalculationMethod.get(method);
    if (method == MethodId.custom) m = m.withAngles(customFajr, customIsha);
    return CalculationOptions(m, madhab: madhab, highLatitude: highLat);
  }

  Map<String, dynamic> toJson() => {
        'place': place.toJson(), 'placeChosen': placeChosen, 'method': method.name, 'madhab': madhab.name,
        'highLat': highLat.name, 'customFajr': customFajr, 'customIsha': customIsha,
        'adjust': {for (final e in adjust.entries) e.key.name: e.value},
        'notify': {for (final e in notify.entries) e.key.name: e.value},
        'preAlert': preAlertMinutes, 'adhanEnabled': adhanEnabled, 'adhanId': adhanId, 'fajrAdhanId': fajrAdhanId,
        'hijriAdjust': hijriAdjust, 'use24h': use24h, 'theme': theme.name, 'quranFontSize': quranFontSize, 'reciterId': reciterId, 'continueNextSurah': continueNextSurah,
        'lastRead': lastRead?.toJson(), 'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      };

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.firstWhere((v) => v.name == name, orElse: () => fallback);

  static Settings fromJsonString(String? s) {
    final r = Settings();
    if (s == null || s.isEmpty) return r;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      if (j['place'] != null) r.place = Place.fromJson(j['place']);
      r.placeChosen = j['placeChosen'] ?? false;
      r.method = _enum(MethodId.values, j['method'], r.method);
      r.madhab = _enum(AsrMadhab.values, j['madhab'], r.madhab);
      r.highLat = _enum(HighLatitudeRule.values, j['highLat'], r.highLat);
      r.customFajr = (j['customFajr'] ?? 18).toDouble();
      r.customIsha = (j['customIsha'] ?? 17).toDouble();
      for (final p in Prayer.values) {
        r.adjust[p] = (j['adjust']?[p.name] ?? 0) as int;
        r.notify[p] = (j['notify']?[p.name] ?? (p != Prayer.sunrise)) as bool;
      }
      r.preAlertMinutes = j['preAlert'] ?? 10;
      r.adhanEnabled = j['adhanEnabled'] ?? true;
      r.adhanId = j['adhanId'] ?? r.adhanId;
      r.fajrAdhanId = j['fajrAdhanId'] ?? r.fajrAdhanId;
      r.hijriAdjust = j['hijriAdjust'] ?? 0;
      r.use24h = j['use24h'] ?? false;
      r.theme = _enum(ThemeChoice.values, j['theme'], r.theme);
      r.quranFontSize = (j['quranFontSize'] ?? 26).toDouble();
      r.reciterId = j['reciterId'] ?? r.reciterId;
      r.continueNextSurah = j['continueNextSurah'] ?? true;
      if (j['lastRead'] != null) r.lastRead = Bookmark.fromJson(j['lastRead']);
      r.bookmarks = ((j['bookmarks'] ?? []) as List).map((e) => Bookmark.fromJson(e)).toList();
    } catch (_) {/* corrupted -> defaults */}
    return r;
  }

  String toJsonString() => jsonEncode(toJson());
}
