import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/adhkar.dart';
import '../data/arbaeen.dart';
import '../data/asbab.dart';
import '../data/asma.dart';
import '../data/atlas.dart';
import '../data/companions_islam.dart';
import '../data/duas.dart';
import '../data/fiqh.dart';
import '../data/ghazawat.dart';
import '../data/hajj.dart';
import '../data/nasab.dart';
import '../data/occasions.dart';
import '../data/quiz.dart' show QuizRef;
import '../data/repository.dart';
import '../data/sabeel.dart';
import '../data/seerah.dart';
import '../ui/adhkar_page.dart';
import '../ui/asbab_page.dart';
import '../ui/asma_page.dart';
import '../ui/atlas_page.dart';
import '../ui/calendar_page.dart';
import '../ui/companions_islam_page.dart';
import '../ui/companions_page.dart';
import '../ui/downloads_page.dart';
import '../ui/duas_page.dart';
import '../ui/ghazawat_page.dart';
import '../ui/hajj_page.dart';
import '../ui/hadith_page.dart';
import '../ui/hifz_page.dart';
import '../ui/khatma_page.dart';
import '../ui/monthly_page.dart';
import '../ui/nasab_page.dart';
import '../ui/occasions_page.dart';
import '../ui/prophets_page.dart';
import '../ui/qibla_page.dart';
import '../ui/quiz_page.dart';
import '../ui/quran_pages.dart';
import '../ui/radio_page.dart';
import '../ui/ramadan_page.dart';
import '../ui/seerah_page.dart';
import '../ui/stats_page.dart';
import '../ui/tasbeeh_page.dart';
import '../ui/zakat_page.dart';

/// «من محتوى التطبيق»: an index of everything the app holds (fiqh, seerah, battles, stories, duas…) so «سبيل»
/// answers from the app's own content and opens the exact item in its page.
///
/// TO ADD A NEW SECTION: add one [LibrarySource] to [SabeelLibrary.sources] (its section name, the assets it
/// reads and a function that turns its data into [LibraryEntry]s). test/sabeel_library_test.dart fails if an
/// asset under assets/data/ is in pubspec.yaml but no source lists it.
class LibraryEntry {
  /// Stable id for tests and de-duplication: «ghazawat:badr», «fiqh:12», «feature:zakat».
  final String id;

  /// The section's name as shown on the card's chip («فقه العبادات»).
  final String section;
  final String title, snippet;

  /// Where the text is quoted from (fiqh: «إسلام ويب — الفتوى رقم …»), shown under the snippet.
  final String? source;

  /// A page of the app (calculator, helper…) rather than a text.
  final bool feature;

  /// Opens the item in its page.
  final void Function(BuildContext context) open;

  late final List<String> _titleWords = _words(title + (_extra.isEmpty ? '' : ' $_extra'));
  late final List<String> _textWords = _words(_text);
  late final String _titleKey = Arabic.searchKey(title);
  final String _text, _extra;

  /// [text] is searched with a lower weight than [title]; [keywords] (other names of the item) count as title.
  LibraryEntry({
    required this.id,
    required this.section,
    required this.title,
    required this.open,
    String snippet = '',
    String text = '',
    String keywords = '',
    this.source,
    this.feature = false,
  })  : snippet = _short(snippet),
        _text = '$snippet $text',
        _extra = keywords;

  static String _short(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 150) return t;
    final cut = t.lastIndexOf(' ', 150);
    return '${t.substring(0, cut < 80 ? 150 : cut)}…';
  }

  /// Distinct search keys of the words, without the prefixes و/ف/ب/ال.
  static List<String> _words(String s) => {
        for (final w in Arabic.normalize(s).split(RegExp(r'[^ء-يa-z0-9]+')))
          if (w.isNotEmpty) Arabic.searchKey(Sabeel.stem(w)),
      }.where((w) => w.isNotEmpty).toList();
}

/// One registered section: what it is called, the bundled assets it covers and how to build its entries.
class LibrarySource {
  final String id, section;

  /// Files under assets/data/ that this source indexes (checked by test/sabeel_library_test.dart).
  final List<String> assets;
  final Future<List<LibraryEntry>> Function(Repository repo) build;
  const LibrarySource(this.id, this.section, this.build, {this.assets = const []});
}

class LibraryResult {
  final List<LibraryEntry> entries;

