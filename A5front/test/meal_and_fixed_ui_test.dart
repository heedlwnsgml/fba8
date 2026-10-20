import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_companion_page.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_schedule_settings_page.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_fixed_schedule_page.dart';

Widget app(Widget page) => MaterialApp(
  theme: ThemeData(
    fontFamily: const bool.fromEnvironment('CAPTURE_UI') ? 'UiKorean' : null,
  ),
  locale: const Locale('ko', 'KR'),
  supportedLocales: const [Locale('ko', 'KR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: page,
);
void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      final loader = FontLoader('UiKorean');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            await File(r'C:\Windows\Fonts\malgun.ttf').readAsBytes(),
          ),
        ),
      );
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              r'C:\Users\USER\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
            ).readAsBytes(),
          ),
        ),
      );
      await icons.load();
    }
  });
  setUp(() => TripDraft.instance.resetInputs());
  testWidgets('혼자 선택 시 기존 아동을 지우고 아동 선택을 막는다', (tester) async {
    TripDraft.instance.ageGroups = ['아동'];
    await tester.pumpWidget(app(const TripCompanionPage()));
    await tester.tap(find.text('혼자'));
    await tester.pump();
    expect(TripDraft.instance.ageGroups, isEmpty);
    await tester.ensureVisible(find.text('아동'));
    await tester.tap(find.text('아동'));
    await tester.pump();
    expect(TripDraft.instance.ageGroups, isEmpty);
  });
  testWidgets('식사 2회 기본값과 선택·간식 자동 저장', (tester) async {
    await tester.pumpWidget(app(const TripScheduleSettingsPage()));
    await tester.ensureVisible(find.text('하루 식사 횟수'));
    expect(TripDraft.instance.mealsPerDay, 2);
    await tester.ensureVisible(find.text('3회'));
    await tester.tap(find.text('3회'));
    await tester.pump();
    await tester.ensureVisible(find.text('중간에 카페·간식도 들르기'));
    await tester.tap(find.text('중간에 카페·간식도 들르기'));
    await tester.pump();
    expect(TripDraft.instance.mealsPerDay, 3);
    expect(TripDraft.instance.includeSnacks, isTrue);
    TripDraft.instance.start = DateTime(2026, 10, 7);
    TripDraft.instance.end = DateTime(2026, 10, 9);
    TripDraft.instance.entryAirport = '하네다공항';
    TripDraft.instance.exitAirport = '나리타국제공항';
    TripDraft.instance.cities = ['요코하마'];
    TripDraft.instance.themes = ['관광'];
    TripDraft.instance.transport = '도보';
    expect(TripDraft.instance.toRequest()['mealsPerDay'], 3);
    expect(TripDraft.instance.toRequest()['includeSnacks'], isTrue);
  });
  testWidgets('맛집 테마에서 5회 선택 후 테마 해제 시 3회로 조정한다', (tester) async {
    TripDraft.instance.themes = ['맛집'];
    await tester.pumpWidget(app(const TripScheduleSettingsPage()));
    await tester.ensureVisible(find.text('5회'));
    await tester.tap(find.text('5회'));
    await tester.pump();
    expect(TripDraft.instance.mealsPerDay, 5);
    await tester.pumpWidget(const SizedBox());
    TripDraft.instance.themes = ['관광'];
    await tester.pumpWidget(app(const TripScheduleSettingsPage()));
    await tester.ensureVisible(find.text('3회'));
    expect(find.text('4회'), findsNothing);
    expect(find.text('5회'), findsNothing);
    expect(TripDraft.instance.mealsPerDay, 3);
  });
  testWidgets('카페 테마는 간식을 자동 선택하고 빡센 대신 알찬 강도를 표시한다', (tester) async {
    TripDraft.instance.themes = ['카페'];
    await tester.pumpWidget(app(const TripScheduleSettingsPage()));
    expect(find.text('알찬'), findsOneWidget);
    expect(find.text('빡센'), findsNothing);
    await tester.ensureVisible(find.text('중간에 카페·간식도 들르기'));
    expect(TripDraft.instance.includeSnacks, isTrue);
    final tile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '중간에 카페·간식도 들르기'),
    );
    expect(tile.value, isTrue);
  });
  testWidgets('고정 일정 달력의 요일과 월을 한국어로 표시한다', (tester) async {
    TripDraft.instance.start = DateTime(2026, 10, 7);
    TripDraft.instance.end = DateTime(2026, 10, 9);
    await tester.pumpWidget(app(const TripFixedSchedulePage()));
    await tester.ensureVisible(find.text('날짜 선택'));
    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    final picker = find.byType(DatePickerDialog);
    expect(picker, findsOneWidget);
    expect(Localizations.localeOf(tester.element(picker)).languageCode, 'ko');
    expect(find.textContaining('Wed'), findsNothing);
    expect(find.textContaining('10월'), findsWidgets);
  });
  testWidgets('고정 일정 입력 화면은 좁은 화면에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: app(const TripFixedSchedulePage())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          r'C:\Users\USER\Documents\Codex\2026-10-04\sork\work\fixed-ui-after.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
    }
  });
}
