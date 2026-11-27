import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../data/duas.dart';
import 'share_card.dart';
import 'theme.dart';

/// Occasion duas: a grid of 3D tiles (sleep, waking up, travel, …).
class DuasPage extends StatelessWidget {
  const DuasPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أدعية المناسبات')),
      body: FutureBuilder(
        future: Duas.load(),
        builder: (context, snap) {
          if (Duas.groups.isEmpty) return const Center(child: CircularProgressIndicator());
          return GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              for (final g in Duas.groups)
                Card3D(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DuaGroupPage(group: g))),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(g.emoji, style: TextStyle(fontSize: 30 * UiScale.icon, shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 4))])),
                        const SizedBox(height: 6),
                        Text(g.title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${Arabic.digits(g.count)} ${g.count == 1 ? 'دعاء' : (g.count <= 10 ? 'أدعية' : 'دعاءً')}',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DuaGroupPage extends StatefulWidget {
  final DuaGroup group;
  const DuaGroupPage({super.key, required this.group});
  @override
  State<DuaGroupPage> createState() => _DuaGroupPageState();
}

class _DuaGroupPageState extends State<DuaGroupPage> {
  final _left = <Dua, int>{};

  void _tap(Dua d) {
    final n = _left[d] ?? d.count;
    if (n == 0) return;
    setState(() => _left[d] = n - 1);
    HapticFeedback.selectionClick();
    if (n - 1 == 0) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final hint = Theme.of(context).hintColor;
    final children = <Widget>[];
    for (final s in g.sections) {
      if (g.sections.length > 1) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
          child: Text(s.title, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15.5)),
        ));
      }
      for (final d in s.items) {
        final left = _left[d] ?? d.count;
        children.add(Card3D(
          child: InkWell(
            onTap: () => _tap(d),
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: d.text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الدعاء')));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Opacity(
                  opacity: left == 0 ? 0.55 : 1,
                  child: Text(d.text, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 19, height: 2)),
                ),
                if (d.virtue.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(d.virtue, style: TextStyle(fontSize: 13, color: AppColors.emerald)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(d.source, style: TextStyle(fontSize: 12, color: hint))),
                  IconButton(
                    tooltip: 'مشاركة كصورة',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.share_outlined, size: 19, color: hint),
                    onPressed: () => shareAsImage(context, text: d.text, ref: d.source, title: g.title),
                  ),
                  if (d.count > 1 || left == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: left == 0 ? AppColors.emerald : AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(left == 0 ? '✓' : Arabic.digits(left),
                          style: TextStyle(fontWeight: FontWeight.w700, color: left == 0 ? Colors.white : AppColors.gold)),
                    ),
                ]),
              ]),
            ),
          ),
        ));
      }
      if (s.sources.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text('المصادر: ${s.sources.join(' • ')}', style: TextStyle(fontSize: 11.5, color: hint)),
        ));
      }
    }
    children.add(Padding(
      padding: const EdgeInsets.all(16),
      child: Text('من كتاب «${Duas.bookSource}»\nاضغط على الدعاء للعدّ، واضغط مطولًا لنسخه.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: hint)),
    ));
    return Scaffold(
      appBar: AppBar(title: Text('${g.emoji} ${g.title}')),
      body: ListView(padding: const EdgeInsets.only(top: 6, bottom: 12), children: children),
    );
  }
}
