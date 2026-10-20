import 'package:flutter/material.dart';
import '../../../core/network/planner_api.dart';

class LiveDirectionsDetails extends StatefulWidget {
  const LiveDirectionsDetails({super.key, required this.route, this.api});
  final Uri route;
  final PlannerApi? api;
  @override
  State<LiveDirectionsDetails> createState() => _LiveDirectionsDetailsState();
}

class _LiveDirectionsDetailsState extends State<LiveDirectionsDetails> {
  late Future<Map<String, dynamic>> result;
  int selected = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    result = (widget.api ?? PlannerApi.instance).getLiveDirections(
      widget.route,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('현재 출발 기준 경로를 조회하고 있습니다.'),
            ],
          ),
        );
      final data = snapshot.data;
      final routes = (data?['routes'] as List? ?? []).whereType<Map>().toList();
      if (routes.isEmpty)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data?['message']?.toString() ?? '실시간 경로를 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(load),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 조회'),
                ),
              ],
            ),
          ),
        );
      if (selected >= routes.length) selected = 0;
      final route = routes[selected];
      final steps = (route['steps'] as List? ?? []).whereType<Map>();
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Google 실시간 이동 안내',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => setState(load),
                tooltip: '현재 경로 새로 조회',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            '현재 출발 기준 · 운행 상황에 따라 달라질 수 있습니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          if (routes.length > 1)
            DropdownButton<int>(
              isExpanded: true,
              value: selected,
              items: [
                for (int i = 0; i < routes.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text('경로 ${i + 1} · 약 ${routes[i]['minutes']}분'),
                  ),
              ],
              onChanged: (i) => setState(() => selected = i ?? 0),
            ),
          Text(
            '총 이동 시간: 약 ${route['minutes']}분',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    step['mode'] == 'WALK'
                        ? Icons.directions_walk
                        : step['mode'] == 'DRIVE'
                        ? Icons.directions_car
                        : Icons.directions_transit,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${step['line']?.toString().isNotEmpty == true
                              ? step['line']
                              : step['mode'] == 'WALK'
                              ? '도보'
                              : step['mode'] == 'DRIVE'
                              ? '자동차'
                              : '대중교통'} · 약 ${step['minutes']}분',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (step['from']?.toString().isNotEmpty == true)
                          Text(
                            '${step['from']} → ${step['to']}',
                            style: const TextStyle(height: 1.5),
                          ),
                        if (step['headsign']?.toString().isNotEmpty == true)
                          Text(
                            '${step['headsign']} 방면 · ${step['stopCount']}개 정류장',
                          ),
                        if (step['departureTime']?.toString().isNotEmpty ==
                            true)
                          Text(
                            '${step['departureTime']} 출발 · ${step['arrivalTime']} 도착',
                          ),
                        if (step['instruction']?.toString().isNotEmpty == true)
                          Text(
                            '${step['instruction']}',
                            style: const TextStyle(height: 1.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
