import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sahih Muslim numbers in assets/data/hadith_muslim.json.gz are Muhammad Fuad Abdul-Baqi's (tools/build_hadith.py,
/// tools/muslim_numbers.json). Each case: words of a well-known hadith → its number, as islamweb's library edition of
/// Sahih Muslim gives it (www.islamweb.net/ar/library/content/1/<page>, page in the comment). Every row holding the
/// words must carry that number.
void main() {
  final rows = (jsonDecode(utf8.decode(const GZipDecoder()
          .decodeBytes(File('assets/data/hadith_muslim.json.gz').readAsBytesSync()))) as Map<String, dynamic>)['h']
      .cast<List>();
  final diac = RegExp('[ً-ٰٟۖ-ۭـ]');
  String plain(String s) => s
      .replaceAll(diac, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp('[^ء-ي ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final texts = [for (final r in rows) (r[1] as int, plain(r[2] as String))];

  const cases = {
    'انما الاعمال بالنيه': 1907, // 3602
    'اللهم باعد بيني وبين خطاياي': 598, // 1011 (was stored as 1354, the source's running number)
    'من غشنا فليس منا': 101, // 217
    'الدين النصيحه': 55, // 153
    'حتي يحب لاخيه': 45, // 135
    'لا تدخلون الجنه حتي تومنوا': 54, // 152
    'ايكم يحب ان يغدو كل يوم الي بطحان': 803, // 1408
    'اللهم اني اسالك الهدي والتقي': 2721, // 4970
    'من سبح الله في دبر كل صلاه': 597, // 1010
    'سبحان الله وبحمده عدد خلقه': 2726, // 4977
    'اذا انصرف من صلاته استغفر ثلاثا': 591, // 1002
    'بني الاسلام علي خمس': 16, // 90
    'ان الله لا ينظر الي صوركم': 2564, // 4723
    'مثل البيت الذي يذكر الله فيه': 779, // 1371
    'من كذب علي متعمدا فليتبوا مقعده من النار': 3, // 10 (al-Muqaddima; was stored as 4)
    'غزوه تبوك وهو يريد الروم': 2769, // 5045 (Ka'b b. Malik; was stored as 7017)
    'من عذاب جهنم ومن عذاب القبر ومن فتنه المحيا والممات': 588, // 995
  };

  test('well-known hadiths carry their Abdul-Baqi number', () {
    for (final MapEntry(key: words, value: number) in cases.entries) {
      final numbers = {for (final (n, t) in texts) if (t.contains(words)) n};
      expect(numbers, {number}, reason: words);
    }
  });

  test('no number beyond the last hadith (the source\'s running numbers go up to 7563)', () {
    final max = texts.map((t) => t.$1).reduce((a, b) => a > b ? a : b);
    expect(max, lessThanOrEqualTo(3033));
    expect(texts.every((t) => t.$1 >= 1), isTrue);
  });
}
