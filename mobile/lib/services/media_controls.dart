import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Something that can be driven from the notification / lock screen / headset buttons.
abstract class MediaSource {
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> next();
  Future<void> previous();
  Future<void> seekTo(Duration position);
  Future<void> rewind15();
  Future<void> forward15();
}

/// One media notification for the app (Qur'an recitation or a prophet story).
class MediaControls extends BaseAudioHandler with SeekHandler {
  static MediaControls? instance;
  static Uri? _art;
  MediaSource? _source;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      // Spoken audio: pauses for calls and when headphones are unplugged (handled by just_audio).
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      instance = await AudioService.init(
        builder: () => MediaControls(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.mawaqeety.playback',
          androidNotificationChannelName: 'التلاوة وقصص الأنبياء',
          androidNotificationChannelDescription: 'التحكم في التلاوة والقصص من الإشعارات وشاشة القفل',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidStopForegroundOnPause: true,
          fastForwardInterval: Duration(seconds: 15),
          rewindInterval: Duration(seconds: 15),
        ),
      );
      // Artwork shown in the notification.
      final f = File('${(await getApplicationSupportDirectory()).path}/media_art.png');
      if (!await f.exists()) {
        final b = await rootBundle.load('assets/images/logo.png');
        await f.writeAsBytes(b.buffer.asUint8List(), flush: true);
      }
      _art = Uri.file(f.path);
    } catch (e) {
      debugPrint('media controls unavailable: $e');
    }
  }

  /// Publishes what is playing. [story] adds ±15 s buttons.
  void show(MediaSource source, {
    required String id,
    required String title,
    required String subtitle,
    required String album,
    required bool playing,
    required bool loading,
    Duration position = Duration.zero,
    Duration? duration,
    bool story = false,
  }) {
    _source = source;
    final item = MediaItem(id: id, title: title, artist: subtitle, album: album, duration: duration, artUri: _art);
    if (mediaItem.value != item) mediaItem.add(item);
    final pp = playing ? MediaControl.pause : MediaControl.play;
    final controls = story
        ? [MediaControl.skipToPrevious, MediaControl.rewind, pp, MediaControl.fastForward, MediaControl.skipToNext, MediaControl.stop]
        : [MediaControl.skipToPrevious, pp, MediaControl.skipToNext, MediaControl.stop];
    playbackState.add(PlaybackState(
      controls: controls,
      androidCompactActionIndices: story ? const [1, 2, 3] : const [0, 1, 2],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      processingState: loading ? AudioProcessingState.loading : AudioProcessingState.ready,
      playing: playing,
      updatePosition: position,
    ));
  }

  /// Removes the notification when [source] is the one currently shown.
  void hide(MediaSource source) {
    if (_source != source) return;
    _source = null;
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
  }

  @override
  Future<void> play() async => _source?.resume();
  @override
  Future<void> pause() async => _source?.pause();
  @override
  Future<void> stop() async {
    final s = _source;
    await s?.stop();
    await super.stop();
  }
  @override
  Future<void> skipToNext() async => _source?.next();
  @override
  Future<void> skipToPrevious() async => _source?.previous();
  @override
  Future<void> seek(Duration position) async => _source?.seekTo(position);
  @override
  Future<void> rewind() async => _source?.rewind15();
  @override
  Future<void> fastForward() async => _source?.forward15();
}
