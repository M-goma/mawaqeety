import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/arabic.dart';
import '../main.dart';
import 'theme.dart';

/// Zakat on money, gold, silver and trade goods (2.5% once the nisab is reached and a Hijri year has passed).
class ZakatPage extends StatefulWidget {
  const ZakatPage({super.key});
  @override
  State<ZakatPage> createState() => _ZakatPageState();
}

class _ZakatPageState extends State<ZakatPage> {
  static const goldNisab = 85.0, silverNisab = 595.0;
  final _c = {for (final k in ['cash', 'owed', 'trade', 'g24', 'g21', 'g18', 'silver', 'debts']) k: TextEditingController()};
  late final _gold = TextEditingController(text: _fmtIn(app.settings.goldPrice));
  late final _silverP = TextEditingController(text: _fmtIn(app.settings.silverPrice));

  static String _fmtIn(double v) => v > 0 ? (v == v.roundToDouble() ? v.toInt().toString() : v.toString()) : '';

  double _v(TextEditingController c) => double.tryParse(Arabic.latinDigits(c.text).replaceAll(',', '').replaceAll('٫', '.').trim()) ?? 0;

  @override
  void dispose() {
    for (final c in [..._c.values, _gold, _silverP]) {
      c.dispose();
    }
    super.dispose();
  }

  String _money(double v) => Arabic.digits(NumberFormat('#,##0.##', 'en').format(v));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gp = _v(_gold), sp = _v(_silverP);
    final pureGold = _v(_c['g24']!) + _v(_c['g21']!) * 21 / 24 + _v(_c['g18']!) * 18 / 24;
    final total = _v(_c['cash']!) + _v(_c['owed']!) + _v(_c['trade']!) + pureGold * gp + _v(_c['silver']!) * sp - _v(_c['debts']!);
    final bySilver = app.settings.nisabSilver;
    final nisab = bySilver ? silverNisab * sp : goldNisab * gp;
    final ready = nisab > 0;
    final due = ready && total >= nisab;

    Widget field(String key, String label, {String? hint}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: TextField(
            controller: _c[key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: label, hintText: hint, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
        );
    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(t, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة الزكاة')),
      body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.all(18),
          decoration: hero3D(radius: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(!ready ? 'أدخل سعر جرام ${bySilver ? 'الفضة' : 'الذهب عيار ٢٤'} أولًا' : due ? 'الزكاة الواجبة' : 'لم يبلغ مالك النصاب',
                style: TextStyle(color: AppColors.heroText, fontSize: 14)),
            Text(due ? _money(total * 0.025) : '—', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
            if (ready)
              Text('مالك الزكوي: ${_money(total < 0 ? 0 : total)} • النصاب: ${_money(nisab)}',
                  style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
          ]),
        ),
        section('الأسعار اليوم (لكل جرام)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _gold,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) { setState(() {}); app.update((x) => x.goldPrice = _v(_gold), reschedule: false); },
                decoration: InputDecoration(labelText: 'الذهب عيار ٢٤', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _silverP,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) { setState(() {}); app.update((x) => x.silverPrice = _v(_silverP), reschedule: false); },
                decoration: InputDecoration(labelText: 'الفضة الخالصة', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('النصاب بالذهب (٨٥ جرامًا)')),
              ButtonSegment(value: true, label: Text('بالفضة (٥٩٥ جرامًا)')),
            ],
            selected: {bySilver},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => app.update((x) => x.nisabSilver = v.first, reschedule: false)),
          ),
        ),
        section('أموالك التي حال عليها الحول'),
        field('cash', 'النقود (في اليد والبنك والمدخرات)'),
        field('owed', 'ديون لك يُرجى سدادها'),
        field('trade', 'قيمة عروض التجارة (البضاعة المعدّة للبيع)'),
        section('الذهب والفضة (بالجرام)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Expanded(child: field('g24', 'عيار ٢٤')),
            Expanded(child: field('g21', 'عيار ٢١')),
            Expanded(child: field('g18', 'عيار ١٨')),
          ]),
        ),
        field('silver', 'الفضة'),
        section('يُخصم'),
        field('debts', 'ديون عليك حالّة (مستحقة الآن)'),
        Card3D(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('كيف تُحسب؟', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '• تجب الزكاة إذا بلغ المال النصاب وحال عليه حول هجري كامل.\n'
                '• مقدارها ربع العشر (٢٫٥٪) من مجموع المال الزكوي.\n'
                '• يُحوَّل الذهب إلى ما يعادله من عيار ٢٤ ثم يُقوَّم بسعر اليوم.\n'
                '• «ليس فيما دون خمس أواقٍ صدقة» — صحيح البخاري ١٤٠٥، صحيح مسلم ٩٧٩.',
                style: TextStyle(height: 1.8, fontSize: 13, color: theme.textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 6),
              Text('حساب تقريبي للإعانة. وفي ذهب الزينة المستعمل خلاف بين العلماء، وفي الحالات الخاصة اسأل أهل العلم أو دار الإفتاء.',
                  style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.6)),
            ]),
          ),
        ),
      ]),
    );
  }
}
