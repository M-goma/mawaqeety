import 'dart:convert';

import 'package:flutter/services.dart';

/// Page layout of the Madinah Mushaf (604 pages): where each page, juz and hizb quarter starts.
class MushafIndex {
  static const pageCount = 604;
  late final String base;
  late final List<int> _pages; // key (surah*1000+ayah) of each page's first ayah
  late final List<int> _juz, _quarters;

  Future<void> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/data/mushaf.json')) as Map<String, dynamic>;
    int key(dynamic e) => (e[0] as int) * 1000 + (e[1] as int);
    base = j['base'];
    _pages = (j['pages'] as List).map(key).toList();
    _juz = (j['juz'] as List).map(key).toList();
    _quarters = (j['quarters'] as List).map(key).toList();
  }

  static int _floor(List<int> starts, int k) {
    var lo = 0, hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= k) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  String url(int page) => '$base${page.toString().padLeft(3, '0')}.png';

  /// The page (1..604) that holds an ayah.
  int pageOf(int surah, int ayah) => _floor(_pages, surah * 1000 + ayah) + 1;

  /// First ayah on a page, as (surah, ayah).
  (int, int) startOf(int page) {
    final k = _pages[page - 1];
    return (k ~/ 1000, k % 1000);
  }

  /// Surah shown at the top of a page (the one its first line belongs to).
  int surahOf(int page) => _pages[page - 1] ~/ 1000;

  int juzOf(int page) => _floor(_juz, _pages[page - 1]) + 1;

  /// Hizb number (1..60) and the quarter (0..3) the page starts in.
  (int, int) hizbOf(int page) {
    final q = _floor(_quarters, _pages[page - 1]);
    return (q ~/ 4 + 1, q % 4);
  }

  int juzStartPage(int juz) => pageOf(_juz[juz - 1] ~/ 1000, _juz[juz - 1] % 1000);
}
