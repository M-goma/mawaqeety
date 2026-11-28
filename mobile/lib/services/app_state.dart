import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show EventChannel;
import 'package:flutter/widgets.dart' show WidgetsBinding;
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
import '../main.dart' show navigatorKey;
import '../ui/mushaf_page.dart' show openMushaf;
import 'adhan_player.dart';
import 'app_updater.dart';
import 'narration.dart';
import 'download_notifier.dart';
import 'mushaf_store.dart';
import 'notification_service.dart';
import 'quran_downloads.dart';
import 'story_downloads.dart';
import 'ghazwa_downloads.dart';
import 'tracker.dart';
import 'radio.dart';
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
  final stories = StoryDownloads();
  final ghazawat = GhazwaDownloads();
  final tracker = Tracker();
  late final downloadNotifier = DownloadNotifier(downloads, mushafStore, repo, stories, ghazawat);
  final narration = Narration();
  final radio = QuranRadio();
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
    await stories.init();
    await ghazawat.init();
    tracker.wirdGoal = () => settings.wirdGoal;
    await tracker.load();
    narration.onSaved = stories.noteSaved;
    narration.storyOrder = [for (final p in repo.prophets) p.id];
    recitation.downloads = downloads;
    // Only one thing plays at a time: starting the radio stops a recitation or story, and the other way round.
    radio.onStart = () {
      if (recitation.active) unawaited(recitation.stop());
      if (narration.speaking) unawaited(narration.stop());
    };
    recitation.addListener(() {
      if (recitation.playing && radio.on) unawaited(radio.stop());
      _watchFlip();
    });
    radio.addListener(_watchFlip);
    narration.addListener(() {
      if (narration.speaking && !narration.paused && radio.on) unawaited(radio.stop());
      _watchFlip();
    });
    await notifications.init(onTap: (r) {
      if (r.actionId?.startsWith('dl_') ?? false) return downloadNotifier.handleAction(r.actionId);
      if (r.actionId?.startsWith('pt_') ?? false) {
        logPrayerAction(r.actionId!, r.payload ?? '');
        return;
      }
      if (r.payload == 'kahf') {
        if (r.actionId == 'kahf_later') {
          unawaited(downloadActionInBackground(r));
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => openKahf());
        return;
      }
      if (r.payload == 'friday_hour') return; // just opens the app
      if (r.payload == DownloadNotifier.payload || (r.payload ?? '').startsWith('pt|')) return; // just opens the app
      playAdhanForCurrent();
    });
    downloadNotifier.onPrayerAction = logPrayerAction;
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

  /// Backup file: the settings and the tracker (prayers, adhkar, fasts…), as JSON.
  String exportBackup() => jsonEncode({
        'app': 'sabeel',
        'version': 1,
        'date': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'tracker': jsonDecode(tracker.exportJson()),
      });

  /// Restores a backup made by [exportBackup]. Returns false if the file is not one.
  Future<bool> importBackup(String text) async {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['app'] != 'sabeel' || j['settings'] is! Map) return false;
      settings = Settings.fromJsonString(jsonEncode(j['settings']));
      await _prefs.setString(_key, settings.toJsonString());
      await tracker.importJson((j['tracker'] ?? <String, dynamic>{}) as Map<String, dynamic>);
      notifyListeners();
      await reschedule();
      return true;
    } catch (e) {
      debugPrint('backup import failed: $e');
      return false;
    }
  }

  /// A "did you pray?" notification button (payload "pt|yyyy-mm-dd|prayer", action "pt_<PrayerLog index>").
  Future<void> logPrayerAction(String action, String payload) async {
    final parts = payload.split('|');
    final v = int.tryParse(action.replaceFirst('pt_', ''));
    if (parts.length != 3 || v == null || v >= PrayerLog.values.length) return;
    final d = DateTime.tryParse(parts[1]);
    final p = Prayer.values.where((x) => x.name == parts[2]).firstOrNull;
    if (d == null || p == null) return;
    await tracker.setPrayer(d, p, PrayerLog.values[v]);
  }

  /// Logs a prayer from the app and stops asking about it.
  Future<void> logPrayer(DateTime date, Prayer p, PrayerLog log) async {
    await tracker.setPrayer(date, p, log);
    unawaited(notifications.refreshPrayerChecks(this));
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

  /// Which of the day's five hadiths to show: it changes with each prayer (Fajr … Isha).
  int get hadithSlot => switch (status().current) {
        Prayer.dhuhr => 1,
        Prayer.asr => 2,
        Prayer.maghrib => 3,
        Prayer.isha => 4,
        _ => 0,
      };

  String get hadithSlotName => const ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'][hadithSlot];

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

  /// Hijri date of a (local) day, with the user's adjustment.
  HijriCalendar hijriOf(DateTime date) => HijriCalendar.fromDate(date.add(Duration(days: settings.hijriAdjust)));

  /// The local day of a Hijri date (inverse of [hijriOf]).
  DateTime fromHijri(int y, int m, int d) {
    final g = HijriCalendar().hijriToGregorian(y, m, d);
    return DateTime(g.year, g.month, g.day).subtract(Duration(days: settings.hijriAdjust));
  }

  /// Days in a Hijri month (29 or 30).
  int hijriMonthLength(int y, int m) => fromHijri(m == 12 ? y + 1 : y, m == 12 ? 1 : m + 1, 1).difference(fromHijri(y, m, 1)).inDays;

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
    // Android: the native adhan service plays it (also when the app is closed).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return;
    final nowUtc = DateTime.now().toUtc();
    final d = day(today);
    for (final p in Prayer.values.where((p) => p.isObligatory && (settings.notify[p] ?? true))) {
      final diff = nowUtc.difference(d[p]).inSeconds;
      final key = '${today.toIso8601String()}-${p.name}';
      if (diff >= 0 && diff < 5 && _lastAutoAdhan != key) {
        _lastAutoAdhan = key;
        // Never cut off a recitation, story or the radio the user is listening to:
        // the prayer notification still alerts them, and the in-app adhan is skipped.
        if (recitation.playing || (narration.speaking && !narration.paused) || radio.playing) continue;
        unawaited(adhan.playFor(p, repo, settings));
      }
    }
  }

  // ---------------- Turn the phone face down to pause what is playing (optional) ----------------
  static const _flipEvents = EventChannel('mawaqeety/flip');
  StreamSubscription<dynamic>? _flip;

  void _watchFlip() {
    final playing = recitation.playing || (narration.speaking && !narration.paused) || radio.on;
    final want = !kIsWeb && defaultTargetPlatform == TargetPlatform.android && settings.flipStopsAudio && playing;
    if (want && _flip == null) {
      _flip = _flipEvents.receiveBroadcastStream().listen((_) {
        if (recitation.playing) unawaited(recitation.pause());
        if (narration.speaking && !narration.paused) unawaited(narration.pause());
        if (radio.on) unawaited(radio.stop());
      }, onError: (_) {});
    } else if (!want && _flip != null) {
      unawaited(_flip!.cancel());
      _flip = null;
    }
  }

  // ---------------- Friday: Surat al-Kahf ----------------
  int get kahfFirst => mushaf.pageOf(18, 1);
  int get kahfLast => mushaf.pageOf(18, 110);
  int get kahfTotal => kahfLast - kahfFirst + 1;

  /// The Friday whose Kahf reading is due now: Friday itself, or Thursday after Maghrib. Null otherwise.
  DateTime? get kahfFriday {
    final t = today;
    if (t.weekday == DateTime.friday) {
      // Friday ends at Maghrib.
      return DateTime.now().toUtc().isBefore(day(t)[Prayer.maghrib]) ? t : null;
    }
    if (t.weekday == DateTime.thursday && DateTime.now().toUtc().isAfter(day(t)[Prayer.maghrib])) return t.add(const Duration(days: 1));
    return null;
  }

  /// Pages of al-Kahf opened for the current Friday.
  int get kahfRead {
    final f = kahfFriday;
    return f != null && settings.kahfDay == dayKey(f) ? settings.kahfPages.length : 0;
  }

  /// Called when a Mushaf page is shown.
  // ---------------- Quran wird and khatma ----------------
  static const mushafPages = 604;

  /// Pages per day of the current khatma plan (0 = no plan).
  int get khatmaDaily => settings.khatmaDays <= 0 ? 0 : (mushafPages / settings.khatmaDays).ceil();

  /// Day of the plan (1 = the day it started).
  int get khatmaDay {
    final s = DateTime.tryParse(settings.khatmaStart);
    return s == null ? 1 : today.difference(DateTime(s.year, s.month, s.day)).inDays + 1;
  }

  /// Page the reader should reach by the end of today.
  int get khatmaTarget => (khatmaDaily * khatmaDay).clamp(0, mushafPages);

  /// Pages read today (distinct Mushaf pages opened).
  int get pagesToday => settings.quranDay == dayKey(today) ? settings.quranPages.length : 0;

  void startKhatma(int days) => update((x) {
        x.khatmaDays = days;
        x.khatmaStart = dayKey(today);
        x.khatmaPage = 0;
      });

  void stopKhatma() => update((x) {
        x.khatmaDays = 0;
        x.khatmaPage = 0;
      });

  void _noteQuranPage(int page) {
    final key = dayKey(today);
    final s = settings;
    final newDay = s.quranDay != key;
    if (!newDay && s.quranPages.contains(page) && (s.khatmaDays == 0 || page <= s.khatmaPage)) return;
    update((x) {
      if (newDay) {
        x.quranDay = key;
        x.quranPages = [];
      }
      if (!x.quranPages.contains(page)) x.quranPages = [...x.quranPages, page];
      if (x.khatmaDays > 0 && page > x.khatmaPage) {
        // The last page after reading most of the Mushaf in order (not a jump to the end): a khatma is
        // complete, and the next one starts.
        final complete = page == mushafPages && x.khatmaPage >= 560;
        x.khatmaPage = page;
        if (complete) {
          x.khatmaDone++;
          x.khatmaPage = 0;
          x.khatmaStart = key;
        }
      }
    }, reschedule: false);
    tracker.setPages(today, settings.quranPages.length);
  }

  void noteMushafPage(int page) {
    _noteQuranPage(page);
    final f = kahfFriday;
    if (f == null || page < kahfFirst || page > kahfLast) return;
    final key = dayKey(f);
    if (settings.kahfDay == key && settings.kahfPages.contains(page)) return;
    update((x) {
      if (x.kahfDay != key) {
        x.kahfDay = key;
        x.kahfPages = [];
      }
      x.kahfPages = [...x.kahfPages, page];
    }, reschedule: false);
  }

  /// Opens the Mushaf at the first unread page of al-Kahf.
  void openKahf() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final read = kahfFriday != null && settings.kahfDay == dayKey(kahfFriday!) ? settings.kahfPages : const <int>[];
    var p = kahfFirst;
    while (p < kahfLast && read.contains(p)) {
      p++;
    }
    openMushaf(ctx, p);
  }

  Future<void> playAdhanForCurrent() async {
    final st = status();
    final p = st.current ?? Prayer.dhuhr;
    await recitation.stop();
    await narration.stop();
    await radio.stop();
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
