import 'package:flutter/material.dart';
import 'directions_preview.dart';
import 'itinerary_place_content.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteMapStop {
  const RouteMapStop({
    this.directionsToHere,
    this.airportAccessUrl,
    this.useProvidedDirections = false,
    this.outgoingDirections = false,
    this.incomingDirections = false,
    required this.name,
    required this.detail,
    required this.latitude,
    required this.longitude,
  });
  final Uri? directionsToHere;
  final Uri? airportAccessUrl;
  final bool useProvidedDirections;
  final bool outgoingDirections;
  final bool incomingDirections;
  final String name, detail;
  final double latitude, longitude;
  bool get hasLocation =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      (latitude != 0 || longitude != 0);
  LatLng get position => LatLng(latitude, longitude);
}

class RouteMapPath {
  const RouteMapPath({required this.coordinates, required this.source});
  final List<List<double>> coordinates;
  final String source;
  List<LatLng> get points => coordinates
      .where(
        (p) =>
            p.length == 2 &&
            p.every((v) => v.isFinite) &&
            p[0].abs() <= 90 &&
            p[1].abs() <= 180,
      )
      .map((p) => LatLng(p[0], p[1]))
      .toList();
}

class ItineraryRouteMap extends StatefulWidget {
  const ItineraryRouteMap({
    super.key,
    required this.stops,
    this.loadTiles = true,
    this.paths = const [],
    this.openDirections,
    this.selectedStopIndex,
    this.selectionRevision = 0,
    this.onStopSelected,
  });
  final List<RouteMapStop> stops;
  final int? selectedStopIndex;
  final int selectionRevision;
  final ValueChanged<int>? onStopSelected;
  final bool loadTiles;
  final List<RouteMapPath> paths;
  final Future<bool> Function(Uri)? openDirections;
  @override
  State<ItineraryRouteMap> createState() => _ItineraryRouteMapState();
}

