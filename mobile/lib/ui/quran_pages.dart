import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../data/repository.dart';
import '../main.dart';
import 'format.dart';
import 'theme.dart';

const _basmala = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';

TextStyle quranStyle(BuildContext context, double size) => TextStyle(
    fontFamily: 'AmiriQuran', fontSize: size, height: 2.1, color: Theme.of(context).colorScheme.onSurface);

class QuranIndexPage extends StatefulWidget {
  const QuranIndexPage({super.key});
  @override
  State<QuranIndexPage> createState() => _QuranIndexPageState();
}

class _QuranIndexPageState extends State<QuranIndexPage> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final surahs = app.repo.surahs.where((s) {
      if (_filter.isEmpty) return true;
      final q = Arabic.normalize(_filter);
      return Arabic.normalize(s.name).contains(q) || s.nameEn.toLowerCase().contains(q) || '${s.number}' == _filter.trim();
    }).toList();
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final last = app.settings.lastRead;
        return Scaffold(
          appBar: AppBar(
            title: const Text('القرآن الكريم'),
            actions: [
              IconButton(tooltip: 'بحث في الآيات', icon: const Icon(Icons.search),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranSearchPage()))),
              IconButton(tooltip: 'العلامات', icon: const Icon(Icons.bookmarks_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksPage()))),
            ],
          ),
          body: ListView(children: [
            if (last != null)
              Card(
                color: AppColors.goldSoft,
                child: ListTile(
                  leading: const Icon(Icons.bookmark, color: AppColors.gold),
                  title: const Text('متابعة القراءة', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('سورة ${app.repo.surahs[last.surah - 1].name} • الآية ${Arabic.digits(last.ayah)}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => openReader(context, last.surah, last.ayah),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: const InputDecoration(hintText: 'ابحث عن سورة بالاسم أو الرقم', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            for (final s in surahs)
              ListTile(
                leading: _NumberBadge(s.number),
                title: Text('سورة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text('${s.meccan ? 'مكية' : 'مدنية'} • ${Arabic.digits(s.verses.length)} آية'),
                trailing: Text(s.nameEn, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                onTap: () => openReader(context, s.number, 1),
              ),
          ]),
        );
      },
    );
  }
}

void openReader(BuildContext context, int surah, int ayah) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuranReaderPage(surah: surah, initialAyah: ayah)));

