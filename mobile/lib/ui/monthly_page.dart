import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/prayer_calculator.dart';
import '../main.dart';
import 'format.dart';
import 'theme.dart';

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});
  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  late DateTime _month = DateTime(app.today.year, app.today.month);

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final s = app.settings;
    final today = app.today;
    const headers = ['اليوم', 'الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM y', 'ar').format(_month)),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(s.place.display, style: const TextStyle(color: AppColors.gold))),
        Container(
          color: AppColors.navy3,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [for (final h in headers) Expanded(child: Text(h, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: days,
            itemBuilder: (context, i) {
              final date = DateTime(_month.year, _month.month, i + 1);
              final t = app.day(date);
              final isToday = date == today;
              return Container(
                color: isToday ? AppColors.goldSoft : (date.weekday == DateTime.friday ? AppColors.emerald.withValues(alpha: 0.08) : null),
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  Expanded(child: Text('${DateFormat('E', 'ar').format(date)} ${i + 1}', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400))),
                  for (final p in Prayer.values)
                    Expanded(child: Text(fmtTime(app.local(t[p]), true), textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12.5))),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
