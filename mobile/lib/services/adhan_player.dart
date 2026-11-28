import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/prayer_calculator.dart';
import '../core/settings.dart';
import '../data/repository.dart';

/// Plays the adhan inside the app. Recordings are downloaded once and cached (streamed on web).
class AdhanPlayer extends ChangeNotifier {
  final _player = AudioPlayer();
  final Map<String, Future<String?>> _downloads = {};
  String? playingId;

  AdhanPlayer() {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        playingId = null;
        notifyListeners();
      }
    });
  }

  bool get isPlaying => playingId != null;

  /// Where the recording of [v] is kept on the phone (null on web).
  Future<String?> localPath(AdhanVoice v) => _localPath(v);

  Future<String?> _localPath(AdhanVoice v) async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/adhan_${v.id}.mp3';
  }

  Future<bool> isDownloaded(AdhanVoice v) async {
    final p = await _localPath(v);
    return p != null && File(p).existsSync();
  }

  Future<String?> ensure(AdhanVoice v) {
    if (kIsWeb) return Future.value(v.url);
    return _downloads.putIfAbsent(v.id, () async {
      try {
        final path = (await _localPath(v))!;
        final f = File(path);
        if (f.existsSync()) return path;
        final r = await http.get(Uri.parse(v.url)).timeout(const Duration(minutes: 5));
        if (r.statusCode != 200 || r.bodyBytes.length < 50 * 1024) return null;
        final tmp = File('$path.part');
        await tmp.writeAsBytes(r.bodyBytes, flush: true);
        await tmp.rename(path);
        return path;
      } catch (e) {
        debugPrint('adhan download failed: $e');
        return null;
      } finally {
        _downloads.remove(v.id);
      }
    });
  }

  Future<void> prefetch(Repository repo, Settings s) async {
    for (final id in {s.adhanId, s.fajrAdhanId}) {
      final v = repo.voice(id);
      if (v != null) await ensure(v);
    }
  }

  Future<void> play(AdhanVoice v) async {
    try {
      await stop();
      playingId = v.id;
      notifyListeners();
      final src = await ensure(v);
      if (src == null) {
        await _player.setAsset('assets/sounds/chime.wav');
      } else if (kIsWeb) {
        await _player.setUrl(src);
      } else {
        await _player.setFilePath(src);
      }
      await _player.play();
    } catch (e) {
      debugPrint('adhan play failed: $e');
      playingId = null;
      notifyListeners();
    }
  }

  Future<void> playFor(Prayer p, Repository repo, Settings s, {bool friday = false}) async {
    if (s.adhanMode == 'voice') return playAlert(p, near: false, friday: friday);
    final v = repo.voice(p == Prayer.fajr ? s.fajrAdhanId : s.adhanId) ?? repo.voices.first;
    await play(v);
  }

  /// The short spoken alert in Mazen's voice: «اقتربت صلاة …» ([near]) or «حان الآن موعد صلاة …».
  static String alertAsset(Prayer p, {required bool near, bool friday = false}) {
    final name = friday && p == Prayer.dhuhr ? 'jumuah' : p.name;
    return 'assets/sounds/alerts/alert-$name-${near ? 'near' : 'now'}-mazen.mp3';
  }

  /// The alert copied to a file, so the native service can play it while the app is closed.
  static Future<String?> alertFile(Prayer p, {required bool near, bool friday = false}) async {
    if (kIsWeb) return null;
    try {
      final asset = alertAsset(p, near: near, friday: friday);
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/alerts');
      final f = File('${dir.path}/${asset.split('/').last}');
      if (await f.exists() && await f.length() > 10000) return f.path;
      await dir.create(recursive: true);
      final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (e) {
      debugPrint('alert file: $e');
      return null;
    }
  }

  Future<void> playAlert(Prayer p, {required bool near, bool friday = false}) async {
    try {
      await stop();
      playingId = 'alert';
      notifyListeners();
      await _player.setAsset(alertAsset(p, near: near, friday: friday));
      await _player.play();
    } catch (e) {
      debugPrint('alert play failed: $e');
      playingId = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    if (playingId != null) {
      playingId = null;
      notifyListeners();
    }
  }
}
