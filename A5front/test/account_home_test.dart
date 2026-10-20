import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/home/widgets/latest_trip_preview.dart';
import 'package:ai_travel_planner/features/mypage/pages/mypage_page.dart';
import 'package:ai_travel_planner/features/schedule/pages/saved_plans_page.dart';

class Adapter implements HttpClientAdapter {
  List<RequestOptions> requests = [];
  bool hasPlans = true, failWithdraw = false;
  String displayName = '기존 이름';
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? f,
  ) async {
    requests.add(o);
    dynamic data;
    int status = 200;
    if (o.path.endsWith('/login'))
      return ResponseBody.fromString('header.payload.signature', 200);
    if (o.path.contains('/generation-jobs')) {
      data = {
        'jobId': 'job',
        'status': o.method == 'DELETE' ? 'CANCELLED' : 'RUNNING',
        'message': '진행 중',
      };
    } else if (o.path.endsWith('/long-trip-settings')) {
      data = {'restDaysEnabled': true, 'liveRestEveryDays': 5,
        'liveRestSightHours': 0.0, 'tourLightEveryDays': 7, 'tourLightSightHours': 3.0};
    } else if (o.path.endsWith('/withdraw')) {
      status = failWithdraw ? 500 : 200;
      data = failWithdraw ? {'message': 'DB 오류'} : '회원 탈퇴 완료';
    } else if (o.path.endsWith('/me')) {
      if (o.method == 'PATCH') displayName = o.data['displayName'];
      data = {
        'id': 1,
        'displayName': displayName,
        'email': 'owner@example.com',
      };
    } else if (o.path == '/api/v1/plans')
      data = hasPlans
          ? [
              {'id': 1, 'title': '과거 여행'},
              {'id': 2, 'title': '최근 여행'},
            ]
          : [];
    else
      data = {
        'request': {
          'startDate': '2026-10-07',
          'endDate': '2026-10-08',
          'cities': ['요코하마'],
        },
        'response': {
          'timeline': [
            {
              'day': 1,
              'time': '09:00',
              'placeName': '첫날 공원',
              'category': '관광지',
            },
            {
              'day': 2,
              'time': '10:00',
              'placeName': '둘째날 신사',
              'category': '관광지',
            },
          ],
        },
      };
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  late Adapter adapter;
  late PlannerApi api;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => 0,
        );
    adapter = Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
    dio.httpClientAdapter = adapter;
    api = PlannerApi(
      dio: dio,
      generationPollInterval: const Duration(milliseconds: 10),
    );
    await api.login('owner@example.com', 'test-only');
  });
  testWidgets('홈은 최신 계정 일정의 첫날과 슬라이드 일차를 보여준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LatestTripPreview(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('최근 여행'), findsOneWidget);
    expect(find.text('과거 여행'), findsNothing);
    expect(find.text('첫날 공원'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('둘째날 신사'), findsOneWidget);
    expect(
      adapter.requests.where((o) => o.path == '/api/v1/plans/2').length,
      1,
    );
  });
  testWidgets(
    'Same start date generation progress does not repeatedly reload the home itinerary',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LatestTripPreview(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      final task = api.startGeneration({
        'title': '같은 날짜 새 일정',
        'startDate': '2026-10-07',
        'endDate': '2026-10-08',
        'cities': ['요코하마'],
      });
      for (int n = 0; n < 20; n++)
        await tester.pump(const Duration(milliseconds: 20));
      expect(
        adapter.requests.where((r) => r.path == '/api/v1/plans').length,
        1,
      );
      expect(find.text('최근 여행'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final cancelled = api.cancelGeneration(task.id);
      await tester.pump(const Duration(milliseconds: 100));
      await cancelled;
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Holding home preview opens the owner list with that plan selected',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(body: LatestTripPreview(api: api)),
          ),
          GoRoute(
            path: AppRoutes.schedule,
            builder: (_, state) => Scaffold(
              body: SingleChildScrollView(
                child: SavedPlansSection(
                  api: api,
                  initialSelection: state.extra as int,
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('최근 여행')),
      );
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('선택 삭제'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('1개 선택'), findsOneWidget);
      expect(find.text('선택 삭제'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
  testWidgets('생성된 일정이 없으면 예시 데이터 대신 빈 상태를 표시한다', (tester) async {
    adapter.hasPlans = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LatestTripPreview(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('일정이 없습니다.'), findsOneWidget);
    expect(find.text('도쿄 여행'), findsNothing);
  });
  testWidgets('로그아웃하면 이미 표시 중인 홈과 전체 목록도 비운다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                LatestTripPreview(api: api),
                SavedPlansSection(api: api),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('최근 여행'), findsWidgets);
    api.logout();
    await tester.pumpAndSettle();
    expect(find.text('최근 여행'), findsNothing);
    expect(find.text('일정이 없습니다.'), findsOneWidget);
  });
  testWidgets('선택에서 전체 선택과 해제로 두 일정을 함께 처리한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SavedPlansSection(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3초'), findsNothing);
    await tester.tap(find.text('선택'));
    await tester.pump();
    await tester.tap(find.text('전체 선택'));
    await tester.pump();
    expect(find.text('2개 선택'), findsOneWidget);
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((c) => c.value == true),
      isTrue,
    );
    await tester.tap(find.text('전체 해제'));
    await tester.pump();
    expect(find.text('0개 선택'), findsOneWidget);
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((c) => c.value == false),
      isTrue,
    );
  });
  testWidgets('마이페이지 이름 편집은 PATCH 성공 결과를 표시한다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('기존 이름'), findsOneWidget);
    await tester.tap(find.byTooltip('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '새 이름');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('새 이름'), findsOneWidget);
    expect(
      adapter.requests.any(
        (o) => o.method == 'PATCH' && o.data['displayName'] == '새 이름',
      ),
      isTrue,
    );
  });
  test('탈퇴는 실제 인증 API 성공 후에만 토큰과 일정 초안을 비운다', () async {
    TripDraft.instance.lastGenerated = {'private': 'old account'};
    await api.withdraw();
    expect(api.isLoggedIn, isFalse);
    expect(TripDraft.instance.lastGenerated, isNull);
    expect(adapter.requests.last.path, '/api/v1/auth/withdraw');
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer header.payload.signature',
    );
  });
  test('탈퇴 실패 시 성공으로 처리하거나 로그인 토큰을 지우지 않는다', () async {
    adapter.failWithdraw = true;
    await expectLater(api.withdraw(), throwsA(isA<PlannerApiException>()));
    expect(api.isLoggedIn, isTrue);
  });
}