class _NumberBadge extends StatelessWidget {
  final int n;
  const _NumberBadge(this.n);
  @override
  Widget build(BuildContext context) => Container(
        width: 40, height: 40, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 1.5)),
        child: Text(Arabic.digits(n), style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class QuranReaderPage extends StatefulWidget {
  final int surah, initialAyah;
  const QuranReaderPage({super.key, required this.surah, this.initialAyah = 1});
  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage> {
  late int _surah = widget.surah;
  final _keys = <int, GlobalKey>{};
  final _scroll = ScrollController();

  Surah get s => app.repo.surahs[_surah - 1];

  int _lastScrolled = -1;

  @override
  void initState() {
    super.initState();
    _jumpTo(widget.initialAyah);
    app.recitation.addListener(_onRecitation);
  }

  @override
  void dispose() {
    app.recitation.removeListener(_onRecitation);
    super.dispose();
  }

  void _onRecitation() {
    final r = app.recitation;
    if (!mounted) return;
    if (r.active && r.surah != _surah && r.surah > 0) {
      _go(r.surah);
    }
    setState(() {});
    if (r.active && r.surah == _surah && r.ayah > 0 && r.ayah != _lastScrolled) {
      _lastScrolled = r.ayah;
      final ctx = _keys[r.ayah]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.25, duration: const Duration(milliseconds: 400));
    }
  }

  void _startRecitation(int ayah) {
    app.narration.stop();
    app.adhan.stop();
    app.recitation.onFinished = (last) {
      if (!app.settings.continueNextSurah || last >= 114) return null;
      app.recitation.play(app.repo, app.settings.reciterId, last + 1, 1);
      return last + 1;
    };
    app.recitation.play(app.repo, app.settings.reciterId, _surah, ayah);
  }

  void _pickReciter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * 0.6,
          child: ListView(children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('اختر القارئ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            for (final r in app.repo.reciters)
              ListTile(
                leading: Icon(r.id == app.settings.reciterId ? Icons.radio_button_checked : Icons.radio_button_off, color: AppColors.emerald),
                title: Text(r.name),
                onTap: () {
                  final wasActive = app.recitation.active;
                  final at = app.recitation.ayah;
                  app.update((x) => x.reciterId = r.id, reschedule: false);
                  Navigator.pop(c);
                  if (wasActive) _startRecitation(at > 0 ? at : 1);
                  setState(() {});
                },
              ),
          ]),
        ),
      ),
    );
  }

  void _jumpTo(int ayah) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[ayah]?.currentContext;
      if (ctx != null && ayah > 1) Scrollable.ensureVisible(ctx, alignment: 0.1);
    });
  }

  void _go(int surah) {
    setState(() {
      _surah = surah;
      _keys.clear();
    });
    _scroll.jumpTo(0);
  }

  void _ayahMenu(int ayah) {
    final b = Bookmark(_surah, ayah);
    final marked = app.settings.bookmarks.contains(b);
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.play_circle_outline, color: AppColors.emerald),
            title: const Text('استماع من هذه الآية'),
            onTap: () {
              Navigator.pop(c);
              _startRecitation(ayah);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_added_outlined),
            title: const Text('حفظ موضع القراءة هنا'),
            onTap: () {
              app.update((x) => x.lastRead = b, reschedule: false);
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ موضع القراءة')));
            },
          ),
          ListTile(
            leading: Icon(marked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
            title: Text(marked ? 'إزالة العلامة' : 'إضافة علامة على الآية'),
            onTap: () {
              app.update((x) => marked ? x.bookmarks.remove(b) : x.bookmarks.add(b), reschedule: false);
              Navigator.pop(c);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = app.settings.quranFontSize;
    final style = quranStyle(context, size);
    final showBasmala = _surah != 1 && _surah != 9;
    final rec = app.recitation;
    return Scaffold(
      bottomNavigationBar: rec.active
          ? SafeArea(
              child: Container(
                color: AppColors.navy3,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.graphic_eq, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${app.repo.reciter(app.settings.reciterId).name} • ${rec.ayah == 0 ? 'البسملة' : 'الآية ${Arabic.digits(rec.ayah)}'}',
                      style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(icon: Icon(rec.playing ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: rec.togglePause),
                  IconButton(icon: const Icon(Icons.stop, color: Colors.white), onPressed: rec.stop),
                ]),
              ),
            )
          : (rec.error != null ? SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Text(rec.error!, textAlign: TextAlign.center))) : null),
      appBar: AppBar(
        title: Text('سورة ${s.name}'),
        actions: [
          IconButton(
            tooltip: 'القارئ',
            icon: const Icon(Icons.record_voice_over_outlined),
            onPressed: _pickReciter,
          ),
          IconButton(
            tooltip: rec.active && rec.playing ? 'إيقاف مؤقت' : 'استماع',
            icon: Icon(rec.active && rec.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.emerald, size: 30),
            onPressed: () {
              if (rec.active) {
                rec.togglePause();
              } else {
                final last = app.settings.lastRead;
                _startRecitation(last != null && last.surah == _surah ? last.ayah : 1);
              }
            },
          ),
          IconButton(
            tooltip: 'حجم الخط',
            icon: const Icon(Icons.format_size),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (c) => StatefulBuilder(
                builder: (c, setSheet) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('حجم خط المصحف'),
                    Slider(
                      min: 18, max: 44, divisions: 13, value: app.settings.quranFontSize,
                      onChanged: (v) {
                        app.update((x) => x.quranFontSize = v, reschedule: false);
                        setSheet(() {});
                        setState(() {});
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold), borderRadius: BorderRadius.circular(14),
              color: AppColors.goldSoft,
            ),
            child: Column(children: [
              Text('سورة ${s.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text('${s.meccan ? 'مكية' : 'مدنية'} • آياتها ${Arabic.digits(s.verses.length)}', style: const TextStyle(fontSize: 13)),
            ]),
          ),
          if (showBasmala) Text(_basmala, textAlign: TextAlign.center, style: style.copyWith(fontSize: size + 2)),
          for (var i = 0; i < s.verses.length; i++)
            InkWell(
              key: _keys.putIfAbsent(i + 1, () => GlobalKey()),
              onLongPress: () => _ayahMenu(i + 1),
              onTap: () => _ayahMenu(i + 1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: rec.active && rec.surah == _surah && rec.ayah == i + 1
                      ? AppColors.emerald.withValues(alpha: 0.18)
                      : (app.settings.bookmarks.contains(Bookmark(_surah, i + 1)) ? AppColors.goldSoft : null),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${s.verses[i]} '),
                    TextSpan(text: ayahNumber(i + 1), style: style.copyWith(color: AppColors.gold, fontSize: size * 0.9)),
                  ]),
                  style: style,
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            if (_surah > 1)
              Expanded(child: OutlinedButton(onPressed: () => _go(_surah - 1), child: Text('السورة السابقة: ${app.repo.surahs[_surah - 2].name}'))),
            if (_surah > 1 && _surah < 114) const SizedBox(width: 8),
            if (_surah < 114)
              Expanded(child: FilledButton(onPressed: () => _go(_surah + 1), child: Text('السورة التالية: ${app.repo.surahs[_surah].name}'))),
          ]),
        ]),
      ),
    );
  }
}

