import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';

void main() {
  test(
    'Unknown route shows average time and fare without inventing a line',
    () {
      final leg = {
        'mode': '대중교통',
        'durationMinutes': 34,
        'estimated': true,
        'source': 'distance-average',
        'steps': [],
        'fareYen': 300,
        'fareNote': '거리 기준 평균: 직선 거리',
      };
      expect(itineraryTransportSummary(leg), contains('약 34분'));
      final text = itineraryDescription({'transportFromPrevious': leg});
      expect(text, contains('약 ¥300'));
      expect(text, isNot(contains('소요시간 미확인')));
    },
  );
}
