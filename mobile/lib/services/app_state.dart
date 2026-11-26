import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/methods.dart';
import '../core/prayer_calculator.dart';
import '../core/settings.dart';
import '../data/mushaf.dart';
import '../data/repository.dart';
import 'adhan_player.dart';
import 'app_updater.dart';
import 'narration.dart';
import 'download_notifier.dart';
import 'mushaf_store.dart';
import 'notification_service.dart';
import 'quran_downloads.dart';
import 'recitation.dart';
import 'widget_service.dart';

class PrayerStatus {
  final Prayer? current;
  final Prayer next;
  final DateTime nextTime; // utc
  final Duration remaining;
  final double progress;
  PrayerStatus(this.current, this.next, this.nextTime, this.remaining, this.progress);
}

/// Central app state: settings, data, prayer times and services.
class AppState extends ChangeNotifier {
  static const _key = 'settings.v1';
  final repo = Repository();
  final notifications = NotificationService();
  final adhan = AdhanPlayer();
  final recitation = Recitation();
  final downloads = QuranDownloads();
  final mushaf = MushafIndex();
  final mushafStore = MushafStore();
  late final downloadNotifier = DownloadNotifier(downloads, mushafStore, repo);
  final narration = Narration();
  final updater = AppUpdater();
  final widgets = WidgetService();
  late SharedPreferences _prefs;
  Settings settings = Settings();
  bool ready = false;
  Timer? _ticker;
  String? _lastAutoAdhan;

  static const hijriMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  Future<void> init() async {
    tzdata.initializeTimeZones();
    _prefs = await SharedPreferences.getInstance();
    settings = Settings.fromJsonString(_prefs.getString(_key));
    await repo.load();
    await downloads.init();
    await mushaf.load();
    await mushafStore.init(mushaf);
    await narration.loadRecordings();
    narration.storyOrder = [for (final p in repo.prophets) p.id];
    recitation.downloads = downloads;
    await notifications.init(onTap: (r) {
      if (r.actionId?.startsWith('dl_') ?? false) return downloadNotifier.handleAction(r.actionId);
      if (r.payload == DownloadNotifier.payload) return; // just opens the app
      playAdhanForCurrent();
    });
    downloadNotifier.init();
    ready = true;
    notifyListeners();
    unawaited(reschedule());
    unawaited(adhan.prefetch(repo, settings));
    // Once per second: refresh the countdown and play the adhan if the app is open at prayer time.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> update(void Function(Settings s) change, {bool reschedule = true}) async {
    change(settings);
    await _prefs.setString(_key, settings.toJsonString());
    notifyListeners();
    if (reschedule) await this.reschedule();
  }

  Future<void> reschedule() async {
    await notifications.schedule(this);
    await widgets.update(this);
  }

  // ---------------- time ----------------
  tz.Location get location {
    try {
      return tz.getLocation(settings.place.tz);
    } catch (_) {
      return tz.local;
    }
  }

  tz.TZDateTime local(DateTime utc) => tz.TZDateTime.from(utc, location);
  tz.TZDateTime get now => tz.TZDateTime.now(location);

  bool _isRamadan(DateTime d) {
    try {
      return HijriCalendar.fromDate(d.add(Duration(days: settings.hijriAdjust))).hMonth == 9;
    } catch (_) {
      return false;
    }
  }

  final Map<String, DailyTimes> _cache = {};

  DailyTimes day(DateTime date) {
    final s = settings;
    final key = '${s.place.lat},${s.place.lng},${s.method},${s.madhab},${s.highLat},${s.customFajr},${s.customIsha},'
        '${s.adjust.values.join(',')},${date.year}-${date.month}-${date.day}';
    return _cache.putIfAbsent(key, () {
      if (_cache.length > 400) _cache.clear();
      final raw = PrayerCalculator.calculate(date.year, date.month, date.day, s.place.lat, s.place.lng, s.options,
          isRamadan: _isRamadan(date));
      return DailyTimes(raw.date, {
        for (final p in Prayer.values) p: raw[p].add(Duration(minutes: s.adjust[p] ?? 0)),
      });
    });
  }

  DateTime get today {
    final n = now;
    return DateTime(n.year, n.month, n.day);
  }

  PrayerStatus status() {
    final t = today;
    final nowUtc = DateTime.now().toUtc();
    final timeline = <(Prayer, DateTime)>[];
    for (final d in [t.subtract(const Duration(days: 1)), t, t.add(const Duration(days: 1))]) {
      final day = this.day(d);
      for (final p in Prayer.values) {
        timeline.add((p, day[p]));
      }
    }
    timeline.sort((a, b) => a.$2.compareTo(b.$2));
    var i = timeline.indexWhere((e) => e.$2.isAfter(nowUtc));
    if (i <= 0) i = 1;
    final next = timeline[i], prev = timeline[i - 1];
    final span = next.$2.difference(prev.$2).inSeconds;
    final progress = span <= 0 ? 0.0 : (nowUtc.difference(prev.$2).inSeconds / span).clamp(0.0, 1.0);
    return PrayerStatus(prev.$1 == Prayer.sunrise ? null : prev.$1, next.$1, next.$2, next.$2.difference(nowUtc), progress);
  }

  String hijri(DateTime date) {
    try {
      final h = HijriCalendar.fromDate(date.add(Duration(days: settings.hijriAdjust)));
      return '${h.hDay} ${hijriMonths[h.hMonth - 1]} ${h.hYear} هـ';
    } catch (_) {
      return '';
    }
  }

  void _tick() {
    if (!ready) return;
    notifyListeners();
    if (!settings.adhanEnabled) return;
    final nowUtc = DateTime.now().toUtc();
    final d = day(today);
    for (final p in Prayer.values.where((p) => p.isObligatory && (settings.notify[p] ?? true))) {
      final diff = nowUtc.difference(d[p]).inSeconds;
      final key = '${today.toIso8601String()}-${p.name}';
      if (diff >= 0 && diff < 5 && _lastAutoAdhan != key) {
        _lastAutoAdhan = key;
        unawaited(recitation.stop());
        unawaited(narration.stop());
        unawaited(adhan.playFor(p, repo, settings));
      }
    }
  }

  Future<void> playAdhanForCurrent() async {
    final st = status();
    final p = st.current ?? Prayer.dhuhr;
    await recitation.stop();
    await narration.stop();
    await adhan.playFor(p, repo, settings);
  }

  // ---------------- location ----------------
  Future<String?> detectLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return 'خدمة الموقع متوقفة في الجهاز';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return 'لم يتم السماح بالوصول للموقع';
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)));
      final near = repo.nearestCity(pos.latitude, pos.longitude);
      String tzId = near.tz;
      await setPlace(Place(
          nameAr: near.nameAr, nameEn: near.nameEn, countryAr: near.countryAr, countryCode: near.countryCode,
          lat: pos.latitude, lng: pos.longitude, tz: tzId));
      return null;
    } catch (e) {
      return 'تعذّر تحديد الموقع';
    }
  }

  Future<void> setPlace(Place p) async {
    final countryChanged = p.countryCode != settings.place.countryCode;
    await update((s) {
      s.place = p;
      s.placeChosen = true;
      if (countryChanged) {
        s.method = CalculationMethod.defaultForCountry(p.countryCode);
        s.madhab = CalculationMethod.defaultMadhabForCountry(p.countryCode);
      }
    });
  }

  bool get isWeb => kIsWeb;
}
