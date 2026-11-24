import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads the prophets' stories aloud with the device's Arabic text-to-speech voice.
class Narration extends ChangeNotifier {
  final _tts = FlutterTts();
  bool speaking = false;
  int _session = 0;
  String? error;

  /// True when a real voice of the requested gender was found (otherwise the pitch is adjusted).
  bool exactVoice = true;

  static const _femaleHints = ['female', 'hoda', 'salma', 'laila', 'layla', 'zariyah', 'amina', 'fatima', 'hala', 'mariam', 'sana', 'muna'];
  static const _maleHints = ['male', 'naayf', 'hamed', 'majed', 'maged', 'tarik', 'shakir', 'omar', 'hamdan'];

  String? _genderOf(Map v) {
    final g = '${v['gender'] ?? ''}'.toLowerCase();
    if (g.contains('female')) return 'female';
    if (g.contains('male')) return 'male';
    final name = '${v['name'] ?? ''}'.toLowerCase();
    if (_femaleHints.any((h) => name.contains(h))) return 'female';
    if (_maleHints.any((h) => name.contains(h))) return 'male';
    return null;
  }

  /// Picks an Arabic voice of the requested gender; if the device has none, keeps the default
  /// Arabic voice and shifts its pitch so the two choices still sound clearly different.
  Future<void> _applyVoice(String gender) async {
    await _tts.setLanguage('ar');
    List voices = [];
    try {
      voices = (await _tts.getVoices as List?) ?? [];
    } catch (_) {}
    final arabic = voices.whereType<Map>().where((v) => '${v['locale'] ?? ''}'.toLowerCase().startsWith('ar')).toList();
    Map? pick;
    for (final v in arabic) {
      if (_genderOf(v) == gender) { pick = v; break; }
    }
    if (pick != null) {
      await _tts.setVoice({'name': '${pick['name']}', 'locale': '${pick['locale']}'});
      await _tts.setPitch(1.0);
      exactVoice = true;
    } else {
      await _tts.setPitch(gender == 'female' ? 1.35 : 0.75);
      exactVoice = false;
    }
  }

  Future<void> speak(List<String> chunks, {String gender = 'male'}) async {
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
      await _applyVoice(gender);
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
