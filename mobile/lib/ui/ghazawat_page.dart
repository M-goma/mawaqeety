import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../data/ghazawat.dart';
import '../data/hadith.dart';
import '../main.dart';
import '../services/ghazwa_downloads.dart';
import 'hadith_page.dart';
import 'mushaf_page.dart';
import 'theme.dart';

// ---------------------------------------------------------------- audio

/// Plays the recorded narration of a battle (male voice). The files are published later; until then
/// [missing] holds the ids whose recording could not be loaded.
class GhazwaAudio extends ChangeNotifier {
  static final instance = GhazwaAudio._();
  GhazwaAudio._();

  AudioPlayer? _player;
  String? currentId;
  bool loading = false;
  bool playing = false;
  final missing = <String>{};

  static String urlOf(String id) => GhazwaDownloads.urlOf(id);

  /// Offline copies; the download itself lives in [GhazwaDownloads] so it can run in the background.
  GhazwaDownloads get store => app.ghazawat;
  bool get supported => store.supported;
  bool isSaved(String id) => store.isSaved(id);
  Future<void> init() => store.init();

  /// Returns false when the recording is not available (yet).
  Future<bool> play(String id) async {
    await stop();
    // Only one thing plays at a time.
    try {
      if (app.narration.speaking) await app.narration.stop();
      if (app.recitation.active) await app.recitation.stop();
      if (app.radio.on) await app.radio.stop();
    } catch (_) {}
    final p = _player ??= AudioPlayer()
      ..playerStateStream.listen((s) {
        final done = s.processingState == ProcessingState.completed;
        final now = s.playing && !done;
        if (done) currentId = null;
        if (now != playing || done) {
          playing = now;
          notifyListeners();
        }
      });
    currentId = id;
    loading = true;
    notifyListeners();
    try {
      final local = await store.localFile(id);
      if (local != null) {
        await p.setFilePath(local.path);
      } else {
        await p.setUrl(urlOf(id)).timeout(const Duration(seconds: 25));
        // Keep a copy so it plays offline next time.
        if (store.supported) unawaited(store.save(id));
      }
      loading = false;
      notifyListeners();
      unawaited(p.play());
      return true;
    } catch (e) {
      debugPrint('ghazwa audio $id: $e');
      missing.add(id);
      currentId = null;
      loading = false;
      playing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> pause() async => _player?.pause();
  Future<void> resume() async => _player?.play();

  Future<void> stop() async {
    await _player?.stop();
    currentId = null;
    playing = false;
    loading = false;
    notifyListeners();
  }
}

/// Plays the narration of the battle [id]; false when the recording is not published yet.
Future<bool> playGhazwa(String id) => GhazwaAudio.instance.play(id);

// ---------------------------------------------------------------- list + map

/// غزوات النبي ﷺ: a timeline of the main battles with a small map.
class GhazawatPage extends StatelessWidget {
  const GhazawatPage({super.key});
  @override
  Widget build(BuildContext context) {
    GhazwaAudio.instance.init();
    return Scaffold(
      appBar: AppBar(title: const Text('غزوات النبي ﷺ'), actions: [
        if (GhazwaAudio.instance.supported)
          ListenableBuilder(
            listenable: app.ghazawat,
            builder: (context, _) => IconButton(
              tooltip: 'تنزيل الغزوات للاستماع دون إنترنت',
              icon: Icon(app.ghazawat.downloading ? Icons.downloading : Icons.download_for_offline_outlined),
              onPressed: () => showGhazawatDownloads(context),
            ),
          ),
      ]),
      body: FutureBuilder(
        future: GhazawatData.load(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('تعذّر تحميل البيانات: ${snap.error}'));
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final hint = Theme.of(context).hintColor;
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const _DownloadProgress(),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: hero3D(radius: 20),
              child: Column(children: [
                Text('﴿وَلَقَدْ نَصَرَكُمُ اللَّهُ بِبَدْرٍ وَأَنتُمْ أَذِلَّةٌ﴾', textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'AmiriQuran', color: Colors.white, fontSize: 18, height: 1.9)),
                Text('آل عمران ١٢٣', style: TextStyle(color: AppColors.goldLight, fontSize: 12)),
                const SizedBox(height: 8),
                Text(d.intro, textAlign: TextAlign.center, style: TextStyle(color: AppColors.heroText, height: 1.7)),
              ]),
            ),
            _GhazawatMap(list: d.list),
            const SizedBox(height: 6),
            for (var i = 0; i < d.list.length; i++)
              _TimelineTile(g: d.list[i], n: i + 1, first: i == 0, last: i == d.list.length - 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(d.note, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: hint, height: 1.6)),
            ),
            for (final r in d.sources) _RefLink(r),
          ]);
        },
      ),
    );
  }
}

