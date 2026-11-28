import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../data/fiqh.dart';
import 'theme.dart';

/// فقه العبادات المختصر — short Q&A quoted from fatwas of إسلام ويب، دار الإفتاء المصرية، الأزهر.
class FiqhPage extends StatefulWidget {
  const FiqhPage({super.key});
  @override
  State<FiqhPage> createState() => _FiqhPageState();
}

class _FiqhPageState extends State<FiqhPage> {
  final _future = FiqhData.load();
  final _ctrl = TextEditingController();
  String? _topic;
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فقه العبادات المختصر')),
      body: FutureBuilder<FiqhData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) {
            return Center(child: snap.hasError ? const Text('تعذّر تحميل البيانات') : const CircularProgressIndicator());
          }
          final list = d.filter(topic: _topic, query: _query);
          final hint = Theme.of(context).hintColor;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) return _header(d);
              if (i == list.length + 1) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    list.isEmpty
                        ? 'لا توجد مسألة مطابقة، جرّب كلمة أخرى.'
                        : 'جُمعت في ${Arabic.digits(d.collected.replaceAll('-', '/'))} من: ${d.sources.map((s) => s.name).join('، ')}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: hint),
                  ),
                );
              }
              return _FiqhCard(item: list[i - 1]);
            },
          );
        },
      ),
    );
  }

  Widget _header(FiqhData d) {
    Widget chip(String label, String? topic) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: ChoiceChip(
            label: Text(label),
            selected: _topic == topic,
            onSelected: (_) => setState(() => _topic = topic),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: hero3D(radius: 20),
        child: Column(children: [
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 6),
          Text('${Arabic.digits(d.items.length)} مسألة في الطهارة والصلاة والصيام والزكاة والحج',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(d.note, textAlign: TextAlign.center, style: TextStyle(color: AppColors.heroText, fontSize: 13.5, height: 1.7)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'ابحث: التيمم، القصر، زكاة الذهب…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _ctrl.clear();
                      _query = '';
                    }),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            isDense: true,
          ),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [chip('الكل', null), for (final t in d.topics) chip(t, t)]),
      ),
      const SizedBox(height: 4),
    ]);
  }
}

Color _sourceColor(String source) => switch (source) {
      'إسلام ويب' => AppColors.emerald,
      'دار الإفتاء المصرية' => AppColors.gold,
      _ => const Color(0xFF4A86C8),
    };

class _FiqhCard extends StatelessWidget {
  final FiqhItem item;
  const _FiqhCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Card3D(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${item.topic} • ${item.sub}', style: TextStyle(fontSize: 12, color: hint)),
          const SizedBox(height: 2),
          Text(item.question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.6)),
          if (item.khilaf)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Text('في المسألة خلاف', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w700)),
              ),
            ),
          for (final a in item.answers) _AnswerView(a),
        ]),
      ),
    );
  }
}

class _AnswerView extends StatelessWidget {
  final FiqhAnswer a;
  const _AnswerView(this.a);

  @override
  Widget build(BuildContext context) {
    final c = _sourceColor(a.source);
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 10),
        decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: c.withValues(alpha: 0.6), width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
              child: Text(a.source, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          Text('«${a.text}»', style: const TextStyle(fontSize: 15, height: 1.85)),
          const SizedBox(height: 4),
          Text(Arabic.digits(a.ref), style: TextStyle(fontSize: 11.5, color: hint, height: 1.5)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: c, visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('اقرأ الفتوى كاملة'),
              onPressed: () => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication),
            ),
          ),
        ]),
      ),
    );
  }
}
