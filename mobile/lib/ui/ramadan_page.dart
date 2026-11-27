import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../main.dart';
import '../services/app_state.dart';
import 'format.dart';
import 'theme.dart';

const _rakahOptions = [0, 8, 11, 20, 23];

String _days(int n) {
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومان';
  return n >= 3 && n <= 10 ? '${Arabic.digits(n)} أيام' : '${Arabic.digits(n)} يومًا';
}

String _nights(int n) {
  if (n == 1) return 'ليلة واحدة';
  if (n == 2) return 'ليلتان';
  return n >= 3 && n <= 10 ? '${Arabic.digits(n)} ليالٍ' : '${Arabic.digits(n)} ليلة';
}

Widget _stat(BuildContext context, String emoji, String value, String label) => Expanded(
      child: Card3D(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gold)),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
          ]),
        ),
      ),
    );

Widget _hadith(BuildContext context, String text, String ref) => Card3D(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(text, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 17, height: 1.9)),
          Text(ref, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
        ]),
      ),
    );

/// رمضان: the fast, taraweeh and tahajjud of each day, with Ramadan's own statistics.
class RamadanPage extends StatelessWidget {
  const RamadanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.tracker]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final today = app.today;
        final h = app.hijriOf(today);
        final inRamadan = h.hMonth == 9;
        // The Ramadan to show: this one, else the last one; and the next one for the countdown.
        final shownYear = inRamadan || h.hMonth > 9 ? h.hYear : h.hYear - 1;
        final nextYear = h.hMonth < 9 ? h.hYear : h.hYear + 1;
        final start = app.fromHijri(shownYear, 9, 1);
        final len = app.hijriMonthLength(shownYear, 9);
        final nextStart = app.fromHijri(nextYear, 9, 1);
        final t = app.tracker;
        final days = [for (var i = 0; i < len; i++) start.add(Duration(days: i))];
        final logs = [for (final d in days) t.day(d)];
        final fasted = logs.where((d) => d.fast).length;
        final taraweeh = logs.where((d) => d.taraweeh > 0).length;
        final rakahs = logs.fold<int>(0, (a, d) => a + d.taraweeh);
        final tahajjud = logs.where((d) => d.tahajjud).length;
        final todayLog = t.day(today);
        final monthStart = DateTime(today.year, today.month, 1);
        var qiyamMonth = 0;
        for (var d = monthStart; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
          if (t.day(d).tahajjud) qiyamMonth++;
        }

        return Scaffold(
          appBar: const _Bar('رمضان'),
          body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              padding: const EdgeInsets.all(18),
              decoration: hero3D(radius: 22),
              child: Row(children: [
                const Text('🌙', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (inRamadan) ...[
                      Text('رمضان ${Arabic.digits(h.hYear)} هـ', style: TextStyle(color: AppColors.heroText, fontSize: 14)),
                      Text('اليوم ${Arabic.digits(h.hDay)} من ${Arabic.digits(len)}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: h.hDay / len, minHeight: 7,
                            color: AppColors.goldLight, backgroundColor: Colors.white24),
                      ),
                    ] else ...[
                      Text('رمضان ${Arabic.digits(nextYear)} هـ', style: TextStyle(color: AppColors.heroText, fontSize: 14)),
                      Text('باقي ${_days(nextStart.difference(today).inDays)}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                      Text('يبدأ تقريبًا ${fmtGregorian(nextStart)}', style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                    ],
                  ]),
                ),
              ]),
            ),
            _Section(inRamadan ? 'اليوم' : 'قيام الليل'),
            Card3D(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                if (inRamadan)
                  SwitchListTile(
                    secondary: const Text('🍽️', style: TextStyle(fontSize: 22)),
                    title: const Text('صمت اليوم'),
                    value: todayLog.fast,
                    onChanged: (v) => t.setFast(today, v),
                  ),
                if (inRamadan)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Text('🕌', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 16),
                        Text('صلاة التراويح', style: TextStyle(fontSize: 16)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final r in _rakahOptions)
                          ChoiceChip(
                            label: Text(r == 0 ? 'لم أصلِّ' : '${Arabic.digits(r)} ركعة'),
                            selected: todayLog.taraweeh == r,
                            onSelected: (_) => t.setTaraweeh(today, r),
                          ),
                      ]),
                    ]),
                  ),
                SwitchListTile(
                  secondary: const Text('✨', style: TextStyle(fontSize: 22)),
                  title: const Text('قمت الليل (التهجد)'),
                  subtitle: inRamadan ? null : Text('هذا الشهر: ${_nights(qiyamMonth)}', style: const TextStyle(fontSize: 12)),
                  value: todayLog.tahajjud,
                  onChanged: (v) => t.setTahajjud(today, v),
                ),
              ]),
            ),
            _Section('إحصائية رمضان ${Arabic.digits(shownYear)} هـ'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _stat(context, '🍽️', '${Arabic.digits(fasted)}/${Arabic.digits(len)}', 'أيام الصيام'),
                _stat(context, '🕌', Arabic.digits(taraweeh), 'ليالي التراويح\n${Arabic.digits(rakahs)} ركعة'),
                _stat(context, '✨', Arabic.digits(tahajjud), 'ليالي التهجد'),
              ]),
            ),
            Card3D(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (var i = 0; i < len; i++) _DayCell(i + 1, logs[i].fast, logs[i].taraweeh > 0, logs[i].tahajjud,
                          lastTen: i >= 20, isToday: inRamadan && days[i] == today),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('🍽️ صيام  •  🕌 تراويح  •  ✨ تهجد  •  الإطار الذهبي: العشر الأواخر',
                      style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
                ]),
              ),
            ),
            _hadith(context, '«مَن قامَ رَمَضانَ إيمانًا واحْتِسابًا، غُفِرَ له ما تَقَدَّمَ مِن ذَنْبِهِ»',
                'صحيح البخاري ٣٧ • صحيح مسلم ٧٥٩'),
          ]),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool fast, taraweeh, tahajjud, lastTen, isToday;
  const _DayCell(this.day, this.fast, this.taraweeh, this.tahajjud, {this.lastTen = false, this.isToday = false});
  @override
  Widget build(BuildContext context) {
    final n = (fast ? 1 : 0) + (taraweeh ? 1 : 0) + (tahajjud ? 1 : 0);
    final p = AppColors.current;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: n == 0 ? Theme.of(context).hintColor.withValues(alpha: 0.10) : p.primary.withValues(alpha: 0.25 + 0.25 * n),
        border: Border.all(color: isToday ? Colors.white : (lastTen ? AppColors.gold : Colors.transparent), width: isToday ? 2 : 1.2),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(Arabic.digits(day), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text('${fast ? '🍽️' : ''}${taraweeh ? '🕌' : ''}${tahajjud ? '✨' : ''}', style: const TextStyle(fontSize: 8.5)),
      ]),
    );
  }
}

