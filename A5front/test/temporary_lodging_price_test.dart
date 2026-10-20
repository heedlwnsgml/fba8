import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';

void main() {
  test('missing lodging prices do not invent a displayed amount', () {
    final place = {'category': '숙소', 'placeName': 'Hotel'};
    expect(itineraryPlaceInformation(place), isNot(contains('숙박비:')));
    expect(
      itineraryPlaceInformation(place, admin: true),
      isNot(contains('숙박비:')),
    );
  });
  test('verified lodging price keeps the simple lodging cost label', () {
    final text = itineraryPlaceInformation({
      'category': '숙소',
      'lowestNightPerRoomYen': 9800,
    });
    expect(text, contains('숙박비: ¥9800'));
    expect(text, isNot(contains('객실')));
  });
}
