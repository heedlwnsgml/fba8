import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_preferences_page.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_route_map.dart';

void main() {
  testWidgets('휴대폰 입력 화면과 핀 상세 시각 검수', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final bytes = File(
        '../TravelPlanner_Backend/src/main/resources/fonts/NanumGothic.ttf',
      ).readAsBytesSync();
      final font = FontLoader('NanumGothic')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                'C:/Users/USER/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
    });
    final key = GlobalKey();
    Widget app(Widget child) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'NanumGothic',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        ),
        home: child,
      ),
    );
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'C:/Users/USER/Documents/Codex/2026-10-04/sork/work/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await tester.pumpWidget(app(const TripPreferencesPage()));
    await tester.pumpAndSettle();
    await capture('trip-preferences-preview');
    await tester.tap(find.text('이동'));
    await tester.pumpAndSettle();
    await capture('trip-transport-preview');
    await tester.tap(find.text('하루 일정'));
    await tester.pumpAndSettle();
    await capture('trip-daily-preview');
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: SizedBox(
            height: 300,
            child: ItineraryRouteMap(
              loadTiles: false,
              stops: [
                RouteMapStop(
                  name: '시부야 방문 장소',
                  detail:
                      '10:15\n관광지\n이동: 지하철 20분, 도보 5분\n지하철 · 도쿄 메트로 긴자선 · 우에노역 → 시부야역 · 20분\n도보 · 시부야역 → 방문 장소 · 5분\n총 이동 시간: 약 25분\n교통비: 성인 1인 ¥250\n시간표는 운행 상황에 따라 변경될 수 있습니다.\n체류시간: 60분\n주소: 도쿄도 시부야구 시부야 1-2-3\n전화번호: +81 3-1234-5678\n영업시간: 10:00 ~ 20:00\n설명: 다양한 전시와 전망 공간을 둘러볼 수 있는 장소입니다.',
                  latitude: 35.66,
                  longitude: 139.7,
                ),
                RouteMapStop(name: "다음 방문 장소", detail: "12:00", latitude: 35.67, longitude: 139.71),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await capture('map-stop-preview');
    await tester.tap(find.text('이동 상세 보기'));
    await tester.pumpAndSettle();
    await capture('map-stop-expanded-preview');
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('CAPTURE_REVISION_UI'));
}
