import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/hadith.dart';
import '../main.dart';
import 'format.dart';
import 'hadith_page.dart';
import 'companions_page.dart';
import 'duas_page.dart';
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
                const _AskButton(),
                const SizedBox(width: 10),
                Text(fmtTime(now, app.settings.use24h), textDirection: TextDirection.ltr,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            );
          },
        ),
        const NextPrayerHero(),
        const RadioCard(),
        const TodayHarvest(),
        const KahfCard(),
        const _HadithOfDay(),
        const _Sections(),
      ]),
    );
  }
}

/// Opens «سبيل» (ask about an ayah or a hadith) from the home header.
class _AskButton extends StatelessWidget {
  const _AskButton();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold.withValues(alpha: 0.16),
      shape: StadiumBorder(side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SabeelPage())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_rounded, size: 18, color: AppColors.gold),
            const SizedBox(width: 4),
            Text('اسأل سبيل', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ]),
        ),
      ),
    );
  }
}

/// A short hadith card; the full one (with its chain, saving and copying) opens on tap.
class _HadithOfDay extends StatelessWidget {
  const _HadithOfDay();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: HadithCollection.load('bukhari'),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final h = snap.data!.ofDay(app.today);
        return Card3D(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('حديث اليوم')),
                  body: ListView(padding: const EdgeInsets.only(top: 6), children: [HadithCard(h)]),
                ))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text('✦ حديث اليوم', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13.5)),
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
      },
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
      tile('🤲', 'أدعية المناسبات', const DuasPage()),
      tile('📿', 'السبحة', const TasbeehPage()),
      tile('🧭', 'القبلة', const QiblaPage()),
    ];
    // Two rows of three.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        SizedBox(
          height: 82,
          child: Row(children: [
            for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: items[i])],
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: Row(children: [
            for (var i = 3; i < 6; i++) ...[if (i > 3) const SizedBox(width: 10), Expanded(child: items[i])],
          ]),
        ),
      ]),
    );
  }
}
