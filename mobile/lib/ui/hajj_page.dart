import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../data/ghazawat.dart' show GhazwaHadith, findGhazwaHadith;
import '../data/hajj.dart';
import 'hadith_page.dart';
import 'theme.dart';

/// دليل الحج والعمرة خطوة بخطوة: Umrah and Hajj (تمتع) steps with rulings, adhkar, mistakes, a checklist
/// saved on the device, ihram prohibitions, the mawaqit and a map of the holy sites.
class HajjPage extends StatefulWidget {
  final int initialTab;
  const HajjPage({super.key, this.initialTab = 0});
  @override
  State<HajjPage> createState() => _HajjPageState();
}

class _HajjPageState extends State<HajjPage> {
  late final Future<HajjData> _data = HajjData.load();
  final _checks = ValueNotifier<Set<String>>({});

  @override
  void initState() {
    super.initState();
    HajjChecks.load().then((s) => _checks.value = s);
  }

  @override
  void dispose() {
    _checks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دليل الحج والعمرة'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'العمرة'),
              Tab(text: 'الحج'),
              Tab(text: 'الإحرام والمواقيت'),
              Tab(text: 'الخريطة'),
            ],
          ),
        ),
        body: FutureBuilder<HajjData>(
          future: _data,
          builder: (context, snap) {
            final d = snap.data;
            if (d == null) {
              return Center(child: snap.hasError ? const Text('تعذّر تحميل البيانات') : const CircularProgressIndicator());
            }
            return TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _GuideView(data: d, guide: d.guide('umrah'), checks: _checks),
                _GuideView(data: d, guide: d.guide('hajj'), checks: _checks),
                _ExtrasView(data: d, checks: _checks),
                HajjMap(data: d),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _toggle(ValueNotifier<Set<String>> checks, String key, bool v) {
  final s = {...checks.value};
  v ? s.add(key) : s.remove(key);
  checks.value = s;
  HajjChecks.save(s);
}

Color rulingColor(String ruling) => switch (ruling) {
  'ركن' => const Color(0xFFD9534F),
  'واجب' => const Color(0xFFE08A1E),
  _ => AppColors.emerald,
};

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final bool onHero;
  const _Badge(this.text, this.color, {this.onHero = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: onHero ? 0.85 : 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: onHero ? 1 : 0.55)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: onHero ? Colors.white : color),
    ),
  );
}

const _khilafColor = Colors.orange;

Widget _sectionTitle(BuildContext context, String t, IconData icon) => Padding(
  padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
  child: Row(
    children: [
      Icon(icon, size: 20, color: AppColors.gold),
      const SizedBox(width: 8),
      Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
    ],
  ),
);

/// One guide: hero with progress, (for Hajj) the three types, then the steps grouped by day.
class _GuideView extends StatelessWidget {
  final HajjData data;
  final HajjGuide guide;
  final ValueNotifier<Set<String>> checks;
  const _GuideView({required this.data, required this.guide, required this.checks});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final isHajj = guide.id == 'hajj';
    return ValueListenableBuilder<Set<String>>(
      valueListenable: checks,
      builder: (context, done, _) {
        final keys = guide.checkKeys.toList();
        final n = keys.where(done.contains).length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(18),
              decoration: hero3D(radius: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(guide.icon, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guide.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                              ),
                            ),
                            Text(
                              '${Arabic.digits(guide.steps.length)} خطوات بالترتيب',
                              style: TextStyle(color: AppColors.goldLight, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(guide.intro, style: TextStyle(color: AppColors.heroText, fontSize: 13.5, height: 1.8)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.checklist_rounded, size: 18, color: AppColors.goldLight),
                      const SizedBox(width: 6),
                      Text(
                        'أنجزت ${Arabic.digits(n)} من ${Arabic.digits(keys.length)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (n > 0)
                        InkWell(
                          onTap: () => _confirmReset(context, keys),
                          child: Text(
                            'مسح',
                            style: TextStyle(color: AppColors.heroText, fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: keys.isEmpty ? 0 : n / keys.length,
                      minHeight: 8,
                      color: AppColors.goldLight,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
            ),
            _RulingLegend(data: data),
            if (isHajj) _TypesCard(data: data),
            for (final (i, s) in guide.steps.indexed) ...[
              if (isHajj && (i == 0 || guide.steps[i - 1].day != s.day)) _DayHeader(hajjDayTitle(s.day)),
              _StepTile(
                step: s,
                done: [for (var i = 0; i < s.checklist.length; i++) s.checkKey(i)].where(done.contains).length,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HajjStepPage(data: data, guide: guide, start: guide.steps.indexOf(s), checks: checks),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                '${data.note}\nجُمعت في ${Arabic.digits(data.collected.replaceAll('-', '/'))}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: hint, height: 1.7),
              ),
            ),
            _RefsList(refs: guide.refs),
          ],
        );
      },
    );
  }

  void _confirmReset(BuildContext context, List<String> keys) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('مسح قائمة التحقق؟'),
        content: Text('ستُلغى علامات ${guide.name} كلها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('مسح')),
        ],
      ),
    );
    if (ok != true) return;
    final s = {...checks.value}..removeAll(keys);
    checks.value = s;
    HajjChecks.save(s);
  }
}

