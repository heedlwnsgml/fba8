import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/state/city_coordinates.dart';
import '../../../core/state/island_travel_labels.dart';
import '../../../core/theme/app_colors.dart';

class CitySelectionMap extends StatefulWidget {
  const CitySelectionMap({
    super.key,
    required this.cities,
    required this.selected,
    required this.onToggle,
    this.anchorCity,
    this.loadTiles = true,
  });
  final List<String> cities;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String? anchorCity;
  final bool loadTiles;
  @override
  State<CitySelectionMap> createState() => _CitySelectionMapState();
}

class _CitySelectionMapState extends State<CitySelectionMap> {
  final controller = MapController();
  String? focused;
  bool ready = false;
  List<String> get visible =>
      widget.cities.where(cityCoordinates.containsKey).toSet().toList();
  LatLng point(String city) {
    final p = cityCoordinates[city]!;
    return LatLng(p[0], p[1]);
  }

  void fit() {
    if (ready && visible.isNotEmpty)
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: visible.map(point).toList(),
          padding: const EdgeInsets.all(30),
          maxZoom: 7,
        ),
      );
  }

  @override
  void didUpdateWidget(covariant CitySelectionMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorCity != widget.anchorCity &&
        cityCoordinates.containsKey(widget.anchorCity)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ready) controller.move(point(widget.anchorCity!), 8);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '지도로 여행 도시 선택',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '핀을 누르거나 아래 도시 목록에서 선택하세요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        SizedBox(
          height: 290,
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: cityCoordinates.containsKey(widget.anchorCity)
                      ? point(widget.anchorCity!)
                      : const LatLng(36.2, 138.2),
                  initialZoom: cityCoordinates.containsKey(widget.anchorCity)
                      ? 8
                      : 4,
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                  onMapReady: () {
                    ready = true;
                    if (!cityCoordinates.containsKey(widget.anchorCity)) fit();
                  },
                ),
                children: [
                  if (widget.loadTiles)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.aiplanner.ai_travel_planner',
                    ),
                  MarkerLayer(
                    markers: [
                      for (final city in visible)
                        Marker(
                          point: point(city),
                          width: 40,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: Semantics(
                            button: true,
                            selected: widget.selected.contains(city),
                            label:
                                '${islandCityLabel(city)} · ${widget.selected.contains(city) ? '선택됨' : '미선택'}',
                            child: Tooltip(
                              message:
                                  '${islandCityLabel(city)} · ${widget.selected.contains(city) ? '선택됨' : '미선택'}',
                              child: GestureDetector(
                                key: ValueKey('city-pin-$city'),
                                onTap: () {
                                  setState(() => focused = city);
                                  widget.onToggle(city);
                                },
                                child: Icon(
                                  Icons.location_on,
                                  size: 36,
                                  color: widget.selected.contains(city)
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF2563EB),
                                  shadows: const [
                                    Shadow(color: Colors.white, blurRadius: 3),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      IconButton(
                        tooltip: '일본 전체 보기',
                        onPressed: fit,
                        icon: const Icon(Icons.fit_screen),
                      ),
                      IconButton(
                        tooltip: '지도 확대',
                        onPressed: () => controller.move(
                          controller.camera.center,
                          controller.camera.zoom + 1,
                        ),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: '지도 축소',
                        onPressed: () => controller.move(
                          controller.camera.center,
                          controller.camera.zoom - 1,
                        ),
                        icon: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 6,
                bottom: 4,
                child: ColoredBox(
                  color: Colors.white70,
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  _Legend('선택 전', Color(0xFF2563EB)),
                  _Legend('선택됨', Color(0xFFEF4444)),
                ],
              ),
              if (focused != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${islandCityLabel(focused!)} · ${widget.selected.contains(focused) ? '선택됨' : '선택 해제됨'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.location_on, color: color, size: 17),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
