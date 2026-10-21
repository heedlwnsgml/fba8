import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/features/schedule/widgets/city_route_overview.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';

class CityApi extends PlannerApi {
  @override
  Future<String> getHotelCurrencyPreference() async => 'JPY';
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {'krwPerJpy': 8.5};
}

void main() {
  test(
    'generated day order wins, repeated adjacent cities collapse and return visits remain',
    () {
      final stops = itineraryCityStops(
        {
          'cities': ['도쿄', '가마쿠라'],
        },
        {
          'days': [
            {'day': 4, 'city': '도쿄'},
            {'day': 1, 'city': '가마쿠라'},
            {'day': 2, 'city': '가마쿠라'},
            {'day': 3, 'city': '요코하마'},
          ],
        },
      );
      expect(stops.map((s) => s.city), ['가마쿠라', '요코하마', '도쿄']);
      expect(stops.map((s) => s.day), [1, 3, 4]);
      expect(stops.every((s) => s.point != null), true);
      expect(
        itineraryCityStops({}, {
          'days': [
            {'day': 1, 'city': '도쿄'},
            {'day': 2, 'city': '요코하마'},
            {'day': 3, 'city': '도쿄'},
          ],
        }).length,
        3,
      );
    },
  );
  testWidgets(
    'first shows cities only, closes to itinerary and reopens from PDF neighbor',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: ItineraryResultPage(
            loadMapTiles: false,
            api: CityApi(),
            request: {
              'title': '가마쿠라 여행',
              'tripDays': 1,
              'cities': ['도쿄', '가마쿠라'],
            },
            response: {
              'planId': 1,
              'days': [
                {'day': 1, 'city': '가마쿠라'},
              ],
              'timeline': [
                {
                  'day': 1,
                  'time': '09:00',
                  'placeName': '첫 관광지',
                  'latitude': 35.32,
                  'longitude': 139.53,
                },
                {
                  'day': 1,
                  'time': '12:00',
                  'placeName': '다음 관광지',
                  'latitude': 35.34,
                  'longitude': 139.55,
                },
              ],
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('city-route-overview')), findsOneWidget);
      final overview = t.widget<CityRouteOverview>(
        find.byType(CityRouteOverview),
      );
      expect(overview.stops.map((s) => s.city), ['가마쿠라']);
      await t.tap(find.text('일정 보기'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('city-route-overview')), findsNothing);
      expect(find.byKey(const ValueKey('map-pin-button-2')), findsNothing);
      await t.tap(find.byKey(const ValueKey('toggle-fixed-map')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('toggle-map-places')));
      await t.pumpAndSettle();
      final pin = find.byKey(const ValueKey('map-pin-button-2'));
      await t.tap(pin);
      await t.pumpAndSettle();
      expect(t.widget<ChoiceChip>(pin).selected, true);
      expect(find.byKey(const ValueKey('timeline-card-0-1')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('toggle-fixed-map')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('show-city-route')));
      await t.pumpAndSettle();
      expect(find.text('전체 도시 경로'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
