import 'dart:async';

import 'package:flutter/material.dart';

import '../core/prayer_calculator.dart';
import '../core/arabic.dart';
import '../main.dart';
import '../services/tracker.dart';
import 'format.dart';
import 'calendar_page.dart';
import 'monthly_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'theme.dart';

class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key});

  static const _icons = {
    Prayer.fajr: Icons.nights_stay_outlined,
    Prayer.sunrise: Icons.wb_twilight,
    Prayer.dhuhr: Icons.wb_sunny_outlined,
    Prayer.asr: Icons.sunny_snowing,
    Prayer.maghrib: Icons.wb_twighlight,
    Prayer.isha: Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.adhan, app.tracker]),
      builder: (context, _) {
        final s = app.settings;
        final now = app.now;
        final today = app.day(app.today);
        final st = app.status();
        final theme = Theme.of(context);
        final isFriday = now.weekday == DateTime.friday;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CityPickerPage())),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.place, color: AppColors.gold, size: 20),
                          const SizedBox(width: 4),
                          Flexible(child: Text(s.place.display, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.expand_more, size: 18),
                        ]),
                      ),
                      const SizedBox(height: 2),
                      Text('${fmtGregorian(now)}\n${app.hijri(now)}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                    ]),
                  ),
                  Text(fmtTime(now, s.use24h), textDirection: TextDirection.ltr,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                ]),
              ),
              // The adhan is turned on or off per prayer with its bell; here only a way to stop it while it plays,
              // and a warning when Android would not let it ring on time.
              if (app.adhan.isPlaying)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => app.adhan.stop(),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('إيقاف الأذان'),
                    ),
                  ),
                ),
              const ExactAlarmBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage())),
                      icon: const Icon(Icons.event_outlined),
                      label: const Text('التقويم الميلادي'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyPage())),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('مواقيت الشهر'),
                    ),
                  ),
                ]),
              ),
              // Today
              for (final p in Prayer.values)
                _PrayerRow(
                  icon: _icons[p]!,
                  name: p == Prayer.dhuhr && isFriday ? 'الجمعة' : p.nameAr,
                  time: fmtTime(app.local(today[p]), s.use24h),
                  isNext: st.next == p && st.nextTime == today[p],
                  isCurrent: st.current == p && DateTime.now().toUtc().isAfter(today[p]),
                  passed: today[p].isBefore(DateTime.now().toUtc()),
                  notify: s.notify[p] ?? false,
                  onToggle: () => app.update((x) => x.notify[p] = !(x.notify[p] ?? false)),
                  log: p.isObligatory && !today[p].isAfter(DateTime.now().toUtc()) ? app.tracker.day(app.today).of(p) : null,
                  onLog: () => showPrayerLogSheet(context, app.today, p),
                ),
              const SunanCard(),
              if (app.isWeb)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('ملاحظة: نسخة المتصفح لا تُرسل إشعارات في الخلفية. لتنبيهات الأذان استخدم تطبيق أندرويد أو برنامج الكمبيوتر.',
                      style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final IconData icon;
  final String name, time;
  final bool isNext, isCurrent, passed, notify;
  final VoidCallback onToggle;
  /// How the prayer was logged today (null = not loggable yet / sunrise).
  final PrayerLog? log;
  final VoidCallback onLog;
  const _PrayerRow({required this.icon, required this.name, required this.time, required this.isNext,
      required this.isCurrent, required this.passed, required this.notify, required this.onToggle,
      required this.log, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = isNext ? AppColors.gold : (isCurrent ? AppColors.emerald : null);
    return Opacity(
      opacity: passed && !isCurrent && log == null ? 0.6 : 1,
      child: Card3D(
        color: isNext ? AppColors.goldSoft : (isCurrent ? AppColors.emerald.withValues(alpha: 0.12) : null),
        shape: highlight == null ? null : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: highlight)),
        child: ListTile(
          leading: Tile3D(size: 40, gold: isNext, child: Icon(icon, color: isNext ? AppColors.navy : AppColors.goldLight, size: 21)),
          title: Row(children: [
            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (isNext || isCurrent)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(8)),
                child: Text(isNext ? 'القادمة' : 'الآن', style: TextStyle(fontSize: 11, color: AppColors.navy, fontWeight: FontWeight.w700)),
              ),
          ]),
          subtitle: log == null
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onLog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: log == PrayerLog.none ? null : _logColor(log!).withValues(alpha: 0.16),
                          border: log == PrayerLog.none ? Border.all(color: theme.hintColor.withValues(alpha: 0.5)) : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(log == PrayerLog.none ? '＋ سجّل صلاتك' : '${log!.emoji} ${log!.label}',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                                color: log == PrayerLog.none ? theme.hintColor : _logColor(log!))),
                      ),
                    ),
                  ),
                ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time, textDirection: TextDirection.ltr, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: notify ? 'إيقاف التنبيه' : 'تفعيل التنبيه',
              icon: Icon(notify ? Icons.notifications_active : Icons.notifications_off_outlined,
                  color: notify ? AppColors.emerald : theme.hintColor, size: 20),
              onPressed: onToggle,
            ),
          ]),
        ),
      ),
    );
  }
}

