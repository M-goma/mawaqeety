import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/arabic.dart';
import '../data/repository.dart';
import 'media_controls.dart';
import 'quran_downloads.dart';

/// Verse-by-verse Qur'an recitation from everyayah.com, with the current ayah exposed for highlighting.
class Recitation extends ChangeNotifier implements MediaSource {
  final _player = AudioPlayer();
  /// Saved recitations, used instead of the internet when available.
  QuranDownloads? downloads;
  List<(int, int, bool)> _queue = []; // surah, ayah, isBasmala
  int surah = 0, ayah = 0;
  bool active = false;
  String? error;

  /// Called when a surah ends; return the next surah number to continue, or null to stop.
  int? Function(int lastSurah)? onFinished;
  Repository? _repo;
  String _reciterName = '';

  Recitation() {
    _player.currentIndexStream.listen((i) {
      if (i == null || i >= _queue.length) return;
      final (s, a, basmala) = _queue[i];
      surah = basmala ? _queue.last.$1 : s;
      ayah = basmala ? 0 : a;
      notifyListeners();
      _publish();
    });
    _player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && active) _finished();
      notifyListeners();
      _publish();
    });
    _player.positionDiscontinuityStream.listen((_) => _publish());
  }

  bool get playing => _player.playing;

  static String url(String reciter, int surah, int ayah) =>
      'https://everyayah.com/data/$reciter/${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  Future<void> play(Repository repo, String reciter, int surah, int from, [int? to]) async {
    final s = repo.surahs[surah - 1];
    _repo = repo;
    _reciterName = repo.reciter(reciter).name;
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

  @override
  Future<void> stop() async {
    active = false;
    ayah = 0;
    await _player.stop();
    notifyListeners();
    MediaControls.instance?.hide(this);
  }

  // ---------------- notification / lock screen ----------------
  void _publish() {
    final mc = MediaControls.instance;
    if (mc == null) return;
    if (!active || _repo == null || surah < 1) {
      mc.hide(this);
      return;
    }
    final ps = _player.processingState;
    mc.show(this,
        id: 'quran-$surah-$ayah',
        title: 'سورة ${_repo!.surahs[surah - 1].name} • ${ayah == 0 ? 'البسملة' : 'الآية ${Arabic.digits(ayah)}'}',
        subtitle: _reciterName,
        album: 'القرآن الكريم',
        playing: _player.playing,
        loading: ps == ProcessingState.loading || ps == ProcessingState.buffering,
        position: _player.position,
        duration: _player.duration);
  }

  @override
  Future<void> resume() => _player.play();
  @override
  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }
  @override
  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else {
      _finished();
    }
  }
  @override
  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }
  @override
  Future<void> seekTo(Duration position) => _player.seek(position);
  @override
  Future<void> rewind15() => _player.seek(_player.position - const Duration(seconds: 15) < Duration.zero
      ? Duration.zero
      : _player.position - const Duration(seconds: 15));
  @override
  Future<void> forward15() => _player.seek(_player.position + const Duration(seconds: 15));
}
