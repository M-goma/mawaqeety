import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Occasion duas from Hisn al-Muslim (assets/data/duas.json, built by tools/build_duas.py).
class Dua {
  final String text, virtue, source;
  final int count;
  const Dua(this.text, this.count, this.virtue, this.source);
}

class DuaSection {
  final String title;
  final List<Dua> items;
  final List<String> sources; // when the book's footnotes don't match item by item
  const DuaSection(this.title, this.items, this.sources);
}

class DuaGroup {
  final String id, title, emoji;
  final List<DuaSection> sections;
  const DuaGroup(this.id, this.title, this.emoji, this.sections);
  int get count => sections.fold(0, (a, s) => a + s.items.length);
}

class Duas {
  static String bookSource = '';
  static List<DuaGroup> groups = const [];

  static Future<void> load() async {
    if (groups.isNotEmpty) return;
    final j = jsonDecode(await rootBundle.loadString('assets/data/duas.json')) as Map<String, dynamic>;
    bookSource = j['source'] as String;
    groups = [
      for (final g in j['groups'] as List)
        DuaGroup(g['id'], g['title'], g['emoji'], [
          for (final s in g['sections'] as List)
            DuaSection(
              s['title'],
              [for (final d in s['items'] as List) Dua(d['text'], d['count'] ?? 1, d['virtue'] ?? '', d['source'] ?? '')],
              [for (final x in (s['sources'] as List?) ?? const []) x as String],
            ),
        ]),
    ];
  }

  static DuaGroup? byId(String id) => groups.where((g) => g.id == id).firstOrNull;
}