/// Section headers of the Hajj guide, by day of Dhul-Hijjah.
String hajjDayTitle(int day) => switch (day) {
  0 => 'قبل أيام الحج: العمرة',
  8 => 'يوم التروية • ٨ ذو الحجة',
  9 => 'يوم عرفة وليلة مزدلفة • ٩ ذو الحجة',
  10 => 'يوم النحر • ١٠ ذو الحجة',
  11 || 12 => 'أيام التشريق • ١١–١٣ ذو الحجة',
  _ => 'قبل السفر',
};

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
    child: Row(
      children: [
        Icon(Icons.wb_sunny_outlined, size: 18, color: AppColors.gold),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold, fontSize: 14.5),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: AppColors.gold.withValues(alpha: 0.35))),
      ],
    ),
  );
}

class _RulingLegend extends StatelessWidget {
  final HajjData data;
  const _RulingLegend({required this.data});
  @override
  Widget build(BuildContext context) {
    return Card3D(
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(Icons.balance_rounded, color: AppColors.gold),
        title: const Text('الركن والواجب والسنة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Wrap(
          spacing: 6,
          children: [for (final r in data.rulings.keys) _Badge(r, rulingColor(r)), const _Badge('خلاف', _khilafColor)],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in data.rulings.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 52, child: _Badge(e.key, rulingColor(e.key))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value, style: const TextStyle(height: 1.7))),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 52, child: _Badge('خلاف', _khilafColor)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('اختلف أهل العلم في حكم هذه الخطوة؛ والمذكور قول الجمهور أو الأرجح عند المصدر.', style: TextStyle(height: 1.7)),
              ),
            ],
          ),
          _RefsList(refs: [data.rulingsRef], dense: true),
        ],
      ),
    );
  }
}

