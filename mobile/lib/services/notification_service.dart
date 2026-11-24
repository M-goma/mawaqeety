import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/prayer_calculator.dart';
import 'app_state.dart';

/// Schedules local notifications for the coming days (Android & iOS). No-op on web.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ok = false;

  /// iOS keeps at most 64 pending notifications; stay under it.
  static const _maxPending = 60;

  Future<void> init({void Function(String?)? onTap}) async {
    if (kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
          requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
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
