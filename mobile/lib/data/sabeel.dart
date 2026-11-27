import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';
import 'hadith.dart';
import 'repository.dart';

/// التفسير الميسر (مجمع الملك فهد), one text per ayah (assets/data/tafsir_muyassar.json.gz,
/// built by tools/build_tafsir.py).
class Tafsir {
  static Tafsir? _cached;
  final String name, source;
  final List<List<String>> t;
  late final List<List<String>> norm = [for (final s in t) [for (final a in s) Arabic.normalize(a)]];
  Tafsir(this.name, this.source, this.t);

  static Future<Tafsir> load() async {
    if (_cached != null) return _cached!;
    final bytes = (await rootBundle.load('assets/data/tafsir_muyassar.json.gz')).buffer.asUint8List();
    final j = jsonDecode(utf8.decode(const GZipDecoder().decodeBytes(bytes))) as Map<String, dynamic>;
    return _cached = Tafsir(j['name'], j['src'], [for (final s in j['t'] as List) (s as List).cast<String>()]);
  }

  String of(int surah, int ayah) => t[surah - 1][ayah - 1];
}

/// One ayah in an answer, with its tafsir.
class SabeelAyah {
  final Surah surah;
  final int ayah;
  final String tafsir;
  SabeelAyah(this.surah, this.ayah, this.tafsir);
  String get text => surah.verses[ayah - 1];
}

class SabeelAnswer {
  final String title; // what we understood, e.g. «آية الكرسي — البقرة ٢٥٥»
  final List<SabeelAyah> ayat;
  final List<Hadith> hadith;
  final bool ruling; // a fiqh/fatwa question: refer to scholars
  final bool more; // more ayat matched than shown
  SabeelAnswer(this.title, this.ayat, this.hadith, {this.ruling = false, this.more = false});
  bool get isEmpty => ayat.isEmpty && hadith.isEmpty;
}

/// «سبيل»: an offline search that answers «تفسير آية…» or «حديث عن…» questions from the bundled
/// Quran, التفسير الميسر and the two Sahih collections. No AI: it only finds and quotes sources.
class Sabeel {
  final Repository repo;
  final Tafsir tafsir;
  final List<HadithCollection> hadith;
  Sabeel(this.repo, this.tafsir, this.hadith);

  static Future<Sabeel> load(Repository repo) async =>
      Sabeel(repo, await Tafsir.load(), [for (final id in HadithCollection.ids) await HadithCollection.load(id)]);

  /// Well-known names of ayat: (names, surah, from, to, words to find hadith about it).
  static const named = <(List<String>, int, int, int, String)>[
    (['ايه الكرسي', 'اية الكرسي', 'الكرسي'], 2, 255, 255, 'آية الكرسي'),
    (['خواتيم البقره', 'خواتيم سوره البقره', 'اخر البقره', 'اواخر البقره', 'امن الرسول'], 2, 285, 286, 'آخر سورة البقرة'),
    (['ايه الدين', 'اية الدين', 'ايه المداينه'], 2, 282, 282, ''),
    (['ايه النور', 'اية النور', 'الله نور السماوات'], 24, 35, 35, ''),
    (['ايات الصيام', 'ايه الصيام', 'اية الصيام', 'ايات الصوم'], 2, 183, 187, ''),
    (['ايه الوضوء', 'اية الوضوء', 'ايه الطهاره'], 5, 6, 6, ''),
    (['ايات المواريث', 'ايه المواريث', 'ايه الميراث'], 4, 11, 12, ''),
    (['ايه الكلاله', 'اية الكلالة'], 4, 176, 176, ''),
    (['ايه الاسراء', 'سبحان الذي اسري'], 17, 1, 1, ''),
    (['ايه الحجاب', 'اية الحجاب'], 33, 53, 53, 'آية الحجاب'),
    (['ايه التيمم', 'اية التيمم'], 4, 43, 43, 'آية التيمم'),
    (['ايه البر', 'ليس البر'], 2, 177, 177, ''),
    (['ايه الشوري', 'وامرهم شوري'], 42, 38, 38, ''),
    (['ايه الصلاه علي النبي', 'ان الله وملائكته يصلون'], 33, 56, 56, ''),
    (['اكملت لكم دينكم', 'ايه اكمال الدين'], 5, 3, 3, 'اليوم أكملت لكم دينكم'),
    (['قل هو الله احد', 'سوره الاخلاص'], 112, 1, 4, 'قل هو الله أحد'),
    (['المعوذتين', 'المعوذات'], 113, 1, 5, 'المعوذات'),
    (['ام الكتاب', 'السبع المثاني', 'الفاتحه'], 1, 1, 7, 'فاتحة الكتاب'),
  ];

