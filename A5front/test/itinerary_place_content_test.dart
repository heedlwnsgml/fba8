import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_place_content.dart';

const information =
    '체류시간: 90분\n주소: 도쿄도 시부야구 진구마에 1-2-3\n전화번호: +81 3-1234-5678\n영업시간: 오전 10:00 ~ 오후 7:00\n영업일: 화, 수, 목, 금, 토, 일';
const movement =
    '이동: 지하철 20분 → 도보 5분\n교통비: 성인 1인 약 2,200원\n지하철 · 긴자선 · 출발역 → 도착역 · 20분\n도보 · 도착역 → 공원 · 5분\n총 이동 시간: 약 25분';
Widget app(Widget content, {double scale = 1}) => MaterialApp(
  theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
  builder: (c, w) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: w!,
  ),
  home: Scaffold(
    backgroundColor: const Color(0xFFF3F6FC),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(18), child: content),
      ),
    ),
  ),
);
void main() {
  testWidgets('핵심 정보와 영업일을 보여주고 주소와 상세 이동은 펼쳐서 본다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ItineraryPlaceContent(
                information: information,
                movement: movement,
                explanation: '정원과 전시 공간을 함께 둘러보는 장소입니다.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('90분'), findsOneWidget);
    expect(find.text('영업일'), findsOneWidget);
    expect(find.text('화, 수, 목, 금, 토, 일'), findsOneWidget);
    expect(find.textContaining('도쿄도'), findsNothing);
    expect(find.textContaining('출발역 → 도착역'), findsNothing);
    await tester.tap(find.text('이동 상세 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('출발역 → 도착역'), findsOneWidget);
    await tester.ensureVisible(find.text('방문 정보'));
    await tester.tap(find.text('방문 정보'));
    await tester.pumpAndSettle();
    expect(find.textContaining('도쿄도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('좁은 화면과 큰 글자에서도 넘치지 않고 긴 설명을 펼친다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final content = ItineraryPlaceContent(
      information: information,
      movement: movement,
      explanation: List.filled(14, '정원과 전시 공간을 둘러봅니다.').join(' '),
    );
    await tester.pumpWidget(app(content, scale: 1.8));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('설명 더 보기'));
    await tester.tap(find.text('설명 더 보기'));
    await tester.pumpAndSettle();
    expect(find.text('설명 접기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('날짜 미정은 전체 영업일을, 지정된 날짜는 해당 요일의 시간만 표시한다', () {
    final p = <String, dynamic>{
      'weeklyOpeningHours':
          '월요일: 휴무일 | 화요일: 10:00 ~ 19:00 | 수요일: 10:00 ~ 19:00 | 목요일: 10:00 ~ 19:00 | 금요일: 10:00 ~ 19:00 | 토요일: 11:00 ~ 20:00 | 일요일: 11:00 ~ 20:00',
    };
    expect(itineraryPlaceInformation(p), contains('영업일: 화, 수, 목, 금, 토, 일'));
    expect(itineraryBusinessHours(p), contains('토, 일: 11:00 ~ 20:00'));
    p['_visitWeekday'] = 5;
    expect(itineraryPlaceInformation(p), contains('영업시간: 토요일: 11:00 ~ 20:00'));
    expect(itineraryPlaceInformation(p), isNot(contains('영업일:')));
  });
  testWidgets('카드 화면 시각 검수', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('NanumGothic')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '../TravelPlanner_Backend/src/main/resources/fonts/NanumGothic.ttf',
              ).readAsBytesSync(),
            ),
          ),
        );
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
    final content = Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('10:00 · 관광', style: TextStyle(color: Colors.blue)),
            const SizedBox(height: 8),
            const Text(
              '1. 방문할 공원',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            ItineraryPlaceContent(
              information: information,
              movement: movement,
              explanation: '정원을 천천히 산책하고 계절마다 달라지는 전시를 함께 둘러보는 장소입니다.',
              directionsUrl: Uri.https('www.google.com', '/maps/dir/'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(RepaintBoundary(key: key, child: app(content)));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        'C:/Users/USER/Documents/Codex/2026-10-04/sork/work/itinerary-card-applied.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('CAPTURE_CARD_UI'));
}