/// الأيام البيض: the 13th, 14th and 15th of each Hijri month.
class WhiteDaysPage extends StatelessWidget {
  const WhiteDaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.tracker]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final today = app.today;
        final h = app.hijriOf(today);
        // This month's white days, or next month's once they have passed.
        var y = h.hYear, m = h.hMonth;
        if (h.hDay > 15) {
          m++;
          if (m > 12) { m = 1; y++; }
        }
        final next = [for (final d in [13, 14, 15]) app.fromHijri(y, m, d)];
        final t = app.tracker;
        // This Hijri year, month by month.
        final months = <(int, List<bool>, bool)>[]; // month, fasted per day, already passed/started
        var total = 0;
        for (var mm = 1; mm <= h.hMonth; mm++) {
          final ds = [for (final d in [13, 14, 15]) app.fromHijri(h.hYear, mm, d)];
          final f = [for (final d in ds) t.day(d).fast];
          total += f.where((x) => x).length;
          months.add((mm, f, !ds.first.isAfter(today)));
        }
        String hijriLabel(DateTime d) {
          final x = app.hijriOf(d);
          return '${Arabic.digits(x.hDay)} ${AppState.hijriMonths[x.hMonth - 1]}';
        }

        return Scaffold(
          appBar: const _Bar('الأيام البيض'),
          body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              padding: const EdgeInsets.all(18),
              decoration: hero3D(radius: 22),
              child: Row(children: [
                const Text('🤍', style: TextStyle(fontSize: 38)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('الأيام البيض القادمة', style: TextStyle(color: AppColors.heroText, fontSize: 14)),
                    Text('${Arabic.digits(13)}–${Arabic.digits(15)} ${AppState.hijriMonths[m - 1]}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    Text(next.first == today
                            ? 'تبدأ اليوم'
                            : next.first.isAfter(today) ? 'بعد ${_days(next.first.difference(today).inDays)}' : 'الآن',
                        style: TextStyle(color: AppColors.goldLight, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            Card3D(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                for (final d in next)
                  CheckboxListTile(
                    secondary: Text(Arabic.digits(app.hijriOf(d).hDay),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gold)),
                    title: Text(fmtGregorian(d)),
                    subtitle: Text(d.isAfter(today) ? hijriLabel(d) : '${hijriLabel(d)} • هل صمته؟', style: const TextStyle(fontSize: 12)),
                    value: t.day(d).fast,
                    // A day can be marked only once it has come.
                    onChanged: d.isAfter(today) ? null : (v) => t.setFast(d, v ?? false),
                  ),
              ]),
            ),
            Card3D(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('ذكّرني مساء اليوم السابق'),
                subtitle: const Text('قبل كل أيام بيض بليلة', style: TextStyle(fontSize: 12)),
                value: app.settings.whiteDaysReminder,
                onChanged: (v) => app.update((x) => x.whiteDaysReminder = v),
              ),
            ),
            _Section('إحصائية ${Arabic.digits(h.hYear)} هـ • ${_days(total)}'),
            Card3D(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  for (final (mm, f, started) in months.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      child: Row(children: [
                        Expanded(child: Text(AppState.hijriMonths[mm - 1], style: const TextStyle(fontSize: 14.5))),
                        for (final x in f)
                          Container(
                            width: 26, height: 26, margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: x ? AppColors.current.primary : Colors.transparent,
                              border: Border.all(color: x ? AppColors.current.primary : theme.hintColor.withValues(alpha: started ? 0.6 : 0.25)),
                            ),
                            child: x ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                      ]),
                    ),
                ]),
              ),
            ),
            _hadith(context,
                'عن أبي هريرة رضي الله عنه قال: «أوصاني خليلي ﷺ بثلاث: صيام ثلاثة أيام من كل شهر، وركعتي الضحى، وأن أوتر قبل أن أنام»',
                'صحيح البخاري ١٩٨١ • صحيح مسلم ٧٢١'),
          ]),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _Bar(this.title);
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(title: Text(title));
}
