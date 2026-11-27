import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/arabic.dart';
import '../data/mushaf.dart';
import '../data/repository.dart';
import 'mushaf_store.dart';
import 'notification_service.dart';
import 'quran_downloads.dart';
import 'story_downloads.dart';
import 'tracker.dart';

/// Buttons in a notification that do not open the app run in a separate isolate;
/// they forward the button id to the app through this port.
@pragma('vm:entry-point')
Future<void> downloadActionInBackground(NotificationResponse r) async {
  final port = IsolateNameServer.lookupPortByName(DownloadNotifier.portName);
  final action = r.actionId ?? '';
  if (action == 'kahf_later') {
    // Ask again in an hour (works while the app is closed).
    final plugin = FlutterLocalNotificationsPlugin();
    tzdata.initializeTimeZones();
    await plugin.zonedSchedule(
      id: NotificationService.fridayBaseId + 50,
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 1)),
      notificationDetails: NotificationService.kahfDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: NotificationService.kahfTitle,
      body: NotificationService.kahfBody,
      payload: 'kahf',
    );
    return;
  }
  if (action.startsWith('pt_')) {
    // "Did you pray?" buttons: tell the running app, or save directly when it is not running.
    if (port != null) {
      port.send('$action#${r.payload ?? ''}');
    } else {
      DartPluginRegistrant.ensureInitialized();
      await logPrayerFromBackground(r.payload ?? '', action);
    }
    return;
  }
  port?.send(r.actionId);
}

/// Keeps Qur'an and Mushaf downloads running after the user leaves the app (Android foreground service),
/// with a progress notification and a notice when they finish — like the media notification of the stories.
class DownloadNotifier {
  static const portName = 'mawaqeety.downloads';
  static const _id = 7700, _doneId = 7701;
  static const payload = 'downloads';

  final QuranDownloads quran;
  final MushafStore mushaf;
  final Repository repo;
  final StoryDownloads stories;
  DownloadNotifier(this.quran, this.mushaf, this.repo, this.stories);

  final _plugin = FlutterLocalNotificationsPlugin();
  final _port = ReceivePort();
  Timer? _timer;
  bool _running = false;

  // What is (or was) being downloaded, to report the result and to resume after a pause.
  final _quranJobs = <String, List<int>>{}; // reciter -> surahs
  bool _mushafJob = false;
  (List<String>, List<String>?)? _storiesJob; // voices, story ids (null = all)
  bool _paused = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// A "did you pray?" button was pressed: (action id, payload).
  void Function(String action, String payload)? onPrayerAction;

  void init() {
    if (!_supported) return;
    IsolateNameServer.removePortNameMapping(portName);
    IsolateNameServer.registerPortWithName(_port.sendPort, portName);
    _port.listen((msg) {
      final m = msg as String?;
      if (m != null && m.startsWith('pt_')) {
        final i = m.indexOf('#');
        onPrayerAction?.call(m.substring(0, i), m.substring(i + 1));
        return;
      }
      handleAction(m);
    });
    quran.addListener(_changed);
    mushaf.addListener(_changed);
    stories.addListener(_changed);
  }

  bool get _anyActive => quran.jobs.isNotEmpty || mushaf.downloading || stories.downloading;

  void _changed() {
    for (final j in quran.jobs.values) {
      _quranJobs.putIfAbsent(j.reciter, () => j.all ? [] : [...j.surahs]);
    }
    if (mushaf.downloading) _mushafJob = true;
    if (stories.downloading) _storiesJob = (stories.jobGenders, stories.jobIds);
    if (_anyActive && !_running) _start();
    if (!_anyActive && _running) _finish();
  }

  AndroidNotificationDetails _progressDetails(int done, int total) => AndroidNotificationDetails(
        'downloads_v1', 'التنزيلات',
        channelDescription: 'تقدّم تنزيل التلاوات وصفحات المصحف',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        showProgress: true,
        maxProgress: total,
        progress: done,
        indeterminate: total == 0,
        category: AndroidNotificationCategory.progress,
        actions: const [
          AndroidNotificationAction('dl_pause', 'إيقاف مؤقت', cancelNotification: false),
          AndroidNotificationAction('dl_cancel', 'إلغاء', cancelNotification: false),
        ],
      );

  (String, String, int, int) _status() {
    final titles = <String>[], lines = <String>[];
    var done = 0, total = 0;
    for (final j in quran.jobs.values) {
      final name = repo.reciter(j.reciter).name;
      final pct = (j.progress * 100).round();
      titles.add('جارٍ تنزيل التلاوة • $name');
      final s = j.currentSurah > 0 ? 'سورة ${repo.surahs[j.currentSurah - 1].name} • ' : '';
      lines.add('$s${Arabic.digits(pct)}٪ (${Arabic.digits(j.doneFiles)} من ${Arabic.digits(j.totalFiles)} آية)');
      done += j.doneFiles;
      total += j.totalFiles;
    }
    if (mushaf.downloading) {
      titles.add('جارٍ تنزيل صفحات المصحف');
      lines.add('${Arabic.digits(mushaf.savedCount)} من ${Arabic.digits(MushafIndex.pageCount)} صفحة');
      done += mushaf.savedCount;
      total += MushafIndex.pageCount;
    }
    if (stories.downloading) {
      titles.add('جارٍ تنزيل قصص الأنبياء • ${_voices(stories.jobGenders)}');
      final p = repo.prophets.where((x) => x.id == stories.currentId).firstOrNull;
      lines.add('${p != null ? 'قصة ${p.nameAr} • ' : ''}${Arabic.digits((stories.progress * 100).round())}٪');
      done += stories.doneFiles;
      total += stories.totalFiles;
    }
    return (titles.isEmpty ? 'جارٍ التنزيل' : titles.first, lines.join('\n'), done, total);
  }

