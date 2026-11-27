import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../data/hadith.dart';
import '../main.dart';
import 'theme.dart';

/// Sahih al-Bukhari and Sahih Muslim only: hadith of the day, the books, search and saved hadiths.
class HadithPage extends StatefulWidget {
  const HadithPage({super.key});
  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  String _id = 'bukhari';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأحاديث الصحيحة'),
        actions: [
          IconButton(
            tooltip: 'بحث',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HadithSearchPage(id: _id))),
          ),
          IconButton(
            tooltip: 'المحفوظة',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HadithMarksPage())),
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([HadithCollection.load('bukhari'), HadithCollection.load(_id)]),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bukhari = snap.data![0], col = snap.data![1];
          final today = bukhari.ofDay(app.today);
          return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'bukhari', label: Text('صحيح البخاري')), ButtonSegment(value: 'muslim', label: Text('صحيح مسلم'))],
                selected: {_id},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _id = v.first),
              ),
            ),
            HadithCard(today, title: '✦ حديث اليوم', highlight: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: Text('الكتب (${Arabic.digits(col.books.length)} كتابًا)', style: TextStyle(color: Theme.of(context).hintColor)),
            ),
            for (final (n, _) in col.books)
              Card3D(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Tile3D(size: 40, child: Text(Arabic.digits(n), style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700))),
                  title: Text(col.bookName(n), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(hadithCount(col.bookCount(n))),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HadithBookPage(col: col, book: n))),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('الصحيحان أصحّ كتب الحديث باتفاق العلماء. النص العربي الكامل بأرقام الأحاديث المعتمدة.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ),
          ]);
        },
      ),
    );
  }
}

/// One hadith: the text (or the full chain), its reference, and save / copy.
class HadithCard extends StatelessWidget {
  final Hadith h;
  final String? title;
  final bool highlight;
  const HadithCard(this.h, {super.key, this.title, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final full = app.settings.hadithFull || !h.hasMatn;
        final saved = app.settings.hadithMarks.contains(h.key);
        return Card3D(
          shape: highlight ? RoundedRectangleBorder(side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5))) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                if (title != null) Text(title!, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (h.hasMatn)
                  SegmentedButton<bool>(
                    style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    segments: const [ButtonSegment(value: false, label: Text('نص الحديث')), ButtonSegment(value: true, label: Text('بالسند'))],
                    selected: {full},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => app.update((x) => x.hadithFull = v.first, reschedule: false),
                  ),
              ]),
              const SizedBox(height: 6),
              SelectableText(full ? h.text : h.matn, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18.5, height: 2)),
              const SizedBox(height: 4),
              Row(children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                    child: Text('${h.col.name} • ${Arabic.digits(h.number)} • ${h.col.bookName(h.book)}',
                        style: TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.w600)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: saved ? 'إزالة من المحفوظة' : 'حفظ',
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? AppColors.gold : null),
                  onPressed: () => app.update((x) => x.hadithMarks = saved
                      ? (x.hadithMarks.where((k) => k != h.key).toList())
                      : [h.key, ...x.hadithMarks], reschedule: false),
                ),
                IconButton(
                  tooltip: 'نسخ',
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${full ? h.text : h.matn}\n\n[${h.col.name}، رقم ${h.number}]'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الحديث')));
                  },
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class HadithBookPage extends StatelessWidget {
  final HadithCollection col;
  final int book;
  const HadithBookPage({super.key, required this.col, required this.book});
  @override
  Widget build(BuildContext context) {
    final list = col.inBook(book);
    return Scaffold(
      appBar: AppBar(title: Text(col.bookName(book))),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 20),
        itemCount: list.length,
        itemBuilder: (_, i) => HadithCard(list[i]),
      ),
    );
  }
}

class HadithSearchPage extends StatefulWidget {
  final String id;
  const HadithSearchPage({super.key, required this.id});
  @override
  State<HadithSearchPage> createState() => _HadithSearchPageState();
}

class _HadithSearchPageState extends State<HadithSearchPage> {
  late String _id = widget.id;
  String _q = '';
  List<Hadith> _results = const [];

  Future<void> _run() async {
    final c = await HadithCollection.load(_id);
    final r = c.search(_q);
    if (mounted) setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بحث في الأحاديث')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'اكتب كلمة أو أكثر، مثل: الكلمة الطيبة', prefixIcon: Icon(Icons.search)),
            onSubmitted: (v) {
              _q = v;
              _run();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'bukhari', label: Text('البخاري')), ButtonSegment(value: 'muslim', label: Text('مسلم'))],
            selected: {_id},
            showSelectedIcon: false,
            onSelectionChanged: (v) {
              _id = v.first;
              _run();
            },
          ),
        ),
        if (_q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_results.isEmpty ? 'لا توجد نتائج' : '${hadithCount(_results.length)}${_results.length >= 150 ? ' (أول ١٥٠)' : ''}',
                style: TextStyle(color: Theme.of(context).hintColor)),
          ),
        Expanded(child: ListView.builder(itemCount: _results.length, itemBuilder: (_, i) => HadithCard(_results[i]))),
      ]),
    );
  }
}

class HadithMarksPage extends StatelessWidget {
  const HadithMarksPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأحاديث المحفوظة')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => FutureBuilder(
          future: Future.wait(app.settings.hadithMarks.map(hadithByKey)),
          builder: (context, snap) {
            final list = (snap.data ?? const []).whereType<Hadith>().toList();
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (list.isEmpty) {
              return Center(
                child: Text('لم تحفظ أحاديث بعد. اضغط 🔖 على أي حديث لحفظه.', style: TextStyle(color: Theme.of(context).hintColor)),
              );
            }
            return ListView(padding: const EdgeInsets.only(top: 6, bottom: 20), children: [for (final h in list) HadithCard(h)]);
          },
        ),
      ),
    );
  }
}
