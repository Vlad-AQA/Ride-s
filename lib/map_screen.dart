import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'add_marker_panel.dart';
import 'config.dart';
import 'i18n.dart';
import 'marker_sheet.dart';
import 'models.dart';
import 'pin.dart';
import 'repo.dart';
import 'settings_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.repo});

  final Repo repo;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final _map = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _me;
  bool _placing = false;
  String? _centerAddress;
  Timer? _geocodeDebounce;

  Repo get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repo.start().catchError((Object e) => _toast(tr('err_generic')));
    _startLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _geocodeDebounce?.cancel();
    repo.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) repo.refresh().catchError((_) {});
  }

  Future<void> _startLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    final first = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _me = LatLng(first.latitude, first.longitude));
    _map.move(_me!, 14);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 15),
    ).listen((p) {
      if (mounted) setState(() => _me = LatLng(p.latitude, p.longitude));
    });
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _startPlacing() {
    if (_me == null) {
      _toast(tr('err_location'));
      _startLocation();
      return;
    }
    _map.move(_me!, _map.camera.zoom < 15 ? 16 : _map.camera.zoom);
    setState(() => _placing = true);
    _geocodeCenter();
  }

  void _onMapEvent(MapEvent e) {
    if (_placing && e is MapEventMoveEnd) {
      _geocodeDebounce?.cancel();
      _geocodeDebounce = Timer(const Duration(milliseconds: 400), _geocodeCenter);
    }
  }

  Future<void> _geocodeCenter() async {
    final c = _map.camera.center;
    String? address;
    try {
      final places = await Geocoding().placemarkFromCoordinates(
        c.latitude,
        c.longitude,
        locale: Locale(lang.value),
      );
      if (places.isNotEmpty) {
        final p = places.first;
        address = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .toSet()
            .join(', ');
      }
    } catch (_) {
      // Геокодер недоступен (нет сети или платформа) — обойдёмся координатами.
    }
    if (!mounted || !_placing) return;
    setState(() => _centerAddress = (address == null || address.isEmpty)
        ? '${c.latitude.toStringAsFixed(5)}, ${c.longitude.toStringAsFixed(5)}'
        : address);
  }

  Future<void> _submit(MarkerType type, String comment) async {
    await repo.addMarker(
      type: type,
      point: _map.camera.center,
      me: _me!,
      address: _centerAddress,
      comment: comment.trim().isEmpty ? null : comment.trim(),
    );
    if (!mounted) return;
    setState(() => _placing = false);
    _toast(tr('added'));
  }

  void _openMarker(RoadMarker m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => MarkerSheet(repo: repo, markerId: m.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: const LatLng(thailandCenterLat, thailandCenterLng),
        initialZoom: 6,
        minZoom: 4,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapEvent: _onMapEvent,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'app.thairide.thairide',
        ),
        if (_me != null)
          MarkerLayer(markers: [
            Marker(point: _me!, width: 22, height: 22, child: const _MeDot()),
          ]),
        ListenableBuilder(
          listenable: Listenable.merge([repo.markers, repo.visibleTypes]),
          builder: (context, _) {
            final visible = repo.visibleTypes.value;
            final list = repo.markers.value.values
                .where((m) => m.isAlive && visible.contains(m.type))
                .toList()
              ..sort((a, b) => a.isFresh == b.isFresh ? 0 : (a.isFresh ? 1 : -1));
            return MarkerLayer(
              markers: [
                for (final m in list)
                  Marker(
                    point: m.point,
                    width: pinWidth,
                    height: pinHeight,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: _placing ? null : () => _openMarker(m),
                      child: Pin(type: m.type, fresh: m.isFresh, hasComments: m.commentsCount > 0),
                    ),
                  ),
              ],
            );
          },
        ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap © CARTO', style: TextStyle(fontSize: 10, color: Colors.black)),
        ),
      ],
    );

    final mapWithControls = Stack(
      children: [
        map,
        if (_placing) ...[
          // Прицел: кончик пина указывает ровно в центр карты.
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: pinHeight),
              child: IgnorePointer(child: Pin(type: MarkerType.checkpoint, fresh: true)),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: _Hint(text: tr('pick_point')),
          ),
        ],
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + 12,
          bottom: 12,
          child: Column(
            children: [
              if (!_placing)
                _RoundButton(
                  icon: Icons.settings,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SettingsScreen(repo: repo)),
                  ),
                ),
              const Spacer(),
              _RoundButton(
                icon: Icons.near_me,
                onTap: () => _me == null ? _startLocation() : _map.move(_me!, 15),
              ),
              const SizedBox(height: 10),
              _RoundButton(
                icon: Icons.add,
                onTap: () => _map.move(_map.camera.center, _map.camera.zoom + 1),
              ),
              const SizedBox(height: 10),
              _RoundButton(
                icon: Icons.remove,
                onTap: () => _map.move(_map.camera.center, _map.camera.zoom - 1),
              ),
              SizedBox(height: _placing ? 8 : 84),
            ],
          ),
        ),
        if (!_placing)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              onPressed: _startPlacing,
              icon: const Icon(Icons.add_location_alt),
              label: Text(tr('place_marker')),
            ),
          ),
      ],
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _placing
          ? Column(
              children: [
                Expanded(child: mapWithControls),
                AddMarkerPanel(
                  address: _centerAddress,
                  onCancel: () => setState(() => _placing = false),
                  onSubmit: _submit,
                ),
              ],
            )
          : mapWithControls,
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E6BFF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Color(0x881E6BFF))],
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xE62A2D34),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white)),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xE62A2D34),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      );
}
