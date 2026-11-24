import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/repository.dart';
import '../main.dart';
import 'format.dart';
import 'quran_pages.dart';
import 'theme.dart';

class ProphetsPage extends StatelessWidget {
  const ProphetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = app.repo.prophets;
    return Scaffold(
      appBar: AppBar(title: const Text('قصص الأنبياء')),
      body: list.isEmpty
          ? const Center(child: Text('سيتم إضافة القصص قريبًا'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: list.length,
              itemBuilder: (c, i) {
                final p = list[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 44, height: 44, alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.circular(12)),
                      child: Text(Arabic.digits(p.order), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    title: Text('${p.nameAr} عليه السلام'.replaceAll('محمد ﷺ عليه السلام', 'محمد ﷺ'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    subtitle: Text(p.title, style: const TextStyle(color: AppColors.gold)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProphetPage(prophet: p))),
                  ),
                );
              },
            ),
    );
  }
}

class ProphetPage extends StatelessWidget {
  final Prophet prophet;
  const ProphetPage({super.key, required this.prophet});

  @override
  Widget build(BuildContext context) {
    final p = prophet;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16.5, height: 1.9);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(p.nameAr)),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 32), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nameAr, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
              Text(p.title, style: const TextStyle(color: Color(0xFFE9C75A), fontSize: 15)),
              const SizedBox(height: 8),
              Text(p.summary, style: const TextStyle(color: Color(0xFFE6F3EE), height: 1.7)),
            ]),
          ),
          for (final s in p.sections) ...[
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 4, height: 22, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(child: Text(s.heading, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 8),
            for (final para in s.body.split('\n\n').where((x) => x.trim().isNotEmpty))
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(para.trim(), style: body, textAlign: TextAlign.justify)),
          ],
          if (p.ayat.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('من آيات القرآن الكريم', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final a in p.ayat) _AyatCard(a),
          ],
          if (p.lessons.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('دروس وعبر', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final l in p.lessons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.star, size: 14, color: AppColors.gold)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l, style: body)),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

class _AyatCard extends StatelessWidget {
  final AyahRef a;
  const _AyatCard(this.a);

  @override
  Widget build(BuildContext context) {
    if (a.surah < 1 || a.surah > 114) return const SizedBox.shrink();
    final s = app.repo.surahs[a.surah - 1];
    final from = a.from.clamp(1, s.verses.length);
    final to = a.to.clamp(from, s.verses.length);
    final style = quranStyle(context, 21);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openReader(context, a.surah, from),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text.rich(
              TextSpan(children: [
                for (var i = from; i <= to; i++) ...[
                  TextSpan(text: '${s.verses[i - 1]} '),
                  TextSpan(text: '${ayahNumber(i)} ', style: style.copyWith(color: AppColors.gold, fontSize: 19)),
                ],
              ]),
              style: style,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 6),
            Text('سورة ${s.name} (${Arabic.digits(from)}${to > from ? '–${Arabic.digits(to)}' : ''})',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
            if (a.note.isNotEmpty) Text(a.note, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
