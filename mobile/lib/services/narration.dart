import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads the prophets' stories aloud with the device's Arabic text-to-speech voice.
class Narration extends ChangeNotifier {
  final _tts = FlutterTts();
  bool speaking = false;
  int _session = 0;
  String? error;

  Future<void> speak(List<String> chunks) async {
    await stop();
    final session = ++_session;
    error = null;
    try {
      await _tts.awaitSpeakCompletion(true);
      final ok = await _tts.isLanguageAvailable('ar');
      if (ok == false) {
        error = 'لا يوجد صوت عربي في الجهاز. ثبّته من إعدادات الهاتف ← اللغة ← تحويل النص إلى كلام.';
        notifyListeners();
        return;
      }
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
      speaking = true;
      notifyListeners();
      for (final c in chunks.where((c) => c.trim().isNotEmpty)) {
        if (session != _session) return;
        await _tts.speak(c);
      }
    } catch (e) {
      debugPrint('tts failed: $e');
      error = 'تعذّر تشغيل القراءة الصوتية على هذا الجهاز.';
    }
    if (session == _session) {
      speaking = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _session++;
    await _tts.stop();
    if (speaking) {
      speaking = false;
      notifyListeners();
    }
  }
}
