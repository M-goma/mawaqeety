import 'package:flutter/material.dart';

import '../data/duas.dart';
import '../data/hadith.dart';
import '../main.dart';
import 'duas_page.dart';
import 'format.dart';
import 'hadith_page.dart';
import 'mushaf_page.dart';
import 'prayer_page.dart';
import 'qibla_page.dart';
import 'radio_page.dart';
import 'tasbeeh_page.dart';
import 'theme.dart';

/// The first tab: what matters right now — the next prayer, the radio, today's harvest,
/// a hadith of the day and quick shortcuts.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final now = app.now;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('السلام عليكم', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text('${fmtGregorian(now)} • ${app.hijri(now)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                  ]),
                ),
                Text(fmtTime(now, app.settings.use24h), textDirection: TextDirection.ltr,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            );
          },
        ),
        const NextPrayerHero(),
        const RadioCard(),
        const TodayHarvest(),
        const KahfCard(),
        FutureBuilder(
          future: HadithCollection.load('bukhari'),
          builder: (context, snap) => snap.hasData
              ? HadithCard(snap.data!.ofDay(app.today), title: '✦ حديث اليوم', highlight: true)
              : const SizedBox.shrink(),
        ),
        const _Shortcuts(),
      ]),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();
  @override
  Widget build(BuildContext context) {
    Widget tile(String emoji, String label, VoidCallback onTap) => Expanded(
          child: Card3D(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10 * UiScale.icon),
                child: Column(children: [
                  Text(emoji, style: TextStyle(fontSize: 24 * UiScale.icon)),
                  const SizedBox(height: 4),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        );
    void push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) => Row(children: [
          tile('📿', 'السبحة', () => push(const TasbeehPage())),
          tile('🧭', 'القبلة', () => push(const QiblaPage())),
          tile('🌙', 'أذكار النوم', () async {
            await Duas.load();
            final g = Duas.byId('sleep');
            if (g != null && context.mounted) push(DuaGroupPage(group: g));
          }),
          app.kahfFriday != null
              ? tile('📖', 'الكهف', app.openKahf)
              : tile('📖', 'المصحف', () => openMushaf(context, app.settings.mushafPage)),
        ]),
      ),
    );
  }
}
