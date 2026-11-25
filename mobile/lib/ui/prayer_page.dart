import 'package:flutter/material.dart';

import '../core/prayer_calculator.dart';
import '../main.dart';
import 'format.dart';
import 'monthly_page.dart';
import 'qibla_page.dart';
import 'settings_page.dart';
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
      listenable: Listenable.merge([app, app.adhan]),
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
              // Hero
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الصلاة القادمة', style: TextStyle(color: AppColors.heroText, fontSize: 14)),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(st.next == Prayer.dhuhr && isFriday ? 'الجمعة' : st.next.nameAr,
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Padding(padding: const EdgeInsets.only(bottom: 8),
                        child: Text(fmtTime(app.local(st.nextTime), s.use24h), style: TextStyle(color: AppColors.goldLight, fontSize: 18))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('الوقت المتبقي', style: TextStyle(color: AppColors.heroText, fontSize: 13)),
                    const Spacer(),
                    Text(fmtCountdown(st.remaining), textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: st.progress, minHeight: 7,
                        backgroundColor: Colors.white24, color: AppColors.goldLight),
                  ),
                  const SizedBox(height: 10),
                  Text(st.current == null ? 'لا توجد صلاة حاليًا (بعد الشروق)' : 'وقت صلاة ${st.current!.nameAr}',
                      style: TextStyle(color: AppColors.heroText, fontSize: 13)),
                ]),
              ),
              // Adhan control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => app.adhan.isPlaying ? app.adhan.stop() : app.playAdhanForCurrent(),
                      icon: Icon(app.adhan.isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                      label: Text(app.adhan.isPlaying ? 'إيقاف الأذان' : 'تشغيل الأذان'),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QiblaPage())),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('اتجاه القبلة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyPage())),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('التقويم الشهري'),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
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
                ),
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
  const _PrayerRow({required this.icon, required this.name, required this.time, required this.isNext,
      required this.isCurrent, required this.passed, required this.notify, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = isNext ? AppColors.gold : (isCurrent ? AppColors.emerald : null);
    return Opacity(
      opacity: passed && !isCurrent ? 0.6 : 1,
      child: Card(
        color: isNext ? AppColors.goldSoft : (isCurrent ? AppColors.emerald.withValues(alpha: 0.12) : null),
        shape: highlight == null ? null : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: highlight)),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
              child: Icon(icon, color: isNext ? AppColors.gold : AppColors.emerald, size: 20)),
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