class _TypesCard extends StatelessWidget {
  final HajjData data;
  const _TypesCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Card3D(
      child: ExpansionTile(
        shape: const Border(),
        leading: const Text('🧭', style: TextStyle(fontSize: 22)),
        title: const Text('أنواع النسك: تمتع، قران، إفراد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text('الدليل يسير على التمتع، مع التنبيه على الفروق', style: TextStyle(fontSize: 12, color: hint)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(data.typesIntro, style: const TextStyle(height: 1.8)),
          if (data.typesKhilaf)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Align(alignment: AlignmentDirectional.centerStart, child: _Badge('في الأفضل خلاف', _khilafColor)),
            ),
          for (final t in data.types)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsetsDirectional.only(start: 10),
              decoration: BoxDecoration(
                border: BorderDirectional(start: BorderSide(color: AppColors.gold.withValues(alpha: 0.6), width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        t.name,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: AppColors.gold),
                      ),
                      const SizedBox(width: 8),
                      _Badge(t.hady ? 'عليه هدي' : 'لا هدي عليه', t.hady ? rulingColor('واجب') : AppColors.emerald),
                    ],
                  ),
                  Text('«${t.talbiya}»', style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 15.5, height: 1.9)),
                  Text(t.text, style: const TextStyle(height: 1.75, fontSize: 14)),
                ],
              ),
            ),
          for (final dh in data.typesDuas) _DhikrCard(dh, flat: true),
          _RefsList(refs: data.typesRefs, dense: true),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final HajjStep step;
  final int done;
  final VoidCallback onTap;
  const _StepTile({required this.step, required this.done, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final total = step.checklist.length;
    final complete = total > 0 && done == total;
    return Card3D(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Tile3D(
                size: 42,
                gold: complete,
                child: complete
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : Text(Arabic.digits(step.order), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(step.dayLabel, style: TextStyle(fontSize: 12, color: hint)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(step.ruling, rulingColor(step.ruling)),
                        if (step.khilaf) const _Badge('خلاف', _khilafColor),
                        if (total > 0) _Badge('${Arabic.digits(done)}/${Arabic.digits(total)}', complete ? AppColors.gold : hint),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

/// One step; swipe or use the arrows for the next/previous step.
class HajjStepPage extends StatefulWidget {
  final HajjData data;
  final HajjGuide guide;
  final int start;
  final ValueNotifier<Set<String>> checks;
  const HajjStepPage({super.key, required this.data, required this.guide, required this.start, required this.checks});
  @override
  State<HajjStepPage> createState() => _HajjStepPageState();
}

class _HajjStepPageState extends State<HajjStepPage> {
  late final _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int i) => _pc.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final steps = widget.guide.steps;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.guide.name} • ${Arabic.digits(_i + 1)}/${Arabic.digits(steps.length)}'),
        actions: [
          IconButton(tooltip: 'السابق', icon: const Icon(Icons.chevron_left), onPressed: _i > 0 ? () => _go(_i - 1) : null),
          IconButton(tooltip: 'التالي', icon: const Icon(Icons.chevron_right), onPressed: _i < steps.length - 1 ? () => _go(_i + 1) : null),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: steps.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (context, i) => _StepView(data: widget.data, step: steps[i], checks: widget.checks),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final HajjData data;
  final HajjStep step;
  final ValueNotifier<Set<String>> checks;
  const _StepView({required this.data, required this.step, required this.checks});

  @override
  Widget build(BuildContext context) {
    final place = data.place(step.place);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: hero3D(radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tile3D(
                    gold: true,
                    size: 46,
                    child: Text(
                      Arabic.digits(step.order),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                          ),
                        ),
                        Text(
                          step.dayLabel,
                          style: TextStyle(color: AppColors.goldLight, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Badge(step.ruling, rulingColor(step.ruling), onHero: true),
                  if (step.khilaf) const _Badge('في المسألة خلاف', _khilafColor, onHero: true),
                ],
              ),
              if (step.rulingNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(step.rulingNote, style: TextStyle(color: AppColors.heroText, fontSize: 13.5, height: 1.75)),
              ],
              if (place != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.goldLight,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: Text('${place.name} على الخريطة'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HajjMapPage(data: data, focus: place.id),
                      ),
                    ),
                  ),
                ),
              ] else if (step.place == 'miqat') ...[
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.goldLight,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: const Text('المواقيت على الخريطة'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HajjMapPage(data: data, focus: 'mawaqit'),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _sectionTitle(context, 'ماذا تفعل', Icons.directions_walk_rounded),
        Card3D(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                for (var i = 0; i < step.what.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.16), shape: BoxShape.circle),
                          child: Text(
                            Arabic.digits(i + 1),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(step.what[i], style: const TextStyle(fontSize: 15, height: 1.85))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (step.others.isNotEmpty)
          Card3D(
            child: ListTile(
              leading: const Text('🧭', style: TextStyle(fontSize: 22)),
              title: const Text('للقارن والمفرد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              subtitle: Text(step.others, style: const TextStyle(height: 1.7, fontSize: 13.5)),
            ),
          ),
        if (step.duas.isNotEmpty) _sectionTitle(context, 'أذكار وأدعية وأدلة', Icons.format_quote_rounded),
        for (final d in step.duas) _DhikrCard(d),
        if (step.mistakes.isNotEmpty) _sectionTitle(context, 'أخطاء شائعة', Icons.report_gmailerrorred_rounded),
        if (step.mistakes.isNotEmpty)
          Card3D(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  for (final m in step.mistakes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(Icons.close_rounded, size: 18, color: Color(0xFFD9534F)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(m, style: const TextStyle(fontSize: 14.5, height: 1.8))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (step.checklist.isNotEmpty) _sectionTitle(context, 'قائمة التحقق', Icons.checklist_rounded),
        if (step.checklist.isNotEmpty)
          ValueListenableBuilder<Set<String>>(
            valueListenable: checks,
            builder: (context, done, _) => Card3D(
              child: Column(
                children: [
                  for (var i = 0; i < step.checklist.length; i++)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.emerald,
                      value: done.contains(step.checkKey(i)),
                      title: Text(
                        step.checklist[i],
                        style: TextStyle(fontSize: 14.5, decoration: done.contains(step.checkKey(i)) ? TextDecoration.lineThrough : null),
                      ),
                      onChanged: (v) => _toggle(checks, step.checkKey(i), v ?? false),
                    ),
                ],
              ),
            ),
          ),
        _sectionTitle(context, 'المصادر', Icons.menu_book_outlined),
        _RefsList(refs: step.refs),
      ],
    );
  }
}

/// A dua/dhikr: Qur'an in the Mushaf font, hadith with its source; a hadith in the bundled Sahihs opens in full.
class _DhikrCard extends StatelessWidget {
  final HajjDhikr d;
  final bool flat;
  const _DhikrCard(this.d, {this.flat = false});

  String get _source => d.isQuran ? 'القرآن الكريم • ${_surahName(d.surah)} ${Arabic.digits(d.ayah)}' : Arabic.digits(d.source);

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final c = d.isQuran ? AppColors.gold : AppColors.emerald;
    final body = Padding(
      padding: EdgeInsets.fromLTRB(flat ? 0 : 16, 12, flat ? 0 : 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(d.isQuran ? '﴿${d.text}﴾' : '«${d.text}»', style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 17, height: 2.0)),
          if (d.note.isNotEmpty) Text(d.note, style: TextStyle(fontSize: 12.5, color: hint, height: 1.6)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(d.isQuran ? Icons.menu_book_rounded : Icons.verified_outlined, size: 15, color: c),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _source,
                  style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700),
                ),
              ),
              if (d.inSahihs)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: c, visualDensity: VisualDensity.compact),
                  onPressed: () => _openHadith(context),
                  child: const Text('الحديث كاملًا'),
                )
              else if (d.via.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: c, visualDensity: VisualDensity.compact),
                  onPressed: () => launchUrl(Uri.parse(d.via), mode: LaunchMode.externalApplication),
                  child: const Text('التخريج'),
                ),
            ],
          ),
        ],
      ),
    );
    return flat ? body : Card3D(child: body);
  }

  void _openHadith(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (c, sc) => FutureBuilder(
          future: findGhazwaHadith(GhazwaHadith(d.collection, d.number, '', d.contains)),
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final h = snap.data;
            return ListView(
              controller: sc,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (h == null) const Padding(padding: EdgeInsets.all(24), child: Text('تعذّر العثور على الحديث.')) else HadithCard(h),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _surahName(int n) => const {2: 'البقرة', 5: 'المائدة', 22: 'الحج', 48: 'الفتح'}[n] ?? 'سورة $n';

class _RefsList extends StatelessWidget {
  final List<HajjRef> refs;
  final bool dense;
  const _RefsList({required this.refs, this.dense = false});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in refs)
          InkWell(
            onTap: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.source,
                          style: TextStyle(fontSize: 11.5, color: AppColors.emerald, fontWeight: FontWeight.w700),
                        ),
                        Text(Arabic.digits(r.ref), style: TextStyle(fontSize: 12.5, color: hint, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (dense) return Padding(padding: const EdgeInsets.only(top: 8), child: list);
    return Card3D(
      child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 6), child: list),
    );
  }
}

/// محظورات الإحرام، المواقيت وقائمة الأمتعة.
class _ExtrasView extends StatelessWidget {
  final HajjData data;
  final ValueNotifier<Set<String>> checks;
  const _ExtrasView({required this.data, required this.checks});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _sectionTitle(context, 'محظورات الإحرام', Icons.block_rounded),
        Card3D(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(data.mahzuratIntro, style: const TextStyle(height: 1.8)),
                for (final g in data.mahzurat) ...[
                  const SizedBox(height: 10),
                  Text(
                    g.name,
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold, fontSize: 15),
                  ),
                  for (final it in g.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(
                              g.name.startsWith('مما يجوز') ? Icons.check_circle_outline : Icons.do_not_disturb_on_outlined,
                              size: 16,
                              color: g.name.startsWith('مما يجوز') ? AppColors.emerald : const Color(0xFFD9534F),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(it, style: const TextStyle(fontSize: 14.5, height: 1.75))),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        for (final d in data.mahzuratDuas) _DhikrCard(d),
        _RefsList(refs: data.mahzuratRefs),
        _sectionTitle(context, 'المواقيت المكانية', Icons.flag_outlined),
        Card3D(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(data.mawaqitIntro, style: const TextStyle(height: 1.8)),
          ),
        ),
        for (final m in data.mawaqit)
          Card3D(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
              leading: Tile3D(size: 40, child: Icon(Icons.flag_rounded, color: AppColors.gold, size: 22)),
              title: Text('${m.name} • ${m.modern}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لـ${m.forWhom} • نحو ${Arabic.digits(m.km)} كم من مكة',
                    style: TextStyle(fontSize: 12.5, color: AppColors.emerald, fontWeight: FontWeight.w600),
                  ),
                  Text(m.note, style: TextStyle(fontSize: 12.5, height: 1.6, color: hint)),
                  Text(
                    '${Arabic.digits(m.lat.toStringAsFixed(4))}° ش، ${Arabic.digits(m.lng.toStringAsFixed(4))}° ق${m.approx ? ' (تقريبي)' : ''}',
                    style: TextStyle(fontSize: 11.5, color: hint),
                  ),
                ],
              ),
              trailing: IconButton(
                tooltip: 'على الخريطة',
                icon: Icon(Icons.map_outlined, color: AppColors.gold),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HajjMapPage(data: data, focus: m.id),
                  ),
                ),
              ),
            ),
          ),
        for (final d in data.mawaqitDuas) _DhikrCard(d),
        _RefsList(refs: data.mawaqitRefs),
        _sectionTitle(context, 'حقيبة الحاج', Icons.luggage_outlined),
        ValueListenableBuilder<Set<String>>(
          valueListenable: checks,
          builder: (context, done, _) => Card3D(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(data.packingNote, style: TextStyle(fontSize: 12.5, color: hint, height: 1.6)),
                ),
                for (var i = 0; i < data.packing.length; i++)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.emerald,
                    value: done.contains(HajjChecks.packKey(i)),
                    title: Text(data.packing[i], style: const TextStyle(fontSize: 14.5)),
                    onChanged: (v) => _toggle(checks, HajjChecks.packKey(i), v ?? false),
                  ),
              ],
            ),
          ),
        ),
        _RefsList(refs: data.packingRefs),
      ],
    );
  }
}

