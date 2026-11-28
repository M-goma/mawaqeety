import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../data/arbaeen.dart';
import '../data/hadith.dart';
import 'hadith_page.dart';
import 'share_card.dart';
import 'theme.dart';

/// «حفظت ١٢ من ٤٢».
String memorizedLabel(int n, int total) => 'حفظت ${Arabic.digits(n)} من ${Arabic.digits(total)}';

/// الأربعون النووية: the 42 hadiths with an-Nawawi's takhrij, links to the two Sahihs, benefits from
/// Ibn Rajab's commentary and a «memorised» tick per hadith.
class ArbaeenPage extends StatefulWidget {
  const ArbaeenPage({super.key});
  @override
  State<ArbaeenPage> createState() => _ArbaeenPageState();
}

class _ArbaeenPageState extends State<ArbaeenPage> {
  late final Future<(Arbaeen, Set<int>)> _load = _init();

  static Future<(Arbaeen, Set<int>)> _init() async => (await Arbaeen.load(), await ArbaeenMemory.load());
  Set<int>? _done;

  void _toggle(int n, bool v) {
    final s = {...?_done};
    v ? s.add(n) : s.remove(n);
    setState(() => _done = s);
    ArbaeenMemory.save(s);
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Scaffold(
      appBar: AppBar(title: const Text('الأربعون النووية')),
      body: FutureBuilder(
        future: _load,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final book = d.$1;
          final done = _done ??= d.$2;
          final total = book.hadiths.length;
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(18),
              decoration: hero3D(radius: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(book.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))])),
                Text(book.author, style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                for (final a in book.about)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('«$a»', style: const TextStyle(fontFamily: 'AmiriQuran', color: Colors.white, fontSize: 15.5, height: 1.9)),
                  ),
                Text('— ${book.aboutSource}', style: TextStyle(color: AppColors.heroText, fontSize: 12)),
                const SizedBox(height: 8),
                Text('اثنان وأربعون حديثًا جمعها النووي (ت ٦٧٦هـ)، وجرى عليها اسم «الأربعين» تغليبًا.',
                    style: TextStyle(color: AppColors.heroText, fontSize: 12.5, height: 1.7)),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.verified_outlined, size: 18, color: AppColors.goldLight),
                  const SizedBox(width: 6),
                  Text(memorizedLabel(done.length, total),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${Arabic.digits((done.length * 100 / total).round())}٪', style: TextStyle(color: AppColors.heroText, fontSize: 12)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: done.length / total,
                    minHeight: 8,
                    color: AppColors.goldLight,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ]),
            ),
            for (final h in book.hadiths)
              Card3D(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Tile3D(
                    size: 40,
                    gold: done.contains(h.number),
                    child: Text(Arabic.digits(h.number), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: Text(h.narrator, style: TextStyle(fontSize: 12.5, color: hint)),
                  trailing: done.contains(h.number)
                      ? Icon(Icons.check_circle, color: AppColors.gold)
                      : const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArbaeenHadithPage(
                        book: book,
                        start: book.hadiths.indexOf(h),
                        memorized: () => _done ?? const {},
                        onToggle: _toggle,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                'النص من نسخة مشكولة للأربعين (مستودع hadith-json)، قوبل كاملًا على طبعة دار المنهاج (نسخة OpenITI) وعلى ألفاظ الصحيحين المرفقة في التطبيق، وصُحّحت الفروق. '
                'الفوائد مقتبسة بنصها من «جامع العلوم والحكم» لابن رجب الحنبلي في المكتبة الإسلامية بموقع إسلام ويب، مع رابط كل حديث.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: hint, height: 1.7),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// One hadith; swipe or use the arrows for the next/previous one.
class ArbaeenHadithPage extends StatefulWidget {
  final Arbaeen book;
  final int start;
  final Set<int> Function() memorized;
  final void Function(int number, bool value) onToggle;
  const ArbaeenHadithPage({super.key, required this.book, required this.start, required this.memorized, required this.onToggle});
  @override
  State<ArbaeenHadithPage> createState() => _ArbaeenHadithPageState();
}

class _ArbaeenHadithPageState extends State<ArbaeenHadithPage> {
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
    final list = widget.book.hadiths;
    return Scaffold(
      appBar: AppBar(
        // chevron icons mirror in RTL: «السابق» shows → and «التالي» shows ←.
        title: Text('الحديث ${_ordinal(list[_i].number)}'),
        actions: [
          IconButton(tooltip: 'السابق', icon: const Icon(Icons.chevron_left), onPressed: _i > 0 ? () => _go(_i - 1) : null),
          IconButton(tooltip: 'التالي', icon: const Icon(Icons.chevron_right), onPressed: _i < list.length - 1 ? () => _go(_i + 1) : null),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: list.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (context, i) => _HadithView(
          h: list[i],
          memorized: widget.memorized().contains(list[i].number),
          onToggle: (v) => setState(() => widget.onToggle(list[i].number, v)),
        ),
      ),
    );
  }
}

class _HadithView extends StatelessWidget {
  final ArbaeenHadith h;
  final bool memorized;
  final ValueChanged<bool> onToggle;
  const _HadithView({required this.h, required this.memorized, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final ref = 'الأربعون النووية • ${Arabic.digits(h.number)} • ${h.takhrij}';
    return ListView(padding: const EdgeInsets.fromLTRB(0, 6, 0, 28), children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: hero3D(radius: 22),
        child: Row(children: [
          Tile3D(gold: true, size: 46, child: Text(Arabic.digits(h.number), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.4)),
              Text('رواية ${h.narrator}', style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
      Card3D(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SelectableText(h.text, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 19, height: 2.05)),
            const SizedBox(height: 6),
            _Chip(h.takhrij, color: AppColors.emerald),
            if (h.grade != null) ...[
              const SizedBox(height: 6),
              Align(alignment: AlignmentDirectional.centerStart, child: _Chip('درجته عند النووي: ${h.grade}', color: AppColors.gold)),
            ],
            if (h.extra case final e?) ...[
              const SizedBox(height: 12),
              Text(e.label, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              SelectableText(e.text, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18, height: 2)),
              if (e.takhrij.isNotEmpty) ...[const SizedBox(height: 4), _Chip(e.takhrij, color: AppColors.emerald)],
            ],
            if (h.note case final n?) ...[
              const SizedBox(height: 12),
              Text('قال النووي', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
              Text(n, style: const TextStyle(fontSize: 14, height: 1.8)),
            ],
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onToggle(!memorized),
                  child: Row(children: [
                    Checkbox(value: memorized, onChanged: (v) => onToggle(v ?? false)),
                    const Flexible(child: Text('حفظت هذا الحديث', style: TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
              IconButton(
                tooltip: 'نسخ',
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${h.copyText}\n— الأربعون النووية، الحديث ${Arabic.digits(h.number)}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الحديث')));
                },
              ),
              IconButton(
                tooltip: 'مشاركة كصورة',
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () => shareAsImage(context, text: h.text, ref: ref, title: h.title),
              ),
            ]),
          ]),
        ),
      ),
      if (h.isnadNote case final n?)
        Card3D(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.gold),
                const SizedBox(width: 6),
                Text('في إسناده كلام', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text('قال ابن رجب: «$n».', style: const TextStyle(fontSize: 14, height: 1.8)),
              const SizedBox(height: 4),
              Text('وحكم النووي عليه مذكور في تخريجه أعلاه؛ فهو مما اختلف فيه أهل الحديث.',
                  style: TextStyle(fontSize: 12, color: hint, height: 1.6)),
            ]),
          ),
        ),
      if (h.sahih.isNotEmpty || h.related.isNotEmpty)
        Card3D(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(h.sahih.isNotEmpty ? 'في الصحيحين' : 'أصله في الصحيحين', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in [...h.sahih, ...h.related])
                  OutlinedButton.icon(
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: Text('${r.name} • ${Arabic.digits(r.number)}'),
                    onPressed: () => _openSahih(context, r, h),
                  ),
              ]),
              const SizedBox(height: 6),
              Text('بترقيم محمد فؤاد عبد الباقي لصحيح مسلم، والترقيم المشهور لصحيح البخاري؛ وقد يختلف اللفظ يسيرًا عن لفظ النووي.',
                  style: TextStyle(fontSize: 11.5, color: hint, height: 1.6)),
            ]),
          ),
        ),
      if (h.benefits.isNotEmpty)
        Card3D(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.lightbulb_outline, size: 18, color: AppColors.gold),
                const SizedBox(width: 6),
                Text('من فوائد الحديث', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              for (final b in h.benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: const TextStyle(fontSize: 14.5, height: 1.85))),
                  ]),
                ),
              if (h.benefitsUrl case final u?)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('ابن رجب، جامع العلوم والحكم — إسلام ويب', style: TextStyle(fontSize: 12.5)),
                    onPressed: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
                  ),
                ),
            ]),
          ),
        ),
    ]);
  }

  Future<void> _openSahih(BuildContext context, SahihRef r, ArbaeenHadith a) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Hadith? h = await r.resolve();
    if (h == null) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر فتح الحديث')));
      return;
    }
    nav.push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('${r.name} • ${Arabic.digits(r.number)}')),
        body: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [HadithCard(h, title: a.title)]),
      ),
    ));
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, {required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600, height: 1.6)),
      );
}

const _ordinals = [
  'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر',
];

/// «الأول» … «الثاني والأربعون».
String _ordinal(int n) {
  if (n <= 10) return _ordinals[n - 1];
  if (n == 11) return 'الحادي عشر';
  if (n == 12) return 'الثاني عشر';
  if (n < 20) return '${_ordinals[n - 11]} عشر';
  const tens = {20: 'العشرون', 30: 'الثلاثون', 40: 'الأربعون'};
  final t = n ~/ 10 * 10, u = n % 10;
  if (u == 0) return tens[t]!;
  return '${u == 1 ? 'الحادي' : _ordinals[u - 1]} و${tens[t]}';
}

/// Exposed for tests.
String arbaeenOrdinal(int n) => _ordinal(n);
