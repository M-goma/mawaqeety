import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../data/companions_islam.dart';
import 'theme.dart';

/// كيف أسلم الصحابة: how and when each of the ten promised Paradise embraced Islam, with sources.
class CompanionsIslamPage extends StatelessWidget {
  const CompanionsIslamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    const list = CompanionsIslam.list;
    return Scaffold(
      appBar: AppBar(title: const Text('كيف أسلم الصحابة')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: hero3D(radius: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Tile3D(size: 48, gold: true, child: Icon(Icons.wb_twilight_rounded, color: AppColors.current.bg, size: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'كيف أسلم الصحابة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                            ),
                          ),
                          Text(
                            'العشرة المبشرون بالجنة • ${Arabic.digits(list.length)} سِيَر',
                            style: TextStyle(color: AppColors.goldLight, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(CompanionsIslam.intro, style: TextStyle(color: AppColors.heroText, fontSize: 14, height: 1.85)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _HeroStat('${Arabic.digits(list.where((c) => c.by.contains('أبي بكر')).length)} بدعوة أبي بكر'),
                    _HeroStat('${Arabic.digits(list.where((c) => c.hadith != null).length)} بحديث من البخاري'),
                  ],
                ),
              ],
            ),
          ),
          for (var i = 0; i < list.length; i++) _Entry(list[i], i + 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'عن المصادر',
                  style: TextStyle(fontWeight: FontWeight.w700, color: hint),
                ),
                const SizedBox(height: 4),
                Text(CompanionsIslam.footnote, style: TextStyle(fontSize: 12, color: hint, height: 1.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String text;
  const _HeroStat(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.45)),
    ),
    child: Text(
      text,
      style: TextStyle(color: AppColors.goldLight, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _Entry extends StatelessWidget {
  final CompanionIslam c;
  final int n;
  const _Entry(this.c, this.n);

  @override
  Widget build(BuildContext context) {
    return Card3D(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Tile3D(
                  size: 36,
                  child: Text(
                    Arabic.digits(n),
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.name} رضي الله عنه', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        c.by,
                        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(c.story, style: const TextStyle(fontSize: 14.5, height: 1.85)),
            if (c.age != null) ...[
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Pill(icon: Icons.cake_outlined, text: 'عمره حين أسلم: ${c.age}'),
                  if (c.ageDisputed) const _Pill(text: 'اختلف فيه المؤرخون', muted: true),
                ],
              ),
            ],
            if (c.hadith != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: BorderDirectional(start: BorderSide(color: AppColors.gold, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(c.hadith!.text, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 15.5, height: 1.9)),
                    const SizedBox(height: 2),
                    Text(
                      'صحيح البخاري ${Arabic.digits(c.hadith!.number)}',
                      style: TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in c.sources)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 14, color: AppColors.emerald),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              s.label,
                              style: TextStyle(fontSize: 11.5, color: AppColors.emerald, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String text;
  final bool muted;
  const _Pill({this.icon, required this.text, this.muted = false});
  @override
  Widget build(BuildContext context) {
    final c = muted ? Theme.of(context).hintColor : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
