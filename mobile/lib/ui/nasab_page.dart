import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../data/nasab.dart';
import 'theme.dart';

/// النسب الشريف: a vertical tree from the Prophet ﷺ up to عدنان, with tap-to-read notes, and where the
/// lineages of the ten promised Paradise meet it.
class NasabPage extends StatefulWidget {
  const NasabPage({super.key});
  @override
  State<NasabPage> createState() => _NasabPageState();
}

class _NasabPageState extends State<NasabPage> {
  final _keys = [for (final _ in Nasab.chain) GlobalKey()];
  final _open = <int>{};
  String? _selected;

  CompanionNasab? get _sel => _selected == null ? null : Nasab.companions.firstWhere((c) => c.id == _selected);

  void _select(CompanionNasab c) {
    setState(() => _selected = _selected == c.id ? null : c.id);
    if (_selected == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[c.meet].currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final sel = _sel;
    return Scaffold(
      appBar: AppBar(title: const Text('النسب الشريف')),
      // A plain column (not a lazy list) so every node of the tree exists and can be scrolled to.
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(),
            Card3D(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'القدر المتفق عليه',
                      style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    const SizedBox(height: 6),
                    const Text(Nasab.agreed, style: TextStyle(fontSize: 14.5, height: 1.85)),
                    const SizedBox(height: 6),
                    _SourceChip(Nasab.zad),
                  ],
                ),
              ),
            ),
            Card3D(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Tile3D(size: 34, gold: true, child: Icon(Icons.favorite_rounded, size: 18, color: AppColors.current.bg)),
                        const SizedBox(width: 10),
                        Text(
                          'نسبه ﷺ من جهة أمه',
                          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(Nasab.mother, style: TextStyle(fontSize: 14.5, height: 1.85)),
                    const SizedBox(height: 6),
                    _SourceChip(Nasab.motherSource),
                  ],
                ),
              ),
            ),
            _sectionTitle('شجرة النسب', 'اضغط على أي اسم لتقرأ نبذة عنه، أو اختر صحابيًا ليظهر ملتقى نسبه.'),
            _companionStrip(),
            const SizedBox(height: 10),
            for (var i = 0; i < Nasab.chain.length; i++) ...[if (i > 0) _Connector(lit: sel != null && i <= sel.meet), _node(i, sel)],
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 4),
              child: Text(
                '… وما فوق عدنان مختلف فيه بين النسّابين، ولا خلاف أنه من ولد إسماعيل بن إبراهيم عليهما السلام.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: hint, height: 1.7),
              ),
            ),
            _sectionTitle('ملتقى أنساب العشرة المبشرين', 'كلهم من قريش، ويلتقي نسب كل واحد منهم بنسب النبي ﷺ عند جدٍّ من أجداده.'),
            for (final c in Nasab.companions) _companionCard(c),
            _footnote(hint),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: hero3D(radius: 22),
    child: Column(
      children: [
        Row(
          children: [
            Tile3D(size: 48, gold: true, child: Icon(Icons.account_tree_rounded, color: AppColors.current.bg, size: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'النسب الشريف',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                    ),
                  ),
                  Text(
                    'من محمد ﷺ إلى عدنان • ${Arabic.digits(Nasab.chain.length - 1)} أبًا',
                    style: TextStyle(color: AppColors.goldLight, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          Nasab.intro,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AmiriQuran', color: Colors.white, fontSize: 16.5, height: 2.0),
        ),
        const SizedBox(height: 6),
        Text(
          Nasab.bukhariRef,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.heroText, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String t, String sub) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor, height: 1.6)),
      ],
    ),
  );

  Widget _companionStrip() => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      children: [
        for (final c in Nasab.companions)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ChoiceChip(label: Text(c.name), selected: _selected == c.id, onSelected: (_) => _select(c)),
          ),
      ],
    ),
  );

  Widget _node(int i, CompanionNasab? sel) {
    final a = Nasab.chain[i];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = AppColors.current;
    final hit = sel != null && sel.meet == i;
    final open = _open.contains(i) || hit;
    final meeting = [
      for (final c in Nasab.companions)
        if (c.meet == i) c,
    ];
    final prophet = i == 0;
    final base = dark ? p.surface : p.lightSurface;
    final top = prophet ? Color.lerp(p.hero.first, Colors.white, 0.08)! : (dark ? Color.lerp(base, Colors.white, 0.08)! : base);
    final bottom = prophet ? p.hero.last : (dark ? Color.lerp(base, Colors.black, 0.25)! : Color.lerp(base, p.primary, 0.06)!);
    final fg = prophet ? Colors.white : null;
    return Center(
      key: _keys[i],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 300,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
          border: Border.all(
            color: hit ? AppColors.gold : (prophet ? AppColors.goldLight.withValues(alpha: 0.7) : AppColors.gold.withValues(alpha: 0.28)),
            width: hit ? 2.2 : 1,
          ),
          boxShadow: [
            if (hit) BoxShadow(color: AppColors.gold.withValues(alpha: 0.55), blurRadius: 22, spreadRadius: 1),
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.55 : 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
              blurRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: a.note == null && meeting.isEmpty ? null : () => setState(() => _open.contains(i) ? _open.remove(i) : _open.add(i)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _Badge(prophet ? null : i, gold: hit || prophet),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                style: TextStyle(fontSize: prophet ? 20 : 17.5, fontWeight: FontWeight.w800, color: fg),
                              ),
                              if (prophet)
                                Text('رسول الله', style: TextStyle(fontSize: 12, color: AppColors.goldLight))
                              else if (i == 1)
                                Text('أبوه ﷺ', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))
                              else if (i == 11)
                                Text('قريش', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                            ],
                          ),
                        ),
                        if (i == 6) _Tag('ملتقى نسب أمه ﷺ'),
                        if (meeting.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 4),
                            child: _Tag(Arabic.digits(meeting.length), strong: hit, icon: Icons.groups_rounded),
                          ),
                        if (a.note != null && !hit)
                          Icon(
                            open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 20,
                            color: prophet ? Colors.white70 : Theme.of(context).hintColor,
                          ),
                      ],
                    ),
                    if (open && a.note != null) ...[
                      const SizedBox(height: 8),
                      Text(a.note!, style: TextStyle(fontSize: 13.5, height: 1.8, color: prophet ? AppColors.heroText : null)),
                    ],
                    if (open && meeting.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'يلتقي عنده: ${meeting.map((c) => c.name).join('، ')}',
                        style: TextStyle(fontSize: 12.5, color: AppColors.gold, fontWeight: FontWeight.w700, height: 1.7),
                      ),
                    ],
                    if (hit) _branch(sel),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The selected companion's own chain, drawn as a small gold side branch inside the meeting node.
  Widget _branch(CompanionNasab c) {
    final hint = Theme.of(context).hintColor;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${c.name} رضي الله عنه',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold, fontSize: 14.5),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              for (var k = 0; k < c.chain.length; k++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (k > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text('بن', style: TextStyle(fontSize: 12, color: hint)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: k == c.chain.length - 1 ? BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)) : null,
                      child: Text(
                        c.chain[k],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: k == c.chain.length - 1 ? FontWeight.w800 : FontWeight.w600,
                          color: k == c.chain.length - 1 ? AppColors.current.bg : null,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _companionCard(CompanionNasab c) {
    final hint = Theme.of(context).hintColor;
    final on = _selected == c.id;
    return Card3D(
      shape: on ? RoundedRectangleBorder(side: BorderSide(color: AppColors.gold, width: 1.6)) : null,
      child: InkWell(
        onTap: () => _select(c),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  _Tag(c.clan),
                ],
              ),
              const SizedBox(height: 6),
              Text(c.lineage, style: const TextStyle(fontSize: 14, height: 1.8)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.call_merge_rounded, size: 18, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'يلتقي مع النبي ﷺ في: '),
                          TextSpan(
                            text: c.meet + 1 < Nasab.chain.length ? '${c.meetName} بن ${Nasab.chain[c.meet + 1].name}' : c.meetName,
                            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Icon(on ? Icons.visibility_rounded : Icons.north_rounded, size: 18, color: hint),
                ],
              ),
              if (c.remark != null) ...[
                const SizedBox(height: 4),
                Text(c.remark!, style: TextStyle(fontSize: 12.5, color: hint, height: 1.6)),
              ],
              const SizedBox(height: 6),
              Align(alignment: AlignmentDirectional.centerStart, child: _SourceChip(c.source)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footnote(Color hint) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'المصادر',
          style: TextStyle(fontWeight: FontWeight.w700, color: hint),
        ),
        const SizedBox(height: 4),
        Text(
          'سلسلة النسب كما ساقها البخاري في ترجمة «باب مبعث النبي ﷺ»، والنبذ عن الأجداد مختصرة من شرح ابن حجر لهذا الباب في فتح الباري، '
          'وما فيها بصيغة «قيل» فهو مما نقله من أقوال أهل اللغة والنسب. وملتقى أنساب الصحابة منقول من فتح الباري وسير أعلام النبلاء وسيرة ابن هشام.',
          style: TextStyle(fontSize: 12, color: hint, height: 1.7),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final s in Nasab.sources) _SourceChip(s)]),
      ],
    ),
  );
}

