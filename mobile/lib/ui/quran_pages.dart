import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../data/repository.dart';
import '../main.dart';
import 'downloads_page.dart';
import 'khatma_page.dart';
import 'mushaf_page.dart';
import 'theme.dart';

TextStyle quranStyle(BuildContext context, double size) => TextStyle(
    fontFamily: 'AmiriQuran', fontSize: size, height: 2.1, color: Theme.of(context).colorScheme.onSurface);

class QuranIndexPage extends StatefulWidget {
  const QuranIndexPage({super.key});
  @override
  State<QuranIndexPage> createState() => _QuranIndexPageState();
}

class _QuranIndexPageState extends State<QuranIndexPage> {
  String _filter = '';
  bool _juz = false;

  @override
  Widget build(BuildContext context) {
    final idx = app.mushaf;
    final surahs = app.repo.surahs.where((s) {
      if (_filter.isEmpty) return true;
      final q = Arabic.normalize(_filter);
      return Arabic.normalize(s.name).contains(q) || s.nameEn.toLowerCase().contains(q) || '${s.number}' == _filter.trim();
    }).toList();
    Widget pageTag(int page) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
          child: Text('ص ${Arabic.digits(page)}', style: TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w600)),
        );
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final last = app.settings.lastRead;
        final page = app.settings.mushafPage;
        return Scaffold(
          appBar: AppBar(
            title: const Text('القرآن الكريم'),
            actions: [
              IconButton(tooltip: 'بحث في الآيات', icon: const Icon(Icons.search),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranSearchPage()))),
              if (app.downloads.supported)
                IconButton(tooltip: 'الاستماع والقراءة دون إنترنت', icon: const Icon(Icons.download_for_offline_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage()))),
              IconButton(tooltip: 'العلامات', icon: const Icon(Icons.bookmarks_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksPage()))),
            ],
          ),
          body: ListView(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              decoration: hero3D(radius: 20),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: const Icon(Icons.menu_book, color: Colors.white, size: 32),
                title: const Text('المصحف الشريف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16.5)),
                subtitle: Text('متابعة من صفحة ${Arabic.digits(page)} • سورة ${app.repo.surahs[idx.surahOf(page) - 1].name}',
                    style: TextStyle(color: AppColors.heroText)),
                trailing: const Icon(Icons.chevron_left, color: Colors.white),
                onTap: () => openMushaf(context, page),
              ),
            ),
            const KhatmaCard(),
            const ReciterTile(),
            if (last != null)
              Card3D(
                color: AppColors.goldSoft,
                child: ListTile(
                  leading: Icon(Icons.bookmark, color: AppColors.gold),
                  title: const Text('موضع القراءة', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('سورة ${app.repo.surahs[last.surah - 1].name} • الآية ${Arabic.digits(last.ayah)} (صفحة ${Arabic.digits(idx.pageOf(last.surah, last.ayah))})'),
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
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('السور')),
                  ButtonSegment(value: true, label: Text('الأجزاء')),
                ],
                selected: {_juz},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _juz = v.first),
              ),
            ),
            if (!_juz) ...[
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
                  trailing: pageTag(idx.pageOf(s.number, 1)),
                  onTap: () => openMushaf(context, idx.pageOf(s.number, 1)),
                ),
            ] else
              for (var j = 1; j <= 30; j++)
                ListTile(
                  leading: _NumberBadge(j),
                  title: Text('الجزء ${Arabic.digits(j)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  subtitle: Text('يبدأ من سورة ${app.repo.surahs[idx.juzStart(j).$1 - 1].name} • آية ${Arabic.digits(idx.juzStart(j).$2)}'),
                  trailing: pageTag(idx.juzStartPage(j)),
                  onTap: () => openReader(context, idx.juzStart(j).$1, idx.juzStart(j).$2),
                ),
          ]),
        );
      },
    );
  }
}

/// Opens the Mushaf at the page of an ayah and highlights that ayah for a moment.
void openReader(BuildContext context, int surah, int ayah) =>
    openMushaf(context, app.mushaf.pageOf(surah, ayah), highlight: Bookmark(surah, ayah));


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


class _NumberBadge extends StatelessWidget {
  final int n;
  const _NumberBadge(this.n);
  @override
  Widget build(BuildContext context) => Tile3D(
        size: 40,
        child: Text(Arabic.digits(n), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold)),
      );
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


/// "القارئ" row: the current reciter, tap to choose another (Quran tab and Settings).
class ReciterTile extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const ReciterTile({super.key, this.margin});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Card3D(
        margin: margin ?? const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: ListTile(
          leading: const Tile3D(size: 40, child: Text('🎙️', style: TextStyle(fontSize: 19))),
          title: const Text('القارئ', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(app.repo.reciter(app.settings.reciterId).name),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => showReciterPicker(context),
        ),
      ),
    );
  }
}