  /// The best entry has every word of the query in its title (a direct answer, shown before the ayat).
  final bool strong;
  const LibraryResult(this.entries, {this.strong = false});
  static const empty = LibraryResult([]);
}

class SabeelLibrary {
  final List<LibraryEntry> entries;
  SabeelLibrary(this.entries);

  /// Results kept per query (the page shows the first [shown], then «المزيد»).
  static const maxResults = 30, shown = 6;

  // ───────────────────────── The registry: one line per section ─────────────────────────
  static final sources = <LibrarySource>[
    const LibrarySource('fiqh', 'فقه العبادات', _fiqh, assets: ['assets/data/fiqh.json']),
    const LibrarySource('ghazawat', 'غزوات النبي ﷺ', _ghazawat, assets: ['assets/data/ghazawat.json']),
    const LibrarySource('seerah', 'السيرة النبوية', _seerah, assets: ['assets/data/seerah.json']),
    const LibrarySource('companions_islam', 'كيف أسلم الصحابة', _companionsIslam),
    const LibrarySource('companions', 'العشرة المبشرون بالجنة', _companions, assets: ['assets/data/companions.json']),
    const LibrarySource('nasab', 'النسب الشريف', _nasab),
    const LibrarySource('prophets', 'قصص الأنبياء', _prophets, assets: ['assets/data/prophets.json']),
    const LibrarySource('arbaeen', 'الأربعون النووية', _arbaeen, assets: ['assets/data/arbaeen.json']),
    const LibrarySource('asbab', 'أسباب النزول', _asbab, assets: ['assets/data/asbab.json']),
    const LibrarySource('asma', 'أسماء الله الحسنى', _asma),
    const LibrarySource('occasions', 'المناسبات والصيام', _occasions),
    const LibrarySource('duas', 'أدعية المناسبات', _duas, assets: ['assets/data/duas.json']),
    const LibrarySource('adhkar', 'أذكار الصباح والمساء', _adhkar),
    const LibrarySource('atlas', 'أطلس قصص الأنبياء', _atlas),
    const LibrarySource('hajj', 'دليل الحج والعمرة', _hajj, assets: ['assets/data/hajj.json']),
    const LibrarySource('features', 'ميزات التطبيق', _features),
  ];

  /// Data assets that are not «content» to quote: the Quran text and tafsir (searched by [Sabeel] itself),
  /// the two Sahihs (searched by [Sabeel]), the quiz (made from the sections above) and app data.
  static const notContent = {
    'assets/data/quran.json', 'assets/data/mushaf.json', 'assets/data/mushaf_ayahs.json',
    'assets/data/tafsir_muyassar.json.gz', 'assets/data/hadith_bukhari.json.gz', 'assets/data/hadith_muslim.json.gz',
    'assets/data/quiz.json', 'assets/data/cities.json', 'assets/data/reciters.json', 'assets/data/adhan_voices.json',
    'assets/data/story_audio.json', 'assets/data/QURAN_TEXT_LICENSE.txt',
  };

  static Set<String> get coveredAssets => {for (final s in sources) ...s.assets};

  static Future<SabeelLibrary>? _loading;

  /// Builds the index once (lazily, on the first question) and shares it.
  static Future<SabeelLibrary> load(Repository repo) => _loading ??= _build(repo).catchError((Object e) {
        _loading = null;
        throw e;
      });

  static Future<SabeelLibrary> _build(Repository repo) async =>
      SabeelLibrary([for (final s in sources) ...await s.build(repo)]);

  /// Words that only shape the question («متى كانت…», «كم…») besides [Sabeel]'s own.
  static const _filler = {'كم', 'متي', 'اين', 'كان', 'كانت', 'يكون', 'تكون', 'اعرف', 'ابحث', 'اسال', 'عايزه', 'نبي', 'لي'};

