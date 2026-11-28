import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../data/atlas.dart';
import '../data/ghazawat.dart';
import '../data/seerah.dart';
import '../main.dart';
import 'ghazawat_page.dart';
import 'prophets_page.dart';
import 'seerah_page.dart';
import 'theme.dart';

/// What the atlas shows: the places of the prophets' stories, the Prophet's ﷺ battles, or the places of the Seerah.
enum AtlasTab { prophets, battles, seerah }

/// Room around the fitted points; more on top, where the labels are.
const _fitPadding = EdgeInsets.fromLTRB(40, 72, 40, 24);

/// Colour of the battle markers (distinct from the gold story markers).
const battleColor = Color(0xFFB3261E);

/// A marker: one place, possibly shared by several battles or Seerah events.
class _Pin {
  final LatLng point;
  final Offset at; // on screen
  final List<int> items; // indexes into the tab's list
  bool showLabel = true;
  _Pin(this.point, this.at, this.items);
}

/// أطلس قصص الأنبياء: the places of the stories on a map; a place opens its note, source and stories.
/// The «الغزوات» tab shows the battles and «السيرة» the places of the Seerah timeline.
class AtlasPage extends StatefulWidget {
  final String? prophetId; // highlight this prophet's places
  final AtlasTab tab;
  final String? focusGhazwa; // open centred on this battle
  final String? focusSeerah; // open centred on this Seerah event
  const AtlasPage({super.key, this.prophetId, this.tab = AtlasTab.prophets, this.focusGhazwa, this.focusSeerah});
  @override
  State<AtlasPage> createState() => _AtlasPageState();
}

class _AtlasPageState extends State<AtlasPage> {
  final _map = MapController();
  bool _satellite = false;
  late AtlasTab _tab = widget.prophetId != null ? AtlasTab.prophets : widget.tab;
  late final Future<(GhazawatData, SeerahData)> _data = _load();

  static Future<(GhazawatData, SeerahData)> _load() async => (await GhazawatData.load(), await SeerahData.load());

  List<AtlasPlace> get _places =>
      widget.prophetId == null ? atlasPlaces : atlasPlaces.where((p) => p.prophets.contains(widget.prophetId)).toList();

  /// Seerah events with a place; a battle takes its place from ghazawat.json.
  static List<(SeerahEvent, LatLng, String)> _seerahPlaces(GhazawatData g, SeerahData s) => [
        for (final e in s.events)
          if (e.place != null)
            (e, LatLng(e.place!.lat, e.place!.lng), e.place!.name)
          else if (e.ghazwa != null && g.byId(e.ghazwa!) != null)
            (e, LatLng(g.byId(e.ghazwa!)!.lat, g.byId(e.ghazwa!)!.lng), g.byId(e.ghazwa!)!.place),
      ];

  /// Groups the points closer than [px] pixels at the current zoom into one marker, then hides the labels that
  /// would overlap a label already placed (bigger groups first); those markers keep only their badge.
  static List<_Pin> _cluster(MapCamera cam, List<LatLng> pts, String Function(_Pin) label, {double px = 40}) {
    final out = <_Pin>[];
    for (var i = 0; i < pts.length; i++) {
      final o = cam.latLngToScreenOffset(pts[i]);
      final at = out.indexWhere((p) => (p.at - o).distance < px);
      if (at < 0) {
        out.add(_Pin(pts[i], o, [i]));
      } else {
        out[at].items.add(i);
      }
    }
    // Badges are always shown; a label must clear them and the labels placed before it.
    final badges = {for (final p in out) p: Rect.fromCenter(center: p.at.translate(0, -15), width: 30, height: 30)};
    final placed = <Rect>[];
    for (final p in [...out]..sort((a, b) => b.items.length.compareTo(a.items.length))) {
      final w = (label(p).length * 6.6 + 20).clamp(40, 150).toDouble();
      final r = Rect.fromCenter(center: p.at.translate(0, -48), width: w, height: 24).inflate(3);
      if (placed.any((q) => q.overlaps(r)) || badges.entries.any((e) => e.key != p && e.value.overlaps(r))) {
        p.showLabel = false;
      } else {
        placed.add(r);
      }
    }
    return out;
  }

  List<LatLng> _points(GhazawatData g, SeerahData s) => switch (_tab) {
        AtlasTab.prophets => [for (final p in _places) LatLng(p.lat, p.lng)],
        AtlasTab.battles => [for (final b in g.list) LatLng(b.lat, b.lng)],
        AtlasTab.seerah => [for (final x in _seerahPlaces(g, s)) x.$2],
      };

