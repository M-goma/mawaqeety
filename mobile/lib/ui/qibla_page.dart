import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../core/qibla.dart';
import '../main.dart';
import 'theme.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});
  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  static const _channel = EventChannel('mawaqeety/compass');
  StreamSubscription? _sub;
  double? _heading;
  int _accuracy = 3;
  String? _error;
  bool _aligned = false;

  bool get _hasSensor => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_hasSensor) {
      final p = app.settings.place;
      _sub = _channel.receiveBroadcastStream({'lat': p.lat, 'lng': p.lng}).listen((e) {
        final l = e as List;
        final h = (l[0] as num).toDouble();
        if (!mounted) return;
        setState(() {
          // Smooth small jitters.
          _heading = _heading == null ? h : _smooth(_heading!, h);
          _accuracy = (l[1] as num).toInt();
        });
        _checkAligned();
      }, onError: (_) => setState(() => _error = 'لا يحتوي هذا الهاتف على حسّاس بوصلة.'));
    }
  }

  static double _smooth(double from, double to) {
    var d = ((to - from + 540) % 360) - 180;
    return (from + d * 0.25 + 360) % 360;
  }

  void _checkAligned() {
    final q = Qibla.bearing(app.settings.place.lat, app.settings.place.lng);
    final diff = (((q - _heading!) + 540) % 360 - 180).abs();
    final now = diff <= 3;
    if (now && !_aligned) HapticFeedback.mediumImpact();
    _aligned = now;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = app.settings.place;
    final q = Qibla.bearing(p.lat, p.lng);
    final km = Qibla.distanceKm(p.lat, p.lng);
    final heading = _heading ?? 0;
    final turn = (((q - heading) + 540) % 360) - 180; // + = turn right
    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(p.display, textAlign: TextAlign.center, style: TextStyle(color: AppColors.gold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('القبلة على بُعد ${Arabic.digits(q.round())}° من الشمال • المسافة إلى مكة ${Arabic.digits(km.round())} كم',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 20),
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedRotation(
            turns: _hasSensor && _heading != null ? -heading / 360 : 0,
            duration: const Duration(milliseconds: 120),
            child: CustomPaint(painter: _DialPainter(qibla: q, aligned: _aligned, palette: AppColors.current,
                dark: Theme.of(context).brightness == Brightness.dark)),
          ),
        ),
        const SizedBox(height: 20),
        if (!_hasSensor)
          const Text('البوصلة الحية متاحة في تطبيق أندرويد. وجّه الشمال في الرسم نحو الشمال الحقيقي، والسهم يشير إلى القبلة.',
              textAlign: TextAlign.center)
        else if (_error != null)
          Text(_error!, textAlign: TextAlign.center)
        else if (_heading == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _aligned ? AppColors.emerald.withValues(alpha: 0.18) : AppColors.goldSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _aligned
                  ? 'أنت تتجه إلى القبلة ✓'
                  : turn > 0
                      ? 'استدر يمينًا ${Arabic.digits(turn.round())}°'
                      : 'استدر يسارًا ${Arabic.digits((-turn).round())}°',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _aligned ? AppColors.emerald : null),
            ),
          ),
          if (_accuracy < 2)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('دقة البوصلة منخفضة: حرّك الهاتف على شكل الرقم 8 عدة مرات، وابتعد عن المعادن والأجهزة الكهربائية.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
            ),
        ],
        const SizedBox(height: 16),
        const Text('ضع الهاتف أفقيًا على سطح مستوٍ للحصول على أدق اتجاه.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double qibla;
  final bool aligned, dark;
  final Palette palette;
  _DialPainter({required this.qibla, required this.aligned, required this.palette, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final ring = Paint()
      ..color = dark ? palette.surface : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r, Paint()..color = palette.accent.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 2);
    final tick = Paint()..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.5);
    for (var d = 0; d < 360; d += 10) {
      final a = (d - 90) * math.pi / 180;
      final len = d % 90 == 0 ? 16.0 : (d % 30 == 0 ? 10.0 : 5.0);
      tick.strokeWidth = d % 90 == 0 ? 3 : 1.4;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r - 2), c + Offset(math.cos(a), math.sin(a)) * (r - 2 - len), tick);
    }
    const labels = {0: 'ش', 90: 'شرق', 180: 'ج', 270: 'غرب'};
    labels.forEach((d, t) {
      final a = (d - 90) * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontFamily: 'Cairo', fontSize: d == 0 ? 20 : 14, fontWeight: FontWeight.w700,
            color: d == 0 ? Colors.redAccent : (dark ? Colors.white70 : Colors.black54))),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, c + Offset(math.cos(a), math.sin(a)) * (r - 38) - Offset(tp.width / 2, tp.height / 2));
    });
    // Qibla needle.
    final qa = (qibla - 90) * math.pi / 180;
    final dir = Offset(math.cos(qa), math.sin(qa));
    final color = aligned ? palette.primary : palette.accent;
    canvas.drawLine(c, c + dir * (r - 60), Paint()..color = color..strokeWidth = 6..strokeCap = StrokeCap.round);
    // Kaaba marker.
    final k = c + dir * (r - 60);
    final rect = Rect.fromCenter(center: k, width: 30, height: 30);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = Colors.black);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top + 7, rect.width, 4), Paint()..color = const Color(0xFFD4AF37));
    canvas.drawCircle(c, 9, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DialPainter o) => o.qibla != qibla || o.aligned != aligned || o.palette != palette || o.dark != dark;
}
