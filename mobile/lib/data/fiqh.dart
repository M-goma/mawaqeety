import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';

/// فقه العبادات المختصر: short questions with excerpts quoted from published fatwas
/// (assets/data/fiqh.json). Nothing here is written by the app; every answer carries its source and URL.
class FiqhAnswer {
  final String source, ref, url, text;
  const FiqhAnswer(this.source, this.ref, this.url, this.text);
  factory FiqhAnswer.fromJson(Map<String, dynamic> j) => FiqhAnswer(j['source'], j['ref'], j['url'], j['text']);
}

class FiqhItem {
  final int id;
  final String topic, sub, question;
  final bool khilaf; // scholars (or the sources) differ on it
  final List<FiqhAnswer> answers;
  late final String _key = Arabic.searchKey('$question $sub ${answers.map((a) => a.text).join(' ')}');
  FiqhItem(this.id, this.topic, this.sub, this.question, this.khilaf, this.answers);

  factory FiqhItem.fromJson(Map<String, dynamic> j) => FiqhItem(j['id'], j['topic'], j['sub'], j['q'], j['khilaf'] == true,
      [for (final a in j['answers'] as List) FiqhAnswer.fromJson(a)]);

  /// Every word of the query must appear in the question, sub-topic or answers (diacritics/alef-insensitive).
  bool matches(String query) {
    final words = Arabic.searchKey(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.every(_key.contains);
  }
}

class FiqhSource {
  final String name, desc, url;
  const FiqhSource(this.name, this.desc, this.url);
}

class FiqhData {
  final String title, collected, note;
  final List<FiqhSource> sources;
  final List<FiqhItem> items;
  FiqhData(this.title, this.collected, this.note, this.sources, this.items);

  /// Topics in their order of first appearance.
  List<String> get topics => {for (final i in items) i.topic}.toList();

  List<FiqhItem> filter({String? topic, String query = ''}) => [
        for (final i in items)
          if ((topic == null || i.topic == topic) && (query.trim().isEmpty || i.matches(query))) i,
      ];

  factory FiqhData.fromJson(Map<String, dynamic> j) => FiqhData(
        j['title'],
        j['collected'],
        j['note'],
        [for (final s in j['sources'] as List) FiqhSource(s['name'], s['desc'], s['url'])],
        [for (final i in j['items'] as List) FiqhItem.fromJson(i)],
      );

  static FiqhData? _cache;
  static Future<FiqhData> load() async =>
      _cache ??= FiqhData.fromJson(jsonDecode(await rootBundle.loadString('assets/data/fiqh.json')) as Map<String, dynamic>);
}
