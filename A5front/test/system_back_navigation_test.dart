import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_travel_planner/core/widgets/system_back_page.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';

class _NavigationSession extends PlannerApi {
  @override
  bool get isLoggedIn => true;
}

final appRouter = createAppRouter(api: _NavigationSession());

void main() {
  setUp(() {
    TripDraft.instance.resetInputs();
  });

  testWidgets(
    'Android back returns to the previous trip step and preserves input',
    (tester) async {
      TripDraft.instance.themes = ['맛집'];
      TripDraft.instance.mealsPerDay = 5;
      appRouter.go(AppRoutes.tripScheduleSettings);
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.tripTransport,
      );
      expect(TripDraft.instance.mealsPerDay, 5);
      expect(TripDraft.instance.themes, ['맛집']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Root back asks before exit and dialog back cancels', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const SystemBackPage(child: Scaffold(body: Text('메인'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('앱을 종료할까요?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('앱을 종료할까요?'), findsNothing);
    expect(find.text('메인'), findsOneWidget);
  });
}
