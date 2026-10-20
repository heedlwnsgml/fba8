import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_route_map.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';

class MapPreviewApi extends PlannerApi {
  @override
  Future<String> getHotelCurrencyPreference() async => 'JPY';
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {'krwPerJpy': 8.5};
}

void main() {
  test('weather guidance is hidden while meal and opening guidance remain', () {
    final result = itineraryGuidance([
      '날씨 예보 범위 밖입니다.',
      '일정 중 장마철 (평년 기준)',
      '식당 예약을 확인하세요.',
      '월요일 휴무인 곳이 있습니다.',
    ]);
    expect(result.values.expand((x) => x).length, 2);
    expect(
      result.values
          .expand((x) => x)
          .any((s) => s.contains('날씨') || s.contains('장마')),
      false,
    );
  });
  testWidgets(
    'map stays fixed, pin selects and scrolls to its card, bottom actions follow scroll direction',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final korean = File('C:/Windows/Fonts/malgun.ttf');
        if (korean.existsSync())
          await ui.loadFontFromList(
            await korean.readAsBytes(),
            fontFamily: 'PreviewKorean',
          );
        final icons = File(
          'C:/Users/USER/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (icons.existsSync())
          await ui.loadFontFromList(
            await icons.readAsBytes(),
            fontFamily: 'MaterialIcons',
          );
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'PreviewKorean'),
          home: RepaintBoundary(
            key: boundary,
            child: ItineraryResultPage(showInitialCityRoute: false,
              loadMapTiles: false,
              api: MapPreviewApi(),
              request: {
                'title': '지도 연동 확인',
                'startDate': '2026-10-19',
                'endDate': '2026-10-19',
                'cities': ['도쿄'],
              },
              response: {
                'planId': 42,
                'warnings': ['날씨 예보 범위 밖입니다.'],
                'timeline': [
                  for (int i = 0; i < 12; i++)
                    {
                      'day': 1,
                      'time': '${9 + i}:00',
                      'endTime': '${9 + i}:40',
                      'placeName': '방문 장소 $i',
                      'category': '관광지',
                      'latitude': i < 3 ? 35.71 + i * .01 : null,
                      'longitude': i < 3 ? 139.79 + i * .01 : null,
                      'summary': '도쿄의 방문 장소를 둘러보는 일정입니다.',
                      'address': '도쿄 주소 $i',
                      'recommendedDuration': 40,
                    },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byType(ItineraryRouteMap);
      final scroll = find.byKey(const ValueKey('itinerary-day-scroll'));
      final top = tester.getTopLeft(map);
      expect(
        find.byKey(const ValueKey('itinerary-bottom-actions')),
        findsOneWidget,
      );
      await tester.dragFrom(tester.getBottomLeft(scroll) + const Offset(150, -30), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(map), top);
      expect(
        find.byKey(const ValueKey('itinerary-bottom-actions')),
        findsNothing,
      );
      await tester.dragFrom(tester.getBottomLeft(scroll) + const Offset(150, -30), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('itinerary-bottom-actions')),
        findsOneWidget,
      );
      await tester.tap(find.text('2').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final card = tester.getRect(
        find.byKey(const ValueKey('timeline-card-0-1')),
      );

      expect(find.textContaining('날씨 예보 범위'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          r'C:\Users\USER\Documents\Codex\2026-10-04\sork\work\sticky-map-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      expect(card.top, greaterThan(tester.getBottomLeft(map).dy));
      expect(card.top, lessThan(tester.getBottomLeft(scroll).dy));
    },
  );
}
