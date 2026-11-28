import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../data/hisn.dart';
import '../main.dart';
import 'adhkar_page.dart';
import 'share_card.dart';
import 'theme.dart';

/// «حصن المسلم»: the book's chapters, numbered as in the book, with search and a filter by topic.
class HisnPage extends StatefulWidget {
  const HisnPage({super.key});
  @override
  State<HisnPage> createState() => _HisnPageState();
}

class _HisnPageState extends State<HisnPage> {
  final _query = TextEditingController();
  String? _topic;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(HisnChapter c, [HisnDhikr? d]) {
    final page = c.link == 'adhkar' ? const AdhkarPage() : HisnChapterPage(chapter: c, focus: d);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حصن المسلم')),
      body: FutureBuilder(
        future: Hisn.load(),
        builder: (context, snap) {
          if (Hisn.chapters.isEmpty) return const Center(child: CircularProgressIndicator());
          final q = _query.text.trim();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث في الأبواب والأذكار',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_query.clear)),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (q.isEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip(null, 'الكل'),
                    for (final t in Hisn.topics) _chip(t.id, '${t.emoji} ${t.title}'),
                  ],
                ),
              ),
            Expanded(child: q.isEmpty ? _chapters() : _results(q)),
          ]);
        },
      ),
    );
  }

  Widget _chip(String? id, String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12.5)),
          selected: _topic == id,
          onSelected: (_) => setState(() => _topic = id),
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _chapters() {
    final list = Hisn.chapters.where((c) => _topic == null || c.topic == _topic).toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: list.length + 1,
      itemBuilder: (context, i) {
        if (i == list.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('من كتاب «${Hisn.bookSource}»، بترقيم أبوابه وأذكاره.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
          );
        }
        return _ChapterTile(chapter: list[i], onTap: () => _open(list[i]));
      },
    );
  }

  Widget _results(String q) {
    final hits = Hisn.search(q);
    if (hits.isEmpty) {
      return Center(child: Text('لا نتائج', style: TextStyle(color: Theme.of(context).hintColor)));
    }
    final hint = Theme.of(context).hintColor;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final (c, d) = hits[i];
        if (d == null) return _ChapterTile(chapter: c, onTap: () => _open(c));
        return Card3D(
          child: InkWell(
            onTap: () => _open(c, d),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(c.heading, style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(d.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.7)),
                if (d.number != null)
                  Text('الذكر رقم ${Arabic.digits(d.number!)}', style: TextStyle(fontSize: 11, color: hint)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final HisnChapter chapter;
  final VoidCallback onTap;
  const _ChapterTile({required this.chapter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = chapter;
    final hint = Theme.of(context).hintColor;
    final n = c.items.length;
    return Card3D(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(c.number == 0 ? '✦' : Arabic.digits(c.number),
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                Text(
                    c.link == 'adhkar'
                        ? 'في تبويب «الأذكار»'
                        : (n == 1 ? 'ذكر واحد' : n == 2 ? 'ذكران' : '${Arabic.digits(n)} ${n <= 10 ? 'أذكار' : 'ذكرًا'}'),
                    style: TextStyle(fontSize: 11.5, color: hint)),
              ]),
            ),
            Icon(Icons.chevron_left, color: hint),
          ]),
        ),
      ),
    );
  }
}

/// One chapter: the dhikr cards. Tap a card to count, the icons copy or share it.
class HisnChapterPage extends StatefulWidget {
  final HisnChapter chapter;

  /// Scrolls to this dhikr when the page opens (from search or «سبيل»).
  final HisnDhikr? focus;
  const HisnChapterPage({super.key, required this.chapter, this.focus});
  @override
  State<HisnChapterPage> createState() => _HisnChapterPageState();
}