/// Progress strip while the battles are downloading, and the error if some failed.
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress();
  @override
  Widget build(BuildContext context) {
    final a = app.ghazawat;
    return ListenableBuilder(
      listenable: a,
      builder: (context, _) {
        if (!a.downloading && a.error == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: hero3D(radius: 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    a.downloading
                        ? 'جارٍ تنزيل الغزوات • ${Arabic.digits(a.doneFiles)} من ${Arabic.digits(a.totalFiles)}'
                        : a.error!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                if (a.downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: a.progress, color: AppColors.gold, backgroundColor: Colors.white24),
                ],
              ]),
            ),
            if (a.downloading)
              TextButton(onPressed: a.cancel, child: const Text('إيقاف', style: TextStyle(color: Colors.white))),
          ]),
        );
      },
    );
  }
}

/// Download every battle narration for offline listening, or delete the saved ones.
void showGhazawatDownloads(BuildContext context) async {
  final a = app.ghazawat;
  await a.init();
  final battles = [for (final g in (await GhazawatData.load()).list) (g.id, g.name)];
  final ids = [for (final b in battles) b.$1];
  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    builder: (c) => ListenableBuilder(
      listenable: a,
      builder: (c, _) {
        final n = ids.where(a.isSaved).length;
        final all = n == ids.length;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('تنزيل الغزوات للاستماع دون إنترنت', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${Arabic.digits(ids.length)} غزوات بصوت مازن، نحو ${Arabic.digits(GhazwaDownloads.totalMB)} ميجابايت. يُفضَّل التنزيل عبر Wi-Fi.',
                  style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(all ? Icons.download_done : Icons.headphones_outlined, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(n == 0 ? 'لا توجد غزوات محفوظة بعد' : 'محفوظ ${Arabic.digits(n)} من ${Arabic.digits(ids.length)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: Text(all ? 'كل الغزوات محفوظة' : n == 0 ? 'تنزيل كل الغزوات' : 'تنزيل الباقي'),
                  onPressed: a.downloading || all
                      ? null
                      : () {
                          Navigator.pop(c);
                          a.downloadAll(battles);
                        },
                ),
              ),
              if (n > 0)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(c);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('حذف الغزوات المحفوظة'),
                          content: const Text('ستُحذف تسجيلات الغزوات من الهاتف، ويمكنك تنزيلها مرة أخرى في أي وقت.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (ok == true) await a.deleteAll();
                    },
                    child: const Text('حذف الغزوات المحفوظة', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
            ]),
          ),
        );
      },
    ),
  );
}

void _open(BuildContext context, Ghazwa g) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => GhazwaPage(g: g)));

class _GhazawatMap extends StatelessWidget {
  final List<Ghazwa> list;
  final Ghazwa? focus;
  final double height;
  const _GhazawatMap({required this.list, this.focus, this.height = 300});

  /// Battles whose places are too close to tell apart at this zoom share one marker (e.g. Uhud, the Trench
  /// and Banu Qurayza around Madinah).
  List<List<int>> _groups() {
    final out = <List<int>>[];
    for (var i = 0; i < list.length; i++) {
      final near = out.where((g) {
        final dy = list[g.first].lat - list[i].lat, dx = list[g.first].lng - list[i].lng;
        return dx * dx + dy * dy < 0.36; // closer than ~0.6°
      });
      if (near.isEmpty) {
        out.add([i]);
      } else {
        near.first.add(i);
      }
    }
    return out;
  }

