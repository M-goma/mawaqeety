/// Arabic text helpers.
class Arabic {
  static const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static String digits(Object n) => n.toString().split('').map((c) {
        final d = int.tryParse(c);
        return d == null ? c : _digits[d];
      }).join();

  static final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  /// Removes harakat/Quranic marks and unifies letter forms, for search.
  static String normalize(String s) => s
      .replaceAll(_marks, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .toLowerCase()
      .trim();

  /// Search key: like [normalize] but without alefs — the Uthmani script omits many alefs
  /// (ٱلۡعَٰلَمِينَ vs العالمين). Apply to both the query and the text.
  static String searchKey(String s) => normalize(s).replaceAll('ا', '');
}