  LatLng? _focus(GhazawatData g, SeerahData s) {
    if (widget.focusGhazwa != null) {
      final b = g.byId(widget.focusGhazwa!);
      if (b != null) return LatLng(b.lat, b.lng);
    }
    if (widget.focusSeerah != null) {
      for (final x in _seerahPlaces(g, s)) {
        if (x.$1.id == widget.focusSeerah) return x.$2;
      }
    }
    return null;
  }

  void _switch(AtlasTab t, GhazawatData g, SeerahData s) {
    setState(() => _tab = t);
    final pts = _points(g, s);
    if (pts.length > 1) {
      _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: _fitPadding, maxZoom: 7));
    } else if (pts.length == 1) {
      _map.move(pts.first, 6);
    }
  }

  String get _title => widget.prophetId != null
      ? 'أماكن قصة ${app.repo.prophets.firstWhere((p) => p.id == widget.prophetId).nameAr}'
      : switch (_tab) {
          AtlasTab.prophets => 'أطلس قصص الأنبياء',
          AtlasTab.battles => 'غزوات النبي ﷺ على الخريطة',
          AtlasTab.seerah => 'أماكن السيرة النبوية',
        };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('تعذّر تحميل البيانات: ${snap.error}'));
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          return _body(context, d.$1, d.$2);
        },
      ),
    );
  }

  bool _opened = false;

  Widget _body(BuildContext context, GhazawatData g, SeerahData s) {
    final pts = _points(g, s);
    final focus = _focus(g, s);
    if (!_opened && focus != null) {
      _opened = true;
      // Open the focused battle's / event's card once the map is shown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.focusGhazwa != null) {
          final b = g.byId(widget.focusGhazwa!);
          if (b != null) showBattleSheet(context, b);
        } else if (widget.focusSeerah != null) {
          final e = s.byId(widget.focusSeerah!);
          if (e != null) showSeerahEvent(context, e, ghazawat: g, fromMap: true);
        }
      });
    }
    return Column(children: [
      if (widget.prophetId == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<AtlasTab>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AtlasTab.prophets, label: Text('الأنبياء'), icon: Icon(Icons.auto_stories_outlined, size: 18)),
                ButtonSegment(value: AtlasTab.battles, label: Text('الغزوات'), icon: Text('⚔️', style: TextStyle(fontSize: 14))),
                ButtonSegment(value: AtlasTab.seerah, label: Text('السيرة'), icon: Icon(Icons.timeline, size: 18)),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => _switch(v.first, g, s),
            ),
          ),
        ),
      Expanded(
        child: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: focus == null && pts.length > 1
                  ? CameraFit.coordinates(coordinates: pts, padding: _fitPadding, maxZoom: 7)
                  : null,
              initialCenter: focus ?? (pts.isEmpty ? const LatLng(27, 40) : pts.first),
              initialZoom: focus != null ? 8 : (pts.length == 1 ? 6 : 4.4),
              minZoom: 3,
              maxZoom: 12,
            ),
            children: [
              _satellite
                  ? TileLayer(
                      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.mawaqeety.app')
                  : TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.mawaqeety.app'),
              // Battles and Seerah places are grouped by their distance on screen, so the groups follow the zoom.
              switch (_tab) {
                AtlasTab.prophets => MarkerLayer(markers: _prophetMarkers(context)),
                AtlasTab.battles => Builder(builder: (c) => MarkerLayer(markers: _battleMarkers(context, MapCamera.of(c), g))),
                AtlasTab.seerah => Builder(builder: (c) => MarkerLayer(markers: _seerahMarkers(context, MapCamera.of(c), g, s))),
              },
              RichAttributionWidget(alignment: AttributionAlignment.bottomLeft, attributions: [
                TextSourceAttribution(_satellite ? 'Esri, Maxar, Earthstar Geographics' : 'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse(_satellite ? 'https://www.esri.com' : 'https://www.openstreetmap.org/copyright'))),
              ]),
            ],
          ),
          Positioned(
            bottom: 26,
            right: 10,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: IconButton(
                tooltip: _satellite ? 'الخريطة' : 'قمر صناعي',
                icon: Icon(_satellite ? Icons.map_outlined : Icons.satellite_alt_outlined, color: Colors.black87),
                onPressed: () => setState(() => _satellite = !_satellite),
              ),
            ),
          ),
        ]),
      ),
      SizedBox(
        height: 112,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          children: switch (_tab) {
            AtlasTab.prophets => [
                for (final p in _places)
                  _card(context, p.name, _names(p), () {
                    _map.move(LatLng(p.lat, p.lng), 7);
                    _show(context, p);
                  }),
              ],
            AtlasTab.battles => [
                for (final b in g.list)
                  _card(context, b.name, b.date, () {
                    _map.move(LatLng(b.lat, b.lng), 8);
                    showBattleSheet(context, b);
                  }, leading: battleColor),
              ],
            AtlasTab.seerah => [
                for (final x in _seerahPlaces(g, s))
                  _card(context, x.$1.title, '${x.$1.badge} • ${x.$3}', () {
                    _map.move(x.$2, 8);
                    showSeerahEvent(context, x.$1, ghazawat: g, fromMap: true);
                  }, leading: x.$1.ghazwa != null ? battleColor : AppColors.emerald),
              ],
          },
        ),
      ),
    ]);
  }

  Widget _card(BuildContext context, String title, String subtitle, VoidCallback onTap, {Color? leading}) => SizedBox(
        width: 200,
        child: Card3D(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (leading != null) ...[
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: leading, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ]),
            ),
          ),
        ),
      );

  // ---------------------------------------------------------------- markers

  Widget _label(String text, Color color, Color border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border.withValues(alpha: 0.8)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );

  List<Marker> _prophetMarkers(BuildContext context) => [
        for (final p in _places)
          Marker(
            point: LatLng(p.lat, p.lng),
            width: 130,
            height: 58,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _show(context, p),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _label(p.name, AppColors.current.hero[1], AppColors.current.accentLight),
                Icon(Icons.location_on, color: AppColors.current.accentLight, size: 26,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
              ]),
            ),
          ),
      ];

  /// A round badge with crossed swords (battles) or a number (Seerah events).
  Widget _badge(String text, Color color, {bool big = false}) => Container(
        width: big ? 32 : 26,
        height: big ? 32 : 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Text(text, style: TextStyle(color: Colors.white, fontSize: big ? 15 : 12, fontWeight: FontWeight.w700, height: 1.1)),
      );

  List<Marker> _battleMarkers(BuildContext context, MapCamera cam, GhazawatData g) {
    String label(_Pin p) =>
        p.items.length == 1 ? g.list[p.items.first].name : [for (final i in p.items) _short(g.list[i].name)].join('، ');
    final pins = _cluster(cam, [for (final b in g.list) LatLng(b.lat, b.lng)], label);
    return [
      for (final pin in pins)
        Marker(
          point: pin.point,
          width: 150,
          height: 62,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => pin.items.length == 1
                ? showBattleSheet(context, g.list[pin.items.first])
                : _pickBattle(context, [for (final i in pin.items) g.list[i]]),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (pin.showLabel) _label(label(pin), const Color(0xFF6B1410), AppColors.goldLight),
              const SizedBox(height: 2),
              _badge(pin.items.length == 1 ? '⚔' : Arabic.digits(pin.items.length), battleColor,
                  big: pin.items.any((i) => g.list[i].id == widget.focusGhazwa)),
            ]),
          ),
        ),
    ];
  }

  static String _mostFrequent(List<String> names) {
    final count = <String, int>{};
    for (final n in names) {
      count[n] = (count[n] ?? 0) + 1;
    }
    return count.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// «غزوة بدر الكبرى» → «بدر».
  static String _short(String name) {
    var n = name.replaceFirst('غزوة ', '').replaceFirst('صلح ', '');
    final i = n.indexOf(' (');
    if (i > 0) n = n.substring(0, i);
    return n.replaceFirst(' الكبرى', '');
  }

  void _pickBattle(BuildContext context, List<Ghazwa> list) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final b in list)
              ListTile(
                leading: _badge('⚔', battleColor),
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(b.date),
                onTap: () {
                  Navigator.pop(c);
                  showBattleSheet(context, b);
                },
              ),
          ]),
        ),
      );

  List<Marker> _seerahMarkers(BuildContext context, MapCamera cam, GhazawatData g, SeerahData s) {
    final places = _seerahPlaces(g, s);
    // A group is named after its most frequent place (Makkah, Madinah…).
    String label(_Pin p) =>
        p.items.length == 1 ? places[p.items.first].$1.title : _mostFrequent([for (final i in p.items) places[i].$3]);
    final pins = _cluster(cam, [for (final x in places) x.$2], label);
    return [
      for (final pin in pins)
        Marker(
          point: pin.point,
          width: 150,
          height: 62,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => pin.items.length == 1
                ? showSeerahEvent(context, places[pin.items.first].$1, ghazawat: g, fromMap: true)
                : _pickEvent(context, [for (final i in pin.items) places[i].$1], g),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (pin.showLabel) _label(label(pin), AppColors.current.hero[1], AppColors.current.accentLight),
              const SizedBox(height: 2),
              _badge(
                Arabic.digits(pin.items.length),
                pin.items.every((i) => places[i].$1.ghazwa != null) ? battleColor : AppColors.emerald,
                big: pin.items.any((i) => places[i].$1.id == widget.focusSeerah),
              ),
            ]),
          ),
        ),
    ];
  }

  void _pickEvent(BuildContext context, List<SeerahEvent> list, GhazawatData g) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
            child: ListView(shrinkWrap: true, children: [
              for (final e in list)
                ListTile(
                  leading: _badge(e.ghazwa != null ? '⚔' : '•', e.ghazwa != null ? battleColor : AppColors.emerald),
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${e.hijriLabel} • ${e.ceLabel}'),
                  onTap: () {
                    Navigator.pop(c);
                    showSeerahEvent(context, e, ghazawat: g, fromMap: true);
                  },
                ),
            ]),
          ),
        ),
      );

  // ---------------------------------------------------------------- prophets

  String _names(AtlasPlace p) => [
        for (final id in p.prophets) app.repo.prophets.firstWhere((x) => x.id == id).nameAr,
      ].join('، ');

  void _show(BuildContext context, AtlasPlace p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (p.certainty == AtlasCertainty.text ? AppColors.emerald : AppColors.gold).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(p.certainty.label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                      color: p.certainty == AtlasCertainty.text ? AppColors.emerald : AppColors.gold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(p.note, style: const TextStyle(height: 1.8, fontSize: 15)),
          const SizedBox(height: 4),
          Text('المصدر: سورة ${p.source}', style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in p.prophets)
              ActionChip(
                avatar: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text('قصة ${app.repo.prophets.firstWhere((x) => x.id == id).nameAr}'),
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProphetPage(prophet: app.repo.prophets.firstWhere((x) => x.id == id))));
                },
              ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- battle sheet

