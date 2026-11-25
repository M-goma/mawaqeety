/// Browser compass (not available outside the web build).
class WebCompass {
  static Future<String> start() async => 'unsupported';
  static double? get heading => null;
}