  Future<void> _start() async {
    _running = true;
    _paused = false;
    final (title, body, done, total) = _status();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await _plugin.cancel(id: _doneId);
      await android?.startForegroundService(
        id: _id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: _progressDetails(done, total),
        startType: AndroidServiceStartType.startNotSticky,
        foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeDataSync},
      );
    } catch (e) {
      debugPrint('download service failed: $e');
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  Future<void> _update() async {
    if (!_running || !_anyActive) return;
    final (title, body, done, total) = _status();
    try {
      await _plugin.show(
        id: _id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: _progressDetails(done, total).copyWithStyle(body),
        ),
      );
    } catch (_) {}
  }

  Future<void> _finish() async {
    _running = false;
    _timer?.cancel();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.stopForegroundService();
      await _plugin.cancel(id: _id);
    } catch (_) {}

    String? title, body;
    var withResume = false;
    if (_paused) {
      title = 'التنزيل متوقف مؤقتًا';
      body = 'ما نُزِّل محفوظ على الهاتف، ويكمل التنزيل من حيث توقف.';
      withResume = true;
    } else {
      final errors = [
        for (final r in _quranJobs.keys)
          if (quran.lastError.containsKey(r)) quran.lastError[r]!,
        if (_mushafJob && mushaf.error != null) mushaf.error!,
        if (_storiesJob != null && stories.error != null) stories.error!,
      ];
      final cancelled = _quranJobs.keys.any(quran.wasCancelled) || (_mushafJob && mushaf.wasCancelled) ||
          (_storiesJob != null && stories.wasCancelled);
      if (errors.isNotEmpty) {
        title = 'توقّف التنزيل';
        body = errors.first;
        withResume = true;
      } else if (!cancelled) {
        final parts = <String>[];
        for (final e in _quranJobs.entries) {
          final what = e.value.isEmpty
              ? 'القرآن كاملًا'
              : e.value.length == 1 ? 'سورة ${repo.surahs[e.value.first - 1].name}' : '${Arabic.digits(e.value.length)} سورة';
          parts.add('$what بصوت ${repo.reciter(e.key).name}');
        }
        if (_mushafJob) parts.add('صفحات المصحف (${Arabic.digits(mushaf.savedCount)} صفحة)');
        if (_storiesJob case (final g, final ids)?) {
          parts.add(ids == null ? 'قصص الأنبياء بصوت ${_voices(g)}' : 'قصة ${repo.prophets.firstWhere((x) => x.id == ids.first).nameAr}');
        }
        if (parts.isNotEmpty) {
          title = '✓ اكتمل التنزيل';
          body = '${parts.join('، ')} جاهز دون إنترنت.';
        }
      }
    }
    if (!withResume) {
      _quranJobs.clear();
      _mushafJob = false;
      _storiesJob = null;
    }
    _paused = false;
    if (title == null) return;
    try {
      await _plugin.show(
        id: _doneId,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'downloads_done_v1', 'اكتمال التنزيلات',
            channelDescription: 'تنبيه عند انتهاء تنزيل التلاوات أو صفحات المصحف',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(body ?? ''),
            actions: withResume
                ? const [AndroidNotificationAction('dl_resume', 'متابعة التنزيل', showsUserInterface: true)]
                : null,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Notification buttons: pause, cancel, resume.
  void handleAction(String? id) {
    switch (id) {
      case 'dl_pause':
      case 'dl_cancel':
        _paused = id == 'dl_pause';
        if (!_paused) {
          _quranJobs.clear();
          _mushafJob = false;
          _storiesJob = null;
        }
        for (final r in quran.jobs.keys.toList()) {
          quran.cancel(r);
        }
        if (mushaf.downloading) mushaf.cancel();
        if (stories.downloading) stories.cancel();
      case 'dl_resume':
        _plugin.cancel(id: _doneId);
        final jobs = Map.of(_quranJobs);
        final m = _mushafJob;
        final st = _storiesJob;
        for (final e in jobs.entries) {
          quran.download(repo, e.key, surahs: e.value.isEmpty ? null : e.value);
        }
        if (m) mushaf.downloadAll();
        if (st != null) stories.download(st.$1, ids: st.$2);
    }
  }
}

String _voices(List<String> g) => g.map((x) => x == 'female' ? 'عرين' : 'نبيل').join(' و');

extension on AndroidNotificationDetails {
  /// Same details, with the multi-line body shown in full.
  AndroidNotificationDetails copyWithStyle(String body) => AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        indeterminate: indeterminate,
        category: category,
        actions: actions,
        styleInformation: BigTextStyleInformation(body),
      );
}
