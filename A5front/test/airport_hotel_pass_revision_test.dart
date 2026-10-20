import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_place_content.dart';
import 'package:ai_travel_planner/features/schedule/widgets/pass_day_comparison.dart';

void main() {
  test(
    'airport route uses the supplied terminal lobby and boarding coordinate',
    () {
      final timeline = <Map<String, dynamic>>[
        {
          'day': 1,
          'placeName': '하네다공항',
          'category': '공항',
          'latitude': 35.5533,
          'longitude': 139.7811,
          'airportAccess': {
            'boardingName': '하네다 제3터미널역',
            'originQuery': '羽田空港第3ターミナル 到着ロビー',
            'destinationQuery': '35.54498,139.7670665',
            'walkMinutes': 3,
          },
        },
        {'day': 1, 'placeName': '시바공원'},
      ];
      itineraryAttachAirportAccess(timeline);
      final uri = timeline.first['_airportAccessUrl'] as Uri;
      expect(uri.queryParameters['origin'], '羽田空港第3ターミナル 到着ロビー');
      expect(uri.queryParameters['destination'], '35.54498,139.7670665');
      expect(uri.queryParameters['travelmode'], 'walking');
    },
  );
  testWidgets(
    'all covered days of a beneficial multi-day pass appear above the disclosure',
    (tester) async {
      final pass = {
        'id': 'p',
        'name': '도쿄 2일 패스',
        'day': 1,
        'validUntilDay': 2,
        'regularFareYen': 1600,
        'passFareYen': 1200,
        'savingYen': 400,
      };
      final costs = {
        'recommendations': [pass],
        'dailyCosts': [
          {
            'day': 1,
            'regularFareYen': 700,
            'optimalFareYen': 1200,
            'passes': [pass],
          },
          {
            'day': 2,
            'regularFareYen': 900,
            'optimalFareYen': 0,
            'passes': [pass],
          },
          {
            'day': 3,
            'regularFareYen': 500,
            'optimalFareYen': 500,
            'passes': [],
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassDayComparison(costs: costs, formatText: (s) => s),
          ),
        ),
      );
      expect(find.textContaining('1일차 -'), findsOneWidget);
      expect(find.textContaining('2일차 -'), findsOneWidget);
      expect(find.textContaining('3일차 -'), findsNothing);
    },
  );
  testWidgets(
    'movement fare is beside stay duration and visit separator is removed',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryPlaceContent(
                information: '체류시간: 90분\n주소: 도쿄',
                movement: '이동: 지하철 20분\n교통비: 성인 1인 약 2,000원\n총 이동 시간: 약 20분',
                explanation: '설명',
              ),
            ),
          ),
        ),
      );
      final stay = tester.getTopLeft(find.text('체류시간'));
      final fare = tester.getTopLeft(find.text('이동 요금'));
      expect((stay.dy - fare.dy).abs(), lessThan(1));
      expect(fare.dx, greaterThan(stay.dx));
      expect(find.byType(Divider), findsNothing);
    },
  );
}