  void _pick(BuildContext context, List<int> group) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final i in group)
              ListTile(
                leading: _NumberBadge(i + 1),
                title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(list[i].date),
                onTap: () {
                  Navigator.pop(c);
                  _open(context, list[i]);
                },
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pts = [for (final g in list) LatLng(g.lat, g.lng)];
    final f = focus;
    return Card3D(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: f == null
                ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(30, 40, 30, 20), maxZoom: 7)
                : null,
            initialCenter: f == null ? const LatLng(25, 38) : LatLng(f.lat, f.lng),
            initialZoom: f == null ? 4.6 : 6.5,
            minZoom: 3,
            maxZoom: 13,
            // The small map of one battle is a picture; the overview can be panned and pinched (no wheel zoom, so
            // scrolling the page over it does not zoom it).
            interactionOptions: InteractionOptions(
                flags: f != null ? InteractiveFlag.none : InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.mawaqeety.app'),
            MarkerLayer(markers: [
              for (final group in _groups())
                Marker(
                  point: LatLng(list[group.first].lat, list[group.first].lng),
                  width: 14.0 + 14 * group.length,
                  height: 24,
                  child: GestureDetector(
                    onTap: f != null
                        ? null
                        : group.length == 1
                            ? () => _open(context, list[group.first])
                            : () => _pick(context, group),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.current.hero[1],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.current.accentLight, width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                      ),
                      child: Text(f != null ? '★' : group.map((i) => Arabic.digits(i + 1)).join('،'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5, height: 1.1)),
                    ),
                  ),
                ),
            ]),
            RichAttributionWidget(alignment: AttributionAlignment.bottomLeft, attributions: [
              TextSourceAttribution('OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final Ghazwa g;
  final int n;
  final bool first, last;
  const _TimelineTile({required this.g, required this.n, required this.first, required this.last});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final line = AppColors.gold.withValues(alpha: 0.45);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 70,
          child: Stack(alignment: Alignment.topCenter, children: [
            Positioned(top: first ? 30 : 0, bottom: last ? null : 0, height: last ? 30 : null,
                child: Container(width: 2, color: line)),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 48,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: g.isBattle ? AppColors.current.hero[1] : AppColors.emerald,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.8)),
                ),
                child: Text('${Arabic.digits(g.year)} هـ',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: Card3D(
            margin: const EdgeInsetsDirectional.fromSTEB(0, 5, 14, 5),
            child: InkWell(
              onTap: () => _open(context, g),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _NumberBadge(n),
                    const SizedBox(width: 8),
                    Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5))),
                    if (!g.isBattle) _Chip('صلح وليس غزوة', AppColors.emerald),
                  ]),
                  Text('${g.date} • ${g.place}', style: TextStyle(fontSize: 12.5, color: AppColors.gold)),
                  const SizedBox(height: 4),
                  Text(g.summary, maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, height: 1.6, color: hint)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int n;
  const _NumberBadge(this.n);
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withValues(alpha: 0.18)),
        child: Text(Arabic.digits(n), style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12.5)),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
      );
}

class _RefLink extends StatelessWidget {
  final GhazwaRef r;
  const _RefLink(this.r);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextButton.icon(
          style: TextButton.styleFrom(alignment: AlignmentDirectional.centerStart),
          onPressed: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(r.title, style: const TextStyle(fontSize: 12.5)),
        ),
      );
}

// ---------------------------------------------------------------- detail

class GhazwaPage extends StatefulWidget {
  final Ghazwa g;
  const GhazwaPage({super.key, required this.g});
  @override
  State<GhazwaPage> createState() => _GhazwaPageState();
}

class _GhazwaPageState extends State<GhazwaPage> {
  late final Future<List<(GhazwaHadith, Hadith?)>> _hadith = _loadHadith();

  @override
  void initState() {
    super.initState();
    GhazwaAudio.instance.init();
  }

  Future<List<(GhazwaHadith, Hadith?)>> _loadHadith() async =>
      [for (final r in widget.g.hadith) (r, await findGhazwaHadith(r))];

