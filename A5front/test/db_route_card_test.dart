import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';

final place = {
  'day': 1,
  'time': '10:00',
  'endTime': '11:30',
  'placeName': '방문할 공원',
  'formattedAddress': '공원 주소',
  'phoneNumber': '123-456',
  'openingHours': '토요일: 09:00 ~ 18:00',
  'description': '공원에서 산책합니다.',
  'transit': {
    'mode': '지하철·버스',
    'minutes': 42,
    'fareYen': 430,
    'source': 'rail-network+gtfs',
    'estimated': true,
    'steps': [
      {
        'type': '승차',
        'category': '지하철',
        'line': '지하철 노선',
        'from': '출발역',
        'to': '환승역',
        'minutes': 20,
      },
      {'type': '환승', 'minutes': 7},
      {
        'type': '승차',
        'category': '버스',
        'line': '市営バス',
        'from': '정류장',
        'to': '공원 앞',
        'minutes': 10,
      },
      {'type': '도보', 'from': '공원 앞', 'to': '공원', 'minutes': 5},
    ],
  },
};

void main() {
  test('매일 숙소 출발과 도착의 빈 체류시간은 숨기고 방문지와 실제 시간은 유지한다', () {
    final timeline = <Map<String, dynamic>>[
      {'day': 1, 'category': '숙소', 'time': '09:00'},
      {'day': 1, 'category': '관광지', 'time': '10:00'},
      {'day': 1, 'category': '숙소', 'time': '22:00'},
      {'day': 2, 'category': '숙박', 'time': '09:00', 'endTime': '09:00'},
      {'day': 3, 'category': '숙소', 'time': '09:00', 'endTime': '09:30'},
    ];
    itineraryMarkLodgingDepartures(timeline);
    expect(itineraryPlaceInformation(timeline[0]), isNot(contains('체류시간')));
    expect(itineraryPlaceInformation(timeline[1]), contains('체류시간: 미확인'));
    expect(itineraryPlaceInformation(timeline[2]), isNot(contains('체류시간')));
    expect(itineraryPlaceInformation(timeline[3]), isNot(contains('체류시간')));
    expect(itineraryPlaceInformation(timeline[4]), contains('체류시간: 30분'));
  });

  test('공항 미지정 출발지의 비어 있는 체류시간은 생략한다', () {
    expect(
      itineraryPlaceInformation({
        '_hideEmptyStartFields': true,
        'time': '09:00',
      }),
      isNot(contains('체류시간')),
    );
    expect(
      itineraryPlaceInformation({
        '_hideEmptyStartFields': true,
        'time': '09:00',
        'endTime': '09:00',
      }),
      isNot(contains('체류시간')),
    );
    expect(
      itineraryPlaceInformation({
        '_hideEmptyStartFields': true,
        'time': '09:00',
        'endTime': '10:00',
      }),
      contains('체류시간: 60분'),
    );
  });

  test('식사 부태그는 주태그와 함께 표시하고 카페를 식사로 바꾸지 않는다', () {
    expect(
      itineraryCategory({
        'category': '쇼핑',
        'themes': ['쇼핑', '맛집'],
      }),
      '쇼핑-식사',
    );
    expect(itineraryCategory({'category': '관광지', 'theme': '사진,식사'}), '관광지-식사');
    expect(itineraryCategory({'category': '쇼핑', 'subType': '식당'}), '쇼핑-식사');
    expect(
      itineraryCategory({
        'category': '쇼핑',
        'themes': ['카페'],
      }),
      '쇼핑',
    );
    expect(itineraryCategory({'category': '식음', 'subType': '라멘'}), '식사');
    expect(itineraryCategory({'category': '식음', 'subType': '카페'}), '간식');
  });

  test('현재 DB DTO를 읽어 지하철 버스 도보의 각각 시간을 유지한다', () {
    final normalized = itineraryNormalizePlace(place);
    final summary = itineraryTransportSummary(
      normalized['transportFromPrevious'] as Map,
    );
    expect(summary, contains('지하철 20분 → 버스 10분 → 도보 5분'));
    expect(summary, isNot(contains('대중교통 42분')));
    final detail = itineraryDescription(place);
    expect(detail, contains('市営バス'));
    expect(detail, contains('정류장 → 공원 앞 · 10분'));
    expect(detail, contains('¥430'));
    expect(detail, contains('총 이동 시간: 약 42분'));
    expect(summary, isNot(contains('총')));
    expect(place.containsKey('transportFromPrevious'), isFalse);
  });
  test('체류시간과 장소 정보는 최신 요청 순서이며 누락 시간을 만들어내지 않는다', () {
    expect(
      itineraryPlaceInformation(
        place,
      ).split('\n').map((s) => s.split(':').first),
      ['체류시간', '주소', '전화번호', '영업시간', '영업일'],
    );
    expect(itineraryStayDuration(place), '90분');
    expect(itineraryStayDuration({'time': '09:00'}), '미확인');
    expect(itineraryStayDuration({'time': '23:00', 'endTime': '00:30'}), '90분');
  });
  testWidgets('작은 화면에서도 정보 순서와 펼치는 상세 이동정보를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(showInitialCityRoute: false,
          request: {
            'title': '테스트',
            'startDate': '2026-10-17',
            'endDate': '2026-10-17',
            'cities': ['도쿄'],
          },
          response: {
            'planId': 1,
            'timeline': [place],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = find.textContaining('방문할 공원').last;
    final movement = find.textContaining('지하철 20분 → 버스 10분 → 도보 5분');
    final info = find.text('90분');
    final explanation = find.text('공원에서 산책합니다.');
    expect(title, findsOneWidget);
    expect(
      tester.getTopLeft(title).dy,
      lessThan(tester.getTopLeft(movement).dy),
    );
    expect(
      tester.getTopLeft(info).dy,
      lessThan(tester.getTopLeft(explanation).dy),
    );
    expect(
      tester.getTopLeft(movement).dy,
      lessThan(tester.getTopLeft(info).dy),
    );
    expect(find.text('이 장소까지 오는 방법'), findsOneWidget);
    await tester.ensureVisible(find.text('이동 상세 보기'));
    await tester.tap(find.text('이동 상세 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('市営バス'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