/// A gold vertical connector between two nodes of the tree.
class _Connector extends StatelessWidget {
  final bool lit;
  const _Connector({required this.lit});
  @override
  Widget build(BuildContext context) {
    final g = AppColors.gold;
    return SizedBox(
      height: 26,
      child: Center(
        child: Column(
          children: [
            Container(
              width: lit ? 4 : 3,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    g.withValues(alpha: lit ? 1 : 0.85),
                    AppColors.goldLight.withValues(alpha: lit ? 1 : 0.5),
                  ],
                ),
                boxShadow: lit ? [BoxShadow(color: g.withValues(alpha: 0.6), blurRadius: 8)] : null,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: g,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 3, offset: const Offset(0, 1.5))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int? n;
  final bool gold;
  const _Badge(this.n, {this.gold = false});
  @override
  Widget build(BuildContext context) => Tile3D(
    size: 34,
    gold: gold,
    child: n == null
        ? Icon(Icons.star_rounded, size: 20, color: AppColors.current.bg)
        : Text(
            Arabic.digits(n!),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: gold ? AppColors.current.bg : AppColors.gold),
          ),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final bool strong;
  final IconData? icon;
  const _Tag(this.text, {this.strong = false, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: strong ? AppColors.gold : AppColors.gold.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: strong ? AppColors.current.bg : AppColors.gold), const SizedBox(width: 3)],
        Text(
          text,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: strong ? AppColors.current.bg : AppColors.gold),
        ),
      ],
    ),
  );
}

class _SourceChip extends StatelessWidget {
  final NasabSource s;
  const _SourceChip(this.s);
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
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
  );
}
