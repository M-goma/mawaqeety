import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../data/ghazawat.dart';
import '../data/repository.dart';
import '../data/seerah.dart';
import '../main.dart';
import 'atlas_page.dart';
import 'ghazawat_page.dart';
import 'mushaf_page.dart';
import 'theme.dart';

/// السيرة النبوية على خط زمني: from the birth in the Year of the Elephant to the death of the Prophet ﷺ,
/// grouped into eras; an event opens its summary, related ayah, battle and sources.
class SeerahPage extends StatefulWidget {
  /// Id of an event to open once the timeline is shown (from «سبيل»).
  final String? openEvent;
  const SeerahPage({super.key, this.openEvent});
  @override
  State<SeerahPage> createState() => _SeerahPageState();
}

class _SeerahPageState extends State<SeerahPage> {
  late final Future<(SeerahData, GhazawatData)> _data = _load();
  final _eraKeys = <String, GlobalKey>{};

  static Future<(SeerahData, GhazawatData)> _load() async => (await SeerahData.load(), await GhazawatData.load());

  @override
  void initState() {
    super.initState();
    final id = widget.openEvent;
    if (id == null) return;
    _data.then((d) {
      final e = d.$1.byId(id);
      if (e == null || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = _eraKeys[e.era]?.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300));
        showSeerahEvent(context, e, ghazawat: d.$2);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السيرة النبوية'),
        actions: [
          IconButton(
            tooltip: 'الخريطة',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AtlasPage(tab: AtlasTab.seerah))),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('تعذّر تحميل البيانات: ${snap.error}'));
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final s = d.$1, g = d.$2;
          final hint = Theme.of(context).hintColor;
          var n = 0;
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _hero(s),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    for (final era in s.eras)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          label: Text(era.name),
                          onPressed: () {
                            final c = _eraKeys[era.id]?.currentContext;
                            if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              for (final era in s.eras) ...[
                _EraHeader(era, s.ofEra(era.id).length, key: _eraKeys.putIfAbsent(era.id, GlobalKey.new)),
                for (final (i, e) in s.ofEra(era.id).indexed)
                  _EventTile(e: e, n: ++n, first: i == 0, last: i == s.ofEra(era.id).length - 1,
                      onTap: () => showSeerahEvent(context, e, ghazawat: g)),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(s.note, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: hint, height: 1.6)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('اعتمدنا على موسوعة السيرة النبوية في المكتبة الإسلامية بموقع إسلام ويب، وعلى فتاوى إسلام ويب وابن باز '
                    'والإسلام سؤال وجواب، وهي تنقل عن سيرة ابن هشام والبداية والنهاية والرحيق المختوم وزاد المعاد. ومع كل حدث روابط مصادره.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: hint, height: 1.7)),
              ),
              for (final r in s.sources) _RefLink(r),
            ]),
          );
        },
      ),
    );
  }

  Widget _hero(SeerahData s) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        padding: const EdgeInsets.all(16),
        decoration: hero3D(radius: 20),
        child: Column(children: [
          const Text('﴿لَّقَدْ كَانَ لَكُمْ فِي رَسُولِ اللَّهِ أُسْوَةٌ حَسَنَةٌ﴾', textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'AmiriQuran', color: Colors.white, fontSize: 18, height: 1.9)),
          Text('الأحزاب ٢١', style: TextStyle(color: AppColors.goldLight, fontSize: 12)),
          const SizedBox(height: 8),
          Text(s.intro, textAlign: TextAlign.center, style: TextStyle(color: AppColors.heroText, height: 1.7)),
          const SizedBox(height: 12),
          Row(children: [
            _stat(Arabic.digits(s.events.length), 'حدثًا'),
            _stat(Arabic.digits(s.eras.length), 'مراحل'),
            _stat(Arabic.digits(63), 'سنة'),
          ]),
        ]),
      );

  Widget _stat(String v, String label) => Expanded(
        child: Column(children: [
          Text(v, style: TextStyle(color: AppColors.goldLight, fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: AppColors.heroText, fontSize: 12)),
        ]),
      );
}

class _EraHeader extends StatelessWidget {
  final SeerahEra era;
  final int count;
  const _EraHeader(this.era, this.count, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: hero3D(radius: 16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(era.name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))])),
              Text(era.range, style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 4),
              Text(era.desc, style: TextStyle(color: AppColors.heroText, fontSize: 12.5, height: 1.6)),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('${Arabic.digits(count)} حدثًا', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
      );
}

