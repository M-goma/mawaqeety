import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Saves the recorded prophet stories ("Nabil" / "Areen") on the device for offline listening.
/// Same files as the narration cache: <app support>/stories/<gender>-<id>-<n>.mp3
class StoryDownloads extends ChangeNotifier {
  Directory? _dir;
  String _base = '';
  Map<String, Map<String, int>> _parts = {};
  Map<String, int> _sizeMB = {};
  final _have = <String>{};

  bool downloading = false;
  bool _cancel = false;
  bool get wasCancelled => _cancel;
  String? error;
  int doneFiles = 0, totalFiles = 0;
  String currentId = '';
  List<String> jobGenders = [];
  List<String>? jobIds; // null = all stories

  bool get supported => !kIsWeb;
  double get progress => totalFiles == 0 ? 0 : doneFiles / totalFiles;

  Future<void> init() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/story_audio.json')) as Map<String, dynamic>;
      _base = j['base'] as String;
      _parts = {
        for (final g in ['male', 'female']) g: ((j[g] ?? {}) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
      };
      _sizeMB = ((j['sizeMB'] ?? {}) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
      if (!supported) return;
      _dir = Directory('${(await getApplicationSupportDirectory()).path}/stories');
      if (await _dir!.exists()) {
        await for (final f in _dir!.list()) {
          if (f is File && f.path.endsWith('.mp3') && await f.length() > 10000) _have.add(f.uri.pathSegments.last);
        }
      }
    } catch (e) {
      debugPrint('story downloads init failed: $e');
    }
  }

  int sizeMB(String gender) => _sizeMB[gender] ?? 100;

  List<String> _files(String id, String gender) =>
      [for (var i = 1; i <= (_parts[gender]?[id] ?? 0); i++) '$gender-$id-$i.mp3'];

  /// True when every part of the story in that voice is on the device.
  bool isSaved(String id, String gender) {
    final f = _files(id, gender);
    return f.isNotEmpty && f.every(_have.contains);
  }

  int savedStories(String gender) => (_parts[gender]?.keys ?? const <String>[]).where((id) => isSaved(id, gender)).length;
  int storyCount(String gender) => _parts[gender]?.length ?? 0;
  bool get anySaved => _have.isNotEmpty;

  /// Approximate size of what is saved, in MB.
  Future<int> savedMB() async {
    if (_dir == null || !await _dir!.exists()) return 0;
    var total = 0;
    await for (final f in _dir!.list()) {
      if (f is File) total += await f.length();
    }
    return (total / 1e6).round();
  }

  /// Notes a file saved by the player's own background cache.
  void noteSaved(String name) {
    if (_have.add(name)) notifyListeners();
  }

  /// Downloads the stories (all when [ids] is null) in the given voices. Files already saved are skipped.
  Future<void> download(List<String> genders, {List<String>? ids}) async {
    if (downloading || !supported) return;
    _dir ??= Directory('${(await getApplicationSupportDirectory()).path}/stories');
    await _dir!.create(recursive: true);
    final files = <(String, String)>[]; // story id, file name
    for (final g in genders) {
      for (final id in ids ?? (_parts[g]?.keys.toList() ?? <String>[])) {
        for (final f in _files(id, g)) {
          files.add((id, f));
        }
      }
    }
    downloading = true;
    _cancel = false;
    error = null;
    jobGenders = genders;
    jobIds = ids;
    doneFiles = 0;
    totalFiles = files.length;
    notifyListeners();
    final client = http.Client();
    var failed = 0;
    var i = 0;
    Future<void> worker() async {
      while (!_cancel && i < files.length) {
        final (id, name) = files[i++];
        currentId = id;
        if (!_have.contains(name)) {
          var ok = false;
          for (var attempt = 0; attempt < 3 && !ok && !_cancel; attempt++) {
            try {
              final r = await client.get(Uri.parse('$_base$name')).timeout(const Duration(minutes: 3));
              if (r.statusCode == 200 && r.bodyBytes.length > 10000) {
                final tmp = File('${_dir!.path}/$name.part');
                await tmp.writeAsBytes(r.bodyBytes, flush: true);
                await tmp.rename('${_dir!.path}/$name');
                _have.add(name);
                ok = true;
              }
            } catch (_) {
              await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            }
          }
          if (!ok && !_cancel) failed++;
        }
        doneFiles++;
        notifyListeners();
      }
    }

    try {
      await Future.wait([for (var w = 0; w < 3; w++) worker()]);
    } finally {
      client.close();
      downloading = false;
      if (failed > 0 && !_cancel) error = 'تعذّر تنزيل $failed جزءًا من القصص. تأكد من الاتصال ثم أعد المحاولة.';
      notifyListeners();
    }
  }

  void cancel() {
    _cancel = true;
  }

  Future<void> deleteAll() async {
    cancel();
    try {
      if (_dir != null && await _dir!.exists()) await _dir!.delete(recursive: true);
    } catch (_) {}
    _have.clear();
    notifyListeners();
  }
}
