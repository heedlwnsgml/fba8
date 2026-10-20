import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:flutter_test/flutter_test.dart';

TripDraft readyDraft() => TripDraft()
  ..start = DateTime(2026, 10, 10)..end = DateTime(2026, 10, 12)
  ..entryAirport = '하네다공항'..exitAirport = '나리타국제공항'..cities = ['도쿄']..themes = ['맛집']..excludedThemes = ['쇼핑']
  ..transport = '도보 및 대중교통'..interIslandTransport = '배';

void main() {
  test('생성 성공은 요청 스냅샷과 저장 결과를 유지하고 다음 입력만 초기화한다', () {
    final draft = readyDraft();
    final request = draft.toRequest();
    final result = <String, dynamic>{'request': request, 'response': {'planId': 1}};
    draft.completeGeneration(result);
    expect(draft.lastGenerated, same(result));
    expect(request['themes'], ['맛집']);
    expect(request['excludedThemes'], ['쇼핑']);
    expect(request['interIslandTransportation'], '배');
    expect(draft.start, isNull);
    expect(draft.cities, isEmpty);
    expect(draft.excludedThemes, isEmpty);
    expect(draft.interIslandTransport, '비행기');
    draft.themes.add('힐링');
    expect(request['themes'], ['맛집']);
  });
  test('기간 변경은 범위 밖 날짜만 비우고 장소와 시간을 유지한다', () {
    final draft = readyDraft()
      ..accommodations = [{'name': '숙소', 'checkIn': '2026-10-10', 'checkOut': '2026-10-12'}]
      ..fixedSchedules = [{'name': '예약', 'date': '2026-10-10', 'startTime': '10:00:00', 'endTime': '11:00:00'}]
      ..start = DateTime(2026, 10, 11);
    draft.constrainDependentDates();
    expect(draft.accommodations.single['name'], '숙소');
    expect(draft.accommodations.single['checkIn'], isNull);
    expect(draft.accommodations.single['checkOut'], '2026-10-12');
    expect(draft.fixedSchedules.single['date'], isNull);
    expect(draft.fixedSchedules.single['startTime'], '10:00:00');
    expect(draft.toRequest, throwsFormatException);
  });
  test('선호와 금지 테마 중복을 막는다', () {
    final draft = readyDraft()..excludedThemes = ['맛집'];
    expect(draft.toRequest, throwsFormatException);
  });
}