class QuranSearchPage extends StatefulWidget {
  const QuranSearchPage({super.key});
  @override
  State<QuranSearchPage> createState() => _QuranSearchPageState();
}

class _QuranSearchPageState extends State<QuranSearchPage> {
  List<SearchHit> _hits = [];
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البحث في القرآن')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'اكتب كلمة (بدون تشكيل)', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() {
              _q = v;
              _hits = app.repo.searchQuran(v);
            }),
          ),
        ),
        if (_q.trim().length >= 2)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: AlignmentDirectional.centerStart,
                  child: Text(_hits.length >= 200 ? 'أكثر من ٢٠٠ نتيجة' : '${Arabic.digits(_hits.length)} نتيجة'))),
        Expanded(
          child: ListView.separated(
            itemCount: _hits.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final h = _hits[i];
              return ListTile(
                title: Text(h.text, style: quranStyle(context, 20).copyWith(height: 1.8)),
                subtitle: Text('سورة ${h.surah.name} • الآية ${Arabic.digits(h.ayah)}', style: const TextStyle(color: AppColors.gold)),
                onTap: () => openReader(context, h.surah.number, h.ayah),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.settings.bookmarks;
          return Scaffold(
            appBar: AppBar(title: const Text('العلامات')),
            body: list.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24),
                    child: Text('لا توجد علامات بعد.\nاضغط على أي آية أثناء القراءة لإضافة علامة.', textAlign: TextAlign.center)))
                : ListView(children: [
                    for (final b in list)
                      ListTile(
                        title: Text(app.repo.surahs[b.surah - 1].verses[b.ayah - 1],
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: quranStyle(context, 19).copyWith(height: 1.8)),
                        subtitle: Text('سورة ${app.repo.surahs[b.surah - 1].name} • الآية ${Arabic.digits(b.ayah)}'),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline),
                            onPressed: () => app.update((x) => x.bookmarks.remove(b), reschedule: false)),
                        onTap: () => openReader(context, b.surah, b.ayah),
                      ),
                  ]),
          );
        },
      );
}
