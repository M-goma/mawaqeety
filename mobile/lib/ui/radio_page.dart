import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../main.dart';
import '../services/radio.dart';
import 'theme.dart';

/// Glossy gold 3D play / stop button.
class GoldBall extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;
  const GoldBall({super.key, required this.icon, required this.onTap, this.size = 92, this.busy = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: Alignment(-0.3, -0.45), radius: 0.95, stops: [0, 0.35, 0.75, 1],
                colors: [Color(0xFFFFF3B8), Color(0xFFE9C75A), Color(0xFFB8901F), Color(0xFF7A5C0C)]),
            boxShadow: [
              BoxShadow(color: Color(0x99000000), blurRadius: 20, offset: Offset(0, 12)),
              BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 3)),
            ],
          ),
          child: busy
              ? Padding(padding: EdgeInsets.all(size * 0.3), child: const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF3A2A00)))
              : Icon(icon, size: size * 0.45, color: const Color(0xFF3A2A00)),
        ),
      );
}

String _radioStatus(QuranRadio r) {
  if (r.error != null) return r.error!;
  if (r.connecting) return 'جارٍ الاتصال…';
  if (r.playing) return 'بث مباشر';
  return 'اضغط للاستماع';
}

/// Small card in the Quran tab; opens the radio page.
class RadioCard extends StatelessWidget {
  const RadioCard({super.key});
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: app.radio,
      builder: (context, _) {
        final r = app.radio;
        return Card3D(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadioPage())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                const Tile3D(child: Text('📻', style: TextStyle(fontSize: 21))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('${QuranRadio.name} ${QuranRadio.city}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Row(children: [
                      if (r.playing) ...[
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5A5F), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                      ],
                      Flexible(child: Text(_radioStatus(r), style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor))),
                    ]),
                  ]),
                ),
                GoldBall(size: 46, icon: r.on ? Icons.stop_rounded : Icons.play_arrow_rounded, busy: r.connecting, onTap: r.toggle),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class RadioPage extends StatelessWidget {
  const RadioPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.radio,
      builder: (context, _) {
        final r = app.radio;
        final left = r.sleepAt?.difference(DateTime.now()).inMinutes;
        Widget sleepChip(int m, String label) {
          final on = r.sleepMinutes == m;
          return Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: ChoiceChip(
              label: Text(label),
              selected: on,
              onSelected: (_) => r.setSleep(m),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('الإذاعة')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
              decoration: hero3D(radius: 26),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: r.playing ? const Color(0xFFFF5A5F) : Colors.white38, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(r.playing ? 'بث مباشر' : 'غير متصل', style: const TextStyle(color: Color(0xFFFFB3B5), fontSize: 12.5)),
                  ]),
                ),
                const SizedBox(height: 10),
                const Text(QuranRadio.name, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))])),
                Text(QuranRadio.city, style: TextStyle(color: AppColors.heroText, fontSize: 15)),
                const SizedBox(height: 18),
                GoldBall(icon: r.on ? Icons.stop_rounded : Icons.play_arrow_rounded, busy: r.connecting, onTap: r.toggle),
                const SizedBox(height: 14),
                Text(_radioStatus(r), textAlign: TextAlign.center, style: TextStyle(color: AppColors.heroText, fontSize: 13)),
                Text('تعمل في الخلفية وعلى شاشة القفل', style: TextStyle(color: AppColors.heroText.withValues(alpha: 0.75), fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 10),
            Card3D(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('⏲  إيقاف تلقائي', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (r.sleepAt != null)
                      Text('بعد ${Arabic.minutes((left ?? 0) + 1)}', style: TextStyle(color: AppColors.gold, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(children: [
                    sleepChip(15, '١٥ دقيقة'),
                    sleepChip(30, '٣٠ دقيقة'),
                    sleepChip(60, 'ساعة'),
                    sleepChip(0, 'بدون'),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('الإذاعة لا تتوقف عند وصول الإشعارات. إذا انقطع الاتصال تعيد الاتصال وحدها.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ]),
        );
      },
    );
  }
}