  /// Entries for [query], best first: a word in the title counts more than in the text; every word must be
  /// found (or all but one for three words or more). [titleOnly] keeps only entries with every word in the title.
  LibraryResult search(String query, {bool titleOnly = false}) {
    final kw = [
      for (final w in Sabeel.keywordsOf(query))
        if (!_filler.contains(w)) Arabic.searchKey(Sabeel.stem(w)),
    ].where((w) => w.isNotEmpty).toSet().toList();
    if (kw.isEmpty) return LibraryResult.empty;
    final ruling = Sabeel.isRuling(query);
    final phrase = kw.join(' ');
    final hits = <(int, int, int, LibraryEntry)>[]; // score, in title, order
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      var score = 0, found = 0, inTitle = 0;
      for (final k in kw) {
        if (_has(e._titleWords, k)) {
          score += e._titleWords.contains(k) ? 4 : 3;
          found++;
          inTitle++;
        } else if (_has(e._textWords, k)) {
          score += 1;
          found++;
        }
      }
      final need = kw.length >= 3 ? kw.length - 1 : kw.length;
      if (found < need || (titleOnly && inTitle < kw.length)) continue;
      if (found < kw.length) score -= 2;
      if (kw.length > 1 && e._titleKey.contains(phrase)) score += 4;
      if (ruling && e.id.startsWith('fiqh:')) score += 3;
      hits.add((score, inTitle, i, e));
    }
    hits.sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$3.compareTo(b.$3));
    return LibraryResult([for (final h in hits.take(maxResults)) h.$4],
        strong: hits.isNotEmpty && hits.first.$2 == kw.length);
  }

  /// A word that starts with [k] (words of two letters must be whole).
  static bool _has(List<String> words, String k) =>
      k.length <= 2 ? words.contains(k) : words.any((w) => w.startsWith(k));
}

// ───────────────────────── Sources ─────────────────────────

void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

Future<List<LibraryEntry>> _fiqh(Repository repo) async => [
      for (final i in (await FiqhData.load()).items)
        LibraryEntry(
          id: 'fiqh:${i.id}',
          section: 'فقه العبادات',
          title: i.question,
          snippet: i.answers.isEmpty ? '' : i.answers.first.text,
          text: '${i.topic} ${i.sub} ${i.answers.map((a) => a.text).join(' ')}',
          keywords: i.sub,
          source: i.answers.map((a) => '${a.source}: ${a.ref}').join(' • '),
          open: (c) => openQuizSource(c, QuizRef('fiqh', id: i.id)),
        ),
    ];

Future<List<LibraryEntry>> _seerah(Repository repo) async => [
      for (final e in (await SeerahData.load()).events)
        LibraryEntry(
          id: 'seerah:${e.id}',
          section: 'السيرة النبوية',
          title: e.title,
          snippet: '${e.when} (${e.hijriLabel}، ${e.ceLabel}): ${e.summary}',
          text: '${e.place?.name ?? ''} ${e.disputed ?? ''}',
          open: (c) => _push(c, SeerahPage(openEvent: e.id)),
        ),
    ];

Future<List<LibraryEntry>> _ghazawat(Repository repo) async => [
      for (final g in (await GhazawatData.load()).list)
        LibraryEntry(
          id: 'ghazawat:${g.id}',
          section: 'غزوات النبي ﷺ',
          title: g.name,
          snippet: '${g.date} — ${g.place}. ${g.summary}',
          text: '${g.muslims} ${g.enemy} ${g.result} ${g.sections.map((s) => '${s.heading} ${s.text}').join(' ')} ${g.lessons.join(' ')}',
          open: (c) => _push(c, GhazwaPage(g: g)),
        ),
    ];

Future<List<LibraryEntry>> _hajj(Repository repo) async {
  final d = await HajjData.load();
  return [
    for (final g in d.guides)
      for (final st in g.steps)
        LibraryEntry(
          id: 'hajj:${g.id}:${st.id}',
          section: 'دليل الحج والعمرة',
          title: '${g.name}: ${st.title}',
          snippet: '${st.dayLabel.isEmpty ? '' : '${st.dayLabel} — '}الحكم: ${st.ruling}. ${st.what.isEmpty ? '' : st.what.first}',
          text: '${st.place} ${st.rulingNote} ${st.what.join(' ')} ${st.mistakes.join(' ')} ${st.others} '
              '${st.duas.map((x) => x.text).join(' ')}',
          keywords: 'حج عمره مناسك ${st.title}',
          source: st.refs.isEmpty ? null : st.refs.first.source,
          open: (ctx) async {
            final checks = await HajjChecks.load();
            if (!ctx.mounted) return;
            _push(ctx, HajjStepPage(data: d, guide: g, start: g.steps.indexOf(st), checks: ValueNotifier(checks)));
          },
        ),
    LibraryEntry(
      id: 'hajj:mahzurat',
      section: 'دليل الحج والعمرة',
      title: 'محظورات الإحرام',
      snippet: d.mahzuratIntro,
      text: d.mahzurat.map((m) => '${m.name} ${m.items.join(' ')}').join(' '),
      keywords: 'محظورات الاحرام ممنوعات المحرم',
      open: (ctx) => _push(ctx, const HajjPage(initialTab: 2)),
    ),
    LibraryEntry(
      id: 'hajj:mawaqit',
      section: 'دليل الحج والعمرة',
      title: 'المواقيت المكانية للحج والعمرة',
      snippet: d.mawaqitIntro,
      text: d.mawaqit.map((m) => '${m.name} ${m.modern} ${m.forWhom} ${m.note}').join(' '),
      keywords: 'ميقات مواقيت الاحرام',
      open: (ctx) => _push(ctx, const HajjPage(initialTab: 2)),
    ),
  ];
}

