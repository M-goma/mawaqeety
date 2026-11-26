import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/arabic.dart';
import 'media_controls.dart';

/// Reads the prophets' stories aloud with the device's Arabic text-to-speech voice.
class Narration extends ChangeNotifier implements MediaSource {
  final _tts = FlutterTts();
  final _player = AudioPlayer();
  bool speaking = false;
  int _session = 0;

  /// Studio recordings of the stories: gender -> story id -> number of parts.
  Map<String, Map<String, int>> _recorded = {};
  String _base = '';
  static const recordedNames = {'male': 'نبيل', 'female': 'عرين'};

  Future<void> loadRecordings() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/story_audio.json')) as Map<String, dynamic>;
      _base = j['base'] as String;
      _recorded = {
        for (final g in ['male', 'female'])
          g: ((j[g] ?? {}) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
      };
    } catch (e) {
      debugPrint('story audio manifest: $e');
    }
    _player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && speaking) {
        speaking = false;
        notifyListeners();
        MediaControls.instance?.hide(this);
        _finished();
      } else {
        _publish();
      }
    });
    _player.currentIndexStream.listen((_) => _publish());
    _player.positionDiscontinuityStream.listen((_) => _publish());
  }

  Future<void> _saveCopies(List<(Uri, File)> files) async {
    final client = http.Client();
    try {
      for (final (uri, file) in files) {
        try {
          final r = await client.get(uri).timeout(const Duration(minutes: 3));
          if (r.statusCode == 200 && r.bodyBytes.length > 10000) {
            final tmp = File('${file.path}.part');
            await tmp.writeAsBytes(r.bodyBytes, flush: true);
            await tmp.rename(file.path);
          }
        } catch (e) {
          debugPrint('story cache failed: $e');
        }
      }
    } finally {
      client.close();
    }
  }

  /// True when the story has a studio recording in this voice.
  bool hasRecording(String storyId, String gender) => (_recorded[gender]?[storyId] ?? 0) > 0;

  /// Plays the studio recording; each part is saved on the device the first time, so it then works offline.
  /// Story order (ids), used by the notification's previous/next buttons.
  List<String> storyOrder = [];
  String? _storyId;
  String _storyTitle = '';
  String _gender = 'male';
  int _parts = 0;

  Future<void> playRecorded(String storyId, String gender, {String title = ''}) async {
    await stop();
    _storyId = storyId;
    _storyTitle = title;
    _gender = gender;
    _parts = _recorded[gender]?[storyId] ?? 0;
    final session = ++_session;
    error = null;
    final parts = _recorded[gender]?[storyId] ?? 0;
    try {
      final dir = kIsWeb ? null : Directory('${(await getApplicationSupportDirectory()).path}/stories');
      if (dir != null) await dir.create(recursive: true);
      final sources = <AudioSource>[];
      final missing = <(Uri, File)>[];
      for (var i = 1; i <= parts; i++) {
        final name = '$gender-$storyId-$i.mp3';
        final uri = Uri.parse('$_base$name');
        if (dir == null) {
          sources.add(AudioSource.uri(uri));
          continue;
        }
        final file = File('${dir.path}/$name');
        if (await file.exists() && await file.length() > 10000) {
          sources.add(AudioSource.file(file.path));
        } else {
          sources.add(AudioSource.uri(uri));
          missing.add((uri, file));
        }
      }
      // Save a copy in the background so the story plays offline next time.
      if (missing.isNotEmpty) unawaited(_saveCopies(missing));
      if (session != _session) return;
      await _player.setAudioSources(sources);
      speaking = true;
      notifyListeners();
      await _player.play();
    } catch (e) {
      debugPrint('recorded story failed: $e');
      error = 'تعذّر تشغيل القصة. تأكد من الاتصال بالإنترنت عند الاستماع إليها أول مرة.';
      speaking = false;
      notifyListeners();
    }
  }
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
      if (session == _session) {
        speaking = false;
        notifyListeners();
        _finished();
        return;
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

  // ---------------- auto-play of the next story ----------------
  /// Called when a story ends by itself (not when the user stops it).
  void Function()? onFinished;
  /// Called when the countdown ends, with the id of the story to play next.
  void Function(String storyId)? onAdvance;
  String? pendingNext;
  int secondsLeft = 0;
  Timer? _nextTimer;

  void _finished() => onFinished?.call();

  /// Shows "next story in 5 seconds" and then asks the page to move on.
  void scheduleNext(String storyId, {int seconds = 5}) {
    cancelNext(notify: false);
    pendingNext = storyId;
    secondsLeft = seconds;
    notifyListeners();
    _nextTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        t.cancel();
        final id = pendingNext;
        pendingNext = null;
        notifyListeners();
        if (id != null) onAdvance?.call(id);
      } else {
        notifyListeners();
      }
    });
  }

  void cancelNext({bool notify = true}) {
    _nextTimer?.cancel();
    _nextTimer = null;
    if (pendingNext != null) {
      pendingNext = null;
      if (notify) notifyListeners();
    }
  }

  @override
  Future<void> stop() async {
    cancelNext();
    _session++;
    await _tts.stop();
    await _player.stop();
    _storyId = null;
    MediaControls.instance?.hide(this);
    if (speaking) {
      speaking = false;
      notifyListeners();
    }
  }

  // ---------------- notification / lock screen (recorded stories) ----------------
  void _publish() {
    final mc = MediaControls.instance;
    final id = _storyId;
    if (mc == null || id == null || !speaking) return;
    final part = (_player.currentIndex ?? 0) + 1;
    final ps = _player.processingState;
    final honor = id == 'muhammad' ? 'ﷺ' : 'عليه السلام';
    mc.show(this,
        id: 'story-$id-$_gender-$part',
        title: _storyTitle.isEmpty ? 'قصص الأنبياء' : 'قصة $_storyTitle $honor',
        subtitle: 'بصوت ${recordedNames[_gender] ?? ''}${_parts > 1 ? ' • الجزء ${Arabic.digits(part)} من ${Arabic.digits(_parts)}' : ''}',
        album: 'قصص الأنبياء',
        playing: _player.playing,
        loading: ps == ProcessingState.loading || ps == ProcessingState.buffering,
        position: _player.position,
        duration: _player.duration,
        story: true);
  }

  /// Moves to the neighbouring story (delta = +1 next, -1 previous).
  void _jump(int delta) {
    final i = storyOrder.indexOf(_storyId ?? '');
    final j = i + delta;
    if (i < 0 || j < 0 || j >= storyOrder.length) return;
    cancelNext(notify: false);
    onAdvance?.call(storyOrder[j]);
  }

  bool get paused => speaking && !_player.playing;

  @override
  Future<void> resume() => _player.play();
  @override
  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }
  @override
  Future<void> next() async => _jump(1);
  @override
  Future<void> previous() async => _jump(-1);
  @override
  Future<void> seekTo(Duration position) => _player.seek(position);
  @override
  Future<void> rewind15() => _player.seek(_player.position - const Duration(seconds: 15) < Duration.zero
      ? Duration.zero
      : _player.position - const Duration(seconds: 15));
  @override
  Future<void> forward15() => _player.seek(_player.position + const Duration(seconds: 15));
}
