import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../data/hifz.dart';
import '../data/sabeel.dart';
import '../main.dart';
import 'hifz_page.dart';
import 'share_card.dart';
import 'theme.dart';

/// Plays one ayah with the app's reciter (and nothing after it).
void playSingleAyah(int surah, int ayah) {
  app.narration.stop();
  app.adhan.stop();
  app.recitation.onFinished = null;
  app.recitation.play(app.repo, app.settings.reciterId, surah, ayah, ayah);
}

/// Bottom sheet of an ayah: its text (words with a meaning are tappable), the chosen tafsir, «معاني الكلمات», and actions (copy, share, listen, memorize).
/// [extra] adds the caller's own actions below (e.g. the Mushaf's reading position and bookmarks).
Future<void> showAyahSheet(BuildContext context, int surah, int ayah,
    {List<Widget> Function(BuildContext sheet)? extra, bool hifz = true}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (c, scroll) => AyahSheet(surah: surah, ayah: ayah, scroll: scroll, hifz: hifz, extra: extra?.call(c) ?? const []),
    ),
  );
}

class AyahSheet extends StatelessWidget {
  final int surah, ayah;
  final ScrollController? scroll;
  final bool hifz;
  final List<Widget> extra;
  const AyahSheet({super.key, required this.surah, required this.ayah, this.scroll, this.hifz = true, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = app.repo.surahs[surah - 1];
    final text = s.verses[ayah - 1];
    final ref = '${s.name} • ${Arabic.digits(ayah)}';
    Widget action(IconData icon, String label, VoidCallback onTap, {bool gold = false}) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Tile3D(size: 42, gold: gold, child: Icon(icon, size: 21, color: gold ? Colors.black87 : AppColors.emerald)),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return ListView(controller: scroll, padding: const EdgeInsets.only(bottom: 16), children: [
      Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40, height: 4,
          decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('سورة ${s.name} • الآية ${Arabic.digits(ayah)}',
                style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const Spacer(),
          Text('صفحة ${Arabic.digits(app.mushaf.pageOf(surah, ayah))}', style: TextStyle(color: theme.hintColor, fontSize: 12.5)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
        child: AyahWords(surah: surah, ayah: ayah),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          action(Icons.copy_rounded, 'نسخ', () async {
            final messenger = ScaffoldMessenger.of(context);
            final t = await Tafsir.load(app.settings.tafsirId).then<Tafsir?>((t) => t, onError: (_) => null);
            await Clipboard.setData(ClipboardData(
                text: '﴿$text﴾ [${s.name}: $ayah]${t == null ? '' : '\n\n${t.name}: ${t.of(surah, ayah)}'}'));
            messenger.showSnackBar(const SnackBar(content: Text('نُسخت الآية وتفسيرها')));
          }),
          action(Icons.share_outlined, 'مشاركة', () => shareAsImage(context, text: '﴿$text﴾', ref: ref)),
          action(Icons.headphones_rounded, 'استمع للآية', () {
            Navigator.pop(context);
            playSingleAyah(surah, ayah);
          }),
          if (hifz)
            action(Icons.psychology_alt_outlined, 'احفظ هذه الآية', gold: true, () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => HifzPage(initial: HifzRange(surah, ayah, ayah))));
            }),
        ]),
      ),
      TafsirCard(surah: surah, ayah: ayah),
      WordMeaningsCard(surah: surah, ayah: ayah),
      if (extra.isNotEmpty) ...[const SizedBox(height: 4), ...extra],
    ]);
  }
}

/// The ayah in the Quran font; words explained in «معاني الكلمات» are tinted and show their meaning on tap.
class AyahWords extends StatefulWidget {
  final int surah, ayah;
  const AyahWords({super.key, required this.surah, required this.ayah});
  @override
  State<AyahWords> createState() => _AyahWordsState();
}

