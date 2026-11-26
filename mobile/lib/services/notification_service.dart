import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/prayer_calculator.dart';
import 'app_state.dart';
import 'download_notifier.dart';

/// Schedules local notifications for the coming days (Android & iOS). No-op on web.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ok = false;

  /// iOS keeps at most 64 pending notifications; stay under it.
  static const _maxPending = 60;

  Future<void> init({void Function(NotificationResponse r)? onTap}) async {
    if (kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
          requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r),
        onDidReceiveBackgroundNotificationResponse: downloadActionInBackground,
      );
      _ok = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (!_ok) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, sound: true, badge: false);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_times_v1', 'مواقيت الصلاة',
      channelDescription: 'تنبيه عند دخول وقت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('chime'),
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
  );

  static const _preDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_reminder_v1', 'تذكير قبل الصلاة',
      channelDescription: 'تذكير قبل دخول الوقت',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
  );

  static const _countdownBaseId = 9000;

  static AndroidNotificationDetails _countdownDetails(DateTime nextUtc, Duration visibleFor) => AndroidNotificationDetails(
        'prayer_countdown_v1', 'الوقت المتبقي للصلاة',
        channelDescription: 'إشعار دائم يعرض العد التنازلي للصلاة القادمة',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        silent: true,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        channelShowBadge: false,
        showWhen: true,
        when: nextUtc.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,
        // Disappears exactly when the next countdown (scheduled for that moment) appears.
        timeoutAfter: visibleFor.inMilliseconds,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.status,
      );

  /// Android only: a silent, persistent notification counting down to the next prayer,
  /// pre-scheduled for every prayer of the coming days so it keeps rolling without the app running.
  Future<void> _scheduleCountdown(AppState app) async {
    if (defaultTargetPlatform != TargetPlatform.android || !app.settings.ongoingCountdown) return;
    final s = app.settings;
    final nowUtc = DateTime.now().toUtc();
    final timeline = <(Prayer, DateTime)>[];
    for (var d = -1; d < 8; d++) {
      final day = app.day(app.today.add(Duration(days: d)));
      for (final p in Prayer.values) {
        timeline.add((p, day[p]));
      }
    }
    timeline.sort((a, b) => a.$2.compareTo(b.$2));
    String title(Prayer p, DateTime t) => p == Prayer.sunrise
        ? 'الشروق • ${_fmt(app.local(t), s.use24h)}'
        : 'صلاة ${p.nameAr} • ${_fmt(app.local(t), s.use24h)}';
    final body = 'الوقت المتبقي للصلاة القادمة • ${s.place.nameAr}';
    var id = _countdownBaseId;
    for (var i = 1; i < timeline.length; i++) {
      final (prevP, prevT) = timeline[i - 1];
      final (nextP, nextT) = timeline[i];
      if (!nextT.isAfter(nowUtc)) continue;
      final details = NotificationDetails(android: _countdownDetails(nextT, nextT.difference(prevT.isAfter(nowUtc) ? prevT : nowUtc)));
      if (!prevT.isAfter(nowUtc)) {
        // Current period: show it right away.
        await _plugin.show(id: id++, title: title(nextP, nextT), body: body, notificationDetails: details);
      } else {
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(prevT, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: title(nextP, nextT),
          body: body,
        );
      }
    }
  }

  Future<void> schedule(AppState app) async {
    if (!_ok) return;
    try {
      await _plugin.cancelAll();
      final s = app.settings;
      final nowUtc = DateTime.now().toUtc();
      var id = 1;
      var count = 0;
      for (var dayOffset = 0; dayOffset < 14 && count < _maxPending; dayOffset++) {
        final date = app.today.add(Duration(days: dayOffset));
        final times = app.day(date);
        for (final p in Prayer.values) {
          if (!(s.notify[p] ?? false)) continue;
          final at = times[p];
          final timeText = _fmt(app.local(at), s.use24h);
          if (s.preAlertMinutes > 0 && count < _maxPending) {
            final pre = at.subtract(Duration(minutes: s.preAlertMinutes));
            if (pre.isAfter(nowUtc)) {
              await _plugin.zonedSchedule(
                id: id++,
                scheduledDate: tz.TZDateTime.from(pre, tz.UTC),
                notificationDetails: _preDetails,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                title: p == Prayer.sunrise ? 'بقي ${s.preAlertMinutes} دقيقة على الشروق' : 'بقي ${s.preAlertMinutes} دقيقة على صلاة ${p.nameAr}',
                body: '${p.nameAr} • $timeText',
              );
              count++;
            }
          }
          if (at.isAfter(nowUtc) && count < _maxPending) {
            await _plugin.zonedSchedule(
              id: id++,
              scheduledDate: tz.TZDateTime.from(at, tz.UTC),
              notificationDetails: _details,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              title: p == Prayer.sunrise ? 'حان وقت الشروق' : 'حان الآن موعد صلاة ${p.nameAr}',
              body: '${p.nameAr} • $timeText • ${s.place.nameAr}',
              payload: p.name,
            );
            count++;
          }
        }
      }
      await _scheduleCountdown(app);
    } catch (e) {
      debugPrint('scheduling failed: $e');
    }
  }

  static String _fmt(DateTime t, bool h24) {
    if (h24) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
  }
}
