import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../core/qibla.dart';
import '../main.dart';
import 'theme.dart';

const _kaaba = LatLng(Qibla.kaabaLat, Qibla.kaabaLng);

/// A mosque found near the user (OpenStreetMap data via the Overpass API).
class Mosque {
  final String name;
  final LatLng at;
  final double meters;
  const Mosque(this.name, this.at, this.meters);
}

/// Points along the great circle from [a] to the Kaaba, so the line is the real qibla direction everywhere.
List<LatLng> _greatCircle(LatLng a, {int n = 128}) {
  double r(double d) => d * math.pi / 180;
  double g(double x) => x * 180 / math.pi;
  final p1 = r(a.latitude), l1 = r(a.longitude), p2 = r(_kaaba.latitude), l2 = r(_kaaba.longitude);
  final d = 2 * math.asin(math.sqrt(math.pow(math.sin((p2 - p1) / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin((l2 - l1) / 2), 2)));
  if (d == 0) return [a];
  return [
    for (var i = 0; i <= n; i++)
      () {
        final f = i / n, ka = math.sin((1 - f) * d) / math.sin(d), kb = math.sin(f * d) / math.sin(d);
        final x = ka * math.cos(p1) * math.cos(l1) + kb * math.cos(p2) * math.cos(l2);
        final y = ka * math.cos(p1) * math.sin(l1) + kb * math.cos(p2) * math.sin(l2);
        final z = ka * math.sin(p1) + kb * math.sin(p2);
        return LatLng(g(math.atan2(z, math.sqrt(x * x + y * y))), g(math.atan2(y, x)));
      }(),
  ];
}

/// The qibla on a map: your place, a golden line along the great circle to the Kaaba, street or satellite view,
/// and the mosques around you.
class QiblaMap extends StatefulWidget {
  const QiblaMap({super.key});
  @override
  State<QiblaMap> createState() => _QiblaMapState();
}

class _QiblaMapState extends State<QiblaMap> {
  final _map = MapController();
  late LatLng _me = LatLng(app.settings.place.lat, app.settings.place.lng);
  bool _precise = false, _satellite = false, _loading = false;
  List<Mosque>? _mosques;
  String? _note;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _me = LatLng(p.latitude, p.longitude);
        _precise = true;
      });
      _map.move(_me, 17);
    } catch (_) {
      // Keep the chosen city.
    }
  }

  Future<void> _findMosques() async {
    setState(() { _loading = true; _note = null; });
    final q = '[out:json][timeout:20];('
        'node["amenity"="place_of_worship"]["religion"="muslim"](around:2500,${_me.latitude},${_me.longitude});'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:2500,${_me.latitude},${_me.longitude}););out center 60;';
    try {
      final r = await http.post(Uri.parse('https://overpass-api.de/api/interpreter'), body: {'data': q}).timeout(const Duration(seconds: 25));
      final els = (jsonDecode(utf8.decode(r.bodyBytes))['elements'] as List?) ?? const [];
      const dist = Distance();
      final list = <Mosque>[
        for (final e in els)
          if ((e['lat'] ?? e['center']?['lat']) != null)
            () {
              final at = LatLng((e['lat'] ?? e['center']['lat']).toDouble(), (e['lon'] ?? e['center']['lon']).toDouble());
              final t = (e['tags'] ?? {}) as Map;
              return Mosque((t['name:ar'] ?? t['name'] ?? 'مسجد').toString(), at, dist(_me, at));
            }(),
      ]..sort((a, b) => a.meters.compareTo(b.meters));
      if (!mounted) return;
      setState(() {
        _mosques = list;
        _note = list.isEmpty ? 'لم نجد مساجد مسجّلة في الخريطة حولك' : null;
      });
      if (list.isNotEmpty) {
        _map.fitCamera(CameraFit.coordinates(coordinates: [_me, ...list.take(12).map((m) => m.at)], padding: const EdgeInsets.all(48)));
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'تعذّر تحميل المساجد، تأكد من الاتصال بالإنترنت');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _directions(Mosque m) => launchUrl(
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${m.at.latitude},${m.at.longitude}'),
        mode: LaunchMode.externalApplication,
      );

  String _dist(double m) => m < 1000 ? '${Arabic.digits(m.round())} م' : '${Arabic.digits((m / 1000).toStringAsFixed(1))} كم';

  @override
  Widget build(BuildContext context) {
    final q = Qibla.bearing(_me.latitude, _me.longitude);
    const gold = Color(0xFFFFC83D); // bright gold reads on streets and on satellite images
    return Column(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(initialCenter: _me, initialZoom: _precise ? 17 : 15, maxZoom: 19, minZoom: 2),
              children: [
                _satellite
                    ? TileLayer(
                        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.mawaqeety.app',
                        maxNativeZoom: 19,
                      )
                    : TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mawaqeety.app',
                        maxNativeZoom: 19,
                      ),
                PolylineLayer(polylines: [
                  Polyline(points: _greatCircle(_me), color: Colors.black45, strokeWidth: 9),
                  Polyline(points: _greatCircle(_me), color: gold, strokeWidth: 5),
                ]),
                MarkerLayer(markers: [
                  for (final m in _mosques ?? const <Mosque>[])
                    Marker(
                      point: m.at,
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => _directions(m),
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.current.primary, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)]),
                          child: const Center(child: Text('🕌', style: TextStyle(fontSize: 16))),
                        ),
                      ),
                    ),
                  Marker(
                    point: _me,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
                    ),
                  ),
                  Marker(point: _kaaba, width: 30, height: 30, child: const Text('🕋', style: TextStyle(fontSize: 24))),
                ]),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(_satellite ? 'Esri, Maxar, Earthstar Geographics' : 'OpenStreetMap contributors',
                        onTap: () => launchUrl(Uri.parse(_satellite ? 'https://www.esri.com' : 'https://www.openstreetmap.org/copyright'))),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(width: 22, height: 5, decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('الخط الذهبي يتجه إلى الكعبة • ${Arabic.digits(q.round())}° من الشمال',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
            Positioned(
              bottom: 26,
              right: 10,
              child: Column(children: [
                _fab(_satellite ? Icons.map_outlined : Icons.satellite_alt_outlined, _satellite ? 'الخريطة' : 'قمر صناعي',
                    () => setState(() => _satellite = !_satellite)),
                const SizedBox(height: 8),
                _fab(Icons.my_location, 'موقعي', () { _map.move(_me, 17); if (!_precise) _locate(); }),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (!_precise)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(kIsWeb ? 'الخريطة على موقع مدينتك؛ اسمح للمتصفح بتحديد موقعك لدقة أكبر.' : 'الخريطة على موقع مدينتك؛ فعّل تحديد الموقع لدقة أكبر.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('🕌'),
            label: Text(_mosques == null ? 'المساجد القريبة' : 'تحديث المساجد'),
            onPressed: _loading ? null : _findMosques,
          ),
        ),
        if (_mosques != null && _mosques!.isNotEmpty) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(icon: const Icon(Icons.list), label: Text(Arabic.digits(_mosques!.length)), onPressed: () => _list(context)),
        ],
      ]),
      if (_note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_note!, style: const TextStyle(fontSize: 12.5))),
    ]);
  }

  Widget _fab(IconData icon, String tip, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: IconButton(tooltip: tip, icon: Icon(icon, color: Colors.black87), onPressed: onTap),
      );

  void _list(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(padding: const EdgeInsets.only(bottom: 20), children: [
        for (final m in _mosques!)
          ListTile(
            leading: const Text('🕌', style: TextStyle(fontSize: 22)),
            title: Text(m.name),
            subtitle: Text(_dist(m.meters)),
            trailing: const Icon(Icons.directions),
            onTap: () => _directions(m),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('بيانات المساجد من OpenStreetMap، وقد لا تشمل كل المساجد.',
              style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
        ),
      ]),
    );
  }
}
