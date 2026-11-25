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

  /// Arabic voices installed on the device (name + locale).
  Future<List<Map<String, String>>> arabicVoices() async {
    try {
      final all = (await _tts.getVoices as List?) ?? [];
      final list = all
          .whereType<Map>()
          .where((v) => '${v['locale'] ?? ''}'.toLowerCase().startsWith('ar'))
          .map((v) => {'name': '${v['name']}', 'locale': '${v['locale']}', 'gender': _genderOf(v) ?? ''})
          .toList();
      list.sort((a, b) => a['name']!.compareTo(b['name']!));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Applies the voice for the chosen gender:
  /// 1) the device voice the user picked for that gender, 2) a device voice whose metadata says that gender,
  /// 3) the default Arabic voice. The pitch and speed always come from the per-gender settings, so the
  /// male voice is clearly deeper (a lower pitch) even when the device only has one Arabic voice.
  Future<void> _applyVoice(String gender, {String preferred = '', double? pitch, double? rate}) async {
    await _tts.setLanguage('ar');
    final voices = await arabicVoices();
    Map<String, String>? pick;
    if (preferred.isNotEmpty) {
      for (final v in voices) {
        if (v['name'] == preferred) { pick = v; break; }
      }
    }
    if (pick == null) {
      for (final v in voices) {
        if (v['gender'] == gender) { pick = v; break; }
      }
    }
    exactVoice = pick != null && (pick['gender'] == gender || preferred.isNotEmpty);
    if (pick != null) await _tts.setVoice({'name': pick['name']!, 'locale': pick['locale']!});
    await _tts.setPitch((pitch ?? (gender == 'female' ? 1.1 : 0.62)).clamp(0.5, 2.0));
    await _tts.setSpeechRate(kIsWeb ? 0.9 : (rate ?? 0.45).clamp(0.2, 1.0));
  }

  /// Plays a short sample with explicit tuning (used by the voice settings sheet).
  Future<void> preview(String gender, {required String voice, required double pitch, required double rate}) async {
    await stop();
    final session = ++_session;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _applyVoice(gender, preferred: voice, pitch: pitch, rate: rate);
      speaking = true;
      notifyListeners();
      await _tts.speak('بسم الله الرحمن الرحيم. هذا هو الصوت الذي ستُقرأ به قصص الأنبياء.');
    } catch (_) {}
    if (session == _session) {
      speaking = false;
      notifyListeners();
    }
  }

  Future<void> speak(List<String> chunks, {String gender = 'male', String voice = '', double? pitch, double? rate}) async {
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
      await _applyVoice(gender, preferred: voice, pitch: pitch, rate: rate);
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