  Widget _title(String t, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.gold)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final hint = Theme.of(context).hintColor;
    return Scaffold(
      appBar: AppBar(title: Text(g.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 6, 0, 28), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(18),
          decoration: hero3D(radius: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))])),
            Text('${g.date} • ${g.place}', style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(g.summary, style: TextStyle(color: AppColors.heroText, height: 1.8)),
            const SizedBox(height: 10),
            if (g.muslims.isNotEmpty) _fact(Icons.groups_outlined, 'المسلمون', g.muslims),
            if (g.enemy.isNotEmpty) _fact(Icons.shield_outlined, g.isBattle ? 'في المقابل' : 'الطرف الآخر', g.enemy),
            if (g.result.isNotEmpty) _fact(Icons.flag_outlined, 'النتيجة', g.result),
            const SizedBox(height: 12),
            _ListenButton(g),
          ]),
        ),
        for (final s in g.sections)
          Card3D(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(s.heading, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(s.text, style: const TextStyle(fontSize: 15.5, height: 1.95)),
              ]),
            ),
          ),
        _title('الموقع', Icons.place_outlined),
        _GhazawatMap(list: [g], focus: g, height: 180),
        if (g.ayat.isNotEmpty) _title('من القرآن الكريم', Icons.menu_book_outlined),
        for (final a in g.ayat) _AyatCard(a),
        if (g.hadith.isNotEmpty) _title('من الصحيحين', Icons.format_quote_outlined),
        if (g.hadith.isNotEmpty)
          FutureBuilder(
            future: _hadith,
            builder: (context, snap) {
              final list = snap.data;
              if (list == null) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              return Column(children: [
                for (final (r, h) in list)
                  h == null
                      ? ListTile(title: Text(r.title), subtitle: Text('${r.collectionName} ${Arabic.digits(r.number)}'))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                            child: Text('${r.title} • ${r.collectionName} ${Arabic.digits(r.number)}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald, fontSize: 13.5)),
                          ),
                          HadithCard(h),
                        ]),
              ]);
            },
          ),
        _title('دروس وعبر', Icons.lightbulb_outline),
        Card3D(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(children: [
              for (final l in g.lessons)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Icon(Icons.circle, size: 7, color: AppColors.emerald),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l, style: const TextStyle(fontSize: 15, height: 1.8))),
                  ]),
                ),
            ]),
          ),
        ),
        if (g.refs.isNotEmpty) _title('مراجع التواريخ والأعداد', Icons.link),
        for (final r in g.refs) _RefLink(r),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text('التواريخ والأعداد على الأشهر عند أهل السير، وقد يختلف فيها المؤرخون.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: hint)),
        ),
      ]),
    );
  }

  Widget _fact(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.goldLight),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w700)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, height: 1.5))),
        ]),
      );
}

class _ListenButton extends StatelessWidget {
  final Ghazwa g;
  const _ListenButton(this.g);
  @override
  Widget build(BuildContext context) {
    final audio = GhazwaAudio.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([audio, app.ghazawat]),
      builder: (context, _) {
        final mine = audio.currentId == g.id;
        final missing = audio.missing.contains(g.id);
        return Row(children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black87),
            onPressed: mine && audio.loading
                ? null
                : () async {
                    if (mine && audio.playing) return audio.pause();
                    if (mine) return audio.resume();
                    final ok = await playGhazwa(g.id);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('التسجيل الصوتي قريبًا')));
                    }
                  },
            icon: mine && audio.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(mine && audio.playing ? Icons.pause : Icons.headphones),
            label: Text(mine && audio.playing ? 'إيقاف مؤقت' : 'استمع'),
          ),
          if (mine && !audio.loading) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'إيقاف',
              onPressed: audio.stop,
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
            ),
          ],
          if (!mine && audio.isSaved(g.id)) ...[
            const SizedBox(width: 10),
            Icon(Icons.download_done, size: 18, color: AppColors.goldLight),
            const SizedBox(width: 4),
            Text('محفوظة على الهاتف', style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
          ],
          if (missing && !mine) ...[
            const SizedBox(width: 10),
            Flexible(child: Text('التسجيل الصوتي قريبًا', style: TextStyle(color: AppColors.heroText, fontSize: 12.5))),
          ],
        ]);
      },
    );
  }
}

class _AyatCard extends StatelessWidget {
  final GhazwaAyat a;
  const _AyatCard(this.a);
  @override
  Widget build(BuildContext context) {
    final surahs = app.repo.surahs;
    if (a.surah < 1 || a.surah > surahs.length) return const SizedBox.shrink();
    final s = surahs[a.surah - 1];
    final to = a.to.clamp(a.from, s.verses.length);
    final range = a.from == to ? Arabic.digits(a.from) : '${Arabic.digits(a.from)}–${Arabic.digits(to)}';
    final text = [
      for (var i = a.from; i <= to; i++) '${s.verses[i - 1]} ﴿${Arabic.digits(i)}﴾',
    ].join(' ');
    return Card3D(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text('سورة ${s.name} $range',
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () => openMushaf(context, app.mushaf.pageOf(a.surah, a.from), highlight: Bookmark(a.surah, a.from)),
              icon: const Icon(Icons.auto_stories_outlined, size: 18),
              label: const Text('في المصحف'),
            ),
          ]),
          if (a.note.isNotEmpty)
            Text(a.note, style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18.5, height: 2.1)),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}
