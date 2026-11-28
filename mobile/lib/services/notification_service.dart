import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/arabic.dart';
import '../core/prayer_calculator.dart';
import '../data/occasions.dart';
import '../data/planner.dart';
import 'adhan_player.dart';
import 'app_state.dart';
import 'download_notifier.dart';
import 'tracker.dart';

/// Schedules local notifications for the coming days (Android & iOS). No-op on web.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ok = false;

  /// iOS keeps at most 64 pending notifications; stay under it.
  static const _maxPending = 60;

  Future<void> init({void Function(NotificationResponse r)? onTap}) async {
    if (kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@drawable/ic_stat_notify');
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

  static const _adhan = MethodChannel('mawaqeety/adhan');

  /// Android: the full adhan plays at prayer time from a native service, even when the app is closed.
  bool _fullAdhan(AppState app) => defaultTargetPlatform == TargetPlatform.android && app.settings.adhanEnabled;

  /// Android 12+: whether the adhan may ring at the exact minute («المنبهات والتذكيرات» permission).
  /// Without it Android may delay the alarm or refuse to start the adhan.
  Future<bool> canExactAlarms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _adhan.invokeMethod<bool>('canExact') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system page where the user allows exact alarms for the app.
  Future<void> requestExactAlarms() async {
    try {
      await _adhan.invokeMethod('requestExact');
    } catch (_) {}
  }

  Future<void> _scheduleFullAdhan(AppState app) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (!_fullAdhan(app)) {
        await _adhan.invokeMethod('cancel');
        return;
      }
      final s = app.settings;
      final nowUtc = DateTime.now().toUtc();
      final items = <Map<String, Object>>[];
      var id = 0;
      // A month ahead, so the adhan keeps coming even if the app is not opened for weeks.
      for (var d = 0; d < 30; d++) {
        final date = app.today.add(Duration(days: d));
        final times = app.day(date);
        for (final p in Prayer.values.where((p) => p.isObligatory && (s.notify[p] ?? false))) {
          final at = times[p];
          if (!at.isAfter(nowUtc)) continue;
          final friday = p == Prayer.dhuhr && date.weekday == DateTime.friday;
          final name = friday ? 'الجمعة' : p.nameAr;
          final voice = s.adhanMode == 'voice';
          final timeText = _fmt(app.local(at), s.use24h);
          String path;
          if (voice) {
            path = await AdhanPlayer.alertFile(p, near: false, friday: friday) ?? '';
          } else {
            final v = app.repo.voice(p == Prayer.fajr ? s.fajrAdhanId : s.adhanId) ?? app.repo.voices.first;
            path = await app.adhan.localPath(v) ?? '';
          }
          // Voice alerts: «اقتربت صلاة …» before the time too (the reminder minutes in the settings).
          if (voice && s.preAlertMinutes > 0) {
            final pre = at.subtract(Duration(minutes: s.preAlertMinutes));
            if (pre.isAfter(nowUtc)) {
              items.add({
                'id': id++,
                'at': pre.millisecondsSinceEpoch,
                'title': 'اقتربت صلاة $name',
                'body': 'بقي ${Arabic.minutes(s.preAlertMinutes)} • $name $timeText',
                'path': await AdhanPlayer.alertFile(p, near: true, friday: friday) ?? '',
                'short': true,
                'flip': s.adhanFlip,
                'power': s.adhanPower,
                'silent': s.adhanSilent,
              });
            }
          }
          items.add({
            'id': id++,
            'at': at.millisecondsSinceEpoch,
            'title': 'حان الآن موعد صلاة $name',
            'body': '$name • $timeText • ${s.place.nameAr}',
            'path': path,
            'short': voice,
            'flip': s.adhanFlip,
            'power': s.adhanPower,
            'silent': s.adhanSilent,
          });
        }
      }
      await _adhan.invokeMethod('schedule', items);
    } catch (e) {
      debugPrint('full adhan scheduling failed: $e');
    }
  }

  Future<void> schedule(AppState app) async {
    if (!_ok) return;
    try {
      await _plugin.cancelAll();
      await _scheduleFullAdhan(app);
      final full = _fullAdhan(app);
      final s = app.settings;
      final nowUtc = DateTime.now().toUtc();
      var id = 1;
      var count = 0;
      // Android: our own alarms post these, so a late one (phone asleep or the app just updated) is dropped.
      final native = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final notes = <Map<String, Object>>[];
      for (var dayOffset = 0; dayOffset < 14 && count < _maxPending; dayOffset++) {
        final date = app.today.add(Duration(days: dayOffset));
        final times = app.day(date);
        for (final p in Prayer.values) {
          if (!(s.notify[p] ?? false)) continue;
          final at = times[p];
          final timeText = _fmt(app.local(at), s.use24h);
          final name = p == Prayer.dhuhr && date.weekday == DateTime.friday ? 'الجمعة' : p.nameAr;
          // The spoken «اقتربت صلاة …» replaces the written reminder for the five prayers.
          final spoken = full && s.adhanMode == 'voice' && p.isObligatory;
          if (s.preAlertMinutes > 0 && count < _maxPending && !spoken) {
            final pre = at.subtract(Duration(minutes: s.preAlertMinutes));
            if (pre.isAfter(nowUtc)) {
              final left = Arabic.minutes(s.preAlertMinutes);
              final title = p == Prayer.sunrise ? 'بقي $left على الشروق' : 'بقي $left على صلاة $name';
              final body = '$name • $timeText';
              if (native) {
                // Shown only until the prayer time; never after it.
                notes.add({'at': pre.millisecondsSinceEpoch, 'title': title, 'body': body,
                  'late': s.preAlertMinutes * 60000 ~/ 2, 'ttl': s.preAlertMinutes * 60000});
              } else {
                await _plugin.zonedSchedule(
                  id: id++,
                  scheduledDate: tz.TZDateTime.from(pre, tz.UTC),
                  notificationDetails: _preDetails,
                  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                  title: title,
                  body: body,
                );
              }
              count++;
            }
          }
          // The native adhan shows its own notification at prayer time.
          if (full && p.isObligatory) continue;
          if (at.isAfter(nowUtc) && count < _maxPending) {
            final title = p == Prayer.sunrise ? 'حان وقت الشروق' : 'حان الآن موعد صلاة $name';
            final body = '$name • $timeText • ${s.place.nameAr}';
            if (native) {
              notes.add({'at': at.millisecondsSinceEpoch, 'title': title, 'body': body, 'late': 15 * 60000, 'ttl': 40 * 60000});
            } else {
              await _plugin.zonedSchedule(
                id: id++,
                scheduledDate: tz.TZDateTime.from(at, tz.UTC),
                notificationDetails: _details,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                title: title,
                body: body,
                payload: p.name,
              );
            }
            count++;
          }
        }
      }
      // White days (13–15 of each Hijri month): a reminder half an hour after Isha the evening before.
      if (s.whiteDaysReminder) {
        final h = app.hijriOf(app.today);
        for (var k = 0; k < 3; k++) {
          var m = h.hMonth + k, y = h.hYear;
          if (m > 12) { m -= 12; y++; }
          final first = app.fromHijri(y, m, 13);
          final at = app.day(first.subtract(const Duration(days: 1)))[Prayer.isha].add(const Duration(minutes: 30));
          if (!at.isAfter(nowUtc)) continue;
          const title = 'غدًا أول الأيام البيض';
          final body = 'صيام ١٣ و١٤ و١٥ ${AppState.hijriMonths[m - 1]} سنّةٌ أوصى بها النبي ﷺ';
          if (native) {
            notes.add({'at': at.millisecondsSinceEpoch, 'title': title, 'body': body, 'late': 2 * 3600000, 'ttl': 12 * 3600000});
          } else {
            await _plugin.zonedSchedule(
              id: 8600 + k,
              scheduledDate: tz.TZDateTime.from(at, tz.UTC),
              notificationDetails: _details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              title: title,
              body: body,
            );
          }
        }
      }
      // Evening reminders (half an hour after Isha the day before) and the daily Quran wird.
      final extra = <(DateTime, String, String)>[];
      DateTime eveOf(DateTime day) => app.day(day.subtract(const Duration(days: 1)))[Prayer.isha].add(const Duration(minutes: 30));
      final hNow = app.hijriOf(app.today);
      if (s.occasionsReminder) {
        for (final o in occasions.where((o) => o.isFast || o.id == 'ramadan' || o.id == 'dhulhijja' || o.id == 'lastten')) {
          for (var y = hNow.hYear; y <= hNow.hYear + 1; y++) {
            final d = app.fromHijri(y, o.month, o.day);
            if (d.difference(app.today).inDays > 120) continue;
            final title = o.isFast ? 'غدًا ${o.name}' : 'غدًا: ${o.name}';
            extra.add((eveOf(d), title, o.note.isNotEmpty ? o.note : o.name));
          }
        }
      }
      if (s.monThuReminder) {
        for (var i = 1; i <= 14; i++) {
          final d = app.today.add(Duration(days: i));
          if (d.weekday != DateTime.monday && d.weekday != DateTime.thursday) continue;
          if (app.hijriOf(d).hMonth == 9) continue;
          extra.add((eveOf(d), d.weekday == DateTime.monday ? 'غدًا الاثنين' : 'غدًا الخميس', 'صيام الاثنين والخميس من سنن النبي ﷺ'));
        }
      }
      if (s.khatmaDays > 0 && s.khatmaReminder) {
        final pages = Arabic.pages(app.khatmaDaily);
        for (var i = 0; i < 7; i++) {
          final d = app.today.add(Duration(days: i));
          extra.add((app.day(d)[Prayer.fajr].add(const Duration(minutes: 30)), '📖 وردك من القرآن اليوم', '$pages • افتح المصحف وأكمل ختمتك'));
        }
      }
      var xid = 8700;
      for (final (at, title, body) in extra) {
        if (!at.isAfter(nowUtc)) continue;
        if (native) {
          notes.add({'at': at.millisecondsSinceEpoch, 'title': title, 'body': body, 'late': 2 * 3600000, 'ttl': 12 * 3600000});
        } else {
          await _plugin.zonedSchedule(
            id: xid++,
            scheduledDate: tz.TZDateTime.from(at, tz.UTC),
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
          );
        }
      }
      // Daily planner: each task's reminder, the morning plan and the evening summary. On Android they go into the
      // same list of native notes (each call replaces all of them), never as a separate call.
      var pid = _plannerBaseId;
      for (final (at, title, body) in _plannerNotes(app, nowUtc)) {
        if (native) {
          notes.add({'at': at.millisecondsSinceEpoch, 'title': title, 'body': body, 'late': 10 * 60000, 'ttl': 60 * 60000});
        } else if (count < _maxPending) {
          await _plugin.zonedSchedule(
            id: pid++,
            scheduledDate: tz.TZDateTime.from(at, tz.UTC),
            notificationDetails: _plannerDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            title: title,
            body: body,
            payload: 'planner',
          );
          count++;
        }
      }
      if (native) {
        // Native alarms are keyed by minute: give reminders that share a minute their own minute.
        final used = <int>{};
        for (final n in notes) {
          var m = (n['at'] as int) ~/ 60000;
          while (!used.add(m)) {
            m++;
          }
          n['at'] = m * 60000;
        }
        try {
          await _adhan.invokeMethod('notes', notes);
        } catch (e) {
          debugPrint('reminder scheduling failed: $e');
        }
      }
      await _schedulePrayerChecks(app);
      await _scheduleFriday(app);
      await _scheduleCountdown(app);
    } catch (e) {
      debugPrint('scheduling failed: $e');
    }
  }

  static const _plannerBaseId = 7000;

  static const _plannerDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'planner_v1', 'مخطط اليوم',
      channelDescription: 'تذكير بمهام اليوم وخطتك وملخصها',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
  );

  /// The planner's notifications for today and tomorrow (UTC time, title, body). No adhan: they only open the app.
  static List<(DateTime, String, String)> _plannerNotes(AppState app, DateTime nowUtc) {
    final pl = app.planner;
    final c = pl.config;
    final s = app.settings;
    final out = <(DateTime, String, String)>[];
    for (var d = 0; d < 2; d++) {
      final date = app.today.add(Duration(days: d));
      final plan = pl.plan(date);
      if (c.reminders) {
        for (final b in plan.taskBlocks) {
          final t = b.task!;
          if (t.done || t.remind == null) continue;
          final at = app.utcAt(date, b.start - t.remind!);
          if (!at.isAfter(nowUtc)) continue;
          final time = _fmt(app.local(app.utcAt(date, b.start)), s.use24h);
          out.add((
            at,
            '⏰ ${t.title}',
            t.remind == 0 ? 'حان موعد مهمتك • $time • ${Arabic.minutes(t.minutes)}' : 'تبدأ بعد ${Arabic.minutes(t.remind!)} • $time',
          ));
        }
      }
      final times = app.day(date);
      final tasks = pl.of(date);
      if (c.morningNote) {
        // Tomorrow's plan also gets today's unfinished tasks (they roll over at midnight).
        var n = tasks.where((t) => !t.done).length;
        if (d == 1 && c.carryOver) n += pl.of(app.today).where((t) => !t.done).length;
        final at = times[Prayer.fajr].add(const Duration(minutes: 45));
        if (n > 0 && at.isAfter(nowUtc)) out.add((at, '🗒️ خطة يومك: ${_tasks(n)}', 'افتح مخطط اليوم لترى جدولك بين الصلوات'));
      }
      if (c.eveningNote) {
        final at = times[Prayer.isha].add(const Duration(minutes: 45));
        final st = PlanStat.of(tasks);
        if (at.isAfter(nowUtc) && (st.total > 0 || d == 1)) {
          out.add((
            at,
            '📋 ملخص يومك',
            d == 0
                ? 'أنجزت ${Arabic.digits(st.done)} من ${_tasks(st.total)}${st.minutes > 0 ? ' • ${Arabic.minutes(st.minutes)} من التركيز' : ''}'
                : 'راجع ما أنجزته اليوم، وخطّط لغدك',
          ));
        }
      }
    }
    return out;
  }

  static String _tasks(int n) => n == 1 ? 'مهمة واحدة' : (n == 2 ? 'مهمتان' : (n <= 10 ? '${Arabic.digits(n)} مهام' : '${Arabic.digits(n)} مهمة'));

  static const fridayBaseId = 8500;

  static const kahfDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'friday_v1', 'تذكير الجمعة',
      channelDescription: 'سورة الكهف وساعة الاستجابة يوم الجمعة',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      actions: [
        AndroidNotificationAction('kahf_read', 'اقرأ الآن', showsUserInterface: true),
        AndroidNotificationAction('kahf_later', 'ذكّرني بعد ساعة'),
      ],
    ),
  );
  static const kahfTitle = '📖 لا تنسَ سورة الكهف';
  static const kahfBody = '«من قرأ سورة الكهف يوم الجمعة أضاء له من النور ما بين الجمعتين» — رواه الحاكم والبيهقي، وصححه الألباني';

  /// Friday reminders for the next two Fridays: al-Kahf on Thursday after Maghrib and on Friday morning,
  /// and the hour of answered prayer (the last hour before Maghrib).
  Future<void> _scheduleFriday(AppState app) async {
    final s = app.settings;
    if (!s.fridayKahf && !s.fridayHour) return;
    final nowUtc = DateTime.now().toUtc();
    var id = fridayBaseId;
    for (var d = 0; d < 14; d++) {
      final date = app.today.add(Duration(days: d));
      if (date.weekday != DateTime.friday) continue;
      final fri = app.day(date);
      final thu = app.day(date.subtract(const Duration(days: 1)));
      Future<void> at(DateTime when, String title, String body, NotificationDetails details, String payload) async {
        if (!when.isAfter(nowUtc)) return;
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
          payload: payload,
        );
      }

      final done = s.kahfDay == dayKey(date) && s.kahfPages.length >= app.kahfTotal;
      if (s.fridayKahf && !done) {
        await at(thu[Prayer.maghrib].add(const Duration(minutes: 40)), kahfTitle, 'ليلة الجمعة بدأت. $kahfBody', kahfDetails, 'kahf');
        await at(fri[Prayer.sunrise].add(const Duration(minutes: 90)), kahfTitle, kahfBody, kahfDetails, 'kahf');
      }
      if (s.fridayHour) {
        await at(
          fri[Prayer.maghrib].subtract(const Duration(hours: 1)),
          '🤲 ساعة الاستجابة',
          'آخر ساعة من يوم الجمعة: أكثِر من الدعاء والصلاة على النبي ﷺ.',
          const NotificationDetails(
            android: AndroidNotificationDetails('friday_v1', 'تذكير الجمعة',
                channelDescription: 'سورة الكهف وساعة الاستجابة يوم الجمعة',
                importance: Importance.high, priority: Priority.high),
          ),
          'friday_hour',
        );
      }
    }
  }

  static const _checkBaseId = 8000;

  /// Android only: about 30 minutes after each prayer, "Did you pray?" with buttons that log it directly.
  Future<void> _schedulePrayerChecks(AppState app) async {
    if (defaultTargetPlatform != TargetPlatform.android || !app.settings.prayerCheck) return;
    final nowUtc = DateTime.now().toUtc();
    var id = _checkBaseId;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_check_v1', 'هل صليت؟',
        channelDescription: 'سؤال بعد كل صلاة لتسجيلها في إحصائياتك',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        actions: [
          AndroidNotificationAction('pt_1', '🕌 في المسجد'),
          AndroidNotificationAction('pt_2', '👥 جماعة'),
          AndroidNotificationAction('pt_3', '🧍 منفردًا'),
        ],
      ),
    );
    for (var d = 0; d < 3; d++) {
      final date = app.today.add(Duration(days: d));
      final times = app.day(date);
      for (final p in trackedPrayers) {
        final at = times[p].add(const Duration(minutes: 30));
        if (!at.isAfter(nowUtc) || app.tracker.day(date).of(p) != PrayerLog.none) continue;
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'هل صليت ${p == Prayer.dhuhr && date.weekday == DateTime.friday ? 'الجمعة' : p.nameAr}؟ 🤍',
          body: 'سجّل صلاتك لتكتمل إحصائيتك اليوم.',
          payload: 'pt|${dayKey(date)}|${p.name}',
        );
      }
    }
  }

  /// Re-plans the "did you pray?" questions (e.g. after a prayer was logged in the app, so it is not asked).
  Future<void> refreshPrayerChecks(AppState app) async {
    if (!_ok) return;
    for (var i = 0; i < 15; i++) {
      await _plugin.cancel(id: _checkBaseId + i);
    }
    await _schedulePrayerChecks(app);
  }

  static String _fmt(DateTime t, bool h24) {
    if (h24) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
  }
}

