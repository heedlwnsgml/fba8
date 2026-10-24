import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/features/trip/widgets/lodging_budget_fields.dart';
import 'package:ai_travel_planner/features/schedule/widgets/pass_day_comparison.dart';
import 'package:ai_travel_planner/features/schedule/widgets/transport_details.dart';
import 'package:ai_travel_planner/features/schedule/widgets/directions_preview.dart';

class _RateApi extends PlannerApi {
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {
    'krwPerJpy': 8.4906,
    'rateDate': '2026-10-16',
  };
}

void main() {
  test('일반 승차권과 패스 이름은 각각 한 번만 표시한다', () {
    final regular = itineraryCompactPassDay({'day': 2, 'optimalFareYen': 400, 'regularFareYen': 400, 'passes': <dynamic>[]});
    expect('일반 승차권'.allMatches(regular).length, 1);
  });
  testWidgets('숙소 예산은 원화가 기본이며 환율을 받은 뒤 엔으로 환산한다', (tester) async {
    final d = TripDraft.instance;
    d.resetInputs();
    expect(d.hotelBudgetCurrency, 'KRW');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LodgingBudgetFields(api: _RateApi()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selector = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>).last,
    );
    expect(selector.selected, {'KRW'});
    await tester.enterText(find.byType(TextFormField), '100000');
    await tester.pump();
    expect(d.hotelBudgetYen, (100000 / 8.4906).floor());
    expect(d.hotelBudgetConversionPending, isFalse);
    expect(find.textContaining('숙소 예산: 100,000원'), findsOneWidget);
  });
  test('날짜가 있으면 해당 요일만, 날짜 미정이면 주간 시간과 휴무일을 표시한다', () {
    final data = <String, dynamic>{
      'openingHours': '수요일: 오전 10:00 ~ 오후 7:00',
      'weeklyOpeningHours': [
        '월요일: 휴무일',
        for (final day in ['화', '수', '목', '금', '토', '일'])
          '$day요일: 오전 10:00 ~ 오후 7:00',
      ].join(' | '),
    };
    final undated = itineraryPlaceInformation(data);
    expect(undated, contains('영업시간: 매주 오전 10:00 ~ 오후 7:00'));
    expect(undated, contains('영업일: 화, 수, 목, 금, 토, 일'));
    data['_visitWeekday'] = 2;
    for (final text in [
      itineraryPlaceInformation(data),
      itineraryDescription(data),
    ]) {
      expect(text, contains('수요일: 오전 10:00 ~ 오후 7:00'));
      expect(text, isNot(contains('매주')));
      expect(text, isNot(contains('휴무일:')));
    }
  });
  testWidgets('저렴한 패스 일자만 먼저 보여주고 나머지 일자는 펼쳐서 확인한다', (tester) async {
    final costs = {
      'dailyCosts': [
        {
          'day': 1,
          'regularFareYen': 800,
          'optimalFareYen': 500,
          'passes': [
            {'name': '도쿄 패스'},
          ],
        },
        {'day': 2, 'regularFareYen': 400, 'optimalFareYen': 400, 'passes': []},
        {
          'day': 3,
          'regularFareYen': 500,
          'optimalFareYen': 700,
          'passes': [
            {'name': '지역 패스'},
          ],
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
    expect(find.textContaining('1일차 - 500엔 (일반 승차권 800엔)'), findsOneWidget);
    expect(find.textContaining('2일차 -'), findsNothing);
    expect(find.textContaining('3일차 -'), findsNothing);
    await tester.tap(find.text('나머지 일자 비교'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2일차 - 일반 승차권 400엔'), findsOneWidget);
    expect(find.textContaining('3일차 - 700엔'), findsOneWidget);
  });
  testWidgets('대기에만 약을 붙이고 총 이동시간과 승차시간은 유지한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransportDetails(
            text: '대기 · 6분\n지하철 · 테스트선 · 20분\n총 이동 시간: 약 26분',
          ),
        ),
      ),
    );
    expect(find.text('대기 · 약 6분'), findsOneWidget);
    expect(find.text('지하철 · 테스트선 · 20분'), findsOneWidget);
    expect(find.text('총 이동 시간: 약 26분'), findsOneWidget);
  });
  testWidgets('팝업은 지도만 표시하고 상세 설명은 일정 카드에서 확인한다', (tester) async {
    final route = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=35,139&destination=36,140&travelmode=transit',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDirectionsPreview(
                context,
                route,
                content: const Text('구글 경로 화면'),
                details: '이동: 지하철 20분\n지하철 · 테스트선 · 20분',
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('구글 경로 화면'), findsOneWidget);
    expect(find.text('지하철 · 테스트선 · 20분'), findsNothing);
    expect(find.text('일정 이동 상세'), findsNothing);
    expect(find.text('구글 경로 화면'), findsOneWidget);
    expect(itineraryEmbeddedDirections(route).queryParameters['dirflg'], 'r');
    expect(
      itineraryEmbeddedDirections(route).queryParameters['saddr'],
      '35,139',
    );
  });
  test('개요 설명에서 관광지·식사·시간 목록을 떼어내 중복하지 않는다', () {
    expect(
      itineraryOverviewDescription(
        '가마쿠라에서 온전히 하루를 보내는 날입니다. 사진·문화 테마를 중심으로 둘러봅니다. 주요 방문지는 해안 공원입니다. 식사는 라멘입니다.',
      ),
      '가마쿠라에서 온전히 하루를 보내는 날입니다. 사진·문화 테마를 중심으로 둘러봅니다.',
    );
  });
}
