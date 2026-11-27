import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';
import 'theme.dart';

/// The ten companions promised Paradise: a short life and situations from the two Sahihs.
class Companion {
  final String id, name, title, bio;
  final List<(String, String, String)> situations; // title, text, source
  const Companion(this.id, this.name, this.title, this.bio, this.situations);
}

class CompanionsData {
  final String intro, introSource, note;
  final List<Companion> list;
  const CompanionsData(this.intro, this.introSource, this.note, this.list);

  static CompanionsData? _cache;
  static Future<CompanionsData> load() async {
    if (_cache != null) return _cache!;
    final j = jsonDecode(await rootBundle.loadString('assets/data/companions.json')) as Map<String, dynamic>;
    return _cache = CompanionsData(j['intro'], j['introSource'], j['note'], [
      for (final c in j['companions'] as List)
        Companion(c['id'], c['name'], c['title'], c['bio'], [
          for (final s in c['situations'] as List) (s['title'] as String, s['text'] as String, s['source'] as String),
        ]),
    ]);
  }
}

class CompanionsPage extends StatelessWidget {
  const CompanionsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العشرة المبشرون بالجنة')),
      body: FutureBuilder(
        future: CompanionsData.load(),
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: hero3D(radius: 20),
              child: Column(children: [
                Text(d.intro, textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'AmiriQuran', color: Colors.white, fontSize: 17, height: 1.9)),
                const SizedBox(height: 6),
                Text(d.introSource, textAlign: TextAlign.center, style: TextStyle(color: AppColors.heroText, fontSize: 12)),
              ]),
            ),
            for (final c in d.list)
              Card3D(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Tile3D(size: 44, child: Text(c.name.characters.first == 'ا' ? c.name.characters.elementAt(2) : c.name.characters.first,
                      style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 18))),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
                  subtitle: Text('${c.title} • ${c.situations.length == 2 ? 'موقفان' : '${Arabic.digits(c.situations.length)} مواقف'}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanionPage(c: c, note: d.note))),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class CompanionPage extends StatelessWidget {
  final Companion c;
  final String note;
  const CompanionPage({super.key, required this.c, required this.note});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 6, 0, 24), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(18),
          decoration: hero3D(radius: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c.name} رضي الله عنه', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))])),
            Text(c.title, style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(c.bio, style: TextStyle(color: AppColors.heroText, height: 1.8)),
          ]),
        ),
        for (final (t, text, src) in c.situations)
          Card3D(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(fontSize: 15.5, height: 1.9)),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                    child: Text(src, style: TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(note, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: hint)),
        ),
      ]),
    );
  }
}
