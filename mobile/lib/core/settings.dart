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
  String palette = 'emerald';
  double quranFontSize = 26;
  String reciterId = 'Alafasy_128kbps';
  bool continueNextSurah = true;
  String narrationVoice = 'male'; // 'male' | 'female'
  // Per-gender voice tuning (device voice name, pitch, speed). Empty name = automatic.
  String voiceMale = '', voiceFemale = '';
  double pitchMale = 0.62, pitchFemale = 1.1;
  double rateMale = 0.42, rateFemale = 0.47;
  bool ongoingCountdown = true;
  /// Home-screen widget style: 'clock' (clock + countdown badge), 'cell' (countdown in the prayer cell), 'countdown' (big countdown).
  String widgetStyle = 'clock';
  bool storyAutoplay = false; // play the next prophet story when one ends // Android: persistent notification with the time left to the next prayer
  Bookmark? lastRead;
  List<Bookmark> bookmarks = [];
  /// Mushaf colours: 'auto' (follows the app theme), 'paper', 'white', 'navy', 'sepia', 'charcoal'.
  String mushafMode = 'auto';
  String mushafNight = 'navy'; // night colours used by 'auto'
  double mushafDim = 0; // 0..0.6 extra dimming inside the Mushaf
  int mushafPage = 1; // last page opened
  bool mushafHint = false; // the long-press tip was shown
  // Tasbeeh and the daily tracker
  int wirdGoal = 100; // daily tasbeeh goal (0 = none)
  bool prayerCheck = true; // "did you pray?" notification after each prayer
  bool fridayKahf = true; // Surat al-Kahf reminder (Thursday after Maghrib and Friday morning)
  bool fridayHour = true; // the hour of answered prayer (last hour before Maghrib on Friday)
  String kahfDay = ''; // Friday (yyyy-mm-dd) the pages below belong to
  List<int> kahfPages = []; // Mushaf pages of al-Kahf opened that Friday
  int tasbeehPhrase = 0; // index in the phrase list (built-in first, then custom)
  int tasbeehTarget = 33; // 33, 100, 0 = free, -1 = after-prayer sequence (33+33+34)
  List<String> tasbeehCustom = [];
  int tasbeehCount = 0; // current round
  int tasbeehStep = 0; // step of the after-prayer sequence

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
        'hijriAdjust': hijriAdjust, 'use24h': use24h, 'theme': theme.name, 'palette': palette, 'quranFontSize': quranFontSize, 'reciterId': reciterId, 'continueNextSurah': continueNextSurah, 'narrationVoice': narrationVoice, 'voiceMale': voiceMale, 'voiceFemale': voiceFemale,
        'pitchMale': pitchMale, 'pitchFemale': pitchFemale, 'rateMale': rateMale, 'rateFemale': rateFemale,
        'ongoingCountdown': ongoingCountdown, 'widgetStyle': widgetStyle, 'storyAutoplay': storyAutoplay,
        'mushafMode': mushafMode, 'mushafNight': mushafNight, 'mushafDim': mushafDim, 'mushafPage': mushafPage, 'mushafHint': mushafHint, 'wirdGoal': wirdGoal, 'prayerCheck': prayerCheck, 'fridayKahf': fridayKahf, 'fridayHour': fridayHour, 'kahfDay': kahfDay, 'kahfPages': kahfPages, 'tasbeehPhrase': tasbeehPhrase, 'tasbeehTarget': tasbeehTarget, 'tasbeehCustom': tasbeehCustom, 'tasbeehCount': tasbeehCount, 'tasbeehStep': tasbeehStep,
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
      r.palette = j['palette'] ?? 'emerald';
      r.quranFontSize = (j['quranFontSize'] ?? 26).toDouble();
      r.reciterId = j['reciterId'] ?? r.reciterId;
      r.continueNextSurah = j['continueNextSurah'] ?? true;
      r.narrationVoice = j['narrationVoice'] ?? 'male';
      r.voiceMale = j['voiceMale'] ?? '';
      r.voiceFemale = j['voiceFemale'] ?? '';
      r.pitchMale = (j['pitchMale'] ?? 0.62).toDouble();
      r.pitchFemale = (j['pitchFemale'] ?? 1.1).toDouble();
      r.rateMale = (j['rateMale'] ?? 0.42).toDouble();
      r.rateFemale = (j['rateFemale'] ?? 0.47).toDouble();
      r.ongoingCountdown = j['ongoingCountdown'] ?? true;
      r.widgetStyle = j['widgetStyle'] ?? 'clock';
      r.storyAutoplay = j['storyAutoplay'] ?? false;
      r.mushafMode = j['mushafMode'] ?? 'auto';
      r.mushafNight = j['mushafNight'] ?? 'navy';
      r.mushafDim = (j['mushafDim'] ?? 0).toDouble();
      r.mushafPage = j['mushafPage'] ?? 1;
      r.mushafHint = j['mushafHint'] ?? false;
      r.wirdGoal = j['wirdGoal'] ?? 100;
      r.prayerCheck = j['prayerCheck'] ?? true;
      r.fridayKahf = j['fridayKahf'] ?? true;
      r.fridayHour = j['fridayHour'] ?? true;
      r.kahfDay = j['kahfDay'] ?? '';
      r.kahfPages = [for (final x in (j['kahfPages'] as List?) ?? const []) x as int];
      r.tasbeehPhrase = j['tasbeehPhrase'] ?? 0;
      r.tasbeehTarget = j['tasbeehTarget'] ?? 33;
      r.tasbeehCustom = ((j['tasbeehCustom'] ?? []) as List).cast<String>();
      r.tasbeehCount = j['tasbeehCount'] ?? 0;
      r.tasbeehStep = j['tasbeehStep'] ?? 0;
      if (j['lastRead'] != null) r.lastRead = Bookmark.fromJson(j['lastRead']);
      r.bookmarks = ((j['bookmarks'] ?? []) as List).map((e) => Bookmark.fromJson(e)).toList();
    } catch (_) {/* corrupted -> defaults */}
    return r;
  }

  String toJsonString() => jsonEncode(toJson());
}