/// Full-screen map, opened from a step («على الخريطة») or a miqat.
class HajjMapPage extends StatelessWidget {
  final HajjData data;
  final String? focus;
  const HajjMapPage({super.key, required this.data, this.focus});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('خريطة المشاعر والمواقيت')),
    body: HajjMap(data: data, focus: focus),
  );
}

/// The holy sites around Makkah and the five mawaqit, on OSM tiles with an Esri satellite toggle.
class HajjMap extends StatefulWidget {
  final HajjData data;
  final String? focus; // a place/miqat id, or 'mawaqit'
  const HajjMap({super.key, required this.data, this.focus});
  @override
  State<HajjMap> createState() => _HajjMapState();
}

class _HajjMapState extends State<HajjMap> {
  final _map = MapController();
  bool _satellite = false;
  late bool _wide = widget.focus == 'mawaqit' || widget.data.mawaqit.any((m) => m.id == widget.focus);

  List<LatLng> get _mashaer => [
    for (final p in widget.data.places)
      if (!p.optional) LatLng(p.lat, p.lng),
  ];
  List<LatLng> get _all => [
    for (final p in widget.data.places) LatLng(p.lat, p.lng),
    for (final m in widget.data.mawaqit) LatLng(m.lat, m.lng),
  ];

  /// Room for the chips on top and the labels above the pins.
  static EdgeInsets _pad(bool wide) => wide ? const EdgeInsets.fromLTRB(40, 110, 40, 30) : const EdgeInsets.fromLTRB(56, 110, 56, 40);

