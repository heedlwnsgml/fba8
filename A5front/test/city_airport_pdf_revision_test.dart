import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_region_page.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_place_content.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_pdf_card.dart';

void main() {
  test(
    'airport card receives actual access stop and walking route without adding stops',
    () {
      final places = <Map<String, dynamic>>[
        {
          'day': 1,
          'placeName': '신치토세공항',
          'category': '교통',
          'latitude': 42.78,
          'longitude': 141.68,
        },
        {
          'day': 1,
          'placeName': '신치토세공항역',
          'subType': '공항 승차 지점',
          'placeId': 'airport-access:cts',
          'latitude': 42.786,
          'longitude': 141.681,
          'transportFromPrevious': {'mode': '도보', 'durationMinutes': 5},
        },
      ];
      itineraryAttachAirportAccess(places);
      expect(places.length, 2);
      expect(
        itineraryPlaceInformation(places.first),
        contains('신치토세공항 → 신치토세공항역'),
      );
      expect(itineraryPlaceInformation(places.first), contains('도보 약 5분'));
      expect(
        (places.first['_airportAccessUrl'] as Uri)
            .queryParameters['travelmode'],
        'walking',
      );
      final nextDay = <Map<String, dynamic>>[
        {...places.first, '_airportAccessText': ''},
        {...places.last, 'day': 2},
      ];
      itineraryAttachAirportAccess(nextDay);
      expect(nextDay.first['_airportAccessText'], '');
    },
  );
  test(
    'traditional accommodations have requested hours without changing restaurants',
    () {
      for (final name in ['온천 료칸', '일본 전통 숙소', 'Sakura Ryokan', '旅館']) {
        expect(
          itineraryBusinessHours({
            'category': '숙소',
            'placeName': name,
            '_visitWeekday': 1,
          }),
          '매주 24시간 영업',
        );
      }
      expect(
        itineraryBusinessHours({
          'category': '식사',
          'placeName': '료칸 앞 식당',
          'openingHours': '오전 11:00 ~ 오후 8:00',
        }),
        isNot('매주 24시간 영업'),
      );
    },
  );
  testWidgets(
    'ordinary restaurant chip is removed but market remains distinct',
    (tester) async {
      Widget card(String type) => MaterialApp(
        home: Scaffold(
          body: ItineraryPlaceContent(
            information: '체류시간: 60분\n식사 장소 유형: $type',
            movement: '',
            explanation: '',
          ),
        ),
      );
      await tester.pumpWidget(card('식당'));
      expect(find.byType(Chip), findsNothing);
      expect(find.text('60분'), findsOneWidget);
      await tester.pumpWidget(card('시장'));
      expect(find.text('시장'), findsOneWidget);
    },
  );
  testWidgets(
    'first city selection scrolls to top and leaves selected region expanded',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      TripDraft.instance.resetInputs();
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: TripRegionPage()));
      await tester.pumpAndSettle();
      final tile = find.byKey(const ValueKey('오키나와')).last;
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: tile, matching: find.text('오키나와')).first,
      );
      await tester.pumpAndSettle();
      final checkbox = find.byWidgetPredicate(
        (w) =>
            w is CheckboxListTile &&
            w.title is Text &&
            (w.title as Text).data == '오키나와',
      );
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      expect(tester.state<ScrollableState>(scroll).position.pixels, 0);
      final expanded = tester.widget<ExpansionTile>(
        find.byType(ExpansionTile).first,
      );
      expect(
        (expanded.title as Row).children.whereType<Expanded>().first.child,
        isA<Text>(),
      );
      expect(expanded.controller!.isExpanded, isTrue);
      expect(TripDraft.instance.cities.first, '오키나와');
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('PDF headings show actual dates and omit repeated undated labels', () {
    expect(itineraryPdfDayHeading(1, '날짜 미지정'), '1일차 일정');
    expect(itineraryPdfDayHeading(2, ''), '2일차 일정');
    expect(itineraryPdfDayHeading(2, '2026.10.20'), '2일차 일정 · 2026.10.20');
  });
  test(
    'outgoing transport belongs to origin stop and never crosses day boundary',
    () {
      final timeline = <Map<String, dynamic>>[
        {
          'day': 1,
          'placeName': '공원',
          'transportFromPrevious': {'durationMinutes': 5},
        },
        {
          'day': 1,
          'placeName': '식당',
          'transportFromPrevious': {'mode': '버스', 'durationMinutes': 20},
        },
        {
          'day': 1,
          'placeName': '숙소',
          'transportFromPrevious': {'mode': '도보', 'durationMinutes': 10},
        },
        {
          'day': 2,
          'placeName': '숙소',
          'transportFromPrevious': {'mode': '도보', 'durationMinutes': 99},
        },
      ];
      itineraryAttachOutgoingLegs(timeline);
      expect((timeline[0]['_transportToNext'] as Map)['durationMinutes'], 20);
      expect((timeline[1]['_transportToNext'] as Map)['durationMinutes'], 10);
      expect(timeline[2].containsKey('_transportToNext'), false);
      expect(timeline[3].containsKey('_transportToNext'), false);
      expect(
        (timeline[1]['transportFromPrevious'] as Map)['durationMinutes'],
        20,
      );
    },
  );

  testWidgets(
    'description then visit info then outgoing route then details and directions',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryPlaceContent(
                information: '체류시간: 90분\n주소: 가마쿠라 해안로',
                movement:
                    '이동: 버스 약 20분\n교통비: 2,200원\n버스 해안선 · 공원 → 식당 · 20분\n총 이동 시간: 약 20분',
                explanation: '바다를 바라보는 공원입니다.',
                directionsUrl: Uri.https('www.google.com', '/maps/dir/'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final labels = [
        '이 장소까지 오는 방법',
        '바다를 바라보는 공원입니다.',
        '방문 정보',
        '이동 상세 보기',
        '실제 경로 보기',
      ];
      for (var i = 0; i + 1 < labels.length; i++) {
        expect(
          tester.getTopLeft(find.text(labels[i])).dy,
          lessThan(tester.getTopLeft(find.text(labels[i + 1])).dy),
        );
      }
    },
  );

  test(
    'Donghwi based cover and daily timetable PDF has long text pagination',
    () async {
      final font = pw.Font.ttf(
        ByteData.sublistView(
          File(
            '../TravelPlanner_Backend/src/main/resources/fonts/NanumGothic.ttf',
          ).readAsBytesSync(),
        ),
      );
      final bytes = await buildDonghwiSchedulePdf(
        regular: font,
        bold: font,
        japanese: font,
        title: '가마쿠라 ~ 요코하마 여행',
        period: '1박 2일 · 날짜 미지정',
        information: {
          '도시': '가마쿠라 → 요코하마',
          '동행': '친구 · 어른 2명',
          '테마': '문화 · 산책',
          '이동 수단': '대중교통',
          '입국': '하네다공항 · 10:00',
        },
        costs: {'대중교통비 (1인)': '12,400원', '숙박비 (성인 1인당)': '55,700원'},
        lodgings: [
          {'name': '해안 료칸', 'period': '1일차 ~ 2일차 (1박)', 'price': '111,300원'},
        ],
        passes: ['1일차 · 지역 1일권 · 2,400원 절약'],
        comment: '바다와 오래된 사찰을 둘러보고 요코하마의 야경을 감상하는 일정입니다.',
        notes: ['원화 금액은 100원 단위로 올림해 표시합니다.', '영업시간과 운행 정보는 출발 전에 확인하세요.'],
        days: [
          for (var day = 1; day <= 2; day++)
            ItineraryPdfDay(
              number: day,
              date: '',
              guidance: {
                '설명': '해안을 따라 산책하고 지역 문화를 둘러봅니다.',
                '관광 시간': '총 180분',
                '교통비': '성인 1인 약 6,200원',
              },
              items: [
                ...itineraryPdfCard(
                  title: '해안 공원',
                  time: '10:00',
                  category: '관광',
                  number: 1,
                  information:
                      '체류시간: 90분\n주소: 가나가와현 가마쿠라시 해안길 1-2\n전화번호: +81 467-00-0000\n영업시간: 매주 오전 10:00 ~ 오후 7:00\n영업일: 월, 화, 수, 목, 금, 토, 일',
                  movement:
                      '이동: 버스 20분 → 도보 5분\n교통비: 약 2,200원\n버스 해안선 · 공원 정류장 → 식당가 · 20분\n총 이동 시간: 약 25분',
                  explanation: '바다와 산책로를 함께 즐길 수 있는 공원입니다.',
                  directionsUrl: Uri.https('www.google.com', '/maps/dir/'),
                ),
                ...itineraryPdfCard(
                  title: '지역 식당',
                  time: '12:00',
                  category: '식사',
                  number: 2,
                  information: '체류시간: 60분\n주소: 가마쿠라 중앙로 3-4',
                  movement: '',
                  explanation: day == 1
                      ? '지역의 신선한 재료로 요리하는 식당입니다.'
                      : List.filled(
                          30,
                          '지역의 신선한 재료를 사용하며 여유롭게 식사할 수 있는 공간입니다.',
                        ).join(' '),
                ),
              ],
            ),
        ],
      );
      final out = File(
        'C:/Users/USER/Documents/Codex/2026-10-04/sork/work/donghwi-pdf-preview.pdf',
      );
      out.writeAsBytesSync(bytes);
      expect(out.lengthSync(), greaterThan(1000));
    },
  );
}
