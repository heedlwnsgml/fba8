import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_loading_page.dart';

class WarningApi extends PlannerApi {
  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) async =>
      {'isWarning': true, 'warningMessage': '도시에 비해 기간이 짧습니다.'};
}

void main() {
  testWidgets(
    'Modify conditions returns to period selection and preserves trip inputs',
    (tester) async {
      final draft = TripDraft.instance;
      draft.resetInputs();
      draft.start = DateTime(2026, 10, 14);
      draft.end = DateTime(2026, 10, 14);
      draft.entryAirport='하네다공항';draft.exitAirport='나리타국제공항';draft.cities = ['도쿄', '요코하마'];
      draft.themes = ['관광'];
      draft.transport = '대중교통';
      final api = WarningApi();
      addTearDown(api.dispose);
      final router = GoRouter(
        initialLocation: '/loading-test',
        routes: [
          GoRoute(
            path: '/loading-test',
            builder: (c, s) => TripLoadingPage(api: api),
          ),
          GoRoute(
            path: AppRoutes.tripPeriod,
            builder: (c, s) => const Scaffold(body: Text('기간 선택 화면')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds:400));
      final left = tester.getRect(find.widgetWithText(TextButton, '조건 수정'));
      final right = tester.getRect(find.widgetWithText(FilledButton, '계속 생성'));
      expect(left.width, closeTo(right.width, .1));
      expect(left.left, lessThan(right.left));
      await tester.tap(find.text('조건 수정'));
      await tester.pumpAndSettle();
      expect(find.text('기간 선택 화면'), findsOneWidget);
      expect(draft.cities, ['도쿄', '요코하마']);
      expect(draft.start, DateTime(2026, 10, 14));
      expect(tester.takeException(), isNull);
    },
  );
}