class _AyahWordsState extends State<AyahWords> {
  List<WordMeaning> _meanings = const [];
  final _taps = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    WordMeanings.load().then((w) {
      if (mounted) setState(() => _meanings = w.of(widget.surah, widget.ayah));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  void _show(WordMeaning m) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(m.phrase, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 24, height: 1.9)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(m.meaning, style: const TextStyle(fontSize: 16, height: 1.8)),
            const SizedBox(height: 10),
            Text('الميسر في غريب القرآن الكريم — مجمع الملك فهد', style: TextStyle(fontSize: 11.5, color: Theme.of(c).hintColor)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('حسنًا'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = app.repo.surahs[widget.surah - 1].verses[widget.ayah - 1].split(' ');
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final spans = <InlineSpan>[];
    for (var i = 0; i < words.length; i++) {
      final m = _meanings.where((m) => m.covers(i)).firstOrNull;
      if (m == null) {
        spans.add(TextSpan(text: '${words[i]} '));
      } else {
        final tap = TapGestureRecognizer()..onTap = () => _show(m);
        _taps.add(tap);
        spans.add(TextSpan(text: words[i], style: TextStyle(color: AppColors.gold), recognizer: tap));
        spans.add(const TextSpan(text: ' '));
      }
    }
    spans.add(TextSpan(text: '﴿${Arabic.digits(widget.ayah)}﴾'));
    return Text.rich(TextSpan(children: spans),
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 22, height: 2.1, color: theme.colorScheme.onSurface));
  }
}

/// The tafsir of the ayah in the book the user chose (chips; remembered in Settings.tafsirId). Each book is
/// loaded the first time it is chosen.
class TafsirCard extends StatefulWidget {
  final int surah, ayah;
  const TafsirCard({super.key, required this.surah, required this.ayah});
  @override
  State<TafsirCard> createState() => _TafsirCardState();
}

class _TafsirCardState extends State<TafsirCard> {
  late TafsirBook _book = Tafsir.byId(app.settings.tafsirId);
  late Future<Tafsir> _tafsir = Tafsir.load(_book.id);

  void _choose(TafsirBook b) {
    if (b.id == _book.id) return;
    setState(() {
      _book = b;
      _tafsir = Tafsir.load(b.id);
    });
    app.update((x) => x.tafsirId = b.id, reschedule: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card3D(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_stories_outlined, size: 19, color: AppColors.gold),
            const SizedBox(width: 6),
            const Text('التفسير', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final b in Tafsir.books)
              ChoiceChip(
                key: ValueKey('tafsir-${b.id}'),
                label: Text(b.label),
                selected: b.id == _book.id,
                onSelected: (_) => _choose(b),
                visualDensity: VisualDensity.compact,
              ),
          ]),
          const SizedBox(height: 8),
          FutureBuilder<Tafsir>(
            key: ValueKey(_book.id),
            future: _tafsir,
            builder: (c, snap) {
              final t = snap.data;
              if (t == null) {
                return snap.hasError
                    ? const Text('تعذّر تحميل التفسير')
                    : const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
              }
              final sec = t.sectionOf(widget.surah, widget.ayah);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.emerald)),
                if (sec.grouped)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('تفسير الآيات ${Arabic.digits(sec.from)}–${Arabic.digits(sec.to)} معًا',
                        style: TextStyle(fontSize: 12.5, color: theme.hintColor)),
                  ),
                const SizedBox(height: 6),
                SelectableText(sec.text, style: const TextStyle(fontSize: 15, height: 1.9)),
                const SizedBox(height: 8),
                Text('المصدر: ${t.source}', style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

/// «معاني الكلمات» of the ayah: الميسر في غريب القرآن الكريم (مجمع الملك فهد). Hidden when the ayah has none.
class WordMeaningsCard extends StatelessWidget {
  final int surah, ayah;
  const WordMeaningsCard({super.key, required this.surah, required this.ayah});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<WordMeanings>(
      future: WordMeanings.load(),
      builder: (c, snap) {
        final w = snap.data;
        final items = w?.of(surah, ayah) ?? const <WordMeaning>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Card3D(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.translate_rounded, size: 19, color: AppColors.gold),
                const SizedBox(width: 6),
                const Text('معاني الكلمات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              ]),
              const SizedBox(height: 6),
              for (final m in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: m.phrase,
                          style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 18, color: AppColors.emerald, height: 1.9)),
                      const TextSpan(text: '  :  '),
                      TextSpan(text: m.meaning),
                    ]),
                    style: const TextStyle(fontSize: 14.5, height: 1.8),
                  ),
                ),
              const SizedBox(height: 6),
              Text('المصدر: ${w!.name} — ${w.source}', style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
            ]),
          ),
        );
      },
    );
  }
}
