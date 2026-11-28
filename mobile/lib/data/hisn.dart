import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';

/// «حصن المسلم» (assets/data/hisn.json, built by tools/build_hisn.py): the book's chapters, numbered as in the
/// book, with each dhikr's text, repetition count, virtue, the book's takhrij and grading.
/// Chapter 27 (أذكار الصباح والمساء) is kept once, in the «الأذكار» tab ([HisnChapter.link] == 'adhkar').
class HisnPart {
  /// Plain text, or a Qur'an quotation: surah, first and last ayah ([partial]: part of an ayah, shown as quoted).
  final String text;
  final (int, int, int)? quran;
  final bool partial;
  const HisnPart(this.text, this.quran, this.partial);
}

/// A hadith of the two Sahihs located in the app's own data: collection id, hadith number and a phrase of the
/// dhikr found in it (checked by test/hisn_test.dart).
class HisnRef {
  final String col, key;
  final int number;
  const HisnRef(this.col, this.number, this.key);
  String get label => '${col == 'bukhari' ? 'البخاري' : 'مسلم'} ${Arabic.digits(number)}';
}

class HisnDhikr {
  final HisnChapter chapter;

  /// The book's number of the dhikr (1–267); null in «فضل الذكر».
  final int? number;
  final String text, virtue, takhrij, grade;
  final int count;
  final List<HisnPart> parts;
  final List<HisnRef> refs;
  HisnDhikr(this.chapter, this.number, this.text, this.count, this.virtue, this.takhrij, this.grade, this.parts, this.refs);

  /// «البخاري مع الفتح ١١/١١٣ ومسلم … (البخاري ٦٣١٢، مسلم ٢٧١١) — في الصحيحين».
  String get source {
    final b = StringBuffer(takhrij.isEmpty ? Hisn.bookSource : takhrij);
    if (refs.isNotEmpty) b.write(' (${refs.map((r) => r.label).join('، ')})');
    if (grade.isNotEmpty) b.write(' — $grade');
    return b.toString();
  }

  late final String searchKey = Arabic.searchKey(text);
}

class HisnChapter {
  final int number;
  final String title, topic;
  final String? link;
  final List<String> urls, sources;
  late final List<HisnDhikr> items;
  HisnChapter(this.number, this.title, this.topic, this.link, this.urls, this.sources);

  /// «١٢. دعاء الذهاب إلى المسجد»; «فضل الذكر» has no number in the book.
  String get heading => number == 0 ? title : '${Arabic.digits(number)}. $title';
  late final String searchKey = Arabic.searchKey(title);
}

class HisnTopic {
  final String id, title, emoji;
  const HisnTopic(this.id, this.title, this.emoji);
}

class Hisn {
  static String bookSource = '';
  static List<HisnTopic> topics = const [];
  static List<HisnChapter> chapters = const [];

  static Future<void> load() async {
    if (chapters.isNotEmpty) return;
    parse(await rootBundle.loadString('assets/data/hisn.json'));
  }

  static void parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    bookSource = j['source'] as String;
    topics = [for (final t in j['topics'] as List) HisnTopic(t['id'], t['title'], t['emoji'])];
    chapters = [
      for (final c in j['chapters'] as List)
        () {
          final ch = HisnChapter(c['n'], c['title'], c['topic'], c['link'], [for (final u in c['url'] as List) u as String],
              [for (final s in (c['sources'] as List?) ?? const []) s as String]);
          ch.items = [
            for (final d in (c['items'] as List?) ?? const [])
              HisnDhikr(
                ch,
                d['n'],
                d['text'],
                d['count'] ?? 1,
                d['virtue'] ?? '',
                d['takhrij'] ?? '',
                d['grade'] ?? '',
                [
                  for (final p in (d['parts'] as List?) ?? const [])
                    p['q'] == null
                        ? HisnPart(p['t'], null, false)
                        : HisnPart(p['src'], (p['q'][0] as int, p['q'][1] as int, p['q'][2] as int), p['part'] == true),
                ],
                [for (final r in (d['refs'] as List?) ?? const []) HisnRef(r['col'], r['n'], r['key'])],
              ),
          ];
          return ch;
        }(),
    ];
  }

  static HisnChapter? byNumber(int n) => chapters.where((c) => c.number == n).firstOrNull;

  /// Chapters whose title has every word of [q], then chapters with a dhikr that has them.
  static List<(HisnChapter, HisnDhikr?)> search(String q) {
    final words = Arabic.searchKey(q).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final out = <(HisnChapter, HisnDhikr?)>[
      for (final c in chapters)
        if (words.every(c.searchKey.contains)) (c, null),
    ];
    for (final c in chapters) {
      for (final d in c.items) {
        if (words.every(d.searchKey.contains)) out.add((c, d));
      }
    }
    return out;
  }
}
