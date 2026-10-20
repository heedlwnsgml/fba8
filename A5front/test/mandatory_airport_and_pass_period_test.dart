import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';

void main() {
  test(
    'Airports are optional while selected airport times use daily defaults',
    () {
      final d = TripDraft.instance..resetInputs();
      d.start = DateTime(2026, 10, 10);
      d.end = DateTime(2026, 10, 11);
      d.cities = ['도쿄'];
      d.themes = ['관광'];
      d.transport = '대중교통';
      expect(d.toRequest()['outCity'], isNull);
      expect(d.toRequest()['outTime'], isNull);
      d.entryAirport = '하네다공항';
      expect(d.toRequest()['outCity'], isNull);
      expect(d.toRequest()['outTime'], isNull);
      d.exitAirport = '나리타국제공항';
      expect(d.toRequest()['inCity'], '하네다공항');
      expect(d.toRequest()['inTime'], '09:00');
      d.resetInputs();
    },
  );
  test('Seven-day JR pass stays consecutive even if last ride is day one', () {
    final text = itineraryPassPeriod({
      'day': 1,
      'endDay': 1,
      'validUntilDay': 7,
      'name': 'JR 전국 7일권',
      'passFareYen': 50000,
    }, DateTime(2026, 10, 10));
    expect(text, contains('1~7일차'));
    expect(text, contains('10/10~10/16'));
    expect(text, contains('연속 사용'));
  });
}
