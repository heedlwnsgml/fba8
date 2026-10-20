import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_accommodation_page.dart';
import 'package:ai_travel_planner/features/trip/widgets/trip_step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _NavigationSession extends PlannerApi {
  @override
  bool get isLoggedIn => true;
}

final appRouter = createAppRouter(api: _NavigationSession());

void main() {
  setUp(() => TripDraft.instance.resetInputs());
  Future<void> showAccommodation(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TripAccommodationPage(
          travelPeriod: DateTimeRange(
            start: DateTime(2026, 7, 2),
            end: DateTime(2026, 7, 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('add, delete and renumber independent accommodation cards', (
    tester,
  ) async {
    await showAccommodation(tester);
    expect(find.text('아직 등록한 숙소가 없습니다.'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapText(tester, '숙소 추가');
    }
    expect(find.text('숙소 3'), findsOneWidget);
    final secondDelete = find.text('삭제').at(1);
    await tester.ensureVisible(secondDelete);
    await tester.tap(secondDelete);
    await tester.pumpAndSettle();
    expect(find.text('숙소 1'), findsOneWidget);
    expect(find.text('숙소 2'), findsOneWidget);
    expect(find.text('숙소 3'), findsNothing);
    expect(find.text('삭제'), findsNWidgets(2));
  });

  testWidgets('date selections obey range and survive deleting another card', (
    tester,
  ) async {
    await showAccommodation(tester);
    await tapText(tester, '숙소 추가');
    await tapText(tester, '시작일');
    var picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.firstDate, DateTime(2026, 7, 2));
    expect(picker.lastDate, DateTime(2026, 7, 10));
    await tapText(tester, '4');
    await tapText(tester, '선택');
    expect(find.text('2026-07-04'), findsOneWidget);
    await tapText(tester, '종료일');
    picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.firstDate, DateTime(2026, 7, 4));
    await tapText(tester, '6');
    await tapText(tester, '선택');
    await tapText(tester, '시작일');
    picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.lastDate, DateTime(2026, 7, 6));
    await tapText(tester, '취소');
    await tapText(tester, '숙소 추가');
    final lastDelete = find.text('삭제').last;
    await tester.ensureVisible(lastDelete);
    await tester.tap(lastDelete);
    await tester.pumpAndSettle();
    expect(find.text('2026-07-04'), findsOneWidget);
    expect(find.text('2026-07-06'), findsOneWidget);
    expect(find.text('숙소 2'), findsNothing);
  });

  testWidgets('숙소 이름 수정은 이동 전 편집 세션에 보관된다', (tester) async {
    await showAccommodation(tester);
    await tapText(tester, '숙소 추가');
    await tester.enterText(find.byType(TextFormField).last, '테스트 숙소');
    expect(TripDraft.instance.accommodations.single['name'], '테스트 숙소');
  });

  testWidgets('통합된 6단계 순서와 이전 이동을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: AppRoutes.tripPeriod,
      routes: appRouter.configuration.routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final routes = [
      AppRoutes.tripPeriod,
      AppRoutes.tripRegion,
      AppRoutes.tripEntryExit,
      AppRoutes.tripAccommodation,
      AppRoutes.tripFixedSchedule,
      AppRoutes.tripCompanion,
    ];
    for (var i = 0; i < routes.length; i++) {
      router.go(routes[i]);
      await tester.pumpAndSettle();
      final header = tester.widget<TripStepHeader>(find.byType(TripStepHeader));
      expect(header.currentStep, i + 1);
      expect(header.totalStep, 6);
      if (i > 0) {
        await tapText(tester, '이전');
        expect(router.routeInformationProvider.value.uri.path, routes[i - 1]);
      }
    }
  });
}
