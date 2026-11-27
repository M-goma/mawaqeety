import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';

/// One hadith: book number, the common hadith number, the full text (with its chain) and where the
/// companion's narration starts (−1 = show the full text).
class Hadith {
  final HadithCollection col;
  final int index, book, number, matnStart;
  final String text;
  const Hadith(this.col, this.index, this.book, this.number, this.text, this.matnStart);

  bool get hasMatn => matnStart > 0;
  String get matn => hasMatn ? text.substring(matnStart) : text;
  /// Stable id for bookmarks: collection and position in the data file.
  String get key => '${col.id}:$index';
  String get ref => '${col.name} • ${col.bookName(book)}';
}

/// صحيح البخاري / صحيح مسلم (assets/data/hadith_<id>.json.gz, built by tools/build_hadith.py).
class HadithCollection {
  final String id, name;
  final List<(int, String)> books;
  late final List<Hadith> all;
  final Map<int, int> _bookCounts = {};
  HadithCollection._(this.id, this.name, this.books);

  static final Map<String, HadithCollection> _cache = {};
  static const ids = ['bukhari', 'muslim'];

  static Future<HadithCollection> load(String id) async {
    final c = _cache[id];
    if (c != null) return c;
    final bytes = (await rootBundle.load('assets/data/hadith_$id.json.gz')).buffer.asUint8List();
    final j = jsonDecode(utf8.decode(const GZipDecoder().decodeBytes(bytes))) as Map<String, dynamic>;
    final col = HadithCollection._(id, j['name'], [for (final b in j['books'] as List) (b[0] as int, b[1] as String)]);
    final rows = j['h'] as List;
    col.all = [for (var i = 0; i < rows.length; i++) Hadith(col, i, rows[i][0], rows[i][1], rows[i][2], rows[i][3])];
    for (final h in col.all) {
      col._bookCounts[h.book] = (col._bookCounts[h.book] ?? 0) + 1;
    }
    return _cache[id] = col;
  }

  String bookName(int n) => 'كتاب ${books.firstWhere((b) => b.$1 == n, orElse: () => (n, '')).$2}';
  int bookCount(int n) => _bookCounts[n] ?? 0;
  List<Hadith> inBook(int n) => all.where((h) => h.book == n).toList();

  static final _diacritics = RegExp('[ً-ْٰـ]');
  static String plain(String s) => s
      .replaceAll(_diacritics, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');

  late final List<String> _plain = [for (final h in all) plain(h.text)];

  List<Hadith> search(String q, {int max = 150}) {
    final words = plain(q.trim()).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final out = <Hadith>[];
    for (var i = 0; i < all.length && out.length < max; i++) {
      if (words.every(_plain[i].contains)) out.add(all[i]);
    }
    return out;
  }

  /// A short hadith with the Prophet's ﷺ own words, a different one each day.
  Hadith ofDay(DateTime day) {
    final pool = _dailyPool ??= all.where((h) => h.hasMatn && h.matn.length >= 70 && h.matn.length <= 330 && h.matn.contains('"')).toList();
    final n = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;
    return pool[(n * 7919) % pool.length];
  }

  List<Hadith>? _dailyPool;
}

String hadithCount(int n) {
  if (n == 1) return 'حديث واحد';
  if (n == 2) return 'حديثان';
  return n <= 10 ? '${Arabic.digits(n)} أحاديث' : '${Arabic.digits(n)} حديثًا';
}

/// Finds a saved hadith from its [Hadith.key].
Future<Hadith?> hadithByKey(String key) async {
  final p = key.split(':');
  if (p.length != 2 || !HadithCollection.ids.contains(p[0])) return null;
  final c = await HadithCollection.load(p[0]);
  final i = int.tryParse(p[1]) ?? -1;
  return i >= 0 && i < c.all.length ? c.all[i] : null;
}
