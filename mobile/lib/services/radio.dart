import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'media_controls.dart';

/// Live stream of إذاعة القرآن الكريم من القاهرة (the only station, by design).
/// Plays in the background with the media notification, reconnects by itself, and has a sleep timer.
class QuranRadio extends ChangeNotifier implements MediaSource {
  static const name = 'إذاعة القرآن الكريم';
  static const city = 'من القاهرة';
  static const streams = [
    'https://stream.radiojar.com/8s5u5tpdtwzuv',
    'https://n0a.radiojar.com/8s5u5tpdtwzuv',
  ];

  final _player = AudioPlayer();

  /// True from "play" until "stop" (also while connecting or reconnecting).
  bool on = false;
  bool connecting = false;
  String? error;
  int _attempt = 0;
  Timer? _retry;
  DateTime? sleepAt;
  int sleepMinutes = 0;
  Timer? _sleep;

  /// Called before the radio starts, to stop anything else that is playing.
  VoidCallback? onStart;

  QuranRadio() {
    _player.playerStateStream.listen((st) {
      final c = st.processingState == ProcessingState.loading || st.processingState == ProcessingState.buffering;
      if (c != connecting) {
        connecting = c;
        notifyListeners();
      }
      // A live stream never "completes": if it does, the connection dropped.
      if (on && st.processingState == ProcessingState.completed) _reconnect();
      _publish();
    });
    _player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace _) {
      debugPrint('radio error: $e');
      if (on) _reconnect();
    });
  }

  bool get playing => on && _player.playing;

  Future<void> play() async {
    onStart?.call();
    on = true;
    error = null;
    _attempt = 0;
    notifyListeners();
    await _connect();
  }

  Future<void> _connect() async {
    _retry?.cancel();
    final url = streams[_attempt % streams.length];
    try {
      connecting = true;
      notifyListeners();
      _publish();
      await _player.setUrl(url);
      if (!on) return;
      unawaited(_player.play());
      _attempt = 0;
      error = null;
    } catch (e) {
      debugPrint('radio connect failed: $e');
      if (on) _reconnect();
    }
    notifyListeners();
  }

  void _reconnect() {
    _retry?.cancel();
    _attempt++;
    if (_attempt > 12) {
      error = 'تعذّر الاتصال بالإذاعة. تأكد من الإنترنت ثم حاول مرة أخرى.';
      on = false;
      connecting = false;
      _player.stop();
      notifyListeners();
      _publish();
      return;
    }
    error = 'انقطع الاتصال… جارٍ إعادة الاتصال';
    notifyListeners();
    _retry = Timer(Duration(seconds: _attempt < 3 ? 2 : 6), () {
      if (on) _connect();
    });
  }

  /// Stops after [minutes] (0 = no timer).
  void setSleep(int minutes) {
    _sleep?.cancel();
    sleepMinutes = minutes < 0 ? 0 : minutes;
    sleepAt = minutes <= 0 ? null : DateTime.now().add(Duration(minutes: minutes));
    if (sleepAt != null) _sleep = Timer(Duration(minutes: minutes), stop);
    notifyListeners();
  }

  void toggle() => playing || connecting ? stop() : play();

  // ---------------- MediaSource (notification / lock screen) ----------------
  @override
  Future<void> resume() => play();
  @override
  Future<void> pause() => stop(); // a live stream is stopped, not paused
  @override
  Future<void> stop() async {
    on = false;
    connecting = false;
    _retry?.cancel();
    _sleep?.cancel();
    sleepAt = null;
    sleepMinutes = 0;
    await _player.stop();
    notifyListeners();
    MediaControls.instance?.hide(this);
  }

  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> rewind15() async {}
  @override
  Future<void> forward15() async {}

  void _publish() {
    final mc = MediaControls.instance;
    if (mc == null) return;
    if (!on) {
      mc.hide(this);
      return;
    }
    mc.show(this,
        id: 'radio-cairo',
        title: name,
        subtitle: '$city • بث مباشر',
        album: 'الإذاعة',
        playing: _player.playing,
        loading: connecting,
        live: true);
  }
}
