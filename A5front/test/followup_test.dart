import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/auth/pages/email_login_page.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_preferences_page.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_loading_page.dart';

class BackgroundApi extends PlannerApi {
  Map<String, dynamic>? captured;
  @override
  Future<Map<String, dynamic>> validatePlan(
    Map<String, dynamic> request,
  ) async => {'isWarning': false};
  @override
  GenerationTask startGeneration(Map<String, dynamic> request) {
    captured = request;
    return GenerationTask('test', request, 0)..status = 'RUNNING';
  }
}

void main() {
  setUp(() => TripDraft.instance.resetInputs());
  testWidgets('로그인과 회원가입을 전환할 때 양쪽 입력과 선택을 지운다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EmailLoginPage()));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'login@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    ))
      expect(field.controller!.text, isEmpty);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'signup@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'otherpassword');
    await tester.tap(find.text('로그인으로 돌아가기'));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    ))
      expect(field.controller!.text, isEmpty);
  });
  testWidgets('선호와 제외 테마를 직접 전환하며 중복 선택을 막는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TripPreferencesPage()));
    await tester.tap(find.text('맛집'));
    await tester.pumpAndSettle();
    expect(TripDraft.instance.themes, ['맛집']);
    await tester.tap(find.text('금지 테마'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맛집'));
    await tester.pumpAndSettle();
    expect(TripDraft.instance.themes, ['맛집']);
    expect(TripDraft.instance.excludedThemes, isEmpty);
    await tester.tap(find.text('선호 테마'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('동행자는 기존 여섯 개이며 배우자도 보인다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TripPreferencesPage()));
    await tester.tap(find.text('동행'));
    await tester.pumpAndSettle();
    for (final name in ['혼자', '친구', '연인', '부모님', '어린이', '배우자'])
      expect(find.text(name), findsOneWidget);
    expect(find.text('가족'), findsNothing);
  });
  testWidgets('생성 요청 후 입력을 복사하고 홈으로 자동 이동한다', (tester) async {
    final d = TripDraft.instance
      ..periodMode = 'nightsOnly'
      ..nights = 2
      ..cities = ['도쿄']
      ..themes = ['관광']
      ..transport = '도보 및 대중교통';
    final api = BackgroundApi();
    final router = GoRouter(
      initialLocation: '/loading',
      routes: [
        GoRoute(
          path: '/loading',
          builder: (c, s) => TripLoadingPage(api: api),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (c, s) => const Scaffold(body: Text('메인 화면')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('메인 화면'), findsOneWidget);
    expect(api.captured!['cities'], ['도쿄']);
    expect(api.captured!['tripDays'], 3);
    expect(d.cities, isEmpty);
  });
}
