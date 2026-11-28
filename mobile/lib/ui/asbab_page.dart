import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/asbab.dart';
import '../data/repository.dart';
import '../main.dart';
import 'hadith_page.dart';
import 'theme.dart';

const _note = 'اقتصرنا هنا على روايات صحيحَي البخاري ومسلم التي تصرّح بأن الآية نزلت في واقعة بعينها '
    '(«فنزلت»، «فأنزل الله»، «نزلت في…») وتذكر الآية نفسها. وقد يصحّ للآية سبب آخر في غير الصحيحين، '
    'وقد تتعدد أسباب الآية الواحدة، ويرى بعض العلماء أن قول الصحابي «نزلت في كذا» قد يُراد به التفسير لا السبب. '
    'وتصنيف السور إلى مكية ومدنية على ما في مصحف المدينة النبوية (مجمع الملك فهد)، وفي بعض السور خلاف بين العلماء.';

enum _Filter { all, meccan, medinan, asbab }

String _ayat(int n) {
  if (n == 1) return 'آية واحدة';
  if (n == 2) return 'آيتان';
  return n % 100 >= 3 && n % 100 <= 10 ? '${Arabic.digits(n)} آيات' : '${Arabic.digits(n)} آية';
}

String _narrations(int n) {
  if (n == 1) return 'رواية واحدة';
  if (n == 2) return 'روايتان';
  return n >= 3 && n <= 10 ? '${Arabic.digits(n)} روايات' : '${Arabic.digits(n)} رواية';
}

String _type(Surah s) => s.meccan ? 'مكية' : 'مدنية';

Widget _typeBadge(Surah s) {
  final c = s.meccan ? AppColors.gold : AppColors.emerald;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
    child: Text(_type(s), style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700)),
  );
}

/// أسباب النزول الصحيحة والمكي والمدني: every surah with its Makki/Madani type, and the occasions of
/// revelation narrated in the two Sahihs.
class AsbabPage extends StatefulWidget {
  const AsbabPage({super.key});
  @override
  State<AsbabPage> createState() => _AsbabPageState();
}

class _AsbabPageState extends State<AsbabPage> {
  _Filter _filter = _Filter.all;
  final _future = Asbab.load();

  @override
  Widget build(BuildContext context) {
    final surahs = app.repo.surahs;
    final meccan = surahs.where((s) => s.meccan).length;
    return Scaffold(
      appBar: AppBar(title: const Text('أسباب النزول والمكي والمدني')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final a = snap.data;
          if (a == null) return const Center(child: CircularProgressIndicator());
          final shown = surahs.where((s) => switch (_filter) {
                _Filter.all => true,
                _Filter.meccan => s.meccan,
                _Filter.medinan => !s.meccan,
                _Filter.asbab => a.inSurah(s.number).isNotEmpty,
              }).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
              decoration: hero3D(radius: 20),
              child: Column(children: [
                Row(children: [
                  _count(Arabic.digits(meccan), 'سورة مكية'),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _count(Arabic.digits(surahs.length - meccan), 'سورة مدنية'),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _count(Arabic.digits(a.all.length), 'رواية صحيحة'),
                ]),
                const SizedBox(height: 10),
                Text('أسباب نزول من صحيحَي البخاري ومسلم في ${Arabic.digits(a.surahs.length)} سورة',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                for (final (f, label) in const [
                  (_Filter.all, 'الكل'),
                  (_Filter.meccan, 'مكية'),
                  (_Filter.medinan, 'مدنية'),
                  (_Filter.asbab, 'فيها سبب نزول صحيح'),
                ])
                  ChoiceChip(label: Text(label), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
              ]),
            ),
            for (final s in shown) _tile(context, s, a.inSurah(s.number)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(_note, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.7, color: Theme.of(context).hintColor)),
            ),
          ]);
        },
      ),
    );
  }

  Widget _count(String n, String label) => Expanded(
        child: Column(children: [
          Text(n, style: TextStyle(color: AppColors.goldLight, fontSize: 24, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        ]),
      );

  Widget _tile(BuildContext context, Surah s, List<Sabab> list) {
    return Card3D(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 10, 0),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.emerald.withValues(alpha: 0.14),
          child: Text(Arabic.digits(s.number), style: TextStyle(fontSize: 13, color: AppColors.emerald, fontWeight: FontWeight.w700)),
        ),
        title: Row(children: [
          Flexible(child: Text('سورة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          const SizedBox(width: 8),
          _typeBadge(s),
        ]),
        subtitle: Text(list.isEmpty ? _ayat(s.verses.length) : '${_ayat(s.verses.length)} • ${_narrations(list.length)} في سبب النزول'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (list.isNotEmpty) Icon(Icons.auto_stories, size: 18, color: AppColors.gold),
          const Icon(Icons.chevron_left),
        ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SurahAsbabPage(surah: s, asbab: list))),
      ),
    );
  }
}

