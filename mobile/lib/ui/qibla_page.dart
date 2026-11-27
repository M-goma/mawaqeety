import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../core/qibla.dart';
import '../main.dart';
import '../services/compass/web_compass.dart';
import 'qibla_map.dart';
import 'theme.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});
  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  bool _mapMode = false;
  static const _channel = EventChannel('mawaqeety/compass');
  StreamSubscription? _sub;
  double? _heading;
  int _accuracy = 3;
  String? _error;
  bool _aligned = false;

  bool get _hasSensor => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool _webStarted = false;
  Timer? _webTimer;
  bool get _live => _hasSensor || _webStarted;

  /// Browser (iPhone Safari / Android Chrome): start the device compass after a tap.
  Future<void> _startWebCompass() async {
    final r = await WebCompass.start();
    if (!mounted) return;
    if (r != 'ok') {
      setState(() => _error = r == 'denied'
          ? 'لم يُسمح باستخدام البوصلة. اسمح بالوصول إلى «الحركة والاتجاه» ثم أعد المحاولة.'
          : 'لا يتوفر حسّاس بوصلة في هذا الجهاز أو المتصفح.');
      return;
    }
    setState(() {
      _webStarted = true;
      _error = null;
    });
    var waited = 0;
    _webTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final h = WebCompass.heading;
      if (!mounted) return;
      if (h == null) {
        waited += 80;
        if (waited > 4000 && _heading == null) {
          _webTimer?.cancel();
          setState(() => _error = 'لا يتوفر حسّاس بوصلة في هذا الجهاز أو المتصفح.');
        }
        return;
      }
      setState(() => _heading = _heading == null ? h : _smooth(_heading!, h));
      _checkAligned();
    });
  }

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
    _webTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = app.settings.place;
    final q = Qibla.bearing(p.lat, p.lng);
    final km = Qibla.distanceKm(p.lat, p.lng);
    final heading = _heading ?? 0;
    final turn = (((q - heading) + 540) % 360) - 180; // + = turn right
    final modes = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('البوصلة'), icon: Icon(Icons.explore_outlined)),
          ButtonSegment(value: true, label: Text('الخريطة'), icon: Icon(Icons.map_outlined)),
        ],
        selected: {_mapMode},
        showSelectedIcon: false,
        onSelectionChanged: (v) => setState(() => _mapMode = v.first),
      ),
    );
    if (_mapMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('اتجاه القبلة')),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(children: [modes, const Expanded(child: QiblaMap())]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        modes,
        Text(p.display, textAlign: TextAlign.center, style: TextStyle(color: AppColors.gold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('القبلة على بُعد ${Arabic.digits(q.round())}° من الشمال • المسافة إلى مكة ${Arabic.digits(km.round())} كم',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 20),
        _Compass3D(
          heading: _live && _heading != null ? heading : 0,
          qibla: q,
          aligned: _aligned,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
        const SizedBox(height: 20),
        if (_error != null && !(kIsWeb && !_webStarted))
          Text(_error!, textAlign: TextAlign.center)
        else if (kIsWeb && !_webStarted)
          Column(children: [
            if (_error != null)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, textAlign: TextAlign.center)),
            FilledButton.icon(
              onPressed: _startWebCompass,
              icon: const Icon(Icons.explore),
              label: Text(_error == null ? 'تشغيل البوصلة' : 'إعادة المحاولة'),
            ),
            const SizedBox(height: 8),
            const Text('على الآيفون سيطلب المتصفح إذن «الحركة والاتجاه»؛ اضغط «سماح».',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ])
        else if (!_live)
          const Text('وجّه الشمال في الرسم نحو الشمال الحقيقي، والسهم يشير إلى القبلة.', textAlign: TextAlign.center)
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


/// A tilted, shaded compass: rotating dial + fixed lubber mark showing where the phone points.
class _Compass3D extends StatelessWidget {
  final double heading, qibla;
  final bool aligned, dark;
  const _Compass3D({required this.heading, required this.qibla, required this.aligned, required this.dark});

  @override
  Widget build(BuildContext context) {
    final p = AppColors.current;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(alignment: Alignment.center, children: [
        // Soft floor shadow gives depth.
        Positioned.fill(
          top: 30,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 40, spreadRadius: -6, offset: const Offset(0, 22)),
            ]),
          ),
        ),
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0011)
            ..rotateX(0.32),
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: Size.infinite, painter: _BezelPainter(p)),
            AnimatedRotation(
              turns: -heading / 360,
              duration: const Duration(milliseconds: 120),
              child: CustomPaint(size: Size.infinite, painter: _FacePainter(qibla: qibla, heading: heading, aligned: aligned, palette: p, dark: dark)),
            ),
            CustomPaint(size: Size.infinite, painter: _GlassPainter(aligned: aligned, palette: p)),
          ]),
        ),
      ]),
    );
  }
}

