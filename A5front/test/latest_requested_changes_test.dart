import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/auth/pages/permission_page.dart';
import 'package:ai_travel_planner/features/schedule/pages/saved_plans_page.dart';

class PlanTestApi extends PlannerApi {
  final ids = <int>[1, 2];
  final deleted = <int>[];
  @override
  bool get isLoggedIn => true;
  @override
  Future<List<Map<String, dynamic>>> listPlans() async => [
    for (final id in ids)
      {
        'id': id,
        'title': '일정 $id',
        'startDate': '2026-10-09',
        'endDate': '2026-10-10',
      },
  ];
  @override
  Future<void> deletePlan(int id) async {
    deleted.add(id);
    ids.remove(id);
    notifyListeners();
  }
}

void main() {
  test('Airport defaults use final daily times and title uses endpoints', () {
    final d = TripDraft();
    d.start = DateTime(2026, 10, 9);
    d.end = DateTime(2026, 10, 10);
    d.cities = ['도쿄', '요코하마', '가마쿠라'];
    d.themes = ['힐링'];
    d.transport = '대중교통';
    d.entryAirport = '하네다 공항';
    d.exitAirport = '나리타 공항';
    d.dailyStart = const TimeOfDay(hour: 10, minute: 30);
    d.dailyEnd = const TimeOfDay(hour: 21, minute: 15);
    final r = d.toRequest();
    expect(r['title'], '도쿄 ~ 가마쿠라 여행');
    expect(r['inTime'], '10:30');
    expect(r['outTime'], '21:15');
    d.title = '  가족 여행  ';
    d.entryTime = const TimeOfDay(hour: 8, minute: 0);
    expect(d.toRequest()['title'], '가족 여행');
    expect(d.toRequest()['inTime'], '08:00');
  });
  test('Old zero-minute walking data is displayed as three minutes', () {
    expect(
      itineraryTransportSummary({'mode': '도보', 'durationMinutes': 0}),
      '이동: 도보 약 3분',
    );
  });
  testWidgets(
    'Small permission screen scrolls without overflow and allowed notice closes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (call) async => 1,
          );
      await tester.pumpWidget(const MaterialApp(home: PermissionPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('위치 권한 설정'));
      await tester.pump();
      expect(find.textContaining('이미 허용'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('이미 허용'), findsNothing);
      await tester.ensureVisible(find.text('다음'));
      expect(find.text('다음'), findsOneWidget);
    },
  );
  testWidgets('Three-second hold selects plans and deletes selected plans only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PlanTestApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(child: SavedPlansSection(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.text('일정 1'));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 100));
    api.notifyListeners(); // background job progress must not destroy the held card
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('선택 삭제'), findsNothing);
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.text('선택 삭제'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('1개 선택'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('선택 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(api.deleted, [1]);
    expect(find.text('일정 1'), findsNothing);
    expect(find.text('일정 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