Color _logColor(PrayerLog l) => switch (l) {
      PrayerLog.mosque => const Color(0xFF2FD39A),
      PrayerLog.jamaah => const Color(0xFF7FB0FF),
      PrayerLog.alone => AppColors.gold,
      PrayerLog.qada => const Color(0xFFE57373),
      PrayerLog.none => Colors.grey,
    };

/// "How did you pray it?" — logs the prayer for the statistics.
void showPrayerLogSheet(BuildContext context, DateTime date, Prayer p) {
  final current = app.tracker.day(date).of(p);
  final name = p == Prayer.dhuhr && date.weekday == DateTime.friday ? 'الجمعة' : p.nameAr;
  showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('صلاة $name — كيف صليتها؟', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        for (final l in PrayerLog.values.skip(1))
          ListTile(
            leading: Text(l.emoji, style: const TextStyle(fontSize: 22)),
            title: Text(l.longLabel),
            trailing: current == l ? Icon(Icons.check_circle, color: AppColors.emerald) : null,
            onTap: () async {
              Navigator.pop(c);
              await app.logPrayer(date, p, l);
              if (!context.mounted) return;
              final streak = app.tracker.prayersStreak(app.today);
              final d = app.tracker.day(date);
              String? msg;
              if (d.allFiveOnTime && const [3, 7, 14, 21, 30, 40, 60, 100, 200, 365].contains(streak)) {
                msg = '🔥 أحسنت! ${Arabic.digits(streak)} أيام متتالية للصلوات الخمس. أحب الأعمال إلى الله أدومها وإن قلّ.';
              } else if (d.prayersDone == 5) {
                msg = 'أتممت الصلوات الخمس اليوم، تقبّل الله منك 🤍';
              } else if (l == PrayerLog.mosque) {
                msg = 'صلاة الجماعة تفضل صلاة الفذّ بسبع وعشرين درجة 🤍';
              }
              if (msg != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
        if (current != PrayerLog.none)
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              app.logPrayer(date, p, PrayerLog.none);
            },
            child: const Text('إلغاء التسجيل'),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('البيانات محفوظة على جهازك فقط', style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
        ),
      ]),
    ),
  );
}

/// Today's prayers, adhkar and wird in one ring.
class TodayHarvest extends StatelessWidget {
  const TodayHarvest();
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([app, app.tracker]), builder: (context, _) => _card(context));

  Widget _card(BuildContext context) {
    final t = app.tracker;
    final day = t.day(app.today);
    final value = t.completion(app.today);
    final goal = app.settings.wirdGoal;
    final left = <String>[
      if (day.prayersDone < 5) '${Arabic.digits(5 - day.prayersDone)} صلوات',
      if (!day.morning) 'أذكار الصباح',
      if (!day.evening) 'أذكار المساء',
      if (goal > 0 && day.tasbeeh < goal) 'الورد',
    ];
    Widget chip(String text, bool done, [VoidCallback? onTap]) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: done ? Colors.white30 : Colors.white12, borderRadius: BorderRadius.circular(10)),
            child: Text(done ? '$text ✓' : text, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
          ),
        );
    return Card3D(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsPage())),
        child: Container(
          decoration: BoxDecoration(gradient: heroGradient),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(value: value, strokeWidth: 6, color: AppColors.goldLight, backgroundColor: Colors.white24),
                ),
                Text('${Arabic.digits((value * 100).round())}٪', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('حصاد اليوم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const Spacer(),
                  Text('إحصائياتي ›', style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                ]),
                Text(left.isEmpty ? 'أتممت يومك، تقبّل الله منك 🤍' : 'باقي: ${left.join('، ')}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.heroText, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  chip('🕌 ${Arabic.digits(day.prayersDone)}/٥', day.prayersDone == 5),
                  chip('☀️ الصباح', day.morning, () => t.setAdhkar(app.today, morning: true, done: !day.morning)),
                  chip('🌙 المساء', day.evening, () => t.setAdhkar(app.today, morning: false, done: !day.evening)),
                  if (goal > 0) chip('📿 ${Arabic.digits(day.tasbeeh)}/${Arabic.digits(goal)}', day.tasbeeh >= goal),
                  if (app.khatmaDaily > 0) chip('📖 ${Arabic.digits(app.pagesToday)}/${Arabic.digits(app.khatmaDaily)}', app.pagesToday >= app.khatmaDaily),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}


/// On Friday (from Thursday's Maghrib): Surat al-Kahf with how many of its pages were opened.
class KahfCard extends StatelessWidget {
  const KahfCard();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (app.kahfFriday == null || !app.settings.fridayKahf) return const SizedBox.shrink();
        final read = app.kahfRead, total = app.kahfTotal;
        final done = read >= total;
        return Card3D(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: InkWell(
            onTap: app.openKahf,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(children: [
                Row(children: [
                  const Tile3D(child: Text('📖', style: TextStyle(fontSize: 21))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('سورة الكهف — يوم الجمعة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(done ? '✓ أتممتها، تقبّل الله منك' : (read == 0 ? 'اضغط لتبدأ القراءة' : 'تابع من حيث توقفت'),
                          style: TextStyle(fontSize: 12.5, color: done ? AppColors.emerald : Theme.of(context).hintColor)),
                    ]),
                  ),
                  Text('${Arabic.digits(read)} / ${Arabic.digits(total)}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(value: read / total, minHeight: 5, color: AppColors.gold),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}


/// The next prayer with its countdown (home page).
class NextPrayerHero extends StatelessWidget {
  const NextPrayerHero({super.key});
  // Compact: one row for the prayer and its time, one row for the countdown.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.settings;
        final st = app.status();
        final isFriday = app.now.weekday == DateTime.friday;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: hero3D(radius: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الصلاة القادمة', style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(st.next == Prayer.dhuhr && isFriday ? 'الجمعة' : st.next.nameAr,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(width: 8),
                  Padding(padding: const EdgeInsets.only(bottom: 5),
                      child: Text(fmtTime(app.local(st.nextTime), s.use24h), style: TextStyle(color: AppColors.goldLight, fontSize: 15))),
                ]),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('الوقت المتبقي', style: TextStyle(color: AppColors.heroText, fontSize: 12)),
                Text(fmtCountdown(st.remaining), textDirection: TextDirection.ltr,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1.3)),
              ]),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: st.progress, minHeight: 5, backgroundColor: Colors.white24, color: AppColors.goldLight),
            ),
          ]),
        );
      },
    );
  }
}