/// Metallic outer ring (does not rotate).
class _BezelPainter extends CustomPainter {
  final Palette p;
  _BezelPainter(this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()
      ..shader = SweepGradient(colors: [
        p.accentLight, p.accent, Color.lerp(p.accent, Colors.black, 0.55)!, p.accent, p.accentLight,
        Color.lerp(p.accent, Colors.black, 0.45)!, p.accentLight,
      ]).createShader(rect));
    // Inner bevel.
    canvas.drawCircle(c, r - 12, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.25)])
          .createShader(rect));
  }

  @override
  bool shouldRepaint(_BezelPainter o) => o.p != p;
}

/// The rotating dial face with directions, degrees and the Qibla needle.
class _FacePainter extends CustomPainter {
  final double qibla, heading;
  final bool aligned, dark;
  final Palette palette;
  _FacePainter({required this.qibla, required this.heading, required this.aligned, required this.palette, required this.dark});

  Offset _at(Offset c, double deg, double radius) {
    final a = (deg - 90) * math.pi / 180;
    return c + Offset(math.cos(a), math.sin(a)) * radius;
  }

  void _label(Canvas canvas, String text, Offset pos, double deg, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.rtl)..layout();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading * math.pi / 180); // cancel the dial rotation: labels stay upright on screen
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 19;
    final rect = Rect.fromCircle(center: c, radius: r);
    // Face: radial gradient, lighter in the middle.
    final face = dark
        ? [Color.lerp(p.surface2, Colors.white, 0.08)!, p.surface, p.bg]
        : [Colors.white, const Color(0xFFF1F1F1), const Color(0xFFD9D9D9)];
    canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: face, stops: const [0, 0.7, 1]).createShader(rect));

    final ink = dark ? Colors.white : const Color(0xFF1E1E1E);
    // Ticks every 5°, longer every 30°.
    for (var d = 0; d < 360; d += 5) {
      final major = d % 30 == 0, cardinal = d % 90 == 0;
      final len = cardinal ? 18.0 : major ? 12.0 : 6.0;
      canvas.drawLine(_at(c, d.toDouble(), r - 4), _at(c, d.toDouble(), r - 4 - len), Paint()
        ..color = ink.withValues(alpha: cardinal ? 0.95 : major ? 0.7 : 0.35)
        ..strokeWidth = cardinal ? 3 : major ? 2 : 1
        ..strokeCap = StrokeCap.round);
    }
    // Degree numbers.
    for (var d = 30; d < 360; d += 30) {
      if (d % 90 == 0) continue;
      _label(canvas, Arabic.digits(d), _at(c, d.toDouble(), r - 30), d.toDouble(),
          TextStyle(fontFamily: 'Cairo', fontSize: r * 0.075, color: ink.withValues(alpha: 0.6)));
    }
    // Full Arabic cardinal names.
    const names = {0: 'شمال', 90: 'شرق', 180: 'جنوب', 270: 'غرب'};
    names.forEach((d, t) {
      _label(canvas, t, _at(c, d.toDouble(), r - 46), d.toDouble(), TextStyle(
        fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: r * (d == 0 ? 0.13 : 0.11),
        color: d == 0 ? const Color(0xFFE53935) : ink,
        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), offset: const Offset(0, 1.5), blurRadius: 2)],
      ));
    });
    // North triangle on the rim.
    final n = Path()
      ..moveTo(_at(c, 0, r - 2).dx, _at(c, 0, r - 2).dy)
      ..lineTo(_at(c, -4, r - 22).dx, _at(c, -4, r - 22).dy)
      ..lineTo(_at(c, 4, r - 22).dx, _at(c, 4, r - 22).dy)
      ..close();
    canvas.drawPath(n, Paint()..color = const Color(0xFFE53935));

    // Qibla needle: a diamond split into a lit and a shaded half.
    final gold = aligned ? p.primary : p.accent;
    final tip = _at(c, qibla, r * 0.62);
    final tail = _at(c, qibla + 180, r * 0.30);
    final left = _at(c, qibla - 90, r * 0.075);
    final right = _at(c, qibla + 90, r * 0.075);
    canvas.drawPath(Path()..moveTo(tip.dx + 3, tip.dy + 5)..lineTo(left.dx + 3, left.dy + 5)..lineTo(tail.dx + 3, tail.dy + 5)
          ..lineTo(right.dx + 3, right.dy + 5)..close(),
        Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(left.dx, left.dy)..lineTo(c.dx, c.dy)..close(),
        Paint()..color = Color.lerp(gold, Colors.white, 0.35)!);
    canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(right.dx, right.dy)..lineTo(c.dx, c.dy)..close(),
        Paint()..color = Color.lerp(gold, Colors.black, 0.25)!);
    final tailColor = dark ? const Color(0xFF9AA4B2) : const Color(0xFF7A828C);
    canvas.drawPath(Path()..moveTo(tail.dx, tail.dy)..lineTo(left.dx, left.dy)..lineTo(c.dx, c.dy)..close(),
        Paint()..color = Color.lerp(tailColor, Colors.white, 0.3)!);
    canvas.drawPath(Path()..moveTo(tail.dx, tail.dy)..lineTo(right.dx, right.dy)..lineTo(c.dx, c.dy)..close(),
        Paint()..color = tailColor);

    // Kaaba at the end of the needle.
    final k = _at(c, qibla, r * 0.76);
    final s = r * 0.13;
    canvas.save();
    canvas.translate(k.dx, k.dy);
    canvas.rotate(qibla * math.pi / 180);
    final box = Rect.fromCenter(center: Offset.zero, width: s, height: s);
    canvas.drawRRect(RRect.fromRectAndRadius(box.shift(const Offset(2, 3)), const Radius.circular(3)),
        Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF3A3A3A), Color(0xFF050505)]).createShader(box));
    canvas.drawRect(Rect.fromLTWH(box.left, box.top + s * 0.22, s, s * 0.14), Paint()..color = const Color(0xFFD4AF37));
    canvas.restore();

    // Centre cap.
    final capRect = Rect.fromCircle(center: c, radius: r * 0.07);
    canvas.drawCircle(c, r * 0.07, Paint()
      ..shader = RadialGradient(center: const Alignment(-0.4, -0.4),
          colors: [Colors.white, p.accentLight, Color.lerp(p.accent, Colors.black, 0.4)!]).createShader(capRect));
  }

  @override
  bool shouldRepaint(_FacePainter o) => o.qibla != qibla || o.heading != heading || o.aligned != aligned || o.palette != palette || o.dark != dark;
}

/// Glass reflection and the fixed mark at the top (where the phone points).
class _GlassPainter extends CustomPainter {
  final bool aligned;
  final Palette palette;
  _GlassPainter({required this.aligned, required this.palette});
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 19;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final glare = Rect.fromCenter(center: c + Offset(-r * 0.25, -r * 0.45), width: r * 1.5, height: r * 0.9);
    canvas.drawOval(glare, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0)]).createShader(glare));
    canvas.restore();
    // Lubber mark.
    final color = aligned ? palette.primary : Colors.white;
    final top = c.dy - r - 14;
    canvas.drawPath(
        Path()..moveTo(c.dx, top + 22)..lineTo(c.dx - 11, top)..lineTo(c.dx + 11, top)..close(),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GlassPainter o) => o.aligned != aligned || o.palette != palette;
}
