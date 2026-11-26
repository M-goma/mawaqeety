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

  Future<Uint8List?> _fetch(int page) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final r = await http.get(Uri.parse(index!.url(page))).timeout(const Duration(seconds: 30));
        if (r.statusCode == 200 && r.bodyBytes.length > 1000) {
          if (_dir != null) {
            await _file(page).writeAsBytes(r.bodyBytes, flush: true);
            _have.add(page);
            notifyListeners();
          }
          return r.bodyBytes;
        }
      } catch (e) {
        debugPrint('mushaf page $page failed: $e');
      }
      await Future.delayed(Duration(seconds: 1 + attempt * 2));
    }
    return null;
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
        if (await load(p) == null) failed++;
      }
    }
    await Future.wait([for (var w = 0; w < 6; w++) worker()]);
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
