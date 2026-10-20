import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';

void main() {
  test('숙소 공통 소개와 빈 설명은 숨기되 실제 특징은 보존한다', () {
    final generic = '도쿄 여행 중 머무는 숙박 시설로, 하루 일정 후 휴식하고 다음 날 여행을 시작하는 거점입니다.';
    expect(
      itineraryPlaceExplanation({
        'category': '숙소',
        'summary': generic,
        'description': '숙소 도착 및 휴식',
      }),
      '',
    );
    expect(itineraryPlaceExplanation({'category': '숙소'}), '');
    expect(
      itineraryPlaceExplanation({
        'category': '숙소',
        'summary': '강변 전망과 노천 온천탕을 갖춘 료칸',
      }),
      '설명: 강변 전망과 노천 온천탕을 갖춘 료칸',
    );
    expect(
      itineraryDescription({'category': '숙소', 'summary': generic}),
      isNot(contains('여행 중 머무는')),
    );
  });
  test('자동차는 미확인 요금 없이 자동차 경로를 열고 대중교통은 유지한다', () {
    expect(
      itineraryDescription({
        'transit': {'mode': '자동차', 'minutes': 20},
      }),
      isNot(contains('요금 미확인')),
    );
    expect(
      itineraryDescription({
        'transit': {'mode': '버스', 'minutes': 20},
      }),
      contains('요금 미확인'),
    );
    expect(
      itineraryDescription({
        'transit': {'mode': '자동차', 'minutes': 20, 'fareYen': 300},
      }),
      contains('¥300'),
    );
    final from = {'latitude': 35.0, 'longitude': 139.0},
        to = {'latitude': 35.1, 'longitude': 139.1};
    expect(
      itineraryDirectionsUrl(
        from,
        to,
        driving: true,
      )!.queryParameters['travelmode'],
      'driving',
    );
    expect(
      itineraryDirectionsUrl(
        from,
        to,
        walking: true,
        driving: true,
      )!.queryParameters['travelmode'],
      'walking',
    );
    expect(itineraryDirectionsUrl(from, from, driving: true), isNull);
  });
  test('숙소 출발 역할 문구는 설명에서 빼고 실제 숙소 소개는 유지한다', () {
    expect(itineraryPlaceExplanation({'description': '숙소 출발'}), '');
    expect(
      itineraryPlaceExplanation({
        'description': '숙소 출발',
        'summary': '강변의 온천 료칸',
      }),
      '설명: 강변의 온천 료칸',
    );
    expect(
      itineraryDescription({'description': '숙소 출발'}),
      isNot(contains('숙소 출발')),
    );
  });
  test('단계 이동은 유지하고 완전 이탈은 초기화하되 요청과 생성 결과는 보존한다', () {
    final draft = TripDraft()
      ..start = DateTime(2026, 10, 12)
      ..end = DateTime(2026, 10, 14)
      ..cities = ['도쿄']
      ..transport = '차량 렌트'
      ..themes = ['카페'];
    final request = draft.toRequest();
    draft.lastGenerated = {'id': 1};
    draft.handleRouteChange('/trip/period', '/trip/region');
    draft.handleRouteChange('/trip/region', '/trip/period');
    expect(draft.cities, ['도쿄']);
    draft.handleRouteChange('/trip/period', '/home');
    expect(draft.start, isNull);
    expect(draft.cities, isEmpty);
    expect(draft.transport, isNull);
    expect(draft.mealsPerDay, 2);
    expect(draft.lastGenerated, {'id': 1});
    expect(request['cities'], ['도쿄']);
    draft.title = '새 여행';
    draft.handleRouteChange('/home', '/trip/period');
    expect(draft.title, '새 여행');
  });
}