class _HisnChapterPageState extends State<HisnChapterPage> {
  final _left = <HisnDhikr, int>{};
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _focusKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300), alignment: 0.1);
      });
    }
  }

  void _tap(HisnDhikr d) {
    final n = _left[d] ?? d.count;
    if (n == 0) return;
    setState(() => _left[d] = n - 1);
    HapticFeedback.selectionClick();
    if (n - 1 == 0) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chapter;
    final hint = Theme.of(context).hintColor;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.heading, maxLines: 2, style: const TextStyle(fontSize: 17)),
        actions: [
          if (c.items.any((d) => d.count > 1))
            IconButton(
              tooltip: 'البدء من جديد',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => setState(_left.clear),
            ),
        ],
      ),
      // A Column in a scroll view (not a lazy list) so that [focus] can be scrolled to on any chapter length.
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final d in c.items)
            _HisnCard(
              key: d == widget.focus ? _focusKey : null,
              dhikr: d,
              left: _left[d] ?? d.count,
              onTap: () => _tap(d),
            ),
          if (c.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Text('التخريج: ${c.sources.join(' • ')}', style: TextStyle(fontSize: 11.5, color: hint)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('من كتاب «${Hisn.bookSource}»\nاضغط على الذكر للعدّ.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: hint)),
          ),
        ]),
      ),
    );
  }
}

class _HisnCard extends StatelessWidget {
  final HisnDhikr dhikr;
  final int left;
  final VoidCallback onTap;
  const _HisnCard({super.key, required this.dhikr, required this.left, required this.onTap});

  /// The text with the Qur'an quotations in the mushaf's script (from the app's Qur'an).
  List<InlineSpan> _spans(double size) {
    final d = dhikr;
    if (d.parts.isEmpty) return [TextSpan(text: d.text)];
    final out = <InlineSpan>[];
    final q = TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: 2.1);
    for (final p in d.parts) {
      final ref = p.quran;
      if (ref == null) {
        out.add(TextSpan(text: p.text));
      } else if (p.partial) {
        out.add(TextSpan(text: '﴿${p.text.trim()}﴾', style: q));
      } else {
        final (s, from, to) = ref;
        final verses = app.repo.surahs[s - 1].verses;
        out.add(TextSpan(text: '﴿', style: q));
        for (var a = from; a <= to; a++) {
          out.add(TextSpan(text: verses[a - 1], style: q));
          out.add(TextSpan(text: ' ﴿${Arabic.digits(a)}﴾ ', style: q.copyWith(fontSize: size * 0.8, color: AppColors.gold)));
        }
        out.add(TextSpan(text: '﴾', style: q));
      }
    }
    return out;
  }

  String get _plainText => _spans(20).map((s) => (s as TextSpan).text ?? '').join().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final d = dhikr;
    final hint = Theme.of(context).hintColor;
    final size = app.settings.quranFontSize.clamp(18, 30).toDouble();
    final done = left == 0;
    return Card3D(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Opacity(
              opacity: done ? 0.55 : 1,
              child: Text.rich(TextSpan(children: _spans(size)),
                  style: TextStyle(fontSize: size * 0.85, height: 1.9, color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.justify),
            ),
            if (d.virtue.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(d.virtue, style: TextStyle(fontSize: 13, color: AppColors.emerald)),
            ],
            const SizedBox(height: 8),
            Text(d.source, style: TextStyle(fontSize: 11.5, color: hint)),
            Row(children: [
              if (d.number != null) Text('الذكر ${Arabic.digits(d.number!)}', style: TextStyle(fontSize: 11.5, color: hint)),
              const Spacer(),
              IconButton(
                tooltip: 'نسخ',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.copy_rounded, size: 18, color: hint),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '$_plainText\n\n${d.source}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الذكر')));
                },
              ),
              IconButton(
                tooltip: 'مشاركة كصورة',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.share_outlined, size: 19, color: hint),
                onPressed: () => shareAsImage(context, text: _plainText, ref: d.source, title: d.chapter.title),
              ),
              Text(d.count > 1 ? 'التكرار: ${Arabic.digits(d.count)}' : 'مرة واحدة', style: TextStyle(fontSize: 12, color: hint)),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 46),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: done ? AppColors.emerald : AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: done
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text(Arabic.digits(left), textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