class _ItineraryRouteMapState extends State<ItineraryRouteMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _interactive = true;
  // 현재 선택한 방문 장소의 인덱스. 선택 전에는 모든 핀이 파란색입니다.
  int? _selectedStopIndex;
  int? get _selection => widget.selectedStopIndex ?? _selectedStopIndex;
  void _activateStop(int index) {
    final wasSelected = _selection == index;
    setState(() => _selectedStopIndex = index);
    widget.onStopSelected?.call(index);
    if (widget.onStopSelected == null || wasSelected)
      _showStop(_stops[index], index + 1);
  }

  List<RouteMapStop> get _stops =>
      widget.stops.where((s) => s.hasLocation).toList();
  String _signature(List<RouteMapStop> stops) =>
      stops.map((s) => '${s.latitude},${s.longitude}').join('|');
  @override
  void didUpdateWidget(covariant ItineraryRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stopsChanged =
        _signature(oldWidget.stops.where((s) => s.hasLocation).toList()) !=
        _signature(_stops);
    final selectionChanged =
        widget.selectedStopIndex != oldWidget.selectedStopIndex ||
        widget.selectionRevision != oldWidget.selectionRevision;
    if (stopsChanged) _selectedStopIndex = null;
    // Fresh path objects on a parent rebuild must not reset the user's camera.
    if (stopsChanged || selectionChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ready) return;
        final index = widget.selectedStopIndex;
        if (selectionChanged &&
            index != null &&
            index >= 0 &&
            index < _stops.length) {
          _controller.move(_stops[index].position, 14);
        } else if (stopsChanged || selectionChanged) {
          _focusOnce();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fit() {
    final points = [..._stops.map((s) => s.position)];
    if (points.isEmpty) return;
    if (points.map((p) => '${p.latitude},${p.longitude}').toSet().length == 1) {
      _controller.move(points.first, 14);
    } else {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(42),
          maxZoom: 14,
        ),
      );
    }
  }

  void _focusOnce() {
    _fit();
    final camera = _controller.camera;
    _controller.move(camera.center, (camera.zoom + .01).clamp(3.0, 19.0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ready) _fit();
    });
  }

  String movementDetails(RouteMapStop stop) {
    final lines = <String>[];
    for (final line in stop.detail.split('\n')) {
      if (line.startsWith('설명:')) break;
      if (RegExp(r'^(이동:|총 이동 시간:|교통비:|항공 구간:)|·.*분$|시간표|운행 변경').hasMatch(line))
        lines.add(line);
    }
    return lines.join('\n');
  }

  void _showStop(RouteMapStop stop, int number) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. ${stop.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _StopDetails(
                  detail: stop.detail,
                  airportAccessUrl: stop.airportAccessUrl,
                ),
                const SizedBox(height: 12),
                if (stop.incomingDirections && stop.directionsToHere != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.directions),
                    label: const Text('실제 경로 보기'),
                    onPressed: () async {
                      final url = stop.directionsToHere!;
                      if (widget.openDirections != null) {
                        await widget.openDirections!(url);
                      } else {
                        await showDirectionsPreview(
                          context,
                          url,
                          details: movementDetails(stop),
                        );
                      }
                    },
                  )
                else if (!stop.incomingDirections &&
                    number < _stops.length &&
                    (!(stop.outgoingDirections ? stop : _stops[number])
                            .useProvidedDirections ||
                        (stop.outgoingDirections ? stop : _stops[number])
                                .directionsToHere !=
                            null))
                  FilledButton.icon(
                    icon: const Icon(Icons.directions),
                    label: Text('실제 경로 보기'),
                    onPressed: () async {
                      final next = _stops[number];
                      final url =
                          (stop.outgoingDirections
                              ? stop.directionsToHere
                              : next.directionsToHere) ??
                          Uri.https('www.google.com', '/maps/dir/', {
                            'api': '1',
                            'origin': '${stop.latitude},${stop.longitude}',
                            'destination': '${next.latitude},${next.longitude}',
                            'travelmode': 'transit',
                          });
                      if (widget.openDirections != null) {
                        await widget.openDirections!(url);
                      } else {
                        await showDirectionsPreview(
                          context,
                          url,
                          details: movementDetails(
                            stop.outgoingDirections ? stop : _stops[number],
                          ),
                        );
                      }
                    },
                  )
                else if (stop.incomingDirections &&
                    stop.directionsToHere == null)
                  const SizedBox.shrink()
                else if (number == _stops.length)
                  const Text('이 날의 마지막 장소입니다.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    if (stops.isEmpty) {
      return const Center(child: Text('위치 정보가 있는 장소가 없어 지도를 표시할 수 없습니다.'));
    }
    final points = stops.map((s) => s.position).toList();

    final groups = <String, List<int>>{};
    for (int i = 0; i < stops.length; i++) {
      final key =
          '${stops[i].latitude.toStringAsFixed(6)},${stops[i].longitude.toStringAsFixed(6)}';
      groups.putIfAbsent(key, () => []).add(i);
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            interactionOptions: InteractionOptions(
              flags: _interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            initialCenter: points.first,
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: () {
              _ready = true;
              // Fit once after layout; moving during onMapReady can leave the tile viewport stale.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _ready) _focusOnce();
              });
            },
          ),
          children: [
            if (widget.loadTiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ai_travel_planner',
                maxNativeZoom: 19,
              ),
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: const Color(0xFF2563EB),
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final indices in groups.values)
                  Marker(
                    point: stops[indices.first].position,
                    width: indices.length > 1 ? 64 : 36,
                    height: 36,
                    child: Tooltip(
                      message: indices
                          .map(
                            (i) =>
                                '${i + 1}. ${stops[i].name} · ${stops[i].detail}',
                          )
                          .join('\n'),
                      child: Semantics(
                        label: indices
                            .map((i) => '지도 장소 ${i + 1}: ${stops[i].name}')
                            .join(', '),
                        button: true,
                        selected: indices.contains(_selection),
                        child: GestureDetector(
                          onTap: () {
                            // 터치한 핀을 선택 상태로 변경합니다.
                            if (indices.length == 1) {
                              _activateStop(indices.first);
                              return;
                            }
                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              builder: (context) => SafeArea(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      0,
                                      24,
                                      24,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '같은 위치의 일정',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        for (final i in indices)
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              '${i + 1}. ${stops[i].name}',
                                            ),
                                            subtitle: Text(stops[i].detail),
                                            onTap: () {
                                              // 같은 좌표의 장소 중 실제 선택한 항목을 기억합니다.
                                              Navigator.pop(context);
                                              _activateStop(i);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: indices.contains(_selection)
                                  ? const Color(0xFFE53935) // 선택됨: 빨간색
                                  : const Color(0xFF2563EB), // 기본: 파란색
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              indices.map((i) => '${i + 1}').join('·'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  '오픈스트리트맵 기여자',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '장소 ${stops.length}곳 · 방문 순서',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Column(
            children: [
              _mapButton(
                Icons.add,
                '지도 확대',
                () => _controller.move(
                  _controller.camera.center,
                  (_controller.camera.zoom + 1).clamp(3, 19),
                ),
              ),
              _mapButton(
                Icons.remove,
                '지도 축소',
                () => _controller.move(
                  _controller.camera.center,
                  (_controller.camera.zoom - 1).clamp(3, 19),
                ),
              ),
              _mapButton(Icons.fit_screen, '전체 경로 보기', _fit),
              _mapButton(
                _interactive ? Icons.lock_open : Icons.pan_tool_alt,
                _interactive ? '지도 조작 종료' : '지도 조작 시작',
                () => setState(() => _interactive = !_interactive),
              ),
            ],
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.all(6),
            color: Colors.white.withValues(alpha: 0.9),
            child: Text('핀을 누르면 아래 일정으로 이동합니다', style: TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }

  Widget _mapButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon),
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
}

class _StopDetails extends StatelessWidget {
  const _StopDetails({required this.detail, this.airportAccessUrl});
  final Uri? airportAccessUrl;
  final String detail;
  @override
  Widget build(BuildContext context) {
    final lines = detail.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final hasHeader =
        lines.isNotEmpty && RegExp(r'^\d{2}:\d{2}').hasMatch(lines.first);
    final headerCount = hasHeader
        ? (lines.length > 1 && !lines[1].contains(':') ? 2 : 1)
        : 0;
    final info = <String>[], movement = <String>[], explanation = <String>[];
    var description = false;
    for (final line in lines.skip(headerCount)) {
      if (line.startsWith('설명:')) description = true;
      if (description)
        explanation.add(line);
      else if (RegExp(
        r'^(체류시간|주소|전화번호|영업시간|영업일|휴무일|평균 숙박요금|1박 최저가|식사 장소 유형|공항 내 이동):',
      ).hasMatch(line))
        info.add(line);
      else if (info.isNotEmpty)
        info.add(line);
      else
        movement.add(line);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHeader) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                avatar: const Icon(Icons.schedule, size: 17),
                label: Text(lines.first),
              ),
              if (headerCount > 1) Chip(label: Text(lines[1])),
            ],
          ),
          const SizedBox(height: 16),
        ],
        ItineraryPlaceContent(
          information: info.join('\n'),
          movement: movement.join('\n'),
          explanation: explanation.join('\n'),
          airportAccessUrl: airportAccessUrl,
        ),
      ],
    );
  }
}
