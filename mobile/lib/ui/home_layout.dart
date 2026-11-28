import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../main.dart';
import 'arbaeen_page.dart';
import 'asbab_page.dart';
import 'asma_page.dart';
import 'atlas_page.dart';
import 'calendar_page.dart';
import 'companions_islam_page.dart';
import 'companions_page.dart';
import 'fiqh_page.dart';
import 'ghazawat_page.dart';
import 'hadith_page.dart';
import 'hajj_page.dart';
import 'hifz_page.dart';
import 'hisn_page.dart';
import 'khatma_page.dart';
import 'nasab_page.dart';
import 'occasions_page.dart';
import 'planner_page.dart';
import 'prophets_page.dart';
import 'qibla_page.dart';
import 'quiz_page.dart';
import 'radio_page.dart';
import 'ramadan_page.dart';
import 'seerah_page.dart';
import 'stats_page.dart';
import 'tasbeeh_page.dart';
import 'theme.dart';
import 'zakat_page.dart';

/// A section of the Home tab the user can show, hide and reorder (Settings › تخصيص الصفحة الرئيسية).
class HomeSection {
  final String id, label;
  final IconData icon;
  const HomeSection(this.id, this.label, this.icon);
}

const homeSections = <HomeSection>[
  HomeSection('prayer', 'الصلاة القادمة والعدّ التنازلي', Icons.access_time),
  HomeSection('radio', 'إذاعة القرآن الكريم', Icons.radio),
  HomeSection('harvest', 'حصاد اليوم', Icons.donut_large),
  HomeSection('planner', 'مهام اليوم (من مخطط اليوم)', Icons.checklist),
  HomeSection('kahf', 'تذكير الكهف يوم الجمعة', Icons.menu_book_outlined),
  HomeSection('hadith', 'حديث الصلاة', Icons.format_quote),
  HomeSection('shortcuts', 'الاختصارات', Icons.apps),
  HomeSection('ask', 'اسأل سبيل', Icons.search),
];

/// A page that can be pinned to the Home tab as a shortcut tile: the Home tiles and everything in «المزيد».
class HomeShortcut {
  final String id, emoji, label;
  final Widget Function() page;
  const HomeShortcut(this.id, this.emoji, this.label, this.page);
}

final homeShortcuts = <HomeShortcut>[
  HomeShortcut('prophets', '🐪', 'قصص الأنبياء', () => const ProphetsPage()),
  HomeShortcut('companions', '🌟', 'العشرة المبشرون', () => const CompanionsPage()),
  HomeShortcut('hadith', '📜', 'الأحاديث', () => const HadithPage()),
  HomeShortcut('hisn', '🤲', 'حصن المسلم', () => const HisnPage()),
  HomeShortcut('tasbeeh', '📿', 'السبحة', () => const TasbeehPage()),
  HomeShortcut('qibla', '🧭', 'القبلة', () => const QiblaPage()),
  HomeShortcut('planner', '🗒️', 'مخطط اليوم', () => const PlannerPage()),
  HomeShortcut('seerah', '🕌', 'السيرة النبوية', () => const SeerahPage()),
  HomeShortcut('ghazawat', '⚔️', 'الغزوات', () => const GhazawatPage()),
  HomeShortcut('nasab', '🌳', 'النسب الشريف', () => const NasabPage()),
  HomeShortcut('companions_islam', '🤝', 'إسلام الصحابة', () => const CompanionsIslamPage()),
  HomeShortcut('arbaeen', '📜', 'الأربعون النووية', () => const ArbaeenPage()),
  HomeShortcut('fiqh', '⚖️', 'فقه العبادات', () => const FiqhPage()),
  HomeShortcut('asbab', '📖', 'أسباب النزول', () => const AsbabPage()),
  HomeShortcut('asma', '✨', 'أسماء الله الحسنى', () => const AsmaPage()),
  HomeShortcut('hifz', '🧠', 'مساعد الحفظ', () => const HifzPage()),
  HomeShortcut('khatma', '📗', 'الورد والختمة', () => const KhatmaPage()),
  HomeShortcut('radio', '📻', 'إذاعة القرآن', () => const RadioPage()),
  HomeShortcut('ramadan', '🌙', 'رمضان', () => const RamadanPage()),
  HomeShortcut('white_days', '🤍', 'الأيام البيض', () => const WhiteDaysPage()),
  HomeShortcut('occasions', '🗓️', 'المناسبات', () => const OccasionsPage()),
  HomeShortcut('calendar', '📅', 'التقويم الميلادي', () => const CalendarPage()),
  HomeShortcut('zakat', '💰', 'حاسبة الزكاة', () => const ZakatPage()),
  HomeShortcut('hajj', '🕋', 'الحج والعمرة', () => const HajjPage()),
  HomeShortcut('atlas', '🗺️', 'أطلس الأنبياء', () => const AtlasPage()),
  HomeShortcut('quiz', '🏆', 'مسابقات', () => const QuizPage()),
  HomeShortcut('stats', '📊', 'إحصائياتي', () => const StatsPage()),
];