  static const _filler = {
    'تفسير', 'فسر', 'معني', 'شرح', 'ما', 'ماذا', 'مااللي', 'هو', 'هي', 'عن', 'في', 'من', 'الي', 'علي', 'ان',
    'ايه', 'ايات', 'الايه', 'الايات', 'اية', 'آية', 'قوله', 'تعالي', 'حديث', 'الحديث', 'احاديث', 'الاحاديث',
    'هل', 'كيف', 'لماذا', 'ليه', 'يقول', 'قال', 'النبي', 'الرسول', 'رسول', 'صلي', 'عليه', 'وسلم', 'ﷺ', 'سوره',
    'السوره', 'رقم', 'اريد', 'عايز', 'ابغي', 'ورد', 'جاء', 'الذي', 'التي', 'اللي', 'ايش', 'وش', 'عند', 'و',
  };
  static const _rulingWords = ['حكم', 'يجوز', 'جايز', 'جائز', 'حلال', 'حرام', 'فتوي', 'مكروه', 'واجب', 'كفاره', 'افتوني'];

  static String _plain(String s) => Arabic.normalize(s).replaceAll(RegExp(r'[؟?،,.:;!«»"()\[\]-]'), ' ');

  /// Drops common prefixes so «الصبر», «والصبر» and «بالصبر» all find «صبر».
  static String _stem(String w) {
    for (final p in const ['وبال', 'وال', 'بال', 'فال', 'كال', 'لل', 'ال']) {
      if (w.startsWith(p) && w.length - p.length >= 3) return w.substring(p.length);
    }
    if (w.length >= 5 && (w.startsWith('و') || w.startsWith('ف'))) return w.substring(1);
    return w;
  }

  late final Map<String, int> _surahNames = {
    for (final s in repo.surahs) ...{
      Arabic.normalize(s.name): s.number,
      _stem(Arabic.normalize(s.name)): s.number,
    }
  };

