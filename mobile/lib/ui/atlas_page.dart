import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/atlas.dart';
import '../main.dart';
import 'prophets_page.dart';
import 'theme.dart';

/// أطلس قصص الأنبياء: the places of the stories on a map; a place opens its note, source and stories.
class AtlasPage extends StatefulWidget {
  final String? prophetId; // highlight this prophet's places
  const AtlasPage({super.key, this.prophetId});
  @override
  State<AtlasPage> createState() => _AtlasPageState();
}

class _AtlasPageState extends State<AtlasPage> {
  final _map = MapController();
  bool _satellite = false;

  List<AtlasPlace> get _places =>
      widget.prophetId == null ? atlasPlaces : atlasPlaces.where((p) => p.prophets.contains(widget.prophetId)).toList();

  @override
  Widget build(BuildContext context) {
    final places = _places;
    final name = widget.prophetId == null ? null : app.repo.prophets.firstWhere((p) => p.id == widget.prophetId).nameAr;
    final pts = [for (final p in places) LatLng(p.lat, p.lng)];
    return Scaffold(
      appBar: AppBar(title: Text(name == null ? 'أطلس قصص الأنبياء' : 'أماكن قصة $name')),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCameraFit: pts.length > 1
                    ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(48), maxZoom: 7)
                    : null,
                initialCenter: pts.isEmpty ? const LatLng(27, 40) : pts.first,
                initialZoom: pts.length == 1 ? 6 : 4.4,
                minZoom: 3,
                maxZoom: 12,
              ),
              children: [
                _satellite
                    ? TileLayer(
                        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.mawaqeety.app')
                    : TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.mawaqeety.app'),
                MarkerLayer(markers: [
                  for (final p in places)
                    Marker(
                      point: LatLng(p.lat, p.lng),
                      width: 130,
                      height: 58,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _show(context, p),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.current.hero[1].withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.current.accentLight.withValues(alpha: 0.8)),
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                            ),
                            child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                          Icon(Icons.location_on, color: AppColors.current.accentLight, size: 26,
                              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
                        ]),
                      ),
                    ),
                ]),
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
            children: [
              for (final p in places)
                SizedBox(
                  width: 200,
                  child: Card3D(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        _map.move(LatLng(p.lat, p.lng), 7);
                        _show(context, p);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(_names(p), maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

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
