import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';

/// What the customer confirmed on the map.
class PickedLocation {
  final double latitude;
  final double longitude;

  /// Street/area name for the point, when the map service knows it.
  final String? address;
  const PickedLocation(this.latitude, this.longitude, {this.address});
}

/// Full-screen map for choosing the delivery point. The pin stays in the
/// middle; the customer moves the map, searches for a place, or jumps to their
/// current location. Lets someone in another city order for a delivery near
/// one of our branches.
class LocationPickerView extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  const LocationPickerView({super.key, this.latitude, this.longitude});

  /// Map tiles. Tests set this to null so no network images are requested.
  static String? tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  State<LocationPickerView> createState() => _LocationPickerViewState();
}

/// Place search and street names come from OpenStreetMap's Nominatim service
/// (free, no key; it asks for an identifying User-Agent and no more than one
/// request per second, so searches only run when the customer submits).
class Geocoder {
  static const _host = 'nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'Grozo/2.0 (com.iftikhar.grozo)',
    'Accept-Language': 'en'
  };

  static Future<List<({String name, LatLng point})>> search(String text) async {
    try {
      final res = await Api.client
          .get(
              Uri.https(_host, '/search', {
                'q': text,
                'format': 'jsonv2',
                'limit': '6',
                'countrycodes': 'pk',
              }),
              headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      return [
        for (final r in jsonDecode(utf8.decode(res.bodyBytes)) as List)
          (
            name: '${r['display_name']}',
            point: LatLng(
                double.parse('${r['lat']}'), double.parse('${r['lon']}')),
          )
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> nameOf(LatLng p) async {
    try {
      final res = await Api.client
          .get(
              Uri.https(_host, '/reverse', {
                'lat': '${p.latitude}',
                'lon': '${p.longitude}',
                'format': 'jsonv2',
                'zoom': '18',
              }),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final a = jsonDecode(utf8.decode(res.bodyBytes))['address'];
      if (a is! Map) return null;
      final parts = [
        a['house_number'],
        a['road'],
        a['neighbourhood'] ?? a['suburb'] ?? a['village'],
      ].where((x) => x != null && '$x'.isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}

/// Distance in km to the nearest active branch, with that branch.
({double km, Map<String, dynamic> branch})? nearestBranch(
    List<Map<String, dynamic>> branches, double lat, double lng) {
  const distance = Distance();
  ({double km, Map<String, dynamic> branch})? best;
  for (final b in branches) {
    final bl = double.tryParse('${b['latitude']}');
    final bg = double.tryParse('${b['longitude']}');
    if (bl == null || bg == null) continue;
    final km =
        distance.as(LengthUnit.Meter, LatLng(lat, lng), LatLng(bl, bg)) / 1000;
    if (best == null || km < best.km) best = (km: km, branch: b);
  }
  return best;
}

/// Furthest distance we deliver, from the admin's delivery-charge tiers.
Future<double?> loadMaxDeliveryKm() async {
  final res = await Api.get('/delivery-charges');
  if (!res.ok || res.data is! List || (res.data as List).isEmpty) return null;
  return (res.data as List)
      .map((t) => double.tryParse('${t['max_km']}') ?? 0)
      .reduce(math.max);
}

class _LocationPickerViewState extends State<LocationPickerView> {
  final _map = MapController();
  final _search = TextEditingController();
  late LatLng _center;
  double? _maxKm;
  bool _searching = false;
  bool _locating = false;
  bool _confirming = false;

  // Abbottabad, used when there is neither a saved point nor a branch location.
  static const _fallback = LatLng(34.1688, 73.2215);

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (widget.latitude != null && widget.longitude != null) {
      _center = LatLng(widget.latitude!, widget.longitude!);
    } else {
      final b = state.selectedBranch;
      final lat = double.tryParse('${b?['latitude']}');
      final lng = double.tryParse('${b?['longitude']}');
      _center = lat != null && lng != null ? LatLng(lat, lng) : _fallback;
    }
    if (state.branches.isEmpty) state.loadBranches();
    loadMaxDeliveryKm().then((km) {
      if (mounted) setState(() => _maxKm = km);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _moveTo(LatLng p, {double zoom = 17}) {
    _map.move(p, zoom);
    setState(() => _center = p);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _runSearch() async {
    final text = _search.text.trim();
    if (text.length < 3) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final results = await Geocoder.search(text);
    if (!mounted) return;
    setState(() => _searching = false);
    if (results.isEmpty) return _toast(context.tr('no_places_found'));
    if (results.length == 1) return _moveTo(results.single.point);
    final picked = await showModalBottomSheet<LatLng>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final r in results)
            ListTile(
              leading: const Icon(Icons.place_outlined, color: brandPrimary),
              title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(ctx, r.point),
            ),
        ]),
      ),
    );
    if (picked != null) _moveTo(picked);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) _toast(context.tr('location_off'));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) _toast(context.tr('location_denied'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      if (mounted) _moveTo(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      if (mounted) _toast(context.tr('err_generic'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    final name = await Geocoder.nameOf(_center);
    if (!mounted) return;
    Navigator.pop(context,
        PickedLocation(_center.latitude, _center.longitude, address: name));
  }

  @override
  Widget build(BuildContext context) {
    final branches = context.watch<AppState>().branches;
    final near = nearestBranch(branches, _center.latitude, _center.longitude);
    final far = near != null && _maxKm != null && near.km > _maxKm!;
    final lang = context.lang;
    String branchName(Map<String, dynamic> b) =>
        (lang == 'ur' && '${b['name_ur'] ?? ''}'.isNotEmpty
                ? b['name_ur']
                : b['name'])
            .toString();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('delivery_location'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              isDense: true,
              hintText: context.tr('search_place'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      tooltip: context.tr('search_place'),
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _runSearch),
            ),
          ),
        ),
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: widget.latitude != null ? 17 : 14,
                onPositionChanged: (camera, _) =>
                    setState(() => _center = camera.center),
              ),
              children: [
                if (LocationPickerView.tileUrl != null)
                  TileLayer(
                    urlTemplate: LocationPickerView.tileUrl,
                    userAgentPackageName: 'com.iftikhar.grozo',
                  ),
                MarkerLayer(markers: [
                  for (final b in branches)
                    if (double.tryParse('${b['latitude']}') != null &&
                        double.tryParse('${b['longitude']}') != null)
                      Marker(
                        point: LatLng(double.parse('${b['latitude']}'),
                            double.parse('${b['longitude']}')),
                        width: 34,
                        height: 34,
                        child: Tooltip(
                          message: branchName(b),
                          child: const CircleAvatar(
                              backgroundColor: brandPrimary,
                              child: Icon(Icons.storefront,
                                  color: Colors.white, size: 18)),
                        ),
                      ),
                ]),
                // Credit required by OpenStreetMap's tile terms.
                Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: GestureDetector(
                    onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright')),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      color: Colors.white70,
                      child: const Text('© OpenStreetMap',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
              ],
            ),
            // The pin marks the middle of the map; its tip is the chosen point.
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 44),
                  child: Icon(Icons.location_on, color: Colors.red, size: 48),
                ),
              ),
            ),
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'my_location',
                tooltip: context.tr('use_my_location'),
                backgroundColor: Colors.white,
                foregroundColor: brandPrimary,
                onPressed: _locating ? null : _useCurrentLocation,
                child: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
              ),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(context.tr('move_map_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            if (near != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  far
                      ? context.trf('far_from_branches',
                          {'km': near.km.toStringAsFixed(0)})
                      : context.trf('nearest_branch', {
                          'km': near.km.toStringAsFixed(1),
                          'branch': branchName(near.branch)
                        }),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: far ? Colors.red.shade700 : brandGreen),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
                onPressed: _confirming ? null : _confirm,
                icon: _confirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(context.tr('confirm_location')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
