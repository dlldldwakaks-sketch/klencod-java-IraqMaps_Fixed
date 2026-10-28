import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() => runApp(const IraqMapsApp());

class IraqMapsApp extends StatelessWidget {
  const IraqMapsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Iraq Maps',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const MapHome(),
  );
}

class MapHome extends StatefulWidget {
  const MapHome({super.key});
  @override
  State<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> {
  final MapController map = MapController();
  final TextEditingController search = TextEditingController();
  final TextEditingController destination = TextEditingController();
  LatLng center = const LatLng(31.0570, 46.2573); // Default view: Nasiriyah, not GPS.
  LatLng? myLocation, selectedPlace;
  List<LatLng> route = [];
  List<Map<String, dynamic>> results = [];
  bool busy = false;
  String? message;

  @override
  void dispose() {
    search.dispose();
    destination.dispose();
    super.dispose();
  }

  Future<LatLng> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('شغّل خدمة الموقع GPS أولاً.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('اسمح للتطبيق بالوصول إلى موقعك من الإعدادات.');
    }
    final p = await Geolocator.getCurrentPosition();
    return LatLng(p.latitude, p.longitude);
  }

  Future<void> locateMe() async {
    setState(() { busy = true; message = null; });
    try {
      final point = await getCurrentPosition();
      if (!mounted) return;
      setState(() { myLocation = point; center = point; message = 'تم تحديد موقعك.'; });
      map.move(point, 15);
    } catch (e) {
      if (mounted) setState(() => message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<List<Map<String, dynamic>>> geocode(String q, {int limit = 5}) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q, 'format': 'jsonv2', 'limit': '$limit', 'accept-language': 'ar'
    });
    final r = await http.get(uri, headers: {'User-Agent': 'IraqMaps/1.0 (Android app)'})
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('خدمة البحث غير متاحة الآن.');
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> searchPlaces() async {
    if (search.text.trim().isEmpty) {
      setState(() => message = 'اكتب اسم مدينة أو شارع أو مكان.');
      return;
    }
    setState(() { busy = true; message = null; results = []; });
    try {
      final found = await geocode(search.text.trim());
      if (!mounted) return;
      setState(() { results = found; if (found.isEmpty) message = 'لم نعثر على نتائج.'; });
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر البحث. تحقق من الإنترنت وحاول لاحقًا.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void selectPlace(Map<String, dynamic> item) {
    final p = LatLng(double.parse(item['lat'].toString()), double.parse(item['lon'].toString()));
    setState(() {
      selectedPlace = p; center = p; search.text = (item['display_name'] ?? '').toString();
      results = []; message = 'تم تحديد المكان.';
    });
    map.move(p, 15);
  }

  Future<void> buildRoute() async {
    if (destination.text.trim().isEmpty) {
      setState(() => message = 'اكتب الوجهة أولاً.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      final start = myLocation ?? await getCurrentPosition();
      final found = await geocode(destination.text.trim(), limit: 1);
      if (found.isEmpty) throw Exception('لم يتم العثور على الوجهة.');
      final item = found.first;
      final end = LatLng(double.parse(item['lat'].toString()), double.parse(item['lon'].toString()));
      final uri = Uri.https('router.project-osrm.org',
        '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
        {'overview': 'full', 'geometries': 'geojson'});
      final r = await http.get(uri).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('خدمة رسم الطرق غير متاحة.');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final routes = data['routes'] as List;
      if (routes.isEmpty) throw Exception('لم يُعثر على طريق بين النقطتين.');
      final first = routes.first as Map<String, dynamic>;
      final coords = first['geometry']['coordinates'] as List;
      final points = coords.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
      final km = ((first['distance'] as num).toDouble() / 1000).toStringAsFixed(1);
      final mins = (((first['duration'] as num).toDouble()) / 60).round();
      if (!mounted) return;
      setState(() {
        myLocation = start; selectedPlace = end; route = points;
        message = 'المسافة: $km كم — المدة التقديرية: $mins دقيقة (قد لا تشمل حركة المرور).';
      });
      if (points.isNotEmpty) map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(48)));
    } catch (e) {
      if (mounted) setState(() => message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void clearRoute() => setState(() { route = []; message = 'تم مسح المسار.'; });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (myLocation != null) Marker(point: myLocation!, width: 42, height: 42,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 34)),
      if (selectedPlace != null) Marker(point: selectedPlace!, width: 42, height: 42,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
    ];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('Iraq Maps | خرائط العراق'), centerTitle: true),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 3), child: Row(children: [
          Expanded(child: TextField(controller: search, textInputAction: TextInputAction.search,
            onSubmitted: (_) => searchPlaces(), decoration: const InputDecoration(
              hintText: 'ابحث عن مدينة أو شارع أو مكان', prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 6),
          IconButton.filled(onPressed: busy ? null : searchPlaces, icon: const Icon(Icons.search)),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(10, 3, 10, 6), child: Row(children: [
          Expanded(child: TextField(controller: destination, textInputAction: TextInputAction.done,
            onSubmitted: (_) => buildRoute(), decoration: const InputDecoration(
              hintText: 'الوجهة لرسم الطريق', prefixIcon: Icon(Icons.flag),
              border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 6),
          FilledButton(onPressed: busy ? null : buildRoute, child: const Text('ارسم الطريق')),
        ])),
        if (busy) const LinearProgressIndicator(),
        if (message != null) Padding(padding: const EdgeInsets.all(6),
          child: Text(message!, style: Theme.of(context).textTheme.bodySmall)),
        if (results.isNotEmpty) SizedBox(height: 140, child: ListView.builder(
          itemCount: results.length, itemBuilder: (context, i) {
            final item = results[i];
            return ListTile(dense: true, leading: const Icon(Icons.place),
              title: Text('${item['display_name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => selectPlace(item));
          })),
        Expanded(child: FlutterMap(mapController: map,
          options: MapOptions(initialCenter: center, initialZoom: 7),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mymap.iraq'),
            if (route.isNotEmpty) PolylineLayer(polylines: [
              Polyline(points: route, strokeWidth: 5, color: Colors.blue)]),
            MarkerLayer(markers: markers),
            RichAttributionWidget(attributions: const [
              TextSourceAttribution('© OpenStreetMap contributors')]),
          ])),
      ]),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(heroTag: 'clear', onPressed: clearRoute,
          tooltip: 'مسح المسار', child: const Icon(Icons.clear)),
        const SizedBox(height: 10),
        FloatingActionButton(heroTag: 'gps', onPressed: busy ? null : locateMe,
          tooltip: 'موقعي الحالي', child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location)),
      ]),
    ));
  }
}
