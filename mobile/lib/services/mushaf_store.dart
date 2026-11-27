import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/mushaf.dart';

/// Mushaf page images: kept on the device after the first view, or all at once for offline reading.
/// Files: <app support>/mushaf/<NNN>.png
class MushafStore extends ChangeNotifier {
  MushafIndex? index;
  Directory? _dir;
  final _have = <int>{};
  final _pending = <int, Future<Uint8List?>>{};

  bool downloading = false;
  bool _cancel = false;
  bool get wasCancelled => _cancel;
  String? error;

  bool get supported => !kIsWeb;
  int get savedCount => _have.length;
  bool get complete => _have.length >= MushafIndex.pageCount;
  double get progress => savedProgress;

  Future<void> init(MushafIndex idx) async {
    index = idx;
    if (!supported) return;
    try {
      _dir = Directory('${(await getApplicationSupportDirectory()).path}/mushaf');
      await _dir!.create(recursive: true);
      await for (final f in _dir!.list()) {
        final n = int.tryParse(f.uri.pathSegments.last.replaceAll('.png', ''));
        if (n != null && f is File && await f.length() > 1000) _have.add(n);
      }
    } catch (e) {
      debugPrint('mushaf store init failed: $e');
    }
  }

  File _file(int page) => File('${_dir!.path}/${page.toString().padLeft(3, '0')}.png');

  /// The saved file for a page, or null when it is not on the device yet.
  File? localFile(int page) => _dir != null && _have.contains(page) ? _file(page) : null;

  /// Page bytes from the device, or from the internet (then saved for next time).
  Future<Uint8List?> load(int page) {
    final f = localFile(page);
    if (f != null) return f.readAsBytes();
    return _pending.putIfAbsent(page, () => _fetch(page).whenComplete(() => _pending.remove(page)));
  }

  /// A copy of the pages on a CDN, used when GitHub refuses or is slow (it limits many requests in a row).
  static const _mirror = 'https://cdn.jsdelivr.net/gh/M-goma/mawaqeety@mushaf-pages/pages/';
  DateTime _coolDownUntil = DateTime(2000);

  String _urlFor(int page, int attempt) =>
      attempt.isEven ? index!.url(page) : '$_mirror${page.toString().padLeft(3, '0')}.png';

  Future<Uint8List?> _fetch(int page, {bool bulk = false}) async {
    final attempts = bulk ? 8 : 3;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (bulk && _cancel) return null;
      final wait = _coolDownUntil.difference(DateTime.now());
      if (wait > Duration.zero) await Future.delayed(wait);
      var delay = Duration(seconds: 1 + attempt * 2);
      try {
        final r = await http.get(Uri.parse(_urlFor(page, attempt))).timeout(const Duration(seconds: 30));
        if (r.statusCode == 200 && r.bodyBytes.length > 1000) {
          if (_dir != null) {
            await _file(page).writeAsBytes(r.bodyBytes, flush: true);
            _have.add(page);
            notifyListeners();
          }
          return r.bodyBytes;
        }
        if (r.statusCode == 429 || r.statusCode >= 500) {
          // Too many requests: everyone waits a little before the next one.
          final s = int.tryParse(r.headers['retry-after'] ?? '') ?? (5 * (attempt + 1)).clamp(5, 30);
          delay = Duration(seconds: s);
          _coolDownUntil = DateTime.now().add(delay);
        }
      } catch (e) {
        debugPrint('mushaf page $page failed: $e');
      }
      await Future.delayed(delay);
    }
    return null;
  }



  /// The pages in 13 zip bundles of 50 (GitHub release): 13 large downloads instead of 604 small ones,
  /// which the page host rate-limits (especially on mobile networks where many users share one address).
  static const _bundles = 'https://github.com/M-goma/mawaqeety/releases/download/mushaf-pages-v1/mushaf-';
  static const _perBundle = 50;

  /// Bytes of the bundle being downloaded, for a smooth progress bar.
  int bundleDone = 0, bundleTotal = 0;

  /// Saves every page that is not on the device yet (about 63 MB in total).
  Future<void> downloadAll() async {
    if (downloading || !supported || _dir == null) return;
    downloading = true;
    _cancel = false;
    error = null;
    notifyListeners();
    final client = http.Client();
    var failed = 0;
    try {
      final count = (MushafIndex.pageCount + _perBundle - 1) ~/ _perBundle;
      for (var k = 1; k <= count && !_cancel; k++) {
        final first = (k - 1) * _perBundle + 1, last = (k * _perBundle).clamp(1, MushafIndex.pageCount);
        if ([for (var p = first; p <= last; p++) p].every(_have.contains)) continue;
        Uint8List? zip;
        for (var attempt = 0; attempt < 4 && zip == null && !_cancel; attempt++) {
          zip = await _fetchBundle(client, k);
          if (zip == null && !_cancel) await Future.delayed(Duration(seconds: 3 + attempt * 5));
        }
        if (zip == null) {
          if (!_cancel) failed++;
          continue;
        }
        for (final f in ZipDecoder().decodeBytes(zip)) {
          final n = int.tryParse(f.name.replaceAll('.png', ''));
          if (n == null || !f.isFile || _have.contains(n)) continue;
          final bytes = f.content as List<int>;
          if (bytes.length < 1000) continue;
          await _file(n).writeAsBytes(bytes, flush: true);
          _have.add(n);
        }
        bundleDone = bundleTotal = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('mushaf bundles failed: $e');
      failed++;
    } finally {
      client.close();
    }
    downloading = false;
    bundleDone = bundleTotal = 0;
    if (failed > 0 && !_cancel) error = 'تعذّر تنزيل بعض صفحات المصحف. تأكد من الاتصال ثم أعد المحاولة؛ ما نُزِّل محفوظ.';
    notifyListeners();
  }

  Future<Uint8List?> _fetchBundle(http.Client client, int k) async {
    try {
      final req = http.Request('GET', Uri.parse('$_bundles${k.toString().padLeft(2, '0')}.zip'));
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      bundleTotal = res.contentLength ?? 0;
      bundleDone = 0;
      final out = BytesBuilder(copy: false);
      var last = DateTime.now();
      await for (final chunk in res.stream.timeout(const Duration(seconds: 40))) {
        if (_cancel) return null;
        out.add(chunk);
        bundleDone += chunk.length;
        if (DateTime.now().difference(last).inMilliseconds > 400) {
          last = DateTime.now();
          notifyListeners();
        }
      }
      final bytes = out.takeBytes();
      return bytes.length > 1000 ? bytes : null;
    } catch (e) {
      debugPrint('mushaf bundle $k failed: $e');
      return null;
    }
  }

  /// Pages saved, counting the bundle in progress proportionally.
  double get savedProgress {
    final part = bundleTotal > 0 ? bundleDone / bundleTotal * _perBundle : 0;
    return ((_have.length + part) / MushafIndex.pageCount).clamp(0, 1);
  }

  void cancel() {
    _cancel = true;
  }

  Future<void> deleteAll() async {
    cancel();
    if (_dir == null) return;
    for (final p in _have.toList()) {
      try {
        await _file(p).delete();
      } catch (_) {}
    }
    _have.clear();
    notifyListeners();
  }
}
