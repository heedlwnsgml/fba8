import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_preferences_page.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';
import 'package:ai_travel_planner/features/schedule/widgets/directions_preview.dart';
import 'package:ai_travel_planner/features/schedule/widgets/transport_details.dart';

void main() {
  testWidgets('취향 탭 좌우 스와이프와 탭 선택을 함께 사용한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TripPreferencesPage()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(find.text('누구와 함께하나요?'), findsOneWidget);
    await tester.tap(find.text('하루 일정'));
    await tester.pumpAndSettle();
    expect(find.text('하루를 언제 시작하고 마칠까요?'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.text('어떻게 이동하나요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('알 수 없는 숙소 도착·교통 거점 체류만 숨기고 실제 방문시간은 유지한다', () {
    for (final category in ['숙소', '숙박', '교통', '공항']) {
      expect(
        itineraryPlaceInformation({'category': category, 'time': '22:00'}),
        isNot(contains('체류시간')),
      );
      expect(
        itineraryPlaceInformation({
          'category': category,
          'time': '22:00',
          'endTime': '22:30',
        }),
        contains('체류시간: 30분'),
      );
    }
    expect(
      itineraryPlaceInformation({'category': '관광지'}),
      contains('체류시간: 미확인'),
    );
  });
  testWidgets('경로는 중앙 미리보기로 열고 바깥 터치로 원래 화면을 유지한다', (tester) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=35,139&destination=36,140&travelmode=driving',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDirectionsPreview(
                  context,
                  url,
                  content: const Text('경로 지도'),
                ),
                child: const Text('경로 열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('경로 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('경로 지도'), findsOneWidget);
    final dialog = tester.getRect(find.byType(Dialog));
    expect(dialog.center.dx, closeTo(400, 1));
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('경로 열기'), findsOneWidget);
    expect(itineraryEmbeddedDirections(url).queryParameters['dirflg'], 'd');
  });
  testWidgets('교통 상세를 구간·총 시간으로 구분해 왼쪽 정렬한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransportDetails(
            text:
                '지하철 · 긴자선 · 출발역 → 도착역 · 20분\n도보 · 5분\n총 이동 시간: 약 25분\n운행 변경 가능',
          ),
        ),
      ),
    );
    expect(find.text('총 이동 시간: 약 25분'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('총 이동 시간: 약 25분')).textAlign,
      TextAlign.left,
    );
  });
  testWidgets('패스 없음은 간결한 안내, 일별 비용은 상세 창에서만 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(showInitialCityRoute: false,
          request: {
            'title': '테스트',
            'cities': ['도쿄'],
            'tripDays': 1,
          },
          response: {
            'timeline': [
              {'day': 1, 'time': '09:00', 'placeName': '공원', 'category': '관광지'},
            ],
            'transportCosts': {
              'unknownLegCount': 0,
              'recommendations': [],
              'dailyCosts': [
                {'day': 1, 'regularFareYen': 800, 'optimalFareYen': 800},
              ],
            },
            'warnings': ['숙소 가격 확인 필요', '버스 노선 확인 필요', '숙소 가격 확인 필요'],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('일반 승차권이 가장 효율적입니다.'), findsOneWidget);
    expect(find.text('나머지 일자 비교'), findsNothing);
    await tester.ensureVisible(find.text('패스 상세보기'));
    await tester.tap(find.text('패스 상세보기'));
    await tester.pumpAndSettle();
    expect(find.text('나머지 일자 비교'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('화면과 PDF 안내는 분야별로 중복 없이 분류된다', () {
    final result = itineraryGuidance([
      '숙소 가격 확인 필요',
      '버스 노선 확인 필요',
      '숙소 가격 확인 필요',
      '영업시간 확인 필요',
      '식당 추천 제한',
    ]);
    expect(result['숙소·숙박비'], ['숙소 가격 확인 필요']);
    expect(result['이동·교통비'], ['버스 노선 확인 필요']);
    expect(result['영업·방문 확인'], ['영업시간 확인 필요']);
    expect(result['식사·간식'], ['식당 추천 제한']);
  });
}
