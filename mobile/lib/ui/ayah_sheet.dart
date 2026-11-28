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

/// Bottom sheet of an ayah: its text, التفسير الميسر, and actions (copy, share, listen, memorize).
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
    final tafsir = Tafsir.load();
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
        child: SelectableText('$text ﴿${Arabic.digits(ayah)}﴾',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 22, height: 2.1, color: theme.colorScheme.onSurface)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          action(Icons.copy_rounded, 'نسخ', () async {
            final messenger = ScaffoldMessenger.of(context);
            final t = await tafsir.then((t) => t.of(surah, ayah), onError: (_) => '');
            await Clipboard.setData(ClipboardData(
                text: '﴿$text﴾ [${s.name}: $ayah]${t.isEmpty ? '' : '\n\nالتفسير الميسر: $t'}'));
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
      Card3D(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FutureBuilder<Tafsir>(
            future: tafsir,
            builder: (c, snap) {
              final t = snap.data;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.auto_stories_outlined, size: 19, color: AppColors.gold),
                  const SizedBox(width: 6),
                  const Text('التفسير الميسر', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                ]),
                const SizedBox(height: 8),
                if (t != null)
                  SelectableText(t.of(surah, ayah), style: const TextStyle(fontSize: 15, height: 1.9))
                else if (snap.hasError)
                  const Text('تعذّر تحميل التفسير')
                else
                  const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
                const SizedBox(height: 8),
                Text('المصدر: ${t?.source ?? 'مجمع الملك فهد لطباعة المصحف الشريف'}',
                    style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
              ]);
            },
          ),
        ),
      ),
      if (extra.isNotEmpty) ...[const SizedBox(height: 4), ...extra],
    ]);
  }
}
