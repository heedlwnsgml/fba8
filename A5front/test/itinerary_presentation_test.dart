import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0분 근거리 이동도 숨기지 않는다', () {
    final text = itineraryDescription({
      'transportFromPrevious': {
        'mode': '도보',
        'source': 'estimate',
        'durationMinutes': 0,
        'estimated': true,
      },
    });
    expect(text, contains('도보 약 3분'));
  });

  test('확인된 노선명과 승하차역 주행시간을 먼저 표시한다', () {
    final text = itineraryDescription({
      'transportFromPrevious': {
        'mode': '철도·도보',
        'source': 'official-catalog',
        'durationMinutes': 27,
        'estimated': true,
        'fareYen': 200,
        'steps': [
          {
            'mode': '도보',
            'lineName': '',
            'from': '호텔',
            'to': '요코하마역',
            'durationMinutes': 5,
          },
          {
            'mode': '대기',
            'lineName': '',
            'from': '요코하마역',
            'to': '요코하마역',
            'durationMinutes': 10,
          },
          {
            'mode': '철도',
            'lineName': '미나토미라이선 (横浜 → みなとみらい)',
            'from': '요코하마역',
            'to': '미나토미라이역',
            'durationMinutes': 4,
          },
          {
            'mode': '도보',
            'lineName': '',
            'from': '미나토미라이역',
            'to': '관광지',
            'durationMinutes': 8,
          },
        ],
      },
    });
    expect(text, startsWith('이동: 도보 5분 → 철도 4분 → 도보 8분'));
    expect(text, contains('요코하마역 → 미나토미라이역 · 4분'));
    expect(text, contains('대기 · 약 10분'));
    expect(text, contains('¥200'));
  });
  test('미확인 이동에 확인된 노선이 있는 것처럼 표시하지 않는다', () {
    final text = itineraryDescription({
      'transportFromPrevious': {
        'mode': '대중교통',
        'source': 'estimate',
        'durationMinutes': 19,
        'estimated': true,
        'steps': [],
      },
    });
    expect(text, contains('경로 확인 필요 · 소요시간 미확인'));
    expect(text, contains('일정 시각은 임시 배치'));
    expect(text, contains('요금 미확인'));
    expect(text, isNot(contains('19분')));
  });
  test('구간 조회 링크의 출발 도착 좌표와 이동수단을 확인한다', () {
    final from = {'latitude': 35.6909, 'longitude': 139.7003},
        to = {'latitude': 35.6808, 'longitude': 139.7225};
    final url = itineraryDirectionsUrl(from, to)!;
    expect(url.host, 'www.google.com');
    expect(url.queryParameters['travelmode'], 'transit');
    expect(url.queryParameters['origin'], '35.6909,139.7003');
    expect(url.queryParameters['destination'], '35.6808,139.7225');
    expect(
      itineraryDirectionsUrl(
        from,
        to,
        walking: true,
      )!.queryParameters['travelmode'],
      'walking',
    );
    expect(itineraryDirectionsUrl(from, from), isNull);
    expect(itineraryDirectionsUrl({}, to), isNull);
  });

  test('테마 일정 문구만 제외하고 장소 정보와 실제 설명을 유지한다', () {
    final description = itineraryDescription({
      'description': '쇼핑,맛집 일정',
      'briefDescription': '역 앞 쇼핑몰',
      'address': '쇼난 주소',
      'phoneNumber': '123',
      'openingDays': '매일',
    });
    expect(description, isNot(contains('쇼핑,맛집 일정')));
    expect(description, contains('역 앞 쇼핑몰'));
    expect(description, contains('주소: 쇼난 주소'));
    expect(
      itineraryDescription({'description': '고정 일정 · 13:00 ~ 14:00'}),
      contains('고정 일정'),
    );
  });
  test('미정 입국과 출국은 맨 앞과 맨 뒤에 정렬한다', () {
    final rows = [
      {'time': '시간 미정', 'placeName': '출국 · 공항'},
      {'time': '09:00', 'placeName': '숙소 출발'},
      {'time': '시간 미정', 'placeName': '입국 · 공항'},
    ];
    rows.sort((a, b) => itineraryOrder(a).compareTo(itineraryOrder(b)));
    expect(rows.first['placeName'], startsWith('입국'));
    expect(rows.last['placeName'], startsWith('출국'));
  });
  test('교통 추정 시간과 NAVITIME 노선별 시간 및 대기를 표시한다', () {
    final text = itineraryDescription({
      'transportFromPrevious': {
        'mode': '대중교통',
        'durationMinutes': 25,
        'estimated': true,
        'source': 'navitime-average',
        'steps': [
          {
            'mode': '철도',
            'lineName': 'JR 도카이도선',
            'from': '도쿄',
            'to': '쇼난',
            'durationMinutes': 20,
          },
        ],
      },
      'waitingMinutes': 30,
    });
    expect(text, contains('총 이동 시간: 약 25분'));
    expect(text, isNot(contains('NAVITIME 평균')));
    expect(text, contains('JR 도카이도선'));
    expect(text, contains('도쿄 → 쇼난'));
    expect(text, contains('30분'));
  });
  test('숙소 미지정 날짜 추천은 이전 끄기 선택과 관계없이 항상 요청한다', () {
    final draft = TripDraft()
      ..start = DateTime(2026, 10, 6)
      ..end = DateTime(2026, 10, 7)
      ..entryAirport = '하네다공항'..exitAirport = '나리타국제공항'..cities = ['도쿄']
      ..themes = ['관광']
      ..transport = '도보';
    expect(draft.toRequest()['suggestHotel'], isTrue);
    draft.suggestHotel = false;
    expect(draft.toRequest()['suggestHotel'], isTrue);
  });
  test('일반 이동 시간에서 추정 괄호를 숨긴다', () {
    final text = itineraryDescription({
      'transportFromPrevious': {
        'mode': '도보',
        'durationMinutes': 3,
        'estimated': true,
        'source': 'estimate',
      },
    });
    expect(text, '이동: 도보 약 3분\n총 이동 시간: 약 3분');
  });

  test(
    'legacy food items distinguish meals from snacks and invalid pins are rejected',
    () {
      expect(itineraryCategory({'category': '식음', 'placeName': '스시 식당'}), '식사');
      expect(
        itineraryCategory({
          'category': '식음',
          'placeName': 'BREAD IT BE bakery',
        }),
        '간식',
      );
      expect(itineraryCategory({'category': '간식', 'placeName': '카페'}), '간식');
      expect(validItineraryLocation(0, 0), isFalse);
      expect(validItineraryLocation(double.nan, 139), isFalse);
      expect(validItineraryLocation(139, 35), isFalse);
      expect(validItineraryLocation(35.55, 139.78), isTrue);
    },
  );
  test('공식 구간 요금을 성인 1인 기준으로 표시한다', () {
    final text = itineraryDescription({
      'transportFromPrevious': {
        'mode': '철도·도보',
        'durationMinutes': 32,
        'estimated': true,
        'source': 'official-catalog',
        'fareYen': 200,
      },
    });
    expect(text, contains('교통비: 성인 1인 ¥200'));
    expect(text, contains('공식 역간 노선·요금'));
  });
  test('미수집 교통 요금을 0원으로 표시하지 않는다', () {
    final text = itineraryDescription({
      'transportFromPrevious': {
        'mode': '대중교통',
        'durationMinutes': 30,
        'estimated': true,
        'source': 'estimate',
        'fareYen': null,
      },
    });
    expect(text, contains('교통비: 요금 미확인'));
    expect(text, isNot(contains('¥0')));
  });
}
