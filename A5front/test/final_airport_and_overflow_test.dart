import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_schedule_settings_page.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_accommodation_page.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';

void main() {
  setUp(() => TripDraft.instance.resetInputs());
  testWidgets(
    'Generation skips airport confirmation and keeps final default times',
    (tester) async {
      final d = TripDraft.instance;
      d.start = DateTime(2026, 10, 14);
      d.end = DateTime(2026, 10, 17);
      d.entryAirport = '하네다공항';
      d.exitAirport = '하네다공항';
      d.dailyStart = const TimeOfDay(hour: 10, minute: 30);
      d.dailyEnd = const TimeOfDay(hour: 21, minute: 15);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (c, s) => const TripScheduleSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.loading,
            builder: (c, s) => const Scaffold(body: Text('생성 화면')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('AI 일정 생성하기'));
      await tester.pumpAndSettle();
      expect(find.text('입출국 시간 최종 확인'), findsNothing);
      expect(find.text('생성 화면'), findsOneWidget);
      expect(d.dailyStart, const TimeOfDay(hour: 10, minute: 30));
      expect(d.dailyEnd, const TimeOfDay(hour: 21, minute: 15));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Accommodation recommendations have no off switch', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TripAccommodationPage()));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('숙소를 지정하지 않은 날은 모두 숙소를 추천해 드립니다.'), findsOneWidget);
  });
  testWidgets(
    'Long itinerary descriptions on a phone with large text never overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final response = <String, dynamic>{
        'planId': 42,
        'timeline': [
          for (int i = 0; i < 9; i++)
            {
              'day': 1,
              'time': '${(9 + i).toString().padLeft(2, '0')}:00',
              'placeName': '관광 장소 $i',
              'category': '관광지',
              'description': List.filled(
                14,
                '긴 한국어 설명과 교통 경로·요금 안내가 있는 일정입니다.',
              ).join('\n'),
            },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: w!,
          ),
          home: ItineraryResultPage(showInitialCityRoute: false,
            response: response,
            request: {
              'title': '도쿄행',
              'startDate': '2026-10-14',
              'endDate': '2026-10-14',
              'cities': ['도쿄'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (int i = 0; i < 18; i++) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
