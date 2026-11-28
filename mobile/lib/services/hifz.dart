import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/hifz.dart';
import 'quran_downloads.dart';
import 'recitation.dart';

/// The memorization helper's saved state: progress and the last choices (range, repetitions, reciter).
class HifzStore extends ChangeNotifier {
  static const _key = 'hifz.v1';
  static const eachChoices = [1, 3, 5, 7, 10];
  static const roundChoices = [1, 2, 3, 5];
  SharedPreferences? _prefs;
  final progress = HifzProgress();
  HifzRange? lastRange;
  int each = 3, rounds = 1;
  String reciter = ''; // empty = the app's reciter
  bool firstLetters = false; // self-test: show the first letter of each word instead of hiding all

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(_key);
      if (raw != null) importJson(jsonDecode(raw) as Map<String, dynamic>, save: false);
    } catch (e) {
      debugPrint('hifz load failed: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs?.setString(_key, jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => {
        'p': progress.toJson(),
        if (lastRange != null) 'r': lastRange!.toJson(),
        'n': each,
        'm': rounds,
        if (reciter.isNotEmpty) 'q': reciter,
        if (firstLetters) 'fl': 1,
      };

  /// Restores saved (or backed-up) data.
  Future<void> importJson(Map<String, dynamic> j, {bool save = true}) async {
    progress.loadJson(((j['p'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>());
    lastRange = HifzRange.fromJson(j['r']);
    each = eachChoices.contains(j['n']) ? j['n'] : 3;
    rounds = roundChoices.contains(j['m']) ? j['m'] : 1;
    reciter = j['q'] is String ? j['q'] : '';
    firstLetters = j['fl'] == 1;
    if (save) await _save();
  }

  Future<void> change(void Function(HifzStore s) f) async {
    f(this);
    await _save();
  }

  Future<void> mastered(int surah, int ayah, DateTime today) => change((s) => s.progress.mastered(surah, ayah, today));
  Future<void> needsReview(int surah, int ayah, DateTime today) => change((s) => s.progress.needsReview(surah, ayah, today));
  Future<void> forget(int surah, int ayah) => change((s) => s.progress.forget(surah, ayah));
}

/// Repeats each ayah of a range N times, then the next, and the whole range M times (everyayah.com audio,
/// or the saved recitation when it was downloaded).
class HifzPlayer extends ChangeNotifier {
  AudioPlayer? _p;
  AudioPlayer get _player => _p ??= _create();
  QuranDownloads? downloads;
  /// Called before playing, to stop the other audio of the app.
  VoidCallback? onStart;

  HifzRange? range;
  int each = 1, rounds = 1;
  int ayah = 0, rep = 0, round = 0;
  bool active = false;
  String? error;
  List<(int, int)> _queue = [];

  bool get playing => active && (_p?.playing ?? false);

  AudioPlayer _create() {
    final p = AudioPlayer();
    p.currentIndexStream.listen((i) {
      if (i == null || i >= _queue.length) return;
      ayah = _queue[i].$1;
      rep = _queue[i].$2;
      notifyListeners();
    });
    p.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && active) _roundDone();
      notifyListeners();
    });
    return p;
  }

  Future<void> play(String reciter, HifzRange r, {required int each, required int rounds, int? startAt}) async {
    onStart?.call();
    range = r;
    this.each = each;
    this.rounds = rounds;
    round = 1;
    _queue = hifzRound(r, each);
    final start = startAt == null ? 0 : _queue.indexWhere((q) => q.$1 == startAt).clamp(0, _queue.length - 1);
    ayah = _queue[start].$1;
    rep = _queue[start].$2;
    active = true;
    error = null;
    notifyListeners();
    try {
      await _player.setAudioSources([
        for (final (a, _) in _queue)
          switch (downloads?.localPath(reciter, r.surah, a)) {
            final String path => AudioSource.file(path),
            null => AudioSource.uri(Uri.parse(Recitation.url(reciter, r.surah, a))),
          }
      ], initialIndex: start);
      unawaited(_player.play());
    } catch (e) {
      debugPrint('hifz audio failed: $e');
      error = 'تعذّر تشغيل التلاوة. تأكد من الاتصال بالإنترنت، أو نزّل السورة للاستماع دون إنترنت.';
      active = false;
      notifyListeners();
    }
  }

  Future<void> _roundDone() async {
    if (round >= rounds) {
      await stop();
      return;
    }
    round++;
    notifyListeners();
    await _player.seek(Duration.zero, index: 0);
    unawaited(_player.play());
  }

  Future<void> togglePause() async {
    if (!active) return;
    _player.playing ? await _player.pause() : await _player.play();
    notifyListeners();
  }

  Future<void> stop() async {
    if (!active && _p == null) return;
    active = false;
    await _p?.stop();
    notifyListeners();
  }
}
