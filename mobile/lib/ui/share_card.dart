import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show Uint8List;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'theme.dart';

/// Draws an ayah, hadith or dhikr on a card in the app's colours and shares it as a picture.
Future<void> shareAsImage(BuildContext context, {required String text, String ref = '', String title = ''}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await renderCard(text: text, ref: ref, title: title);
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'sabeel.png')],
      fileNameOverrides: const ['sabeel.png'],
      text: ref.isEmpty ? text : '$text\n[$ref]',
    ));
  } catch (e) {
    messenger.showSnackBar(const SnackBar(content: Text('تعذّرت المشاركة')));
  }
}

Future<Uint8List> renderCard({required String text, String ref = '', String title = ''}) async {
  const w = 1080.0, h = 1350.0, pad = 96.0;
  final p = AppColors.current;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()
    ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(w, h), [p.hero[0], p.hero[1], p.hero.last], [0, 0.55, 1]));
  // Soft frame.
  final frame = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 40, w - 80, h - 80), const Radius.circular(48));
  c.drawRRect(frame, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = p.accentLight.withValues(alpha: 0.55));

  TextPainter tp(String s, TextStyle st, double maxW) =>
      TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.rtl, textAlign: TextAlign.center)..layout(maxWidth: maxW);

  final head = title.isEmpty ? null : tp(title, TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 40, color: p.accentLight), w - 2 * pad);
  final foot = tp('سبيل – رفيق المسلم', TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 34, color: Colors.white.withValues(alpha: 0.85)), w);
  final refP = ref.isEmpty ? null : tp(ref, TextStyle(fontFamily: 'Cairo', fontSize: 32, color: p.accentLight), w - 2 * pad);

  // The largest font size that fits.
  final top = 120.0 + (head == null ? 0 : head.height + 30);
  final bottom = h - 150 - (refP == null ? 0 : refP.height + 30);
  var size = text.length <= 20 ? 130.0 : text.length <= 60 ? 84.0 : 64.0;
  late TextPainter body;
  while (true) {
    body = tp(text, TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: 1.9, color: Colors.white), w - 2 * pad);
    if (body.height <= bottom - top || size <= 26) break;
    size -= 3;
  }
  head?.paint(c, Offset((w - head.width) / 2, 110));
  final y = top + ((bottom - top) - body.height) / 2;
  body.paint(c, Offset((w - body.width) / 2, y));
  refP?.paint(c, Offset((w - refP.width) / 2, y + body.height + 30));
  foot.paint(c, Offset((w - foot.width) / 2, h - 120));

  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
