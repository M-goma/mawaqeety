import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../main.dart';
import 'theme.dart';

const tasbeehPhrases = [
  'سُبْحَانَ اللهِ',
  'الْحَمْدُ لِلَّهِ',
  'اللهُ أَكْبَرُ',
  'لَا إِلَٰهَ إِلَّا اللهُ',
  'أَسْتَغْفِرُ اللهَ',
  'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
  'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ',
  'سُبْحَانَ اللهِ وَبِحَمْدِهِ',
];

/// After each obligatory prayer: 33 × subhan Allah, 33 × al-hamdu lillah, 34 × Allahu akbar (Muslim).
const _afterPrayer = [(0, 33), (1, 33), (2, 34)];

/// Electronic tasbeeh: tap anywhere to count, with light vibration and a stronger one at the target.
class TasbeehPage extends StatelessWidget {
  const TasbeehPage({super.key});

  List<String> get _phrases => [...tasbeehPhrases, ...app.settings.tasbeehCustom];

  int get _phraseIndex {
    final s = app.settings;
    if (s.tasbeehTarget == -1) return _afterPrayer[s.tasbeehStep.clamp(0, 2)].$1;
    return s.tasbeehPhrase.clamp(0, _phrases.length - 1);
  }

  int get _target {
    final s = app.settings;
    if (s.tasbeehTarget == -1) return _afterPrayer[s.tasbeehStep.clamp(0, 2)].$2;
    return s.tasbeehTarget;
  }

  void _tap() {
    final s = app.settings;
    final target = _target;
    final next = s.tasbeehCount + 1;
    app.tracker.addTasbeeh(app.today);
    if (target > 0 && next >= target) {
      HapticFeedback.heavyImpact();
      app.update((x) {
        x.tasbeehCount = 0;
        if (x.tasbeehTarget == -1) x.tasbeehStep = (x.tasbeehStep + 1) % 3;
      }, reschedule: false);
    } else {
      HapticFeedback.lightImpact();
      app.update((x) => x.tasbeehCount = next, reschedule: false);
    }
  }

  void _reset() => app.update((x) {
        x.tasbeehCount = 0;
        x.tasbeehStep = 0;
      }, reschedule: false);

  Future<void> _addPhrase(BuildContext context) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('ذكر خاص'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'اكتب الذكر')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    app.update((x) {
      x.tasbeehCustom = [...x.tasbeehCustom, text];
      x.tasbeehPhrase = tasbeehPhrases.length + x.tasbeehCustom.length - 1;
      if (x.tasbeehTarget == -1) x.tasbeehTarget = 33;
      x.tasbeehCount = 0;
    }, reschedule: false);
  }

  Future<void> _editWird(BuildContext context) async {
    final c = TextEditingController(text: '${app.settings.wirdGoal}');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('وردك اليومي من التسبيح'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'مثلًا ٥٠٠ (اكتب ٠ لإلغائه)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, int.tryParse(Arabic.latinDigits(c.text.trim()))), child: const Text('حفظ')),
        ],
      ),
    );
    if (v != null && v >= 0) app.update((x) => x.wirdGoal = v, reschedule: false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.tracker]),
      builder: (context, _) {
        final s = app.settings;
        final phrases = _phrases;
        final target = _target;
        final count = s.tasbeehCount;
        final today = app.tracker.day(app.today).tasbeeh;
        final first = DateTime(app.today.year, app.today.month, 1);
        final month = app.tracker.tasbeehBetween(first, app.today);
        final goal = s.wirdGoal;
        Widget chip(String label, bool on, VoidCallback onTap, {VoidCallback? onLong}) => Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: GestureDetector(
                onLongPress: onLong,
                child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => onTap()),
              ),
            );
        return Scaffold(
          appBar: AppBar(
            title: const Text('السبحة'),
            actions: [
              IconButton(tooltip: 'تصفير العدّاد', icon: const Icon(Icons.restart_alt), onPressed: _reset),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
              Wrap(children: [
                for (var i = 0; i < phrases.length; i++)
                  chip(phrases[i], s.tasbeehTarget != -1 && _phraseIndex == i, () {
                    app.update((x) {
                      x.tasbeehPhrase = i;
                      x.tasbeehCount = 0;
                      if (x.tasbeehTarget == -1) x.tasbeehTarget = 33;
                    }, reschedule: false);
                  }, onLong: i < tasbeehPhrases.length
                      ? null
                      : () => app.update((x) {
                            x.tasbeehCustom = [...x.tasbeehCustom]..removeAt(i - tasbeehPhrases.length);
                            x.tasbeehPhrase = 0;
                          }, reschedule: false)),
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 6),
                  child: ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('ذكر خاص'), onPressed: () => _addPhrase(context)),
                ),
              ]),
              const SizedBox(height: 4),
              Wrap(children: [
                for (final (t, label) in const [(33, '٣٣'), (100, '١٠٠'), (0, 'حر'), (-1, 'بعد الصلاة ٣٣+٣٣+٣٤')])
                  chip(label, s.tasbeehTarget == t, () => app.update((x) {
                        x.tasbeehTarget = t;
                        x.tasbeehCount = 0;
                        x.tasbeehStep = 0;
                      }, reschedule: false)),
              ]),
              const SizedBox(height: 14),
              Center(
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: CustomPaint(
                    painter: _RingPainter(target > 0 ? count / target : (count % 100) / 100, AppColors.gold, AppColors.navy3),
                    child: Center(
                      child: Container(
                        width: 222,
                        height: 222,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(AppColors.emerald, Colors.white, 0.15)!, AppColors.emerald, heroGradient.colors.last]),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8))],
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(Arabic.digits(count), style: const TextStyle(color: Colors.white, fontSize: 68, fontWeight: FontWeight.w700, height: 1.1)),
                          Text(target > 0 ? 'من ${Arabic.digits(target)}' : 'عدّ حر', style: TextStyle(color: AppColors.heroText)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(phrases[_phraseIndex], textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 30, height: 1.8)),
              if (s.tasbeehTarget == -1)
                Text('الخطوة ${Arabic.digits(s.tasbeehStep + 1)} من ٣ • تسبيح ما بعد الصلاة', textAlign: TextAlign.center, style: TextStyle(color: AppColors.gold)),
              Text('اضغط على الدائرة أو في أي مكان بالشاشة', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
              const SizedBox(height: 14),
              Row(children: [
                _Stat('اليوم', today),
                _Stat('هذا الشهر', month),
                _Stat('مجموعك كله', app.tracker.tasbeehBetween(DateTime(2020), app.today)),
              ]),
              const SizedBox(height: 10),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _editWird(context),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('وردك اليومي', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).hintColor),
                        const Spacer(),
                        Text(goal > 0 ? '${Arabic.digits(today)} / ${Arabic.digits(goal)}' : 'غير محدد',
                            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                      ]),
                      if (goal > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: math.min(1, today / goal), minHeight: 8, color: AppColors.gold),
                        ),
                        if (today >= goal)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('✓ أتممت وردك اليوم، تقبّل الله منك', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: [
              Text(Arabic.digits(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ]),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color, track;
  _RingPainter(this.value, this.color, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
    canvas.drawArc(r, 0, 2 * math.pi, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = 12);
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * value.clamp(0, 1), false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value || o.color != color;
}
