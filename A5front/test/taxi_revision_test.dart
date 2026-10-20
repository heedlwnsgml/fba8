import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';

void main() {
  test('taxi estimate remains visible without a rail or bus line name', () {
    final leg = {
      'source': 'taxi',
      'mode': '택시',
      'durationMinutes': 24,
      'fareYen': 2800,
      'estimated': true,
      'steps': [
        {'mode': '택시', 'durationMinutes': 24},
      ],
    };
    expect(itineraryUnverifiedTransport(leg), isFalse);
    expect(itineraryTransportSummary(leg), '이동: 택시 약 24분');
  });
}