Future<List<LibraryEntry>> _companionsIslam(Repository repo) async => [
      for (final c in CompanionsIslam.list)
        LibraryEntry(
          id: 'companions_islam:${c.id}',
          section: 'كيف أسلم الصحابة',
          title: 'إسلام ${c.name}',
          snippet: '${c.by}. ${c.story}',
          text: '${c.age ?? ''} ${c.hadith?.text ?? ''}',
          keywords: 'كيف اسلم ${c.name}',
          source: c.sources.isEmpty ? null : c.sources.first.label,
          open: (ctx) => _push(ctx, const CompanionsIslamPage()),
        ),
    ];

Future<List<LibraryEntry>> _companions(Repository repo) async {
  final d = await CompanionsData.load();
  return [
    for (final c in d.list)
      LibraryEntry(
        id: 'companions:${c.id}',
        section: 'العشرة المبشرون بالجنة',
        title: c.name,
        snippet: '${c.title}. ${c.bio}',
        text: c.situations.map((s) => '${s.$1} ${s.$2}').join(' '),
        open: (ctx) => _push(ctx, CompanionPage(c: c, note: d.note)),
      ),
  ];
}

Future<List<LibraryEntry>> _nasab(Repository repo) async => [
      LibraryEntry(
        id: 'nasab:prophet',
        section: 'النسب الشريف',
        title: 'نسب النبي ﷺ',
        snippet: Nasab.intro,
        text: '${Nasab.agreed} ${Nasab.mother} ${Nasab.chain.map((a) => '${a.name} ${a.note ?? ''}').join(' ')}',
        keywords: 'النسب الشريف نسب الرسول ام النبي امه',
        source: Nasab.bukhariRef,
        open: (c) => _push(c, const NasabPage()),
      ),
      for (final n in Nasab.companions)
        LibraryEntry(
          id: 'nasab:${n.id}',
          section: 'النسب الشريف',
          title: 'نسب ${n.name}',
          snippet: '${n.lineage}. يلتقي مع النبي ﷺ عند ${n.meetName}. ${n.remark ?? ''}',
          source: n.source.label,
          open: (c) => _push(c, const NasabPage()),
        ),
    ];

Future<List<LibraryEntry>> _prophets(Repository repo) async => [
      for (final p in repo.prophets)
        LibraryEntry(
          id: 'prophets:${p.id}',
          section: 'قصص الأنبياء',
          title: 'قصة ${p.displayName}',
          snippet: p.summary,
          text: '${p.title} ${p.sections.map((s) => '${s.heading} ${s.body}').join(' ')} ${p.lessons.join(' ')}',
          keywords: 'نبي الله ${p.nameAr}',
          open: (c) => _push(c, ProphetPage(prophet: p)),
        ),
    ];

Future<List<LibraryEntry>> _arbaeen(Repository repo) async => [
      for (final h in (await Arbaeen.load()).hadiths)
        LibraryEntry(
          id: 'arbaeen:${h.number}',
          section: 'الأربعون النووية',
          title: 'الحديث ${Arabic.digits(h.number)}: ${h.title}',
          snippet: h.text,
          text: '${h.narrator} ${h.benefits.join(' ')}',
          source: h.takhrij,
          open: (c) => openQuizSource(c, QuizRef('arbaeen', n: h.number)),
        ),
    ];

Future<List<LibraryEntry>> _asbab(Repository repo) async {
  final a = await Asbab.load();
  return [
    for (final s in a.all)
      LibraryEntry(
        id: 'asbab:${s.surah}:${s.from}:${s.collection}${s.number}',
        section: 'أسباب النزول',
        title: 'سبب نزول سورة ${repo.surahs[s.surah - 1].name}، ${s.ayahLabel}',
        snippet: s.excerpt,
        keywords: 'سبب نزول ${repo.surahs[s.surah - 1].name}',
        source: s.ref,
        open: (c) => _push(c, SurahAsbabPage(surah: repo.surahs[s.surah - 1], asbab: a.inSurah(s.surah))),
      ),
  ];
}