/// One surah: its revelation type, number of ayat and its sahih occasions of revelation.
class SurahAsbabPage extends StatelessWidget {
  final Surah surah;
  final List<Sabab> asbab;
  const SurahAsbabPage({super.key, required this.surah, required this.asbab});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    // Narrations of the same verses share one ayah block.
    final groups = <(int, int), List<Sabab>>{};
    for (final s in asbab) {
      (groups[(s.from, s.to)] ??= []).add(s);
    }
    return Scaffold(
      appBar: AppBar(title: Text('سورة ${surah.name}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 6, 0, 24), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(18),
          decoration: hero3D(radius: 22),
          child: Column(children: [
            Text('سورة ${surah.name}', style: const TextStyle(fontFamily: 'AmiriQuran', color: Colors.white, fontSize: 26, height: 1.8)),
            const SizedBox(height: 4),
            Text('${surah.meccan ? 'مكية' : 'مدنية'} • ${_ayat(surah.verses.length)} • ترتيبها في المصحف ${Arabic.digits(surah.number)}',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(asbab.isEmpty ? 'لا رواية فيها في الصحيحين ضمن ما جُمع هنا' : '${_narrations(asbab.length)} في سبب النزول من الصحيحين',
                style: TextStyle(color: AppColors.heroText, fontSize: 13)),
          ]),
        ),
        if (asbab.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'لم نجد في صحيحَي البخاري ومسلم رواية تصرّح بسبب نزول آية من هذه السورة وتذكرها. '
              'ولا يعني ذلك أنه لا سبب لها؛ فأكثر القرآن نزل ابتداءً، وقد يصح السبب في غير الصحيحين.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.9, color: hint),
            ),
          ),
        for (final MapEntry(key: (from, to), value: list) in groups.entries) _group(context, from, to, list),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(_note, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.7, color: hint)),
        ),
      ]),
    );
  }

  Widget _group(BuildContext context, int from, int to, List<Sabab> list) {
    final ayat = [for (var a = from; a <= to && a <= surah.verses.length; a++) a];
    const maxShown = 4;
    return Card3D(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(list.first.ayahLabel, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15.5)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              for (final a in ayat.take(maxShown)) TextSpan(text: '${surah.verses[a - 1]} ﴿${Arabic.digits(a)}﴾ '),
              if (ayat.length > maxShown) const TextSpan(text: '… '),
            ]),
            style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 20, height: 2.1),
          ),
          for (final s in list) ...[
            const Divider(height: 18),
            Text(s.excerpt, style: const TextStyle(fontSize: 15, height: 1.9)),
            const SizedBox(height: 6),
            Row(children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                  child: Text(s.ref, style: TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.w700)),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.menu_book, size: 18),
                label: const Text('الحديث كاملًا'),
                onPressed: () => _openHadith(context, s),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _openHadith(BuildContext context, Sabab s) async {
    final h = await s.hadith();
    if (!context.mounted || h == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(s.ref)),
          body: ListView(padding: const EdgeInsets.only(top: 6, bottom: 20), children: [HadithCard(h)]),
        ),
      ),
    );
  }
}
