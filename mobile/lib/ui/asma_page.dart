import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/asma.dart';
import '../main.dart';
import 'share_card.dart';
import 'theme.dart';

/// Index of the name of the day (a different one each day).
int asmaOfDay(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000 % asmaAlHusna.length;

class AsmaPage extends StatefulWidget {
  const AsmaPage({super.key});
  @override
  State<AsmaPage> createState() => _AsmaPageState();
}

class _AsmaPageState extends State<AsmaPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = asmaOfDay(app.today);
    final (dn, dm, _) = asmaAlHusna[today];
    final q = Arabic.normalize(_q);
    final list = [
      for (var i = 0; i < asmaAlHusna.length; i++)
        if (q.isEmpty || Arabic.normalize(asmaAlHusna[i].$1).contains(q) || Arabic.normalize(asmaAlHusna[i].$2).contains(q)) i,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('أسماء الله الحسنى')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            padding: const EdgeInsets.all(18),
            decoration: hero3D(radius: 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اسم اليوم', style: TextStyle(color: AppColors.heroText, fontSize: 14)),
              Text(dn, style: const TextStyle(fontFamily: 'AmiriQuran', color: Colors.white, fontSize: 36, height: 1.6)),
              Text(dm, style: TextStyle(color: AppColors.goldLight, fontSize: 14.5, height: 1.6)),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم أو معنى',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [
              for (final i in list)
                Card3D(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => _show(context, i),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(Arabic.digits(i + 1), style: TextStyle(fontSize: 11, color: AppColors.gold)),
                        FittedBox(
                          child: Text(asmaAlHusna[i].$1, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 22, height: 1.7)),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Text(
              '«إن لله تسعةً وتسعين اسمًا، مائةً إلا واحدًا، من أحصاها دخل الجنة» — صحيح البخاري ٢٧٣٦، صحيح مسلم ٢٦٧٧.\n'
              'هذا السرد هو المشهور في جامع الترمذي، وفي تعيين الأسماء فيه خلاف بين العلماء. والأسماء المتقابلة (القابض الباسط، الخافض الرافع، المعز المذل، الضار النافع، المعطي المانع) تُذكر مقترنة. المعاني مختصرة من شروح أهل العلم كما في موقعَي الإسلام سؤال وجواب وابن باز.',
              style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.7),
            ),
          ),
        ),
      ]),
    );
  }

  void _show(BuildContext context, int i) {
    final (n, m, disputed) = asmaAlHusna[i];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(Arabic.digits(i + 1), textAlign: TextAlign.center, style: TextStyle(color: AppColors.gold)),
          Text(n, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 40, height: 1.7)),
          const SizedBox(height: 6),
          Text(m, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.8)),
          if (disputed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('مما اختلف العلماء في عدّه من الأسماء، والمعنى ثابت لله تعالى',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Theme.of(c).hintColor)),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('مشاركة كصورة'),
            onPressed: () => shareAsImage(context, text: n, ref: m, title: 'من أسماء الله الحسنى'),
          ),
        ]),
      ),
    );
  }
}
