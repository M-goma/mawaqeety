import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/occasions.dart';
import '../main.dart';
import '../services/app_state.dart';
import 'format.dart';
import 'hajj_page.dart';
import 'theme.dart';

/// The next start of [o] on or after [from] (local days).
DateTime nextOccasion(Occasion o, DateTime from) {
  final h = app.hijriOf(from);
  for (var y = h.hYear; y <= h.hYear + 1; y++) {
    final start = app.fromHijri(y, o.month, o.day);
    final end = start.add(Duration(days: o.days - 1));
    if (!end.isBefore(from)) return start;
  }
  return app.fromHijri(h.hYear + 1, o.month, o.day);
}

/// Voluntary fasts that fall on [d]: the occasion, the white days, or Monday/Thursday.
String? sunnahFastOn(DateTime d) {
  final h = app.hijriOf(d);
  for (final o in occasions.where((o) => o.isFast && o.id != 'shawwal')) {
    if (h.hMonth == o.month && h.hDay == o.day) return o.name;
  }
  if (h.hMonth == 10 && h.hDay >= 2) return 'ستٌّ من شوال';
  if (h.hMonth != 9 && h.hDay >= 13 && h.hDay <= 15) return 'الأيام البيض';
  if (h.hMonth != 9 && d.weekday == DateTime.monday) return 'صيام الاثنين';
  if (h.hMonth != 9 && d.weekday == DateTime.thursday) return 'صيام الخميس';
  return null;
}

String _days(int n) {
  if (n == 0) return 'اليوم';
  if (n == 1) return 'غدًا';
  if (n == 2) return 'بعد يومين';
  return n <= 10 ? 'بعد ${Arabic.digits(n)} أيام' : 'بعد ${Arabic.digits(n)} يومًا';
}

class OccasionsPage extends StatelessWidget {
  const OccasionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.tracker]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final today = app.today;
        final list = [for (final o in occasions) (o, nextOccasion(o, today))]..sort((a, b) => a.$2.compareTo(b.$2));
        final first = list.first;
        final fastToday = sunnahFastOn(today);
        final t = app.tracker;
        // Voluntary fasts this Hijri year (outside Ramadan).
        final h = app.hijriOf(today);
        var count = 0;
        for (var d = app.fromHijri(h.hYear, 1, 1); !d.isAfter(today); d = d.add(const Duration(days: 1))) {
          if (t.day(d).fast && app.hijriOf(d).hMonth != 9) count++;
        }
        final inProgress = !first.$2.isAfter(today);

        return Scaffold(
          appBar: AppBar(title: const Text('المناسبات وصيام السنن')),
          body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              padding: const EdgeInsets.all(18),
              decoration: hero3D(radius: 22),
              child: Row(children: [
                const Text('🗓️', style: TextStyle(fontSize: 38)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inProgress ? 'الآن' : 'المناسبة القادمة', style: TextStyle(color: AppColors.heroText, fontSize: 14)),
                    Text(first.$1.name, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700)),
                    Text(inProgress ? fmtGregorian(today) : '${_days(first.$2.difference(today).inDays)} • ${fmtGregorian(first.$2)}',
                        style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
            if (fastToday != null)
              Card3D(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: CheckboxListTile(
                  secondary: const Text('🍽️', style: TextStyle(fontSize: 22)),
                  title: Text('اليوم: $fastToday'),
                  subtitle: const Text('هل صمت اليوم؟', style: TextStyle(fontSize: 12)),
                  value: t.day(today).fast,
                  onChanged: (v) => t.setFast(today, v ?? false),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('صمت هذا العام الهجري تطوعًا: ${Arabic.digits(count)} ${count >= 3 && count <= 10 ? 'أيام' : 'يومًا'}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (final (o, d) in list) _OccasionTile(o, d, today),
            Card3D(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ListTile(
                  leading: const Text('📅', style: TextStyle(fontSize: 22)),
                  title: const Text('صيام الاثنين والخميس'),
                  subtitle: Text('$monThuNote\n$monThuRef', style: const TextStyle(fontSize: 12, height: 1.6)),
                ),
              ]),
            ),
            Card3D(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Column(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('ذكّرني بالمناسبات وأيام الصيام'),
                  subtitle: const Text('عرفة وعاشوراء وتاسوعاء وغيرها، مساء اليوم السابق', style: TextStyle(fontSize: 12)),
                  value: app.settings.occasionsReminder,
                  onChanged: (v) => app.update((x) => x.occasionsReminder = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.event_repeat),
                  title: const Text('ذكّرني بصيام الاثنين والخميس'),
                  value: app.settings.monThuReminder,
                  onChanged: (v) => app.update((x) => x.monThuReminder = v),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text('التواريخ بالحساب الفلكي، وقد تختلف يومًا عن رؤية الهلال في بلدك؛ يمكنك ضبطها من الإعدادات (تعديل التاريخ الهجري).',
                  style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.6)),
            ),
          ]),
        );
      },
    );
  }
}

class _OccasionTile extends StatelessWidget {
  final Occasion o;
  final DateTime date, today;
  const _OccasionTile(this.o, this.date, this.today);
  @override
  Widget build(BuildContext context) {
    final emoji = switch (o.kind) { OccasionKind.fast => '🍽️', OccasionKind.event => '🌙', OccasionKind.season => '✨', OccasionKind.noFast => '🎉' };
    final now = !date.isAfter(today);
    final h = app.hijriOf(date);
    return Card3D(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        shape: const Border(),
        leading: Text(emoji, style: const TextStyle(fontSize: 22)),
        title: Text(o.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${Arabic.digits(h.hDay)} ${AppState.hijriMonths[h.hMonth - 1]} • ${fmtGregorian(date)}',
            style: const TextStyle(fontSize: 12)),
        trailing: Text(now ? 'الآن' : _days(date.difference(today).inDays),
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12.5)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (o.note.isNotEmpty) Text(o.note, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 16, height: 1.9)),
          if (o.ref.isNotEmpty) Text(o.ref, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
          if (o.month == 12)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.gold, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.mosque_outlined, size: 18),
              label: const Text('دليل الحج والعمرة خطوة بخطوة'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HajjPage(initialTab: 1))),
            ),
        ],
      ),
    );
  }
}
