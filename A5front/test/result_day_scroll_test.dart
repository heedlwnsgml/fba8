import 'package:flutter/material.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';

class ResultMoneyApi extends PlannerApi {
  @override
  Future<String> getHotelCurrencyPreference() async => 'KRW';
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {'krwPerJpy': 8.5};
}

void main() {
  testWidgets('대중교통과 항공료를 구분하고 지역 사업자 패스 비교를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(showInitialCityRoute: false,
          api: ResultMoneyApi(),
          request: {
            'title': '비용 확인',
            'startDate': '2026-10-14',
            'endDate': '2026-10-15',
            'cities': ['도쿄'],
          },
          response: {
            'planId': 42,
            'timeline': [
              {'day': 1, 'time': '09:00', 'placeName': '공원', 'category': '관광지'},
            ],
            'transportCosts': {
              'knownFareYen': 3000,
              'totalFareYen': 3000,
              'knownOptimalFareYen': 1500,
              'unknownLegCount': 0,
              'flightLegCount': 1,
              'flightFareYen': 24300,
              'knownFlightFareYen': 24300,
              'unknownFlightLegCount': 0,
              'recommendations': [
                {
                  'day': 1,
                  'endDay': 2,
                  'name': '도쿄 지하철 48시간권',
                  'passFareYen': 1500,
                  'regularFareYen': 3000,
                  'savingYen': 1500,
                },
              ],
              'passComparisons': [
                {
                  'day': 1,
                  'endDay': 2,
                  'name': '도쿄 지하철 48시간권',
                  'passFareYen': 1500,
                  'regularFareYen': 3000,
                  'savingYen': 1500,
                },
              ],
              'jrPassComparisons': [
                {
                  'day': 1,
                  'name': 'JR 전국 패스 · JR 이용 가정',
                  'passFareYen': 50000,
                  'regularFareYen': 90000,
                  'savingYen': 40000,
                },
              ],
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('패스 상세보기'));
    await tester.tap(find.text('패스 상세보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('대중교통비 25,500원'), findsWidgets);
    expect(find.textContaining('예상 국내선 항공료 206,600원'), findsWidgets);
    expect(find.textContaining('한국↔일본 국제선'), findsNothing);
    expect(find.textContaining('도쿄 지하철 48시간권'), findsWidgets);
    expect(find.textContaining('JR 이용 가정'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Day content has its own height, centered navigation and expandable transport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryResultPage(showInitialCityRoute: false,
            request: {
              'title': '스크롤 확인',
              'startDate': '2026-10-14',
              'endDate': '2026-10-15',
              'cities': ['도쿄'],
            },
            response: {
              'planId': 42,
              'timeline': [
                for (int i = 0; i < 8; i++)
                  {
                    'day': 1,
                    'time': '${9 + i}:00',
                    'placeName': '장소 $i',
                    'category': '관광지',
                    'description': List.filled(8, '장소 설명입니다.').join('\n'),
                    'transportFromPrevious': {
                      'mode': '지하철·도보',
                      'durationMinutes': 25,
                      'fareYen': 210,
                      'source': 'official-catalog',
                      'steps': [
                        {
                          'mode': '지하철',
                          'lineName': '긴자선',
                          'from': '출발역',
                          'to': '도착역',
                          'durationMinutes': 15,
                        },
                      ],
                    },
                  },
                {
                  'day': 2,
                  'time': '09:00',
                  'placeName': '짧은 날의 장소',
                  'category': '관광지',
                  'description': '짧은 일정',
                },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byKey(const ValueKey('itinerary-day-scroll'));
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      final longExtent = position().maxScrollExtent;
      expect(find.byType(PageView), findsNothing);
      expect(find.textContaining('출발역 → 도착역'), findsNothing);
      await tester.ensureVisible(find.text('이동 상세 보기').first);
      await tester.tap(find.text('이동 상세 보기').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('출발역 → 도착역'), findsOneWidget);
      await tester.ensureVisible(find.text('다음 일차').first);
      await tester.pumpAndSettle();
      final previous = tester.getRect(find.text('이전 일차').first);
      final next = tester.getRect(find.text('다음 일차').first);
      expect((previous.left + next.right) / 2, closeTo(180, 15));
      await tester.tap(find.text('다음 일차').first);
      await tester.pumpAndSettle();
      expect(position().pixels, 0);
      expect(position().maxScrollExtent, lessThan(longExtent / 2));
      expect(find.textContaining('짧은 날의 장소'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