HomeShortcut? shortcutById(String id) {
  for (final s in homeShortcuts) {
    if (s.id == id) return s;
  }
  return null;
}

/// Settings › تخصيص الصفحة الرئيسية: show, hide and reorder the Home sections, and choose its shortcuts.
class HomeCustomizePage extends StatelessWidget {
  const HomeCustomizePage({super.key});

  static const maxShortcuts = 9;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.settings;
        final theme = Theme.of(context);
        // Shown sections first (in their order), then the hidden ones.
        final order = [
          for (final id in s.homeSections)
            if (homeSections.any((h) => h.id == id)) homeSections.firstWhere((h) => h.id == id),
          for (final h in homeSections)
            if (!s.homeSections.contains(h.id)) h,
        ];
        void save(void Function(Settings x) f) => app.update(f, reschedule: false);
        return Scaffold(
          appBar: AppBar(title: const Text('تخصيص الصفحة الرئيسية'), actions: [
            TextButton(
              onPressed: () => save((x) {
                x.homeSections = List.of(Settings.defaultHomeSections);
                x.homeShortcuts = List.of(Settings.defaultHomeShortcuts);
              }),
              child: const Text('الافتراضي'),
            ),
          ]),
          body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('الأقسام', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.gold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('فعّل ما تريد أن يظهر، واسحب ☰ لتغيير الترتيب.', style: TextStyle(fontSize: 12.5, color: theme.hintColor)),
            ),
            Card3D(
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (from, to) {
                  if (to > from) to--;
                  final list = List.of(order)..insert(to, order.removeAt(from));
                  final shown = s.homeSections.toSet();
                  save((x) => x.homeSections = [for (final h in list) if (shown.contains(h.id)) h.id]);
                },
                children: [
                  for (var i = 0; i < order.length; i++)
                    ListTile(
                      key: ValueKey(order[i].id),
                      leading: Icon(order[i].icon, color: AppColors.gold),
                      title: Text(order[i].label),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                          value: s.homeSections.contains(order[i].id),
                          onChanged: (on) => save((x) {
                            final ids = [for (final h in order) if (h.id == order[i].id ? on : x.homeSections.contains(h.id)) h.id];
                            x.homeSections = ids;
                          }),
                        ),
                        ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                      ]),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('الاختصارات (${Arabic.digits(s.homeShortcuts.length)} من ${Arabic.digits(maxShortcuts)})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.gold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('اختر الصفحات التي تريدها على الرئيسية؛ تظهر بترتيب اختيارك.',
                  style: TextStyle(fontSize: 12.5, color: theme.hintColor)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final sc in homeShortcuts)
                  FilterChip(
                    avatar: Text(sc.emoji),
                    label: Text(s.homeShortcuts.contains(sc.id)
                        ? '${sc.label} (${Arabic.digits(s.homeShortcuts.indexOf(sc.id) + 1)})'
                        : sc.label),
                    selected: s.homeShortcuts.contains(sc.id),
                    onSelected: (on) {
                      if (on && s.homeShortcuts.length >= maxShortcuts) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الحد الأقصى ٩ اختصارات؛ ألغِ واحدًا أولًا')));
                        return;
                      }
                      save((x) => x.homeShortcuts = on ? [...x.homeShortcuts, sc.id] : [...x.homeShortcuts]..remove(sc.id));
                    },
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
