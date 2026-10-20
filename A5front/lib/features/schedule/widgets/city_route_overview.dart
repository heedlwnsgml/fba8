import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/state/city_coordinates.dart';

class CityRouteStop {
  const CityRouteStop(this.city, this.day, this.point);
  final String city;
  final int? day;
  final LatLng? point;
}

/// Use generated day order, including added cities; never sort the user's route.
List<CityRouteStop> itineraryCityStops(Map request, Map response) {
  final days = (response['days'] as List? ?? []).whereType<Map>().toList()
    ..sort(
      (a, b) => ((a['day'] as num?)?.toInt() ?? 0).compareTo(
        (b['day'] as num?)?.toInt() ?? 0,
      ),
    );
  final route = <CityRouteStop>[];
  void add(String city, int? day) {
    city = city.trim();
    if (city.isEmpty || (route.isNotEmpty && route.last.city == city)) return;
    final center = cityCoordinates[city];
    LatLng? point = center == null ? null : LatLng(center[0], center[1]);
    if (point == null && day != null) {
      final places = (response['timeline'] as List? ?? [])
          .whereType<Map>()
          .where(
            (p) =>
                p['day'] == day &&
                p['latitude'] is num &&
                p['longitude'] is num &&
                (p['latitude'] as num).abs() <= 90 &&
                (p['longitude'] as num).abs() <= 180 &&
                ((p['latitude'] as num) != 0 || (p['longitude'] as num) != 0),
          )
          .toList();
      if (places.isNotEmpty) {
        point = LatLng(
          places
                  .map((p) => (p['latitude'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              places.length,
          places
                  .map((p) => (p['longitude'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              places.length,
        );
      }
    }
    route.add(CityRouteStop(city, day, point));
  }

  for (final d in days) {
    add(d['city']?.toString() ?? '', (d['day'] as num?)?.toInt());
  }
  if (route.isEmpty) {
    for (final c in (request['cities'] as List? ?? [])) {
      add(c.toString(), null);
    }
  }
  return route;
}

class CityRouteOverview extends StatelessWidget {
  const CityRouteOverview({
    super.key,
    required this.stops,
    this.loadTiles = true,
  });
  final List<CityRouteStop> stops;
  final bool loadTiles;
  Future<void> selectCity(BuildContext context, List<int> indices) async {
    int? index;
    if (indices.length == 1) {
      index = indices.first;
    } else {
      index = await showDialog<int>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(stops[indices.first].city),
          children: [
            for (final i in indices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, i),
                child: Text('${stops[i].day ?? 1}일차 일정 보기'),
              ),
          ],
        ),
      );
    }
    if (context.mounted && index != null)
      Navigator.pop(context, stops[index].day ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final points = stops
        .where((s) => s.point != null)
        .map((s) => s.point!)
        .toList();
    final groups = <String, List<int>>{};
    for (int i = 0; i < stops.length; i++) {
      if (stops[i].point != null) {
        groups.putIfAbsent('${stops[i].point}', () => []).add(i);
      }
    }
    return Dialog(
      key: const ValueKey('city-route-overview'),
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height * .78).clamp(300.0, 650.0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '전체 도시 경로',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text('여행에서 방문할 도시와 이동 순서입니다.'),
                const SizedBox(height: 12),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: points.isEmpty
                        ? const Center(child: Text('아래에서 방문 도시를 확인해 주세요.'))
                        : FlutterMap(
                            options: MapOptions(
                              initialCenter: points.first,
                              initialZoom: 8,
                              initialCameraFit: CameraFit.coordinates(
                                coordinates: points,
                                padding: const EdgeInsets.all(44),
                                maxZoom: 9,
                              ),
                            ),
                            children: [
                              if (loadTiles)
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.ai_travel_planner',
                                ),
                              if (points.length > 1)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: points,
                                      color: const Color(0xFF2563EB),
                                      strokeWidth: 3,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  for (final indices in groups.values)
                                    Marker(
                                      point: stops[indices.first].point!,
                                      width: 130,
                                      height: 66,
                                      child: Tooltip(
                                        message: indices
                                            .map(
                                              (i) =>
                                                  '${i + 1}. ${stops[i].city}',
                                            )
                                            .join(' / '),
                                        child: GestureDetector(
                                          key: ValueKey(
                                            'city-route-pin-${indices.first}',
                                          ),
                                          onTap: () =>
                                              selectCity(context, indices),
                                          child: Column(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF2563EB,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  indices
                                                      .map((i) => '${i + 1}')
                                                      .join('·'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                color: Colors.white,
                                                child: Text(
                                                  stops[indices.first].city,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution('© OpenStreetMap'),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: stops.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        onTap: () => selectCity(context, [i]),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(stops[i].city)),
                            if (stops[i].day != null)
                              Text(
                                '${stops[i].day}일차부터',
                                style: const TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('일정 보기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
