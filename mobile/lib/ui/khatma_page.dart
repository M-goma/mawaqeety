import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../main.dart';
import '../services/app_state.dart';
import 'mushaf_page.dart';
import 'theme.dart';

const _plans = [7, 10, 15, 20, 30, 60];

String _pages(int n) {
  if (n == 1) return 'صفحة واحدة';
  if (n == 2) return 'صفحتان';
  return n >= 3 && n <= 10 ? '${Arabic.digits(n)} صفحات' : '${Arabic.digits(n)} صفحة';
}

String _planLabel(int d) => d == 7 ? 'أسبوع' : d == 30 ? 'شهر' : d == 60 ? 'شهران' : '${Arabic.digits(d)} يومًا';

/// The Quran tab's card: today's wird and the khatma progress.
class KhatmaCard extends StatelessWidget {
  const KhatmaCard({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.settings;
        final open = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KhatmaPage()));
        if (s.khatmaDays <= 0) {
          return Card3D(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: ListTile(
              leading: const Tile3D(size: 40, child: Text('📖', style: TextStyle(fontSize: 19))),
              title: const Text('ورد القرآن والختمة', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('حدّد مدة ختمتك ونحسب لك ورد كل يوم'),
              trailing: const Icon(Icons.chevron_left),
              onTap: open,
            ),
          );
        }
        final daily = app.khatmaDaily, today = app.pagesToday;
        final left = (app.khatmaTarget - s.khatmaPage).clamp(0, AppState.mushafPages);
        return Card3D(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                const Tile3D(size: 40, child: Text('📖', style: TextStyle(fontSize: 19))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('وردك اليوم', style: TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${Arabic.digits(today)} / ${Arabic.digits(daily)}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(value: s.khatmaPage / AppState.mushafPages, minHeight: 6),
                    ),
                    const SizedBox(height: 3),
                    Text(left == 0 ? 'أنت على الخطة • الختمة ${Arabic.digits((s.khatmaPage * 100 / AppState.mushafPages).round())}٪'
                        : 'باقي ${_pages(left)} لتلحق بخطتك',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class KhatmaPage extends StatelessWidget {
  const KhatmaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.tracker]),
      builder: (context, _) {
        final s = app.settings;
        final theme = Theme.of(context);
        final active = s.khatmaDays > 0;
        final next = (s.khatmaPage + 1).clamp(1, AppState.mushafPages);
        var week = 0;
        for (var i = 0; i < 7; i++) {
          week += app.tracker.day(app.today.subtract(Duration(days: i))).pages;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('ورد القرآن والختمة')),
          body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              padding: const EdgeInsets.all(18),
              decoration: hero3D(radius: 22),
              child: active
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ختمة في ${_planLabel(s.khatmaDays)} • اليوم ${Arabic.digits(app.khatmaDay)}',
                          style: TextStyle(color: AppColors.heroText, fontSize: 14)),
                      Text('وصلت إلى صفحة ${Arabic.digits(s.khatmaPage)}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: s.khatmaPage / AppState.mushafPages, minHeight: 8,
                            color: AppColors.goldLight, backgroundColor: Colors.white24),
                      ),
                      const SizedBox(height: 6),
                      Text('وردك اليومي ${_pages(app.khatmaDaily)} • المطلوب حتى اليوم: صفحة ${Arabic.digits(app.khatmaTarget)}',
                          style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        icon: const Icon(Icons.menu_book),
                        label: Text('أكمل من صفحة ${Arabic.digits(next)}'),
                        onPressed: () => openMushaf(context, next),
                      ),
                    ])
                  : const Row(children: [
                      Text('📖', style: TextStyle(fontSize: 38)),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text('اختر مدة الختمة، فنحسب ورد كل يوم، ونتابع تقدّمك تلقائيًا من صفحات المصحف التي تقرؤها.',
                            style: TextStyle(color: Colors.white, height: 1.7)),
                      ),
                    ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(active ? 'تغيير المدة (يبدأ ختمة جديدة)' : 'مدة الختمة', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in _plans)
                  ChoiceChip(
                    label: Text('${_planLabel(d)} • ${_pages((AppState.mushafPages / d).ceil())}'),
                    selected: s.khatmaDays == d,
                    onSelected: (_) => _confirmStart(context, d),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _stat(context, '🏁', Arabic.digits(s.khatmaDone), 'ختمات أتممتها'),
                _stat(context, '📄', Arabic.digits(app.pagesToday), 'صفحات اليوم'),
                _stat(context, '📅', Arabic.digits(week), 'صفحات الأسبوع'),
              ]),
            ),
            Card3D(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('ذكّرني بوردي كل يوم'),
                  subtitle: const Text('بعد صلاة الفجر بنصف ساعة', style: TextStyle(fontSize: 12)),
                  value: s.khatmaReminder,
                  onChanged: active ? (v) => app.update((x) => x.khatmaReminder = v) : null,
                ),
                if (active)
                  ListTile(
                    leading: const Icon(Icons.stop_circle_outlined),
                    title: const Text('إيقاف الخطة'),
                    onTap: () => app.stopKhatma(),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text('تُحسب الصفحة مقروءة حين تفتحها في المصحف. وتكتمل الختمة عند بلوغ آخر صفحة بعد قراءة المصحف بالترتيب.',
                  style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.6)),
            ),
          ]),
        );
      },
    );
  }

  void _confirmStart(BuildContext context, int days) {
    if (app.settings.khatmaDays <= 0 || app.settings.khatmaPage == 0) {
      app.startKhatma(days);
      return;
    }
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ختمة جديدة؟'),
        content: Text('ستبدأ ختمة جديدة في ${_planLabel(days)} من الصفحة الأولى.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(onPressed: () { Navigator.pop(c); app.startKhatma(days); }, child: const Text('ابدأ')),
        ],
      ),
    );
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
}
