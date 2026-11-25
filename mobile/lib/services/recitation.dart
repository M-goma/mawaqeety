import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/repository.dart';
import 'quran_downloads.dart';

/// Verse-by-verse Qur'an recitation from everyayah.com, with the current ayah exposed for highlighting.
class Recitation extends ChangeNotifier {
  final _player = AudioPlayer();
  /// Saved recitations, used instead of the internet when available.
  QuranDownloads? downloads;
  List<(int, int, bool)> _queue = []; // surah, ayah, isBasmala
  int surah = 0, ayah = 0;
  bool active = false;
  String? error;

  /// Called when a surah ends; return the next surah number to continue, or null to stop.
  int? Function(int lastSurah)? onFinished;

  Recitation() {
    _player.currentIndexStream.listen((i) {
      if (i == null || i >= _queue.length) return;
      final (s, a, basmala) = _queue[i];
      surah = basmala ? _queue.last.$1 : s;
      ayah = basmala ? 0 : a;
      notifyListeners();
    });
    _player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && active) _finished();
      notifyListeners();
    });
  }

  bool get playing => _player.playing;

  static String url(String reciter, int surah, int ayah) =>
      'https://everyayah.com/data/$reciter/${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  Future<void> play(Repository repo, String reciter, int surah, int from, [int? to]) async {
    final s = repo.surahs[surah - 1];
    final end = (to ?? s.verses.length).clamp(from, s.verses.length);
    _queue = [
      if (from == 1 && surah != 1 && surah != 9) (1, 1, true),
      for (var a = from; a <= end; a++) (surah, a, false),
    ];
    error = null;
    active = true;
    this.surah = surah;
    ayah = from;
    notifyListeners();
    try {
      await _player.setAudioSources([
        for (final q in _queue)
          switch (downloads?.localPath(reciter, q.$1, q.$2)) {
            final String path => AudioSource.file(path),
            null => AudioSource.uri(Uri.parse(url(reciter, q.$1, q.$2))),
          }
      ]);
      unawaited(_player.play());
    } catch (e) {
      debugPrint('recitation failed: $e');
      error = 'تعذّر تشغيل التلاوة. تأكد من الاتصال بالإنترنت، أو نزّل السورة للاستماع دون إنترنت.';
      active = false;
      notifyListeners();
    }
  }

  void _finished() {
    final next = onFinished?.call(surah);
    if (next == null) {
      stop();
    }
  }

  Future<void> togglePause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> stop() async {
    active = false;
    ayah = 0;
    await _player.stop();
    notifyListeners();
  }
}
