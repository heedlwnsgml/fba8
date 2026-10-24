import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/trip/widgets/city_selection_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/services/permission_onboarding.dart';

class _NavigationSession extends PlannerApi {
  @override
  bool get isLoggedIn => true;
}

final appRouter = createAppRouter(api: _NavigationSession());

void main() {
  final requestedPermissions = <int>[];
  setUp(() {
    requestedPermissions.clear();
    SharedPreferences.setMockInitialValues({});
    TripDraft.instance.resetInputs();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async {
            if (call.method == 'requestPermissions') {
              final values = List<int>.from(call.arguments as List);
              requestedPermissions.addAll(values);
              return {for (final permission in values) permission: 1};
            }
            return 0;
          },
        );
  });
  test('Permission introduction is shown once after completion', () async {
    expect(await PermissionOnboarding.shouldShow(), isTrue);
    await PermissionOnboarding.complete();
    expect(await PermissionOnboarding.shouldShow(), isFalse);
  });
  testWidgets('First startup shows permission UI and completion opens login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go(AppRoutes.splash);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한 설정'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(requestedPermissions.length, 2);
    expect(await PermissionOnboarding.shouldShow(), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'City confirmation appears only when selection changes and lock is below title',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TripDraft.instance.cities = ['도쿄'];
      appRouter.go(AppRoutes.tripRegion);
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
      await tester.pumpAndSettle();
      expect(find.text('선택한 도시'), findsNothing);
      expect(tester.getTopLeft(find.byType(ExpansionTile).first).dy, lessThan(tester.getTopLeft(find.text('도시 고정')).dy));
      expect(
        tester.getTopLeft(find.text('도시 고정')).dy,
        greaterThan(tester.getTopLeft(find.byType(CitySelectionMap)).dy),
      );
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('선택한 도시'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('다음')));
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.tripEntryExit,
      );
      appRouter.go(AppRoutes.tripRegion);
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('선택한 도시'), findsNothing);
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.tripEntryExit,
      );
      TripDraft.instance.cities = ['横浜'];
      appRouter.go(AppRoutes.tripRegion);
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('선택한 도시'), findsOneWidget);
      await tester.tap(find.text('선택 수정'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
