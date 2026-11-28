import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';

/// A tafsir the ayah sheet can show ([Tafsir.books]); the user's choice is `Settings.tafsirId`.
class TafsirBook {
  final String id, label, asset;
  const TafsirBook(this.id, this.label, this.asset);
}

/// The part of a tafsir that explains an ayah: the book often explains several ayat together ([from]–[to]).
class TafsirSection {
  final int from, to;
  final String text;
  /// The page the text was taken from, when the data records it (تفسير السعدي: islamweb.net).
  final String? url;
  const TafsirSection(this.from, this.to, this.text, [this.url]);
  bool get grouped => to > from;
}

/// A bundled tafsir, loaded lazily and once per book ([load] always returns the same instance for an id).
/// - التفسير الميسر (مجمع الملك فهد): one text per ayah (assets/data/tafsir_muyassar.json.gz, tools/build_tafsir.py);
/// - تفسير السعدي (islamweb.net, tools/build_tafsir_saadi.py) and المختصر في تفسير القرآن الكريم
///   (tools/build_tafsirs.py): sections of one or more ayat, as the books group them. Sources in
///   assets/data/TAFSIR_SOURCES.txt.
class Tafsir {
  static const muyassar = TafsirBook('muyassar', 'الميسر', 'assets/data/tafsir_muyassar.json.gz');
  static const books = [
    muyassar,
    TafsirBook('saadi', 'السعدي', 'assets/data/tafsir_saadi.json.gz'),
    TafsirBook('mukhtasar', 'المختصر', 'assets/data/tafsir_mukhtasar.json.gz'),
  ];
  static TafsirBook byId(String id) => books.firstWhere((b) => b.id == id, orElse: () => muyassar);

  static final _loading = <String, Future<Tafsir>>{};

  final TafsirBook book;
  /// Display name («التفسير الميسر», «تفسير السعدي»…), the publisher/author line, and the dataset it came from.
  final String name, source, via;
  /// Per surah, the sections in order; each ayah is in at most one. An ayah the source does not explain has none
  /// (تفسير السعدي on islamweb: 6:105–107).
  final List<List<TafsirSection>> sections;
  /// Per surah and ayah, the index of its section in [sections], or -1.
  final List<List<int>> _index;
  late final List<List<String>> t = [
    for (var s = 0; s < sections.length; s++) [for (final i in _index[s]) i < 0 ? '' : sections[s][i].text]
  ];
  late final List<List<String>> norm = [for (final s in t) [for (final a in s) Arabic.normalize(a)]];

  Tafsir(this.book, this.name, this.source, this.via, this.sections)
      : _index = [for (final secs in sections) _indexOf(secs)];

  static List<int> _indexOf(List<TafsirSection> secs) {
    final index = List.filled(secs.isEmpty ? 0 : secs.last.to, -1);
    for (var i = 0; i < secs.length; i++) {
      for (var a = secs[i].from; a <= secs[i].to; a++) {
        index[a - 1] = i;
      }
    }
    return index;
  }

  /// The tafsir «سبيل» searches: always التفسير الميسر.
  static Future<Tafsir> load([String id = 'muyassar']) {
    final book = byId(id);
    return _loading[book.id] ??= _load(book).catchError((Object e) {
      _loading.remove(book.id); // let a later call try again
      throw e;
    });
  }

  static Future<Tafsir> _load(TafsirBook book) async {
    final bytes = (await rootBundle.load(book.asset)).buffer.asUint8List();
    return parse(book, utf8.decode(const GZipDecoder().decodeBytes(bytes)));
  }

  static Tafsir parse(TafsirBook book, String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final List<List<TafsirSection>> secs;
    if (j['s'] case final List s) {
      // Optional 4th field: the source page ids (تفسير السعدي: islamweb pages); the first one fills j['url'] ('…/{}').
      final url = j['url'] as String?;
      String? page(List x) => url != null && x.length > 3 ? url.replaceFirst('{}', '${(x[3] as List).first}') : null;
      secs = [
        for (final surah in s)
          [
            for (final x in surah as List)
              TafsirSection(x[0] as int, x[1] as int, x[2] as String, page(x as List))
          ]
      ];
    } else {
      secs = [
        for (final surah in j['t'] as List)
          [for (final (i, x) in (surah as List).indexed) TafsirSection(i + 1, i + 1, x as String)]
      ];
    }
    return Tafsir(book, j['name'] as String, j['src'] as String, (j['via'] ?? '') as String, secs);
  }

  /// The section that explains the ayah, or null when the source has none for it.
  TafsirSection? sectionOf(int surah, int ayah) {
    final index = _index[surah - 1];
    final i = ayah <= index.length ? index[ayah - 1] : -1;
    return i < 0 ? null : sections[surah - 1][i];
  }

  /// The ayah's tafsir text ('' when the source has none for it).
  String of(int surah, int ayah) => sectionOf(surah, ayah)?.text ?? '';
}

/// One explained word or phrase of an ayah: [word] is the 0-based index of its first word in the ayah
/// (quran.json), [count] its number of words; word = -1 when it could not be placed in the ayah.
class WordMeaning {
  final int word, count;
  final String phrase, meaning;
  const WordMeaning(this.word, this.count, this.phrase, this.meaning);
  bool covers(int i) => word >= 0 && i >= word && i < word + count;
}

/// «معاني الكلمات»: الميسر في غريب القرآن الكريم (مجمع الملك فهد), assets/data/gharib_muyassar.json.gz,
/// built by tools/build_tafsirs.py. Loaded lazily and once.
class WordMeanings {
  static const asset = 'assets/data/gharib_muyassar.json.gz';
  static Future<WordMeanings>? _loading;
  final String name, source, via;
  final List<List<List<WordMeaning>>> w;
  WordMeanings(this.name, this.source, this.via, this.w);

  static Future<WordMeanings> load() => _loading ??= _load().catchError((Object e) {
        _loading = null;
        throw e;
      });

  static Future<WordMeanings> _load() async {
    final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
    return parse(utf8.decode(const GZipDecoder().decodeBytes(bytes)));
  }

  static WordMeanings parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return WordMeanings(j['name'] as String, j['src'] as String, (j['via'] ?? '') as String, [
      for (final s in j['w'] as List)
        [
          for (final a in s as List)
            [for (final x in a as List) WordMeaning(x[0] as int, x[1] as int, x[2] as String, x[3] as String)]
        ]
    ]);
  }

  List<WordMeaning> of(int surah, int ayah) => w[surah - 1][ayah - 1];
}