Future<List<LibraryEntry>> _asma(Repository repo) async => [
      for (final (name, meaning, _) in asmaAlHusna)
        LibraryEntry(
          id: 'asma:$name',
          section: 'أسماء الله الحسنى',
          title: 'اسم الله «$name»',
          snippet: meaning,
          keywords: 'معنى اسم الله $name',
          open: (c) => _push(c, const AsmaPage()),
        ),
    ];

Future<List<LibraryEntry>> _occasions(Repository repo) async => [
      for (final o in occasions)
        LibraryEntry(
          id: 'occasions:${o.id}',
          section: 'المناسبات والصيام',
          title: o.name,
          snippet: o.note,
          keywords: o.isFast ? 'صيام صوم فضل' : '',
          source: o.ref.isEmpty ? null : o.ref,
          open: (c) => _push(c, const OccasionsPage()),
        ),
      LibraryEntry(
        id: 'occasions:monthu',
        section: 'المناسبات والصيام',
        title: 'صيام الاثنين والخميس',
        snippet: monThuNote,
        keywords: 'صوم يوم الاثنين الخميس',
        source: monThuRef,
        open: (c) => _push(c, const OccasionsPage()),
      ),
    ];

Future<List<LibraryEntry>> _duas(Repository repo) async {
  await Duas.load();
  return [
    for (final g in Duas.groups)
      for (final (i, s) in g.sections.indexed)
        LibraryEntry(
          id: 'duas:${g.id}:$i',
          section: 'أدعية المناسبات',
          title: s.title == g.title ? 'دعاء ${g.title}' : '${g.title}: ${s.title}',
          snippet: s.items.isEmpty ? '' : s.items.first.text,
          text: s.items.map((d) => '${d.text} ${d.virtue}').join(' '),
          keywords: 'دعاء ادعيه ذكر ${g.title}',
          source: s.items.isEmpty || s.items.first.source.isEmpty ? Duas.bookSource : s.items.first.source,
          open: (c) => _push(c, DuaGroupPage(group: g)),
        ),
  ];
}

Future<List<LibraryEntry>> _adhkar(Repository repo) async => [
      for (final (i, d) in adhkar.indexed)
        if (d.quran.isEmpty && (d.morning ?? d.evening) != null)
          LibraryEntry(
            id: 'adhkar:$i',
            section: 'أذكار الصباح والمساء',
            title: (d.morning ?? d.evening)!.split(' ').take(7).join(' '),
            snippet: d.morning ?? d.evening!,
            text: '${d.evening ?? ''} ${d.virtue}',
            source: d.source,
            open: (c) => _push(c, const AdhkarPage()),
          ),
    ];

Future<List<LibraryEntry>> _atlas(Repository repo) async {
  String names(List<String> ids) =>
      [for (final id in ids) ...repo.prophets.where((p) => p.id == id).map((p) => p.nameAr)].join(' ');
  return [
    for (final p in atlasPlaces)
      LibraryEntry(
        id: 'atlas:${p.name}',
        section: 'أطلس قصص الأنبياء',
        title: p.name,
        snippet: p.note,
        text: names(p.prophets),
        keywords: 'مكان اين',
        source: '${p.source} (${p.certainty.label})',
        open: (c) => _push(c, const AtlasPage()),
      ),
  ];
}