/// The card of a battle on the atlas: date, place, result, «اقرأ الغزوة» and «استمع».
void showBattleSheet(BuildContext context, Ghazwa b) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final hint = Theme.of(c).hintColor;
      Widget row(IconData icon, String label, String value) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: AppColors.gold),
              const SizedBox(width: 6),
              Text('$label: ', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              Expanded(child: Text(value, style: const TextStyle(height: 1.5))),
            ]),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: battleColor, shape: BoxShape.circle),
                child: const Text('⚔', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(b.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              if (!b.isBattle)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                  child: Text('صلح وليس غزوة', style: TextStyle(fontSize: 11.5, color: AppColors.emerald, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 6),
            row(Icons.event_outlined, 'التاريخ', b.date),
            row(Icons.place_outlined, 'المكان', b.approx ? '${b.place} — الموضع على الخريطة تقريبي' : b.place),
            if (b.result.isNotEmpty) row(Icons.flag_outlined, 'النتيجة', b.result),
            const SizedBox(height: 8),
            Text(b.summary, style: TextStyle(height: 1.8, color: hint)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GhazwaPage(g: b)));
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('اقرأ الغزوة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _BattleListen(b)),
            ]),
          ]),
        ),
      );
    },
  );
}

class _BattleListen extends StatelessWidget {
  final Ghazwa b;
  const _BattleListen(this.b);
  @override
  Widget build(BuildContext context) {
    final audio = GhazwaAudio.instance;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final mine = audio.currentId == b.id;
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black87),
          onPressed: mine && audio.loading
              ? null
              : () async {
                  if (mine && audio.playing) return audio.pause();
                  if (mine) return audio.resume();
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await playGhazwa(b.id);
                  if (!ok) messenger.showSnackBar(const SnackBar(content: Text('التسجيل الصوتي قريبًا')));
                },
          icon: mine && audio.loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(mine && audio.playing ? Icons.pause : Icons.headphones),
          label: Text(mine && audio.playing ? 'إيقاف مؤقت' : 'استمع'),
        );
      },
    );
  }
}
