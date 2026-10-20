import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_route_map.dart';

class _NavigationSession extends PlannerApi {
  @override
  bool get isLoggedIn => true;
}

final appRouter = createAppRouter(api: _NavigationSession());

void main() {
  testWidgets('실제 라우터의 완전 이탈은 입력을 비운다', (tester) async {
    final draft = TripDraft.instance;
    draft.resetInputs();
    appRouter.go(AppRoutes.tripPeriod);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();
    draft.cities = ['도쿄'];
    draft.transport = '차량 렌트';
    draft.title = '미완료 여행';
    appRouter.go(AppRoutes.tripRegion);
    await tester.pumpAndSettle();
    expect(draft.title, '미완료 여행');
    appRouter.go(AppRoutes.login);
    await tester.pumpAndSettle();
    expect(draft.title, isEmpty);
    expect(draft.cities, isEmpty);
    expect(draft.transport, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('핀의 다음 구간 자동차 URL을 사용하고 불가능한 구간은 링크가 없다', (tester) async {
    Uri? opened;
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '35.0,139.0',
      'destination': '35.1,139.1',
      'travelmode': 'driving',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: ItineraryRouteMap(
              loadTiles: false,
              openDirections: (value) async {
                opened = value;
                return true;
              },
              stops: [
                const RouteMapStop(
                  name: '숙소',
                  detail: '숙소 정보',
                  latitude: 35,
                  longitude: 139,
                  useProvidedDirections: true,
                ),
                RouteMapStop(
                  name: '공원',
                  detail: '공원 정보',
                  latitude: 35.1,
                  longitude: 139.1,
                  useProvidedDirections: true,
                  directionsToHere: url,
                ),
                const RouteMapStop(
                  name: '다른 섬',
                  detail: '항공 이동',
                  latitude: 36,
                  longitude: 140,
                  useProvidedDirections: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('실제 경로 보기'));
    await tester.pumpAndSettle();
    expect(opened, url);
    Navigator.of(tester.element(find.text('1. 숙소'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.directions), findsNothing);
  });
}
