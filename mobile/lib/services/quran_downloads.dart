import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/repository.dart';
import 'recitation.dart';

/// Progress of a running download for one reciter.
class DownloadJob {
  final String reciter;
  final List<int> surahs;
  int doneFiles = 0, totalFiles = 0;
  int currentSurah = 0;
  bool cancelled = false;
  bool all = false; // the whole Qur'an was requested
  String? error;
  DownloadJob(this.reciter, this.surahs);
  double get progress => totalFiles == 0 ? 0 : doneFiles / totalFiles;
}

/// Saves recitations ayah by ayah so they play without internet.
/// Files: <app support>/quran/<reciter>/<SSSAAA>.mp3, plus done.json with the complete surahs.
class QuranDownloads extends ChangeNotifier {
  Directory? _root;
  final _done = <String, Set<int>>{};
  final jobs = <String, DownloadJob>{};

  bool get supported => !kIsWeb;

  Future<void> init() async {
    if (!supported) return;
    try {
      _root = Directory('${(await getApplicationSupportDirectory()).path}/quran');
      if (!await _root!.exists()) return;
      await for (final d in _root!.list()) {
        if (d is! Directory) continue;
        final f = File('${d.path}/done.json');
        if (await f.exists()) {
          _done[d.path.split(Platform.pathSeparator).last] = ((jsonDecode(await f.readAsString()) as List).cast<int>()).toSet();
        }
      }
    } catch (e) {
      debugPrint('downloads init failed: $e');
    }
  }

  static String _name(int s, int a) => '${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3';

  /// The saved file for an ayah, or null when it is not on the device.
  String? localPath(String reciter, int surah, int ayah) {
    if (_root == null) return null;
    final f = File('${_root!.path}/$reciter/${_name(surah, ayah)}');
    return f.existsSync() ? f.path : null;
  }

  bool isReady(String reciter, int surah) => _done[reciter]?.contains(surah) ?? false;
  int readyCount(String reciter) => _done[reciter]?.length ?? 0;
  DownloadJob? job(String reciter) => jobs[reciter];

  /// Rough size of the whole Qur'an for a reciter, from the bitrate in its id (about 25 hours of audio).
  static String estimateFullSize(String reciter) {
    final m = RegExp(r'(\d+)kbps').firstMatch(reciter);
    final kbps = int.tryParse(m?.group(1) ?? '') ?? 64;
    final mb = kbps * 1000 / 8 * 25 * 3600 / 1e6;
    return mb >= 1000 ? '${(mb / 1000).toStringAsFixed(1)} جيجابايت' : '${mb.round()} ميجابايت';
  }

  Future<int> sizeOnDisk(String reciter) async {
    if (_root == null) return 0;
    final d = Directory('${_root!.path}/$reciter');
    if (!await d.exists()) return 0;
    var total = 0;
    await for (final f in d.list()) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  Future<void> _saveDone(String reciter) async {
    final f = File('${_root!.path}/$reciter/done.json');
    await f.writeAsString(jsonEncode(_done[reciter]!.toList()..sort()));
  }

  /// Downloads the given surahs (all 114 when [surahs] is null). Safe to call again: existing files are skipped.
  Future<void> download(Repository repo, String reciter, {List<int>? surahs}) async {
    if (!supported || jobs.containsKey(reciter)) return;
    _root ??= Directory('${(await getApplicationSupportDirectory()).path}/quran');
    final dir = Directory('${_root!.path}/$reciter');
    await dir.create(recursive: true);
    final list = (surahs ?? [for (var i = 1; i <= 114; i++) i]).where((s) => !isReady(reciter, s)).toList();
    final job = DownloadJob(reciter, list)..all = surahs == null;
    _cancelled.remove(reciter);
    lastError.remove(reciter);
    // The basmala (1:1) is played before most surahs, so it is always saved.
    final files = <(int, int)>[(1, 1)];
    for (final s in list) {
      for (var a = 1; a <= repo.surahs[s - 1].verses.length; a++) {
        if (s != 1 || a != 1) files.add((s, a));
      }
    }
    job.totalFiles = files.length;
    jobs[reciter] = job;
    notifyListeners();

    final client = http.Client();
    var lastNotify = DateTime.now();
    Future<bool> fetch((int, int) f) async {
      final file = File('${dir.path}/${_name(f.$1, f.$2)}');
      if (await file.exists() && await file.length() > 0) return true;
      for (var attempt = 0; attempt < 3; attempt++) {
        if (job.cancelled) return false;
        try {
          final r = await client.get(Uri.parse(Recitation.url(reciter, f.$1, f.$2))).timeout(const Duration(seconds: 40));
          if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
            final tmp = File('${file.path}.part');
            await tmp.writeAsBytes(r.bodyBytes, flush: true);
            await tmp.rename(file.path);
            return true;
          }
        } catch (_) {/* retry */}
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
      return false;
    }

    try {
      // Surah by surah, a few files at a time, so finished surahs become playable immediately.
      final bySurah = <int, List<(int, int)>>{};
      for (final f in files) {
        bySurah.putIfAbsent(f.$1, () => []).add(f);
      }
      for (final s in bySurah.keys.toList()..sort()) {
        if (job.cancelled) break;
        job.currentSurah = s;
        final queue = [...bySurah[s]!];
        var ok = true;
        Future<void> worker() async {
          while (queue.isNotEmpty && !job.cancelled) {
            final f = queue.removeAt(0);
            if (!await fetch(f)) ok = false;
            job.doneFiles++;
            if (DateTime.now().difference(lastNotify).inMilliseconds > 300) {
              lastNotify = DateTime.now();
              notifyListeners();
            }
          }
        }

        await Future.wait([for (var i = 0; i < 6; i++) worker()]);
        if (job.cancelled) break;
        if (!ok) {
          job.error = 'تعذّر تنزيل بعض الآيات. تحقق من الإنترنت ثم أعد المحاولة؛ سيُكمل التنزيل من حيث توقف.';
          break;
        }
        if (list.contains(s)) {
          (_done[reciter] ??= {}).add(s);
          await _saveDone(reciter);
        }
        notifyListeners();
      }
    } finally {
      client.close();
      jobs.remove(reciter);
      if (job.error != null) lastError[reciter] = job.error!;
      notifyListeners();
    }
  }

  final lastError = <String, String>{};

  final _cancelled = <String>{};
  bool wasCancelled(String reciter) => _cancelled.contains(reciter);

  void cancel(String reciter) {
    if (jobs[reciter] != null) _cancelled.add(reciter);
    jobs[reciter]?.cancelled = true;
    notifyListeners();
  }

  Future<void> delete(String reciter) async {
    cancel(reciter);
    if (_root == null) return;
    final d = Directory('${_root!.path}/$reciter');
    if (await d.exists()) await d.delete(recursive: true);
    _done.remove(reciter);
    lastError.remove(reciter);
    notifyListeners();
  }
}
