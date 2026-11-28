import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/hadith.dart';
import '../main.dart';
import 'format.dart';
import 'hadith_page.dart';
import 'companions_page.dart';
import 'hisn_page.dart';
import 'planner_page.dart';
import 'prayer_page.dart';
import 'prophets_page.dart';
import 'qibla_page.dart';
import 'tasbeeh_page.dart';
import 'radio_page.dart';
import 'sabeel_page.dart';
import 'theme.dart';

/// The first tab, on one screen: the next prayer, the radio, today's harvest, al-Kahf on Friday,
/// and the hadith of the day.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.only(bottom: 12), children: [
        ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final now = app.now;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('السلام عليكم', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('${fmtGregorian(now)} • ${app.hijri(now)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                  ]),
                ),
                Text(fmtTime(now, app.settings.use24h), textDirection: TextDirection.ltr,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            );
          },
        ),
        const NextPrayerHero(),
        const RadioCard(),
        const TodayHarvest(),
        const PlannerHomeCard(),
        const KahfCard(),
        const _HadithOfDay(),
        const _Sections(),
        const _AskBar(),
      ]),
    );
  }
}

/// Opens «سبيل» (ask about an ayah, a hadith or anything in the app): a wide bar under the section tiles.
class _AskBar extends StatelessWidget {
  const _AskBar();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card3D(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6), width: 1.2)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SabeelPage())),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Icon(Icons.search_rounded, color: AppColors.gold, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('اسأل سبيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  Text('آية، حديث، مسألة، غزوة… من محتوى التطبيق', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.hintColor),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A short hadith card; the full one (with its chain, saving and copying) opens on tap.
class _HadithOfDay extends StatelessWidget {
  const _HadithOfDay();
  static final _bukhari = HadithCollection.load('bukhari');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _bukhari,
      // Rebuilt with the app so the hadith changes when the next prayer comes in.
      builder: (context, snap) => ListenableBuilder(listenable: app, builder: (context, _) {
        if (!snap.hasData) return const SizedBox.shrink();
        final h = snap.data!.ofDay(app.today, app.hadithSlot);
        return Card3D(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                  appBar: AppBar(title: Text('حديث ${app.hadithSlotName}')),
                  body: ListView(padding: const EdgeInsets.only(top: 6), children: [HadithCard(h)]),
                ))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text('✦ حديث ${app.hadithSlotName}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const Spacer(),
                  Text('${h.col.name} • ${Arabic.digits(h.number)}', style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
                ]),
                const SizedBox(height: 2),
                Text(h.matn, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 16, height: 1.9)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

/// The main sections as compact tiles, filling the rest of the home screen.
class _Sections extends StatelessWidget {
  const _Sections();
  @override
  Widget build(BuildContext context) {
    Widget tile(String emoji, String label, Widget page) => Card3D(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(emoji, style: const TextStyle(fontSize: 26, shadows: [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 3))])),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    final items = [
      tile('🐪', 'قصص الأنبياء', const ProphetsPage()),
      tile('🌟', 'العشرة المبشرون', const CompanionsPage()),
      tile('📜', 'الأحاديث', const HadithPage()),
      tile('🤲', 'حصن المسلم', const HisnPage()),
      tile('📿', 'السبحة', const TasbeehPage()),
      tile('🧭', 'القبلة', const QiblaPage()),
    ];
    // Two rows of three.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        SizedBox(
          height: 76,
          child: Row(children: [
            for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: items[i])],
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: Row(children: [
            for (var i = 3; i < 6; i++) ...[if (i > 3) const SizedBox(width: 10), Expanded(child: items[i])],
          ]),
        ),
      ]),
    );
  }
}
