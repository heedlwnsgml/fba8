import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';

void main() {
  test(
    'Compact movement is Korean while detailed bus names remain original',
    () {
      final leg = {
        'mode': 'バス',
        'durationMinutes': 19,
        'estimated': false,
        'steps': [
          {
            'mode': 'バス',
            'lineName': '横浜市営バス',
            'from': '横浜駅',
            'to': '中華街',
            'durationMinutes': 19,
          },
        ],
      };
      expect(itineraryTransportSummary(leg), '이동: 버스 19분');
      expect(
        itineraryDescription({'transportFromPrevious': leg}),
        contains('横浜市営バス'),
      );
      final average = {
        'mode': '대중교통',
        'source': 'distance-average',
        'estimated': true,
        'durationMinutes': 25,
        'fareYen': 300,
        'fareNote': '거리 기준 평균: 직선 거리',
      };
      expect(itineraryTransportSummary(average), '이동: 대중교통 약 25분');
      expect(
        itineraryDescription({'transportFromPrevious': average}),
        isNot(contains('거리 기준')),
      );
    },
  );
}
