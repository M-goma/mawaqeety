import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/arabic.dart';
import '../data/occasions.dart';
import '../main.dart';
import '../services/app_state.dart';
import 'format.dart';
import 'theme.dart';

const _weekdays = ['سبت', 'أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];

/// Events of a day: Islamic occasions and the white days.
List<String> calendarEvents(DateTime d) {
  final h = app.hijriOf(d);
  final out = <String>[];
  for (final o in occasions) {
    if (h.hMonth == o.month && h.hDay >= o.day && h.hDay < o.day + o.days) {
      // Multi-day seasons are named on their first day only.
      if (o.days == 1 || h.hDay == o.day) out.add(o.name);
    }
  }
  if (h.hMonth != 9 && h.hDay >= 13 && h.hDay <= 15) out.add('الأيام البيض');
  if (h.hDay == 1 && out.every((e) => !e.contains('رمضان') && !e.contains('السنة'))) {
    out.add('بداية ${AppState.hijriMonths[h.hMonth - 1]}');
  }
  return out;
}

/// The Gregorian month with the Hijri date under each day, the occasions and the white days.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = DateTime(app.today.year, app.today.month);

  void _go(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = app.today;
    final first = _month;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final lead = (first.weekday + 1) % 7; // Saturday first
    final hFirst = app.hijriOf(first), hLast = app.hijriOf(DateTime(first.year, first.month, days));
    final hijriSpan = hFirst.hMonth == hLast.hMonth
        ? '${AppState.hijriMonths[hFirst.hMonth - 1]} ${Arabic.digits(hFirst.hYear)} هـ'
        : '${AppState.hijriMonths[hFirst.hMonth - 1]} – ${AppState.hijriMonths[hLast.hMonth - 1]} ${Arabic.digits(hLast.hYear)} هـ';
    final events = <(DateTime, String)>[
      for (var i = 1; i <= days; i++)
        for (final e in calendarEvents(DateTime(first.year, first.month, i))) (DateTime(first.year, first.month, i), e),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('التقويم الميلادي')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: hero3D(radius: 20),
          child: Row(children: [
            IconButton(onPressed: () => _go(-1), icon: const Icon(Icons.chevron_right, color: Colors.white)),
            Expanded(
              child: Column(children: [
                Text(DateFormat('MMMM y', 'ar').format(first),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Text(hijriSpan, style: TextStyle(color: AppColors.goldLight, fontSize: 13)),
              ]),
            ),
            IconButton(onPressed: () => _go(1), icon: const Icon(Icons.chevron_left, color: Colors.white)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(w, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: w == 'جمعة' ? AppColors.gold : theme.hintColor)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 0.78,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= days; d++) _Day(DateTime(first.year, first.month, d), today),
            ],
          ),
        ),
        if (_month.year != today.year || _month.month != today.month)
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.today),
              label: const Text('العودة إلى اليوم'),
              onPressed: () => setState(() => _month = DateTime(today.year, today.month)),
            ),
          ),
        if (events.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text('في هذا الشهر', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Card3D(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (final (d, e) in events)
                ListTile(
                  dense: true,
                  leading: Text(Arabic.digits(d.day),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  title: Text(e),
                  subtitle: Text('${fmtGregorian(d)} • ${app.hijri(d)}', style: const TextStyle(fontSize: 11.5)),
                ),
            ]),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text('التاريخ الهجري بالحساب الفلكي، ويمكن تعديله يومًا أو يومين من الإعدادات بحسب رؤية الهلال في بلدك.',
              style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.6)),
        ),
      ]),
    );
  }
}

class _Day extends StatelessWidget {
  final DateTime d, today;
  const _Day(this.d, this.today);
  @override
  Widget build(BuildContext context) {
    final h = app.hijriOf(d);
    final isToday = d == today;
    final events = calendarEvents(d);
    final white = h.hMonth != 9 && h.hDay >= 13 && h.hDay <= 15;
    final special = events.any((e) => e != 'الأيام البيض' && !e.startsWith('بداية '));
    final p = AppColors.current;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(fmtGregorian(d), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(app.hijri(d), style: TextStyle(color: AppColors.gold, fontSize: 15)),
            const SizedBox(height: 10),
            if (events.isEmpty) Text('لا مناسبة في هذا اليوم', style: TextStyle(color: Theme.of(c).hintColor)),
            for (final e in events) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $e', style: const TextStyle(fontSize: 15))),
          ]),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isToday
              ? p.primary.withValues(alpha: 0.85)
              : special
                  ? AppColors.gold.withValues(alpha: 0.18)
                  : Theme.of(context).hintColor.withValues(alpha: 0.07),
          border: Border.all(color: white ? AppColors.gold.withValues(alpha: 0.7) : Colors.transparent, width: 1.2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(Arabic.digits(d.day),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isToday ? Colors.white : null)),
          Text(Arabic.digits(h.hDay),
              style: TextStyle(fontSize: 11, color: isToday ? Colors.white70 : AppColors.gold)),
          if (special) Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(color: isToday ? Colors.white : AppColors.gold, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
