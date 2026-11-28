import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/arabic.dart';

/// Saves the recorded battle narrations (Mazen) on the device for offline listening.
/// Same folder as the prophets' stories: <app support>/stories/ghazwa-<id>-mazen.mp3
/// The download keeps running after the user leaves the app (see DownloadNotifier).
class GhazwaDownloads extends ChangeNotifier {
  static String fileOf(String id) => 'ghazwa-$id-mazen.mp3';
  static String urlOf(String id) =>
      'https://github.com/M-goma/mawaqeety/releases/download/stories-audio/${fileOf(id)}';

  /// Approximate size of all the recordings, in MB.
  static const totalMB = 35;

  Directory? _dir;
  final saved = <String>{};
  bool downloading = false, _cancel = false;
  bool get wasCancelled => _cancel;
  int doneFiles = 0, totalFiles = 0;
  String? error;
  String currentName = '';
  List<(String, String)> job = []; // (id, name) of the current or last job
  double get progress => totalFiles == 0 ? 0 : doneFiles / totalFiles;
  bool get supported => !kIsWeb;
  bool isSaved(String id) => saved.contains(id);

  Future<Directory?> folder() async {
    if (!supported) return null;
    if (_dir == null) {
      _dir = Directory('${(await getApplicationSupportDirectory()).path}/stories');
      if (await _dir!.exists()) {
        await for (final f in _dir!.list()) {
          final n = f.uri.pathSegments.last;
          if (f is File && n.startsWith('ghazwa-') && n.endsWith('-mazen.mp3') && await f.length() > 10000) {
            saved.add(n.substring(7, n.length - 10));
          }
        }
        notifyListeners();
      }
    }
    return _dir;
  }

  Future<void> init() async {
    try {
      await folder();
    } catch (e) {
      debugPrint('ghazwa downloads init: $e');
    }
  }

  /// The saved file of a battle, or null.
  Future<File?> localFile(String id) async {
    final dir = await folder();
    if (dir == null || !saved.contains(id)) return null;
    final f = File('${dir.path}/${fileOf(id)}');
    if (await f.exists()) return f;
    saved.remove(id);
    return null;
  }

  Future<bool> save(String id, [http.Client? client]) async {
    final dir = await folder();
    if (dir == null) return false;
    await dir.create(recursive: true);
    final c = client ?? http.Client();
    try {
      for (var attempt = 0; attempt < 3 && !(downloading && _cancel); attempt++) {
        try {
          final r = await c.get(Uri.parse(urlOf(id))).timeout(const Duration(minutes: 3));
          if (r.statusCode == 200 && r.bodyBytes.length > 10000) {
            final tmp = File('${dir.path}/${fileOf(id)}.part');
            await tmp.writeAsBytes(r.bodyBytes, flush: true);
            await tmp.rename('${dir.path}/${fileOf(id)}');
            saved.add(id);
            notifyListeners();
            return true;
          }
        } catch (_) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Downloads every battle in [battles] (id, name) not yet on the device.
  Future<void> downloadAll(List<(String, String)> battles) async {
    if (downloading || !supported) return;
    await folder();
    job = battles;
    final todo = battles.where((b) => !saved.contains(b.$1)).toList();
    downloading = true;
    _cancel = false;
    error = null;
    doneFiles = 0;
    totalFiles = todo.length;
    notifyListeners();
    final client = http.Client();
    var failed = 0;
    try {
      for (final (id, name) in todo) {
        if (_cancel) break;
        currentName = name;
        notifyListeners();
        if (!await save(id, client) && !_cancel) failed++;
        doneFiles++;
        notifyListeners();
      }
    } finally {
      client.close();
      downloading = false;
      if (failed > 0 && !_cancel) error = 'تعذّر تنزيل ${Arabic.digits(failed)} من الغزوات. تأكد من الاتصال ثم أعد المحاولة.';
      notifyListeners();
    }
  }

  void cancel() => _cancel = true;

  Future<void> deleteAll() async {
    cancel();
    final dir = await folder();
    if (dir != null && await dir.exists()) {
      for (final id in saved.toList()) {
        try {
          await File('${dir.path}/${fileOf(id)}').delete();
        } catch (_) {}
      }
    }
    saved.clear();
    notifyListeners();
  }
}