/// The confirmed sunnahs of the day (الرواتب، الضحى، الوتر), tapped when done.
class SunanCard extends StatelessWidget {
  const SunanCard({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.tracker,
      builder: (context, _) {
        final t = app.tracker;
        final d = t.day(app.today);
        return Card3D(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text('السنن والنوافل', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const Spacer(),
                Text('${Arabic.digits(d.sunanDone)} / ${Arabic.digits(Sunnah.values.length)}',
                    style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in Sunnah.values)
                  FilterChip(
                    label: Text(s.label),
                    tooltip: s.detail,
                    selected: d.did(s),
                    onSelected: (v) => t.setSunnah(app.today, s, v),
                  ),
              ]),
              const SizedBox(height: 6),
              Text('«ما من عبدٍ مسلمٍ يصلّي لله كل يومٍ ثنتي عشرة ركعةً تطوعًا غير فريضة إلا بنى الله له بيتًا في الجنة» — صحيح مسلم ٧٢٨',
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor, height: 1.6)),
            ]),
          ),
        );
      },
    );
  }
}


/// السنن والنوافل as its own page (from «المزيد»).
class SunanPage extends StatelessWidget {
  const SunanPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('السنن والنوافل')),
        body: ListView(padding: const EdgeInsets.only(top: 4, bottom: 20), children: const [SunanCard()]),
      );
}


/// Shown when Android 12+ does not allow exact alarms: without it the adhan can come late or not at all.
class ExactAlarmBanner extends StatefulWidget {
  const ExactAlarmBanner({super.key});
  @override
  State<ExactAlarmBanner> createState() => _ExactAlarmBannerState();
}

class _ExactAlarmBannerState extends State<ExactAlarmBanner> with WidgetsBindingObserver {
  bool _exact = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final ok = await app.notifications.canExactAlarms();
    if (!mounted) return;
    if (ok && !_exact) unawaited(app.notifications.schedule(app)); // just allowed: plan the adhans again
    setState(() => _exact = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_exact || !app.settings.adhanEnabled) return const SizedBox.shrink();
    return Card3D(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.alarm_off, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            const Expanded(child: Text('الأذان قد يتأخر أو لا يعمل', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          const Text('اسمح للتطبيق بـ«المنبهات والتذكيرات» ليؤذّن في وقت كل صلاة تمامًا، حتى والهاتف في وضع توفير الطاقة.',
              style: TextStyle(fontSize: 13, height: 1.6)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: app.notifications.requestExactAlarms,
              icon: const Icon(Icons.settings),
              label: const Text('السماح الآن'),
            ),
          ),
        ]),
      ),
    );
  }
}
