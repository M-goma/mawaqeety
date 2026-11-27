import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../main.dart';
import '../services/tracker.dart';
import 'theme.dart';

const _weekDays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

/// Statistics to encourage completing each day: weekly completion, streaks, how prayers were prayed, the month.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.tracker]),
      builder: (context, _) {
        final t = app.tracker;
        final today = app.today;
        final from = _month ? DateTime(today.year, today.month, 1) : today.subtract(const Duration(days: 6));
        final dist = t.distribution(from, today);
        final total = dist.values.fold<int>(0, (a, b) => a + b);
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('إحصائياتي')),
          body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('آخر ٧ أيام')), ButtonSegment(value: true, label: Text('هذا الشهر'))],
                selected: {_month},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _month = v.first),
              ),
            ),
            // Streaks
            Row(children: [
              _Streak('🔥', t.prayersStreak(today), 'أيام الصلوات الخمس'),
              _Streak('🕌', t.fajrMosqueStreak(today), 'الفجر في المسجد'),
              _Streak('☀️', t.morningStreak(today), 'أذكار الصباح'),
            ]),
            // Daily completion
            Card3D(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('اكتمال الأيام', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('الصلوات الخمس + أذكار الصباح والمساء + وردك من التسبيح', style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
                  const SizedBox(height: 10),
                  if (!_month)
                    SizedBox(
                      height: 130,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 6; i >= 0; i--)
                          _Bar(t.completion(today.subtract(Duration(days: i))), _weekDays[today.subtract(Duration(days: i)).weekday - 1], i == 0),
                      ]),
                    )
                  else
                    _MonthGrid(today),
                ]),
              ),
            ),
            // How the prayers were prayed
            Card3D(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('صلواتك المسجّلة (${Arabic.digits(total)} صلاة)', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (total == 0)
                    Text('سجّل صلواتك من شاشة المواقيت لتظهر هنا.', style: TextStyle(color: theme.hintColor))
                  else
                    for (final l in PrayerLog.values.skip(1))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          SizedBox(width: 128, child: Text('${l.emoji} ${l.label}', style: const TextStyle(fontSize: 13))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: dist[l]! / total, minHeight: 8, color: _color(l)),
                            ),
                          ),
                          SizedBox(width: 44, child: Text('${Arabic.digits((dist[l]! * 100 / total).round())}٪', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5))),
                        ]),
                      ),
                ]),
              ),
            ),
            // Tasbeeh
            Card3D(
              child: ListTile(
                leading: const Text('📿', style: TextStyle(fontSize: 24)),
                title: Text('${Arabic.digits(t.tasbeehBetween(from, today))} تسبيحة'),
                subtitle: Text(_month ? 'هذا الشهر' : 'آخر ٧ أيام'),
              ),
            ),
            Builder(builder: (context) {
              var sunan = 0, pages = 0, days = 0;
              for (var d = from; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
                sunan += t.day(d).sunanDone;
                pages += t.day(d).pages;
                days++;
              }
              return Card3D(
                child: Column(children: [
                  ListTile(
                    leading: const Text('✨', style: TextStyle(fontSize: 24)),
                    title: Text('${Arabic.digits(sunan)} من ${Arabic.digits(days * Sunnah.values.length)} سنة'),
                    subtitle: const Text('الرواتب والضحى والوتر'),
                  ),
                  ListTile(
                    leading: const Text('📖', style: TextStyle(fontSize: 24)),
                    title: Text(Arabic.pages(pages)),
                    subtitle: const Text('قرأتها من المصحف'),
                  ),
                ]),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _quote(today),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gold, height: 1.8),
              ),
            ),
            Text('البيانات محفوظة على جهازك فقط، ولا تُرسل لأي مكان.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.hintColor)),
          ]),
        );
      },
    );
  }

  static String _quote(DateTime d) => const [
        '«صلاةُ الجماعةِ تَفضُلُ صلاةَ الفذِّ بسبعٍ وعشرين درجة» — متفق عليه',
        '«أحبُّ الأعمالِ إلى اللهِ أدومُها وإن قلّ» — متفق عليه',
        '«مَن صلّى العشاءَ في جماعةٍ فكأنما قام نصفَ الليل، ومَن صلّى الصبحَ في جماعةٍ فكأنما صلّى الليلَ كلَّه» — رواه مسلم',
        '«كلمتان خفيفتان على اللسان، ثقيلتان في الميزان: سبحان الله وبحمده، سبحان الله العظيم» — متفق عليه',
        '«ألا بذكرِ اللهِ تطمئنُّ القلوب» — الرعد ٢٨',
      ][d.day % 5];

  static Color _color(PrayerLog l) => switch (l) {
        PrayerLog.mosque => const Color(0xFF12A372),
        PrayerLog.jamaah => const Color(0xFF3B82F6),
        PrayerLog.alone => AppColors.gold,
        PrayerLog.qada => const Color(0xFFE57373),
        PrayerLog.none => Colors.grey,
      };
}

class _Streak extends StatelessWidget {
  final String icon, label;
  final int days;
  const _Streak(this.icon, this.days, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card3D(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(children: [
              Text('$icon ${Arabic.digits(days)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(days == 1 ? 'يوم' : 'أيام متتالية', style: TextStyle(fontSize: 11, color: AppColors.gold)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
            ]),
          ),
        ),
      );
}

class _Bar extends StatelessWidget {
  final double value;
  final String label;
  final bool isToday;
  const _Bar(this.value, this.label, this.isToday);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(value > 0 ? '${Arabic.digits((value * 100).round())}٪' : '', style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 2),
          Container(
            height: 6 + 86 * value,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.emerald, AppColors.emerald.withValues(alpha: 0.6)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
        ]),
      );
}

/// The month as a grid; darker squares = more complete days.
class _MonthGrid extends StatelessWidget {
  final DateTime today;
  const _MonthGrid(this.today);
  @override
  Widget build(BuildContext context) {
    final first = DateTime(today.year, today.month, 1);
    final days = DateTime(today.year, today.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${_months[today.month - 1]} ${Arabic.digits(today.year)}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          for (var i = 0; i < lead; i++) const SizedBox.shrink(),
          for (var d = 1; d <= days; d++)
            () {
              final date = DateTime(today.year, today.month, d);
              final v = date.isAfter(today) ? -1.0 : app.tracker.completion(date);
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v < 0 ? Colors.transparent : (v == 0 ? AppColors.navy3 : AppColors.emerald.withValues(alpha: 0.25 + 0.75 * v)),
                  border: date == today ? Border.all(color: AppColors.gold, width: 2) : (v < 0 ? Border.all(color: AppColors.navy3) : null),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(Arabic.digits(d), style: const TextStyle(fontSize: 11)),
              );
            }(),
        ],
      ),
    ]);
  }
}