  SabeelAnswer ask(String query) {
    final raw = Arabic.latinDigits(query);
    final q = _plain(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
    final ruling = _rulingWords.any((w) => q.split(' ').any((t) => t == w || t.startsWith(w)));
    if (q.isEmpty) return SabeelAnswer('', const [], const []);

    // 1) "2:255" or "2/255"
    final ref = RegExp(r'(\d{1,3})\s*[:/]\s*(\d{1,3})(?:\s*-\s*(\d{1,3}))?').firstMatch(raw);
    if (ref != null) {
      final a = _range(int.parse(ref[1]!), int.parse(ref[2]!), int.tryParse(ref[3] ?? ''));
      if (a != null) return a.withRuling(ruling);
    }

    // 2) A well-known name: «آية الكرسي», «خواتيم البقرة»…
    for (final n in named) {
      if (n.$1.any((k) => q.contains(k))) {
        final a = _range(n.$2, n.$3, n.$4, hadithWords: n.$5);
        if (a != null) return a.withRuling(ruling);
      }
    }

    // 3) A surah by name, with an ayah number or range («الكهف 10», «سورة البقرة آية 255 - 257»).
    final words = q.split(' ');
    final nums = RegExp(r'\d+').allMatches(q).map((m) => int.parse(m[0]!)).toList();
    for (var i = 0; i < words.length; i++) {
      final two = i + 1 < words.length ? '${words[i]} ${words[i + 1]}' : null;
      final hasSurahWord = i > 0 && (words[i - 1] == 'سوره' || words[i - 1] == 'لسوره');
      final number = two != null && _surahNames.containsKey(two) ? _surahNames[two] : _surahNames[words[i]] ?? _surahNames[_stem(words[i])];
      if (number == null) continue;
      if (nums.isNotEmpty) {
        final a = _range(number, nums[0], nums.length > 1 && nums[1] > nums[0] ? nums[1] : null);
        if (a != null) return a.withRuling(ruling);
      }
      final rest = _keywords(words.where((w) => w != words[i] && (two == null || !two.contains(w))).join(' '));
      if (hasSurahWord || rest.isEmpty) {
        final s = repo.surahs[number - 1];
        if (rest.isEmpty) {
          final show = s.verses.length < 10 ? s.verses.length : 10;
          return SabeelAnswer('سورة ${s.name} — من أولها', [for (var a = 1; a <= show; a++) _ayah(number, a)],
              _hadith(['سوره ${Arabic.normalize(s.name)}']), ruling: ruling, more: s.verses.length > show);
        }
        return _keywordAnswer(rest, onlySurah: number, ruling: ruling);
      }
    }

    // 4) Keywords: search the ayat (and their tafsir) and the hadith.
    final kw = _keywords(q);
    if (kw.isEmpty) return SabeelAnswer('', const [], const [], ruling: ruling);
    // «حديث …» quotes a hadith: show only ayat that have every word.
    return _keywordAnswer(kw, ruling: ruling, exact: q.split(' ').contains('حديث'));
  }

  List<String> _keywords(String q) => [
        for (final w in q.split(' '))
          if (w.length >= 2 && !_filler.contains(w) && !_rulingWords.any(w.startsWith) && !RegExp(r'^\d+$').hasMatch(w)) w,
      ];

  SabeelAyah _ayah(int s, int a) => SabeelAyah(repo.surahs[s - 1], a, tafsir.of(s, a));

  SabeelAnswer? _range(int s, int from, int? to, {String hadithWords = ''}) {
    if (s < 1 || s > 114) return null;
    final surah = repo.surahs[s - 1];
    if (from < 1 || from > surah.verses.length) return null;
    var end = (to ?? from).clamp(from, surah.verses.length);
    if (end - from > 9) end = from + 9;
    final title = from == end
        ? 'سورة ${surah.name} — الآية ${Arabic.digits(from)}'
        : 'سورة ${surah.name} — الآيات ${Arabic.digits(from)}–${Arabic.digits(end)}';
    final hw = hadithWords.isEmpty ? <String>[] : [Arabic.normalize(hadithWords)];
    return SabeelAnswer(title, [for (var a = from; a <= end; a++) _ayah(s, a)], hw.isEmpty ? const [] : _hadith(hw));
  }

  SabeelAnswer _keywordAnswer(List<String> kw, {int? onlySurah, bool ruling = false, bool exact = false}) {
    final stems = [for (final w in kw) _stem(w)];
    final verseKeys = [for (final w in stems) Arabic.searchKey(w)];
    final phrase = Arabic.searchKey(kw.join(' '));
    final full = <(int, int, int)>[], partial = <(int, int, int)>[]; // score, surah, ayah
    for (var s = 1; s <= 114; s++) {
      if (onlySurah != null && s != onlySurah) continue;
      final verses = repo.surahs[s - 1].verses;
      for (var a = 1; a <= verses.length; a++) {
        final v = Arabic.searchKey(verses[a - 1]);
        final t = tafsir.norm[s - 1][a - 1];
        var score = 0, found = 0;
        for (var i = 0; i < stems.length; i++) {
          // Without its alefs a word can shrink to two letters («ربا» → «رب»): match it in the tafsir only.
          final inV = verseKeys[i].length >= 3 && _has(v, verseKeys[i]), inT = _has(t, stems[i]);
          if (inV || inT) found++;
          if (inV) score += 3;
          if (inT) score += 1;
        }
        if (found == stems.length) {
          if (kw.length > 1 && v.contains(phrase)) score += 10;
          full.add((score, s, a));
        } else if (!exact && stems.length > 1 && found == stems.length - 1) {
          partial.add((score, s, a));
        }
      }
    }
    int byScore((int, int, int) x, (int, int, int) y) =>
        y.$1 != x.$1 ? y.$1.compareTo(x.$1) : (x.$2 * 1000 + x.$3).compareTo(y.$2 * 1000 + y.$3);
    full.sort(byScore);
    final scored = full.length >= 5 ? full : [...full, ...(partial..sort(byScore))];
    final top = scored.take(12).map((e) => _ayah(e.$2, e.$3)).toList();
    final where = onlySurah == null ? '' : ' في سورة ${repo.surahs[onlySurah - 1].name}';
    return SabeelAnswer('نتائج «${kw.join(' ')}»$where', top, onlySurah == null ? _hadith(stems) : const [],
        ruling: ruling, more: scored.length > top.length);
  }

  /// A word that starts with [w] (after و/ف/ب/ل/ك and «ال»): «صبر» finds «والصبر» and «صبروا» but «ربا»
  /// does not find «أقربائكم». Two-letter words (بر، حج) must be the whole word.
  static final _re = <String, RegExp>{};
  static bool _has(String text, String w) => (_re[w] ??= RegExp(
          '(^|[^ء-ي])(و|ف)?(ب|ل|ك)?(ال|ل)?$w${w.length <= 2 ? '([^ء-ي]|\$)' : ''}'))
      .hasMatch(text);

  /// Hadith whose text has every word; the Prophet's ﷺ own words first, shortest first.
  List<Hadith> _hadith(List<String> words, {int max = 8}) {
    final ws = [for (final w in words) HadithCollection.plain(w)];
    final found = <Hadith>[];
    for (final c in hadith) {
      found.addAll(c.search(ws.join(' '), max: 60));
    }
    found.sort((a, b) {
      final qa = a.hasMatn && a.matn.contains('"') ? 0 : 1, qb = b.hasMatn && b.matn.contains('"') ? 0 : 1;
      return qa != qb ? qa.compareTo(qb) : a.matn.length.compareTo(b.matn.length);
    });
    final seen = <String>{};
    return [
      for (final h in found)
        if (seen.add(_head(h))) h,
    ].take(max).toList();
  }
}

String _head(Hadith h) {
  final p = HadithCollection.plain(h.matn).replaceAll(RegExp(r'[^ء-ي]'), '');
  return p.length > 50 ? p.substring(0, 50) : p;
}

extension on SabeelAnswer {
  SabeelAnswer withRuling(bool r) => r ? SabeelAnswer(title, ayat, hadith, ruling: true, more: more) : this;
}
