import 'dart:js_interop';

@JS('mwqCompass.start')
external JSPromise<JSString> _start();

@JS('mwqCompass.heading')
external JSNumber? get _heading;

/// Browser compass via DeviceOrientation (webkitCompassHeading on iPhone Safari).
class WebCompass {
  static Future<String> start() async {
    try {
      return (await _start().toDart).toDart;
    } catch (_) {
      return 'error';
    }
  }

  static double? get heading {
    final h = _heading?.toDartDouble;
    return (h == null || h < 0) ? null : h;
  }
}
