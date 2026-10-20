import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_place_content.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_pdf_card.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_route_map.dart';

class _Adapter implements HttpClientAdapter {
  String email = 'admin@example.com';
  bool reject = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (reject)
      return ResponseBody.fromString(
        '{}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': email, 'role': 'ADMIN'})))
        .replaceAll('=', '');
    return ResponseBody.fromString(
      'header.$payload.signature',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'admin view preference survives logout and new client but stays account scoped',
    () async {
      final adapter = _Adapter();
      PlannerApi make() => PlannerApi(
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
          ..httpClientAdapter = adapter,
      );
      final api = make();
      await api.login('admin@example.com', 'test');
      api.setViewAsUser(true);
      await Future<void>.delayed(Duration.zero);
      api.logout();
      await api.login('admin@example.com', 'test');
      expect(api.viewAsUser, true);
      expect(api.isAdmin, true);
      final fresh = make();
      await fresh.login('admin@example.com', 'test');
      expect(fresh.viewAsUser, true);
      adapter.email = 'another@example.com';
      await fresh.login('another@example.com', 'test');
      expect(fresh.viewAsUser, false);
      api.dispose();
      fresh.dispose();
    },
  );
  testWidgets('cold protected navigation and HTTP401 both return to login', (
    tester,
  ) async {
    final adapter = _Adapter();
    final api = PlannerApi(
      dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
        ..httpClientAdapter = adapter,
    );
    final router = createAppRouter(api: api);
    router.go(AppRoutes.tripRegion);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    await tester.runAsync(() => api.login('admin@example.com', 'test'));
    router.go(AppRoutes.tripRegion);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.tripRegion,
    );
    adapter.reject = true;
    await tester.runAsync(
      () => expectLater(api.getProfile(), throwsA(isA<PlannerApiException>())),
    );
    await tester.pumpAndSettle();
    expect(api.isLoggedIn, false);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    api.dispose();
  });
  testWidgets(
    'hotel gets verified one-room nightly price as a visible metric',
    (tester) async {
      final timeline = <Map<String, dynamic>>[
        {
          'day': 1,
          'category': '숙소',
          'placeName': '바다 료칸',
          'placeId': 'hotel-A',
        },
      ];
      itineraryAttachLodgingPrices(timeline, [
        {
          'name': '바다 료칸',
          'placeId': 'hotel-A',
          'checkInDay': 1,
          'checkOutDay': 2,
          'lowestNightPerRoomYen': 13100,
        },
      ]);
      final information = itineraryPlaceInformation(timeline.first);
      expect(information, contains('숙박비: ¥13100'));
      expect(information, isNot(contains('평균 숙박요금')));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryPlaceContent(
                information: information,
                movement: '',
                explanation: '',
              ),
            ),
          ),
        ),
      );
      expect(find.text('숙박비'), findsOneWidget);
      expect(find.textContaining('13100'), findsOneWidget);
    },
  );
  testWidgets('incoming pin shows route to clicked stop including final stop', (
    tester,
  ) async {
    Uri? opened;
    final route = Uri.parse(
      'https://www.google.com/maps/dir/?origin=A&destination=B',
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
                const RouteMapStop(
                  name: 'A',
                  detail: '첫 장소',
                  latitude: 35.325,
                  longitude: 139.555,
                  incomingDirections: true,
                  useProvidedDirections: true,
                ),
                RouteMapStop(
                  name: 'B',
                  detail: '마지막 장소',
                  latitude: 35.318,
                  longitude: 139.551,
                  incomingDirections: true,
                  useProvidedDirections: true,
                  directionsToHere: route,
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
    expect(opened, route);
  });
  test('compact PDF links to separate detail page and back', () async {
    final font = pw.Font.ttf(
      ByteData.sublistView(
        File(
          '../TravelPlanner_Backend/src/main/resources/fonts/NanumGothic.ttf',
        ).readAsBytesSync(),
      ),
    );
    List<pw.Widget> card(bool expanded) => itineraryPdfCard(
      title: '해안 료칸',
      time: '18:00',
      category: '숙소',
      number: 2,
      information:
          '1박 최저가: 객실 1개 · 약 111,300원\n주소: 가마쿠라 해안로 1-2\n전화번호: +81 123-456-789\n영업시간: 매주 24시간 영업',
      movement:
          '이동: 버스 약 20분\n교통비: 약 2,200원\n버스 해안선 · 공원 → 료칸 정류장 · 20분\n총 이동 시간: 약 20분',
      explanation: '해안을 바라보며 온천을 즐길 수 있는 전통 숙소입니다.',
      detailKey: 'd1-s2',
      expanded: expanded,
    );
    final bytes = await buildDonghwiSchedulePdf(
      regular: font,
      bold: font,
      japanese: font,
      title: '가마쿠라 여행',
      period: '1박 2일 · 날짜 미지정',
      information: {'도시': '가마쿠라'},
      costs: {'숙박비': '111,300원'},
      lodgings: [],
      passes: [],
      notes: [],
      days: [
        ItineraryPdfDay(
          number: 1,
          date: '',
          guidance: {},
          items: card(false),
          details: card(true),
        ),
      ],
    );
    File(
      'C:/Users/USER/Documents/Codex/2026-10-04/sork/work/session-pdf-details-preview.pdf',
    ).writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(1000));
  });
}
