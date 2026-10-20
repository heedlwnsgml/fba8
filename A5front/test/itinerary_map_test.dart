import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_route_map.dart';

const first = RouteMapStop(
  name: '가마쿠라 신사',
  detail: '09:06 · 관광지',
  latitude: 35.325,
  longitude: 139.555,
);
const second = RouteMapStop(
  name: '가마쿠라 식당',
  detail: '11:00 · 식음',
  latitude: 35.318,
  longitude: 139.551,
);
Widget map(List<RouteMapStop> stops) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 600,
      height: 280,
      child: ItineraryRouteMap(stops: stops, loadTiles: false),
    ),
  ),
);
void main() {
  testWidgets('핀을 누르면 해당 번호의 주소 전화 영업시간 설명을 보여준다', (tester) async {
    const rich = RouteMapStop(
      name: '방문 공원',
      detail:
          '체류시간: 90분\n주소: 공원 주소\n전화번호: 123\n영업시간: 09:00 ~ 18:00\n설명: 산책하는 공원',
      latitude: 35.325,
      longitude: 139.555,
    );
    await tester.pumpWidget(map([rich, second]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('1. 방문 공원'), findsOneWidget);
    await tester.tap(find.text('방문 정보'));
    await tester.pumpAndSettle();
    expect(find.text('공원 주소'), findsOneWidget);
    expect(find.text('산책하는 공원'), findsOneWidget);
    expect(find.text('실제 경로 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty or invalid positions do not display a misleading default map',
    (tester) async {
      await tester.pumpWidget(
        map([
          const RouteMapStop(
            name: '위치 미정',
            detail: '',
            latitude: 0,
            longitude: 0,
          ),
        ]),
      );
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.textContaining('위치 정보가 있는 장소가 없어'), findsOneWidget);
    },
  );
  testWidgets('numbered stops connect in visit order', (tester) async {
    await tester.pumpWidget(map([first, second]));
    await tester.pumpAndSettle();
    expect(find.text('장소 2곳 · 방문 순서'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      2,
    );
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('1. 가마쿠라 신사'), findsOneWidget);
    expect(find.text('09:06 · 관광지'), findsOneWidget);
  });
  testWidgets(
    'changing day updates markers and camera and single repeated coordinate stays finite',
    (tester) async {
      await tester.pumpWidget(map([first, second]));
      await tester.pumpAndSettle();
      const far = RouteMapStop(
        name: '아오모리',
        detail: '10:00',
        latitude: 40.82,
        longitude: 140.74,
      );
      await tester.pumpWidget(map([far, far]));
      await tester.pumpAndSettle();
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(layer.markers.every((m) => m.point.latitude == 40.82), isTrue);
      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      expect(camera.center.latitude, closeTo(40.82, 0.01));
      expect(camera.zoom.isFinite, isTrue);
      await tester.tap(find.byTooltip('전체 경로 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'departure and return at one hotel keep both visit numbers visible',
    (tester) async {
      await tester.pumpWidget(map([first, second, first]));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        2,
      );
      expect(find.text('1·3'), findsOneWidget);
      await tester.tap(find.text('1·3'));
      await tester.pumpAndSettle();
      expect(find.text('같은 위치의 일정'), findsOneWidget);
      expect(find.text('1. 가마쿠라 신사'), findsOneWidget);
      expect(find.text('3. 가마쿠라 신사'), findsOneWidget);
    },
  );

  testWidgets('Visit order line remains visible when geometry exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: ItineraryRouteMap(
              stops: [first, second],
              loadTiles: false,
              paths: const [
                RouteMapPath(
                  coordinates: [
                    [35.325, 139.555],
                    [35.321, 139.556],
                    [35.318, 139.551],
                  ],
                  source: 'official-gtfs',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Visit order is connected and map interaction can be paused', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: ItineraryRouteMap(
              stops: [first, second],
              loadTiles: false,
              paths: const [
                RouteMapPath(
                  coordinates: [
                    [35.325, 139.555],
                    [35.318, 139.551],
                  ],
                  source: 'osm-walking',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(
      tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .interactionOptions
          .flags,
      InteractiveFlag.all,
    );
    await tester.tap(find.byTooltip('지도 조작 종료'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .interactionOptions
          .flags,
      InteractiveFlag.none,
    );
  });
  testWidgets('Camera fits stops without invisible route detours', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: ItineraryRouteMap(
              stops: [first, second],
              loadTiles: false,
              paths: const [
                RouteMapPath(
                  coordinates: [
                    [35.325, 139.555],
                    [35.33, 139.61],
                    [35.318, 139.551],
                  ],
                  source: 'official-gtfs',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
    expect(camera.visibleBounds.east, lessThan(139.61));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Second pin opens directions to third and last has no onward route',
    (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 280,
              child: ItineraryRouteMap(
                stops: [first, second, first],
                loadTiles: false,
                openDirections: (uri) async {
                  opened = uri;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실제 경로 보기'));
      await tester.pumpAndSettle();
      expect(opened?.host, 'www.google.com');
      expect(opened?.queryParameters['origin'], '35.318,139.551');
      expect(opened?.queryParameters['destination'], '35.325,139.555');
      Navigator.of(tester.element(find.text('2. 가마쿠라 식당'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('1·3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3. 가마쿠라 신사'));
      await tester.pumpAndSettle();
      expect(find.text('이 날의 마지막 장소입니다.'), findsOneWidget);
      expect(find.byIcon(Icons.directions), findsNothing);
    },
  );
  testWidgets(
    'outgoing provided route uses the clicked pin rather than the next pins route',
    (tester) async {
      Uri? opened;
      final route1 = Uri.parse(
        'https://www.google.com/maps/dir/?origin=A&destination=B',
      );
      final route2 = Uri.parse(
        'https://www.google.com/maps/dir/?origin=B&destination=C',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 280,
              child: ItineraryRouteMap(
                loadTiles: false,
                openDirections: (url) async {
                  opened = url;
                  return true;
                },
                stops: [
                  RouteMapStop(
                    name: 'A',
                    detail: '첫 장소',
                    latitude: 35.325,
                    longitude: 139.555,
                    useProvidedDirections: true,
                    outgoingDirections: true,
                    directionsToHere: route1,
                  ),
                  RouteMapStop(
                    name: 'B',
                    detail: '둘째 장소',
                    latitude: 35.318,
                    longitude: 139.551,
                    useProvidedDirections: true,
                    outgoingDirections: true,
                    directionsToHere: route2,
                  ),
                  const RouteMapStop(
                    name: 'C',
                    detail: '마지막 장소',
                    latitude: 35.31,
                    longitude: 139.54,
                    useProvidedDirections: true,
                    outgoingDirections: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실제 경로 보기'));
      await tester.pumpAndSettle();
      expect(opened, route2);
      expect(tester.takeException(), isNull);
    },
  );
}
