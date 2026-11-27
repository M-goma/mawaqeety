import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../data/sabeel.dart';
import '../main.dart';
import 'hadith_page.dart';
import 'mushaf_page.dart';
import 'theme.dart';

/// «سبيل»: ask about an ayah's tafsir or a hadith; answers quote the Quran, التفسير الميسر and
/// the two Sahih collections, offline.
class SabeelPage extends StatefulWidget {
  final String? initial;
  const SabeelPage({super.key, this.initial});
  @override
  State<SabeelPage> createState() => _SabeelPageState();
}

class _SabeelPageState extends State<SabeelPage> {
  static const examples = ['تفسير آية الكرسي', 'الكهف 10', 'خواتيم البقرة', 'الصبر', 'بر الوالدين', 'حديث إنما الأعمال بالنيات'];
  late final _ctrl = TextEditingController(text: widget.initial ?? '');
  late final Future<Sabeel> _engine = Sabeel.load(app.repo);
  SabeelAnswer? _answer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initial ?? '').isNotEmpty) _ask(widget.initial!);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    _ctrl.text = q;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final e = await _engine;
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final a = e.ask(q);
    if (mounted) setState(() { _answer = a; _busy = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = _answer;
    return Scaffold(
      appBar: AppBar(title: const Text('سبيل — اسأل عن آية أو حديث')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => v.trim().isEmpty ? null : _ask(v.trim()),
            decoration: InputDecoration(
              hintText: 'مثال: تفسير آية الكرسي، أو حديث عن الصدقة',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.send_rounded), onPressed: () => _ctrl.text.trim().isEmpty ? null : _ask(_ctrl.text.trim())),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(spacing: 6, runSpacing: 0, children: [
            for (final e in examples) ActionChip(label: Text(e, style: const TextStyle(fontSize: 12.5)), onPressed: () => _ask(e), visualDensity: VisualDensity.compact),
          ]),
        ),
        if (_busy) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        if (!_busy && a == null) _intro(theme),
        if (!_busy && a != null) ...[
          if (a.ruling) _note(theme, Icons.gavel_rounded,
              'سؤالك عن حكم شرعي: هذه نصوص للاطلاع فقط وليست فتوى. اسأل أهل العلم أو دار الإفتاء في بلدك.'),
          if (a.isEmpty)
            _note(theme, Icons.search_off_rounded, 'لم أجد نتيجة. جرّب كلمة من الآية أو الحديث، أو اسم السورة ورقم الآية (مثل: البقرة 255).')
          else ...[
            if (a.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(a.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.gold)),
              ),
            if (a.ayat.isNotEmpty) _section(theme, '📖 الآيات وتفسيرها (التفسير الميسر)'),
            for (final x in a.ayat) _AyahCard(x),
            if (a.more) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('توجد نتائج أخرى؛ زِد كلمة لتضييق البحث.', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            ),
            if (a.hadith.isNotEmpty) _section(theme, '📜 من الأحاديث الصحيحة (البخاري ومسلم)'),
            for (final h in a.hadith) HadithCard(h),
          ],
          _disclaimer(theme),
        ],
      ]),
    );
  }

  Widget _section(ThemeData theme, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
        child: Text(t, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _note(ThemeData theme, IconData icon, String text) => Card3D(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.6))),
          ]),
        ),
      );

  Widget _intro(ThemeData theme) => Card3D(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('كيف تسأل سبيل؟', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.gold)),
            const SizedBox(height: 6),
            const Text(
              '• تفسير آية: اكتب اسمها (آية الكرسي) أو السورة ورقم الآية (الكهف 10).\n'
              '• موضوع: اكتب كلمة أو أكثر (الصبر، بر الوالدين) فتظهر الآيات وتفسيرها والأحاديث.\n'
              '• حديث: اكتب جزءًا من نصه (إنما الأعمال بالنيات).\n'
              'يعمل بلا إنترنت، وينقل النصوص من مصادرها كما هي.',
              style: TextStyle(height: 1.8),
            ),
          ]),
        ),
      );

  Widget _disclaimer(ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Text(
          'سبيل بحث آلي في النصوص وليس مفتيًا. المصادر: المصحف (رواية حفص)، التفسير الميسر — مجمع الملك فهد لطباعة المصحف الشريف، صحيح البخاري وصحيح مسلم.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.6),
        ),
      );
}

class _AyahCard extends StatelessWidget {
  final SabeelAyah a;
  const _AyahCard(this.a);
  @override
  Widget build(BuildContext context) {
    return Card3D(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SelectableText('${a.text} ﴿${Arabic.digits(a.ayah)}﴾',
              style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 20, height: 2.1)),
          const Divider(height: 14),
          SelectableText(a.tafsir, style: const TextStyle(fontSize: 14.5, height: 1.8)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
              child: Text('${a.surah.name} • ${Arabic.digits(a.ayah)}',
                  style: TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('في المصحف'),
              onPressed: () => openMushaf(context, app.mushaf.pageOf(a.surah.number, a.ayah), highlight: Bookmark(a.surah.number, a.ayah)),
            ),
            IconButton(
              tooltip: 'نسخ',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: '﴿${a.text}﴾ [${a.surah.name}: ${a.ayah}]\n\nالتفسير الميسر: ${a.tafsir}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخت الآية وتفسيرها')));
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
