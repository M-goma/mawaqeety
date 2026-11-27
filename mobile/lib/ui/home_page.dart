import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/hadith.dart';
import '../main.dart';
import 'format.dart';
import 'hadith_page.dart';
import 'prayer_page.dart';
import 'radio_page.dart';
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
        const KahfCard(),
        const _HadithOfDay(),
      ]),
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
