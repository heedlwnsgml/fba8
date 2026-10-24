import 'package:flutter/material.dart';
import '../../../core/network/planner_api.dart';

class MissingHotelPricesCard extends StatefulWidget {
  const MissingHotelPricesCard({super.key, required this.api});
  final PlannerApi api;
  @override
  State<MissingHotelPricesCard> createState() => _MissingHotelPricesCardState();
}

class _MissingHotelPricesCardState extends State<MissingHotelPricesCard> {
  late Future<List<String>> hotels;
  @override
  void initState() {
    super.initState();
    hotels = widget.api.getHotelPriceFailures();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '숙박비 적재 필요',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              IconButton(
                tooltip: '목록 새로고침',
                onPressed: () =>
                    setState(() { hotels = widget.api.getHotelPriceFailures(); }),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          FutureBuilder<List<String>>(
            future: hotels,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LinearProgressIndicator();
              if (snapshot.hasError)
                return const Text('목록을 불러오지 못했습니다. 새로고침해 주세요.');
              final names = snapshot.data ?? [];
              if (names.isEmpty) return const Text('적재가 필요한 숙소가 없습니다.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final name in names)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(name),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
