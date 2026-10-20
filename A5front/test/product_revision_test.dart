import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/state/city_ordering.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_preferences_page.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_entry_exit_page.dart';
import 'package:ai_travel_planner/features/trip/widgets/lodging_budget_fields.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_travel_planner/features/trip/widgets/trip_step_header.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TripDraft.instance.loadDefaults();
    TripDraft.instance.resetInputs();
  });
  test('날짜 미정은 실제 날짜를 전송하지 않고 숙소·고정 일정을 일차로 보낸다', () {
    final d = TripDraft()
      ..periodMode = 'nightsOnly'
      ..nights = 2
      ..cities = ['도쿄']
      ..themes = ['관광']
      ..transport = '도보 및 대중교통';
    d.accommodations = [
      {'name': '호텔', 'checkIn': '1970-01-01', 'checkOut': '1970-01-03'},
    ];
    d.fixedSchedules = [
      {
        'name': '고정 장소',
        'date': '1970-01-02',
        'startTime': '12:00:00',
        'endTime': '13:00:00',
      },
    ];
    final request = d.toRequest();
    expect(request.containsKey('startDate'), false);
    expect(request.containsKey('endDate'), false);
    expect(request['tripDays'], 3);
    expect(request['accommodations'][0]['checkInDay'], 1);
    expect(request['fixedSchedules'][0]['dayNumber'], 2);
    expect(request['fixedSchedules'][0]['date'], isNull);
  });
  test('기본값은 새 앱 세션과 입력 초기화 후에도 유지되며 해제할 수 있다', () async {
    final d = TripDraft()
      ..themes = ['카페']
      ..transport = '차량 렌트'
      ..dailyStart = const TimeOfDay(hour: 10, minute: 30)
      ..hotelBudgetYen = 12000;
    await d.saveDefaults(6);
    await d.saveDefaults(4);
    d.resetInputs();
    expect(d.themes, ['카페']);
    expect(d.hotelBudgetYen, 12000);
    final next = TripDraft();
    await next.loadDefaults();
    expect(next.transport, '차량 렌트');
    expect(next.dailyStart.hour, 10);
    await next.clearDefaults(6);
    next.resetInputs();
    expect(next.themes, isEmpty);
    expect(next.hotelBudgetYen, 12000);
  });
  test('도시 이름이 여러 개면 제목의 첫 도시를 기준으로 가까운 도시부터 정렬한다', () {
    final anchor = itineraryAnchorCity('도쿄 ~ 삿포로 여행', ['삿포로', '도쿄'], []);
    expect(anchor, '도쿄');
    final cities = ['삿포로', '요코하마', '도쿄']
      ..sort((a, b) => compareCities(anchor, a, b));
    expect(cities, ['도쿄', '요코하마', '삿포로']);
  });
  testWidgets('날짜 미정 입출국 화면의 다음은 시작일 달력을 요구하지 않는다', (tester) async {
    final d = TripDraft.instance
      ..periodMode = 'nightsOnly'
      ..nights = 2
      ..cities = ['도쿄'];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (c, s) => const TripEntryExitPage()),
        GoRoute(
          path: AppRoutes.tripAccommodation,
          builder: (c, s) => const Scaffold(body: Text('숙소 단계')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('숙소 단계'), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(d.start, isNull);
  });
  testWidgets('숙소 요금 전용임을 명시하고 하루당·총액을 전송한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LodgingBudgetFields())),
    );
    expect(find.textContaining('식비·교통비·관광 비용은 포함하지 않습니다'), findsOneWidget);
    await tester.tap(find.text('엔 (JPY)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 숙박비'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '80000');
    expect(TripDraft.instance.hotelBudgetMode, 'total');
    expect(TripDraft.instance.hotelBudgetYen, 80000);
  });
  testWidgets('통합 취향 화면은 작은 휴대폰의 큰 글자에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: w!,
        ),
        home: const TripPreferencesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 5; i++) {
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    for (final label in ['동행', '이동', '하루 일정']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -350),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('상단 고정 버튼은 누를 때마다 고정과 해제를 반복한다', (tester) async {
    TripDraft.instance.themes = ['관광'];
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TripStepHeader(currentStep: 6))),
    );
    final button = find.byTooltip('눌러 기본값 고정 · 다시 눌러 해제');
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(TripDraft.instance.hasDefaults(6), isTrue);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(TripDraft.instance.hasDefaults(6), isFalse);
  });
}
