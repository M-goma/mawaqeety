import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../core/prayer_calculator.dart';
import '../data/adhkar.dart';
import '../main.dart';
import 'theme.dart';

class AdhkarPage extends StatefulWidget {
  const AdhkarPage({super.key});
  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage> {
  late bool _morning = _isMorningNow();
  // Remaining counts per list, kept while the app is open (reset each new day).
  final _left = <bool, List<int>>{};
  String _day = '';

  static bool _isMorningNow() {
    try {
      final t = app.day(app.today);
      final now = DateTime.now().toUtc();
      return now.isAfter(t[Prayer.fajr]) && now.isBefore(t[Prayer.asr]);
    } catch (_) {
      return DateTime.now().hour < 15;
    }
  }

  List<Dhikr> get _items => adhkar.where((d) => d.availableAt(_morning)).toList();

  List<int> _counts() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (today != _day) {
      _day = today;
      _left.clear();
    }
    return _left.putIfAbsent(_morning, () => _items.map((d) => d.count).toList());
  }

  void _tap(int i) {
    final c = _counts();
    if (c[i] == 0) return;
    setState(() => c[i]--);
    HapticFeedback.selectionClick();
    if (c[i] == 0) HapticFeedback.mediumImpact();
    // All done: counts toward today's statistics.
    if (c.every((n) => n == 0)) app.tracker.setAdhkar(app.today, morning: _morning);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final counts = _counts();
    final total = items.fold<int>(0, (a, d) => a + d.count);
    final done = total - counts.fold<int>(0, (a, b) => a + b);
    final finished = counts.where((c) => c == 0).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأذكار'),
        actions: [
          IconButton(
            tooltip: 'البدء من جديد',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => setState(() => _left.remove(_morning)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.wb_sunny_outlined), label: Text('أذكار الصباح')),
              ButtonSegment(value: false, icon: Icon(Icons.nights_stay_outlined), label: Text('أذكار المساء')),
            ],
            selected: {_morning},
            onSelectionChanged: (v) => setState(() => _morning = v.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 8,
                    backgroundColor: AppColors.goldSoft, color: AppColors.gold),
              ),
            ),
            const SizedBox(width: 10),
            Text('${Arabic.digits(finished)} / ${Arabic.digits(items.length)}', style: TextStyle(color: AppColors.gold)),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length + (finished == items.length ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == items.length) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('أتممت ${_morning ? 'أذكار الصباح' : 'أذكار المساء'}، تقبّل الله منك 🤍',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: AppColors.emerald, fontWeight: FontWeight.w700)),
                );
              }
              return _DhikrCard(dhikr: items[i], morning: _morning, left: counts[i], onTap: () => _tap(i));
            },
          ),
        ),
      ]),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  final Dhikr dhikr;
  final bool morning;
  final int left;
  final VoidCallback onTap;
  const _DhikrCard({required this.dhikr, required this.morning, required this.left, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final size = app.settings.quranFontSize.clamp(18, 30).toDouble();
    final completed = left == 0;
    final body = <InlineSpan>[];
    final pre = dhikr.textFor(morning);
    if (dhikr.quran.isNotEmpty) {
      if (pre != null) body.add(TextSpan(text: '$pre\n', style: TextStyle(fontSize: size * 0.8)));
      if (dhikr.basmala) {
        body.add(TextSpan(text: 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ\n',
            style: TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: 2)));
      }
      for (final (s, from, to) in dhikr.quran) {
        final verses = app.repo.surahs[s - 1].verses;
        for (var a = from; a <= to; a++) {
          body.add(TextSpan(text: '${verses[a - 1]} ', style: TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: 2.1)));
          body.add(TextSpan(text: '﴿${Arabic.digits(a)}﴾ ',
              style: TextStyle(fontFamily: 'AmiriQuran', fontSize: size * 0.85, color: AppColors.gold)));
        }
      }
    } else {
      body.add(TextSpan(text: pre, style: TextStyle(fontSize: size * 0.85, height: 1.9)));
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: completed ? 0.55 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text.rich(TextSpan(children: body), style: TextStyle(color: onSurface), textAlign: TextAlign.justify),
              if (dhikr.virtue.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(dhikr.virtue, style: TextStyle(fontSize: 13, color: AppColors.emerald)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(dhikr.source, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
                Text(dhikr.count > 1 ? 'التكرار: ${Arabic.digits(dhikr.count)}' : 'مرة واحدة',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(minWidth: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: completed ? AppColors.emerald : AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: completed
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : Text(Arabic.digits(left), textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.gold)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
