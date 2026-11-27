import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  double get progress => _have.length / MushafIndex.pageCount;

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

  Future<Uint8List?> _loadBulk(int page) {
    final f = localFile(page);
    if (f != null) return Future.value(Uint8List(1));
    return _pending.putIfAbsent(page, () => _fetch(page, bulk: true).whenComplete(() => _pending.remove(page)));
  }

  /// Saves every page that is not on the device yet (about 66 MB in total).
  Future<void> downloadAll() async {
    if (downloading || !supported) return;
    downloading = true;
    _cancel = false;
    error = null;
    notifyListeners();
    final missing = [for (var p = 1; p <= MushafIndex.pageCount; p++) if (!_have.contains(p)) p];
    var failed = 0;
    var i = 0;
    Future<void> worker() async {
      while (!_cancel && i < missing.length) {
        final p = missing[i++];
        if (await _loadBulk(p) == null && !_cancel) failed++;
      }
    }
    await Future.wait([for (var w = 0; w < 4; w++) worker()]);
    downloading = false;
    if (failed > 0 && !_cancel) error = 'تعذّر تنزيل $failed صفحة. تأكد من الاتصال ثم أعد المحاولة.';
    notifyListeners();
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