/// The app's pages as entries, so «كيف أحفظ القرآن» suggests مساعد الحفظ and «حاسبة الزكاة» opens the calculator.
Future<List<LibraryEntry>> _features(Repository repo) async {
  LibraryEntry f(String id, String title, String snippet, String keywords, Widget Function() page) => LibraryEntry(
        id: 'feature:$id',
        section: 'ميزات التطبيق',
        title: title,
        snippet: snippet,
        keywords: keywords,
        feature: true,
        open: (c) => _push(c, page()),
      );
  return [
    f('zakat', 'حاسبة الزكاة', 'احسب زكاة النقود والذهب والفضة وعروض التجارة، والنصاب (٨٥ جرامًا من الذهب أو ٥٩٥ من الفضة) بسعر الجرام الذي تدخله.',
        'زكاه المال نصاب الزكاه الذهب الفضه حساب الزكاه كم الزكاه', () => const ZakatPage()),
    f('ramadan', 'رمضان', 'متابعة الصيام والتراويح والتهجد في شهر رمضان.', 'رمضان صيام رمضان التراويح التهجد قيام الليل',
        () => const RamadanPage()),
    f('whitedays', 'الأيام البيض', 'صيام ١٣ و١٤ و١٥ من كل شهر هجري ومتابعته.', 'الايام البيض صيام ثلاثه ايام من كل شهر',
        () => const WhiteDaysPage()),
    f('occasions', 'المناسبات وصيام السنن', 'عرفة وعاشوراء والعيدان والاثنين والخميس بتواريخها.',
        'مناسبات اسلاميه صيام السنن صيام التطوع', () => const OccasionsPage()),
    f('hifz', 'مساعد الحفظ', 'كرّر المقطع بصوت القارئ، واختبر حفظك بإخفاء الكلمات، وراجِع في موعدك.',
        'حفظ القران احفظ تحفيظ مراجعه الحفظ تثبيت الحفظ', () => const HifzPage()),
    f('tafsir', 'التفسير الميسر', 'اضغط على أي آية في المصحف لترى تفسيرها، أو اسأل سبيل عن آية.',
        'تفسير القران تفسير ايه معنى الايه', () => const QuranIndexPage()),
    f('mushaf', 'المصحف', 'قراءة القرآن الكريم بالرسم العثماني والاستماع إلى التلاوة.', 'المصحف قراءه القران تلاوه سور القران',
        () => const QuranIndexPage()),
    f('khatma', 'ورد القرآن والختمة', 'خطة ختمة ووردك اليومي من القرآن.', 'ختمه ختم القران ورد يومي', () => const KhatmaPage()),
    f('quiz', 'مسابقات', 'أسئلة قصيرة من محتوى التطبيق بمصادرها.', 'مسابقه اسئله اختبر معلوماتك سؤال وجواب', () => const QuizPage()),
    f('calendar', 'التقويم', 'التقويم الميلادي مع التاريخ الهجري والأيام البيض.', 'التقويم الهجري التاريخ الهجري الميلادي', () => const CalendarPage()),
    f('monthly', 'مواقيت الشهر', 'جدول مواقيت الصلاة للشهر كاملًا.', 'مواقيت الصلاه جدول الشهر امساكيه', () => const MonthlyPage()),
    f('atlas', 'أطلس قصص الأنبياء', 'أماكن قصص الأنبياء والغزوات وأحداث السيرة على الخريطة.', 'خريطه اطلس اماكن الانبياء',
        () => const AtlasPage()),
    f('downloads', 'الاستماع دون إنترنت', 'نزّل المصحف كاملًا أو سورًا محددة بصوت القارئ لتستمع إليها دون إنترنت.', 'تنزيل تحميل بدون انترنت التلاوات',
        () => const DownloadsPage()),
    f('qibla', 'اتجاه القبلة', 'البوصلة والخريطة لمعرفة اتجاه القبلة.', 'القبله اتجاه الكعبه بوصله', () => const QiblaPage()),
    f('tasbeeh', 'السبحة', 'سبحة إلكترونية ووردك اليومي من التسبيح.', 'سبحه تسبيح عداد', () => const TasbeehPage()),
    f('adhkar', 'الأذكار', 'أذكار الصباح والمساء من حصن المسلم.', 'اذكار الصباح المساء', () => const AdhkarPage()),
    f('duas', 'أدعية المناسبات', 'أدعية النوم والسفر والطعام والكرب وغيرها من حصن المسلم.', 'ادعيه دعاء حصن المسلم',
        () => const DuasPage()),
    f('hadith', 'الأحاديث الصحيحة', 'تصفّح صحيح البخاري وصحيح مسلم وابحث فيهما.', 'صحيح البخاري صحيح مسلم احاديث بحث',
        () => const HadithPage()),
    f('radio', 'الإذاعة', 'إذاعة القرآن الكريم مباشرة.', 'اذاعه راديو القران', () => const RadioPage()),
    f('stats', 'إحصائياتي', 'صلواتك وأذكارك ووردك.', 'احصائيات متابعه', () => const StatsPage()),
    f('prophets', 'قصص الأنبياء', 'قصص الأنبياء من القرآن والسنة الصحيحة.', 'قصص الانبياء', () => const ProphetsPage()),
  ];
}
