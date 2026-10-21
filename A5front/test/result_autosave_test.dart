import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';

final request = {
  'startDate': '2026-10-07',
  'endDate': '2026-10-07',
  'cities': ['요코하마'],
};
Map<String, dynamic> response(String name) => {
  'planId': 1,
  'timeline': [
    {
      'itineraryId': 11,
      'day': 1,
      'time': '11:00',
      'placeName': name,
      'category': '관광지',
    },
  ],
};

class FakeApi extends PlannerApi {
  @override
  Future<String> getHotelCurrencyPreference() async => 'KRW';
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {'krwPerJpy': 8.5};
  int deletions = 0, regenerations = 0;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> deletePlanItem(int id, int itemId) async {
    if (fail) throw const PlannerApiException('저장 실패');
    deletions++;
    return {
      'request': request,
      'response': {'planId': 1, 'timeline': <dynamic>[]},
    };
  }

  @override
  Future<Map<String, dynamic>> regeneratePlan(
    int id,
    Map<String, dynamic> req,
  ) async {
    regenerations++;
    return response('새 공원');
  }
}

Future<void> mount(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(1000, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/result',
    routes: [
      GoRoute(
        path: '/result',
        builder: (c, s) => ItineraryResultPage(showInitialCityRoute: false,
          api: api,
          response: response('기존 공원'),
          request: request,
        ),
      ),
      GoRoute(
        path: '/schedule',
        builder: (c, s) => const Scaffold(body: Text('일정 목록')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();

}

void main() {
  testWidgets('저장된 결과에서도 삭제가 즉시 API에 반영된다', (tester) async {
    final api = FakeApi();
    await mount(tester, api);
    expect(find.text('자동 저장됨'), findsWidgets);
    // PDF 메뉴를 사용한 뒤에도 편집 상태가 유지된다.
    await tester.tap(find.byTooltip('PDF 저장 및 공유'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('일정 PDF'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(api.deletions, 1);
    expect(find.text('기존 공원'), findsNothing);
    expect(find.text('자동 저장됨'), findsWidgets);
  });
  testWidgets('재생성은 서버 응답으로 바뀌며 자동 저장 상태를 유지한다', (tester) async {
    final api = FakeApi();
    await mount(tester, api);
    await tester.tap(find.text('다시 추천'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생성'));
    await tester.pumpAndSettle();
    expect(api.regenerations, 1);
    expect(find.text('새 공원'), findsWidgets);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('일정 목록'), findsOneWidget);
    expect(find.text('일정을 저장하시겠습니까?'), findsNothing);
  });
  testWidgets('DB 저장 실패 시 기존 일정을 유지한다', (tester) async {
    final api = FakeApi()..fail = true;
    await mount(tester, api);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('기존 공원'), findsWidgets);
    expect(api.deletions, 0);
    expect(find.textContaining('변경을 저장하지 못했습니다'), findsOneWidget);
  });
}
