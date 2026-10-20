import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/features/trip/widgets/lodging_budget_fields.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';
import 'package:ai_travel_planner/features/schedule/widgets/transport_details.dart';

class RateApi extends PlannerApi {
  RateApi({this.admin = false});
  final bool admin;
  @override
  bool get isAdmin => admin;
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {
    'krwPerJpy': 8.4906,
    'rateDate': '2026-10-16',
    'sourceUrl': 'https://example.com',
  };
}

void main() {
  test('실제 다음 시각에 맞춰 체류 여유시간을 포함하며 DB 원본 종료시간은 유지한다', () {
    final rows = <Map<String, dynamic>>[
      {'day': 1, 'time': '10:00', 'endTime': '12:00', 'category': '관광지'},
      {
        'day': 1,
        'time': '12:37',
        'transportFromPrevious': {'durationMinutes': 22},
      },
    ];
    itineraryIncludeStayBuffer(rows);
    expect(rows.first['endTime'], '12:00');
    expect(rows.first['_displayEndTime'], '12:15');
    expect(itineraryPlaceInformation(rows.first), contains('체류시간: 135분'));
  });
  test('매주 동일한 영업시간과 휴무 요일을 각각 표시한다', () {
    final data = {
      'openingHours': '수: 오전 10:00 ~ 오후 7:00',
      'weeklyOpeningHours': [
        '월요일: 휴무일',
        '화요일: 휴무일',
        for (final day in ['수', '목', '금', '토', '일'])
          '$day요일: 오전 10:00 ~ 오후 7:00',
      ].join(' | '),
    };
    expect(itineraryBusinessHours(data), '매주 오전 10:00 ~ 오후 7:00');
    expect(itineraryBusinessClosures(data), '월요일, 화요일');
    expect(itineraryDiningLabel('개별 식당'), '식당');
    expect(itineraryDiningLabel('시장'), '시장');
  });
  testWidgets('원·엔 어느 쪽을 입력해도 숙소 예산은 엔으로 전달하고 아래 환산을 표시한다', (tester) async {
    final d = TripDraft.instance;
    d.hotelBudgetYen = null;
    d.hotelBudgetInput = null;
    d.hotelBudgetCurrency = 'JPY';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LodgingBudgetFields(api: RateApi()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '10000');
    await tester.pump();
    expect(find.textContaining('85,000원'), findsOneWidget);
    await tester.tap(find.text('원 (KRW)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '100000');
    await tester.pump();
    expect(d.hotelBudgetYen, (100000 / 8.4906).floor());
    expect(find.textContaining('숙소 예산: 100,000원'), findsOneWidget);
    d.hotelBudgetYen = null;
    d.hotelBudgetInput = null;
    d.hotelBudgetCurrency = 'JPY';
  });
  testWidgets('같은 역에서 대기하거나 환승할 때 역 이름을 반복하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransportDetails(
            text: '대기 · 사쿠라기초역 → 사쿠라기초역 · 5분\n환승 · A역 → B역 · 10분',
          ),
        ),
      ),
    );
    expect(find.text('사쿠라기초역 → 사쿠라기초역'), findsNothing);
    expect(find.text('A역 → B역'), findsOneWidget);
  });
  testWidgets('미확인 필드는 일반 사용자에게 숨기고 관리자에게만 표시한다', (tester) async {
    Widget result(bool admin) => MaterialApp(
      home: ItineraryResultPage(showInitialCityRoute: false,
        api: RateApi(admin: admin),
        request: {
          'title': '방문',
          'cities': ['도쿄'],
          'tripDays': 1,
        },
        response: {
          'timeline': [
            {
              'day': 1,
              'time': '10:00',
              'placeName': '공원',
              'category': '관광지',
              'address': '확인된 주소',
            },
          ],
          'warnings': ['숙소 자료 없음'],
        },
      ),
    );
    await tester.pumpWidget(result(false));
    await tester.pumpAndSettle();
    expect(find.textContaining('미확인'), findsNothing);
    expect(find.textContaining('자료 없음'), findsNothing);
    expect(find.textContaining('정보 없음'), findsNothing);
    await Scrollable.ensureVisible(tester.element(find.text('방문 정보')), alignment: 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('방문 정보'));
    await tester.pumpAndSettle();
    expect(find.textContaining('확인된 주소'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(result(true));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(find.text('방문 정보')), alignment: 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('방문 정보'));
    await tester.pumpAndSettle();
    expect(find.text('전화번호'), findsOneWidget);
    expect(find.text('정보 없음'), findsWidgets);
  });
}
