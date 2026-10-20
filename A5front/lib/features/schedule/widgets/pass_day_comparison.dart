import 'package:flutter/material.dart';
import '../../../core/state/itinerary_presentation.dart';

/// Keep useful days visible; the complete comparison remains one disclosure away.
class PassDayComparison extends StatelessWidget {
  const PassDayComparison({
    super.key,
    required this.costs,
    required this.formatText,
  });
  final Map? costs;
  final String Function(String) formatText;

  Widget dayCard(Map day) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F6FC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      formatText(itineraryCompactPassDay(day)),
      style: const TextStyle(height: 1.6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final daily = (costs?['dailyCosts'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final beneficial = itineraryBeneficialPassDays(costs);
    final remaining = daily.where((d) => !beneficial.contains(d)).toList();
    final recommendations = itineraryPdfPassRecommendations(costs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (beneficial.isNotEmpty) ...[
          const Text(
            '패스가 유리한 날',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...beneficial.map(dayCard),
        ],
        if (daily.isEmpty)
          for (final pass in recommendations)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                formatText(
                  '${itineraryPassPeriod(pass, null)}\n일반 승차권 ${pass['regularFareYen']}엔 → 패스 ${pass['passFareYen']}엔',
                ),
                style: const TextStyle(height: 1.6),
              ),
            ),
        if (recommendations.any(
          (p) =>
              (p['validUntilDay'] as num? ??
                  p['endDay'] as num? ??
                  p['day'] as num? ??
                  1) >
              (p['day'] as num? ?? 1),
        ))
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              '연속 사용 패스는 정해진 기간 전체에 적용되며, 구매비는 구매일에 한 번 반영됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (remaining.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('other-pass-days'),
            tilePadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: const Text('나머지 일자 비교'),
            children: remaining.map(dayCard).toList(),
          ),
      ],
    );
  }
}