class _EventTile extends StatelessWidget {
  final SeerahEvent e;
  final int n;
  final bool first, last;
  final VoidCallback onTap;
  const _EventTile({required this.e, required this.n, required this.first, required this.last, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final line = AppColors.gold.withValues(alpha: 0.45);
    final battle = e.ghazwa != null;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 72,
          child: Stack(alignment: Alignment.topCenter, children: [
            Positioned(top: first ? 30 : 0, bottom: last ? null : 0, height: last ? 30 : null,
                child: Container(width: 2, color: line)),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                  color: battle ? battleColor : (e.hy > 0 ? AppColors.current.hero[1] : AppColors.emerald),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.8)),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
                ),
                child: Text(e.badge, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, height: 1.3)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: Card3D(
            margin: const EdgeInsetsDirectional.fromSTEB(0, 5, 14, 5),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    if (battle) const Text('⚔️', style: TextStyle(fontSize: 14)),
                  ]),
                  Text(e.when, style: TextStyle(fontSize: 12.5, color: AppColors.gold, fontWeight: FontWeight.w600)),
                  Text([e.hijriLabel, e.ceLabel, if (e.age != null) ageLabel(e.age!)].join(' • '),
                      style: TextStyle(fontSize: 11.5, color: hint)),
                  const SizedBox(height: 4),
                  Text(e.summary, maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, height: 1.6, color: hint)),
                  if (e.disputed != null || e.place != null || e.ayah != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(spacing: 6, runSpacing: 4, children: [
                        if (e.disputed != null) _Chip('على الأشهر', AppColors.gold, Icons.info_outline),
                        if (e.place != null) _Chip(e.place!.name, AppColors.emerald, Icons.place_outlined),
                        if (e.ayah != null) _Chip('آية', AppColors.emerald, Icons.menu_book_outlined),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _Chip(this.text, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _RefLink extends StatelessWidget {
  final SeerahRef r;
  const _RefLink(this.r);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextButton.icon(
          style: TextButton.styleFrom(alignment: AlignmentDirectional.centerStart),
          onPressed: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(r.title, style: const TextStyle(fontSize: 12.5)),
        ),
      );
}

// ---------------------------------------------------------------- event sheet

/// The details of one event: dates, summary, the disputed point, the related ayah, the battle and the sources.
/// [fromMap]: opened from the atlas (no «على الخريطة» button).
Future<void> showSeerahEvent(BuildContext context, SeerahEvent e, {GhazawatData? ghazawat, bool fromMap = false}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (c, scroll) => _EventSheet(e: e, ghazawat: ghazawat, fromMap: fromMap, scroll: scroll, outer: context),
    ),
  );
}

class _EventSheet extends StatelessWidget {
  final SeerahEvent e;
  final GhazawatData? ghazawat;
  final bool fromMap;
  final ScrollController scroll;
  final BuildContext outer;
  const _EventSheet({required this.e, required this.ghazawat, required this.fromMap, required this.scroll, required this.outer});

  Future<void> _openBattle(BuildContext context) async {
    final g = (ghazawat ?? await GhazawatData.load()).byId(e.ghazwa!);
    if (g == null || !context.mounted) return;
    Navigator.pop(context);
    if (outer.mounted) Navigator.push(outer, MaterialPageRoute(builder: (_) => GhazwaPage(g: g)));
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final a = e.ayah;
    final surahs = app.repo.surahs;
    final hasAyah = a != null && a.surah >= 1 && a.surah <= surahs.length;
    return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
      Text(e.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(e.when, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
      Text([e.hijriLabel, e.ceLabel, if (e.age != null) ageLabel(e.age!)].join(' • '),
          style: TextStyle(fontSize: 12.5, color: hint)),
      if (e.place != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.place_outlined, size: 16, color: AppColors.emerald),
            const SizedBox(width: 4),
            Expanded(
              child: Text('${e.place!.name}${e.place!.approx ? ' (موضع تقريبي)' : ''}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.emerald, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      const SizedBox(height: 10),
      Text(e.summary, style: const TextStyle(fontSize: 15.5, height: 1.95)),
      if (e.disputed != null)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'على الأشهر: ', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                TextSpan(text: e.disputed),
              ]), style: const TextStyle(fontSize: 13.5, height: 1.7)),
            ),
          ]),
        ),
      if (hasAyah) _ayah(context, a, surahs[a.surah - 1]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (e.ghazwa != null)
          FilledButton.icon(
            onPressed: () => _openBattle(context),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('اقرأ الغزوة'),
          ),
        if (!fromMap && (e.place != null || e.ghazwa != null))
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(outer, MaterialPageRoute(builder: (_) => AtlasPage(tab: AtlasTab.seerah, focusSeerah: e.id)));
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('على الخريطة'),
          ),
      ]),
      const SizedBox(height: 10),
      Text('المصادر', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
      for (final r in e.refs)
        TextButton.icon(
          style: TextButton.styleFrom(alignment: AlignmentDirectional.centerStart, padding: EdgeInsets.zero),
          onPressed: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(r.title, style: const TextStyle(fontSize: 12.5)),
        ),
    ]);
  }

  Widget _ayah(BuildContext context, SeerahAyah a, Surah s) {
    final verses = s.verses;
    final to = a.to.clamp(a.from, verses.length);
    final range = a.from == to ? Arabic.digits(a.from) : '${Arabic.digits(a.from)}–${Arabic.digits(to)}';
    final text = [for (var i = a.from; i <= to; i++) '${verses[i - 1]} ﴿${Arabic.digits(i)}﴾'].join(' ');
    return Card3D(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('سورة ${s.name} $range', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                openMushaf(outer, app.mushaf.pageOf(a.surah, a.from), highlight: Bookmark(a.surah, a.from));
              },
              icon: const Icon(Icons.auto_stories_outlined, size: 18),
              label: const Text('في المصحف'),
            ),
          ]),
          Text(text, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18, height: 2.1)),
        ]),
      ),
    );
  }
}
