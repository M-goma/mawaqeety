/// Arabic text helpers.
class Arabic {
  static const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// «٥ دقائق»، «١٥ دقيقة»، «دقيقتان»، «دقيقة واحدة».
  static String minutes(int n) {
    if (n == 1) return 'دقيقة واحدة';
    if (n == 2) return 'دقيقتان';
    return n >= 3 && n <= 10 ? '${digits(n)} دقائق' : '${digits(n)} دقيقة';
  }

  /// «٥ صفحات»، «٢٠ صفحة».
  static String pages(int n) {
    if (n == 1) return 'صفحة واحدة';
    if (n == 2) return 'صفحتان';
    return n >= 3 && n <= 10 ? '${digits(n)} صفحات' : '${digits(n)} صفحة';
  }

  static String digits(Object n) => n.toString().split('').map((c) {
        final d = int.tryParse(c);
        return d == null ? c : _digits[d];
      }).join();

  /// Arabic-Indic digits → Latin digits (for parsing numbers typed with an Arabic keyboard).
  static String latinDigits(String s) => s.split('').map((c) {
        final i = _digits.indexOf(c);
        return i < 0 ? c : '$i';
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
