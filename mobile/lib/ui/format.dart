import 'package:intl/intl.dart' show DateFormat;

import '../core/arabic.dart';

String fmtTime(DateTime t, bool h24) {
  if (h24) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
}

String fmtCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

String fmtGregorian(DateTime d) => DateFormat('EEEE، d MMMM y', 'ar').format(d);

String ayahNumber(int n) => '\uFD3F${Arabic.digits(n)}\uFD3E';
