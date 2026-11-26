import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../data/repository.dart';
import '../main.dart';
import 'downloads_page.dart';
import 'mushaf_page.dart';
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
              if (app.downloads.supported)
                IconButton(tooltip: 'الاستماع دون إنترنت', icon: const Icon(Icons.download_for_offline_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage()))),
              IconButton(tooltip: 'العلامات', icon: const Icon(Icons.bookmarks_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksPage()))),
            ],
          ),
          body: ListView(children: [
            _ViewSwitch(),
            if (app.settings.quranView == 'mushaf')
              Card(
                child: ListTile(
                  leading: Icon(Icons.menu_book, color: AppColors.emerald, size: 30),
                  title: const Text('المصحف الشريف', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('صفحة ${Arabic.digits(app.settings.mushafPage)} • سورة ${app.repo.surahs[app.mushaf.surahOf(app.settings.mushafPage) - 1].name}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => openMushaf(context, app.settings.mushafPage),
                ),
              ),
            if (last != null)
              Card(
                color: AppColors.goldSoft,
                child: ListTile(
                  leading: Icon(Icons.bookmark, color: AppColors.gold),
                  title: const Text('متابعة القراءة', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('سورة ${app.repo.surahs[last.surah - 1].name} • الآية ${Arabic.digits(last.ayah)}'),
                  trailing: IconButton(
                    tooltip: 'إزالة موضع القراءة',
                    icon: const Icon(Icons.close),
                    onPressed: () => app.update((x) => x.lastRead = null, reschedule: false),
                  ),
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

void openReader(BuildContext context, int surah, int ayah) {
  if (app.settings.quranView == 'mushaf') {
    openMushaf(context, app.mushaf.pageOf(surah, ayah));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuranReaderPage(surah: surah, initialAyah: ayah)));
  }
}

/// Starts verse-by-verse recitation, continuing into the next surah when enabled.
void startQuranRecitation(int surah, int ayah) {
  app.narration.stop();
  app.adhan.stop();
  app.recitation.onFinished = (last) {
    if (!app.settings.continueNextSurah || last >= 114) return null;
    app.recitation.play(app.repo, app.settings.reciterId, last + 1, 1);
    return last + 1;
  };
  app.recitation.play(app.repo, app.settings.reciterId, surah, ayah);
}

void showReciterPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(c).size.height * 0.6,
        child: ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('اختر القارئ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (app.downloads.supported) ...[
            ListTile(
              leading: Icon(Icons.download_for_offline_outlined, color: AppColors.gold),
              title: const Text('الاستماع دون إنترنت'),
              subtitle: const Text('تنزيل المصحف أو السور على الهاتف'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage()));
              },
            ),
            const Divider(),
          ],
          for (final r in app.repo.reciters)
            ListTile(
              leading: Icon(r.id == app.settings.reciterId ? Icons.radio_button_checked : Icons.radio_button_off, color: AppColors.emerald),
              title: Text(r.name),
              onTap: () {
                final rec = app.recitation;
                final wasActive = rec.active;
                final (s, at) = (rec.surah, rec.ayah);
                app.update((x) => x.reciterId = r.id, reschedule: false);
                Navigator.pop(c);
                if (wasActive && s > 0) startQuranRecitation(s, at > 0 ? at : 1);
              },
            ),
        ]),
      ),
    ),
  );
}

class _ViewSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'mushaf', icon: Icon(Icons.menu_book), label: Text('المصحف')),
            ButtonSegment(value: 'text', icon: Icon(Icons.notes), label: Text('نص')),
          ],
          selected: {app.settings.quranView},
          onSelectionChanged: (v) => app.update((x) => x.quranView = v.first, reschedule: false),
        ),
      );
}

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
      // While listening, the saved reading position moves along with the recitation.
      final pos = Bookmark(r.surah, r.ayah);
      if (app.settings.lastRead != pos) app.update((x) => x.lastRead = pos, reschedule: false);
      final ctx = _keys[r.ayah]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.25, duration: const Duration(milliseconds: 400));
    }
  }

  void _startRecitation(int ayah) => startQuranRecitation(_surah, ayah);

  void _pickReciter() => showReciterPicker(context);

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
            leading: Icon(Icons.play_circle_outline, color: AppColors.emerald),
            title: const Text('استماع من هذه الآية'),
            onTap: () {
              Navigator.pop(c);
              _startRecitation(ayah);
            },
          ),
          if (app.settings.lastRead == b)
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined),
              title: const Text('إزالة موضع القراءة'),
              onTap: () {
                app.update((x) => x.lastRead = null, reschedule: false);
                Navigator.pop(c);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إزالة موضع القراءة')));
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.bookmark_added_outlined),
              title: const Text('حفظ موضع القراءة هنا'),
              subtitle: app.settings.lastRead != null ? const Text('سيحلّ محلّ الموضع المحفوظ السابق') : null,
              onTap: () {
                app.update((x) => x.lastRead = b, reschedule: false);
                Navigator.pop(c);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ موضع القراءة')));
              },
            ),
          ListTile(
            leading: Icon(marked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
            title: Text(marked ? 'إزالة العلامة' : 'إضافة علامة على الآية'),
            onTap: () {
              app.update((x) => marked ? x.bookmarks.remove(b) : x.bookmarks.add(b), reschedule: false);
              Navigator.pop(c);
              setState(() {});
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
                  Icon(Icons.graphic_eq, color: AppColors.gold),
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
            tooltip: 'عرض المصحف',
            icon: const Icon(Icons.menu_book),
            onPressed: () {
              app.update((x) => x.quranView = 'mushaf', reschedule: false);
              openMushaf(context, app.mushaf.pageOf(_surah, _lastScrolled > 0 ? _lastScrolled : 1), replace: true);
            },
          ),
          if (app.downloads.supported)
            ListenableBuilder(
              listenable: app.downloads,
              builder: (context, _) {
                final id = app.settings.reciterId;
                final job = app.downloads.job(id);
                if (app.downloads.isReady(id, _surah)) {
                  return IconButton(
                    tooltip: 'السورة محفوظة للاستماع دون إنترنت',
                    icon: Icon(Icons.offline_pin, color: AppColors.emerald),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage())),
                  );
                }
                if (job != null && job.surahs.contains(_surah)) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.gold)),
                  );
                }
                return IconButton(
                  tooltip: 'تنزيل السورة للاستماع دون إنترنت',
                  icon: const Icon(Icons.download_for_offline_outlined),
                  onPressed: job != null
                      ? null
                      : () {
                          app.downloads.download(app.repo, id, surahs: [_surah]);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('جارٍ تنزيل سورة ${s.name} بصوت ${app.repo.reciter(id).name}')));
                        },
                );
              },
            ),
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
                    if (app.settings.lastRead == Bookmark(_surah, i + 1))
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: Icon(Icons.bookmark, size: size * 0.8, color: AppColors.emerald),
                        ),
                      ),
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
                subtitle: Text('سورة ${h.surah.name} • الآية ${Arabic.digits(h.ayah)}', style: TextStyle(color: AppColors.gold)),
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