  CameraFit _fit(bool wide) {
    final f = widget.focus;
    if (f != null && f != 'mawaqit') {
      final p = widget.data.place(f);
      final m = widget.data.mawaqit.where((m) => m.id == f).firstOrNull;
      final pt = p != null
          ? LatLng(p.lat, p.lng)
          : m != null
          ? LatLng(m.lat, m.lng)
          : null;
      if (pt != null && !wide) return CameraFit.coordinates(coordinates: [pt], maxZoom: 14);
      if (pt != null && m != null) {
        return CameraFit.coordinates(coordinates: [pt, const LatLng(21.4225, 39.8262)], padding: _pad(true));
      }
    }
    return CameraFit.coordinates(coordinates: wide ? _all : _mashaer, padding: _pad(wide), maxZoom: 14);
  }

  void _setWide(bool v) {
    setState(() => _wide = v);
    _map.fitCamera(CameraFit.coordinates(coordinates: v ? _all : _mashaer, padding: _pad(v), maxZoom: 14));
  }

  /// A pin with its label above it (no label when [label] is empty).
  Marker _marker({required LatLng at, required String label, required bool miqat, required VoidCallback onTap}) => Marker(
    point: at,
    width: 120,
    height: 54,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (label.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (miqat ? const Color(0xFF6B4F12) : AppColors.current.hero[1]).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.current.accentLight.withValues(alpha: 0.8)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          Icon(
            miqat ? Icons.flag_rounded : Icons.location_on,
            color: miqat ? const Color(0xFFF2C14E) : AppColors.current.accentLight,
            size: 24,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: _fit(_wide),
            initialCenter: const LatLng(21.4, 39.9),
            initialZoom: 11,
            minZoom: 4,
            maxZoom: 18,
          ),
          children: [
            _satellite
                ? TileLayer(
                    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.mawaqeety.app',
                  )
                : TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.mawaqeety.app'),
            MarkerLayer(
              markers: [
                for (final m in d.mawaqit)
                  _marker(at: LatLng(m.lat, m.lng), label: 'ميقات ${m.name}', miqat: true, onTap: () => _showMiqat(context, m)),
                // Zoomed out, the sites around Makkah would pile up: keep the Haram, and Madinah's pin without a label
                // (it sits right by Dhul-Hulayfah).
                for (final p in d.places)
                  if (!_wide || p.id == 'haram' || p.optional)
                    _marker(
                      at: LatLng(p.lat, p.lng),
                      label: _wide && p.optional ? '' : p.name,
                      miqat: false,
                      onTap: () => _showPlace(context, p),
                    ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(
                  _satellite ? 'Esri, Maxar, Earthstar Geographics' : 'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse(_satellite ? 'https://www.esri.com' : 'https://www.openstreetmap.org/copyright')),
                ),
              ],
            ),
          ],
        ),
        PositionedDirectional(
          top: 10,
          start: 10,
          end: 10,
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('المشاعر'), selected: !_wide, onSelected: (_) => _setWide(false)),
              ChoiceChip(label: const Text('المواقيت والمدينة'), selected: _wide, onSelected: (_) => _setWide(true)),
            ],
          ),
        ),
        Positioned(
          bottom: 26,
          right: 10,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: IconButton(
              tooltip: _satellite ? 'الخريطة' : 'قمر صناعي',
              icon: Icon(_satellite ? Icons.map_outlined : Icons.satellite_alt_outlined, color: Colors.black87),
              onPressed: () => setState(() => _satellite = !_satellite),
            ),
          ),
        ),
      ],
    );
  }

  void _sheet(BuildContext context, String title, String badge, List<Widget> body) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                if (badge.isNotEmpty) _Badge(badge, AppColors.gold),
              ],
            ),
            const SizedBox(height: 8),
            ...body,
          ],
        ),
      ),
    );
  }

  void _showPlace(BuildContext context, HajjPlace p) => _sheet(context, p.name, p.optional ? 'للزيارة' : 'من المشاعر', [
    Text(p.desc, style: const TextStyle(height: 1.8, fontSize: 15)),
    const SizedBox(height: 4),
    Text(
      '${Arabic.digits(p.lat.toStringAsFixed(4))}° ش، ${Arabic.digits(p.lng.toStringAsFixed(4))}° ق',
      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
    ),
  ]);

  void _showMiqat(BuildContext context, HajjMiqat m) => _sheet(context, 'ميقات ${m.name}', m.modern, [
    Text(
      'لـ${m.forWhom}',
      style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 4),
    Text(m.note, style: const TextStyle(height: 1.8, fontSize: 15)),
    const SizedBox(height: 4),
    Text(
      '${Arabic.digits(m.lat.toStringAsFixed(4))}° ش، ${Arabic.digits(m.lng.toStringAsFixed(4))}° ق${m.approx ? ' (تقريبي)' : ''}',
      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
    ),
  ]);
}
