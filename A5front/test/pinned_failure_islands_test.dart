import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
import 'package:ai_travel_planner/core/state/island_travel_labels.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_loading_page.dart';

class FailedValidation implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    r.path.endsWith('/login')
        ? 'header.payload.signature'
        : '{"message":"비행기·배 이동은 지원하지 않습니다."}',
    r.path.endsWith('/login') ? 200 : 400,
    headers: {
      Headers.contentTypeHeader: [
        r.path.endsWith('/login') ? 'text/plain' : 'application/json',
      ],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TripDraft.instance.loadDefaults();
    TripDraft.instance.resetInputs();
  });
  testWidgets('고정 후 수정한 값은 생성 검증 실패해도 보존되고 다음 세션에서 복원된다', (t) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FailedValidation();
    final api = PlannerApi(dio: dio);
    await t.runAsync(() => api.login('test@example.com', 'test'));
    final d = TripDraft.instance
      ..start = DateTime(2026, 10, 21)
      ..end = DateTime(2026, 10, 23)
      ..cities = ['미야코지마']
      ..themes = ['관광']
      ..transport = '대중교통';
    await d.saveDefaults(6);
    d.themes = ['힐링'];
    d.mealsPerDay = 3;
    d.restDaysEnabled = false;
    d.dailyEnd = const TimeOfDay(hour: 21, minute: 30);
    await t.pumpWidget(MaterialApp(home: TripLoadingPage(api: api)));
    await t.pumpAndSettle();
    expect(find.textContaining('비행기·배'), findsOneWidget);
    d.resetInputs();
    expect(d.hasDefaults(6), isTrue);
    expect(d.themes, ['힐링']);
    expect(d.mealsPerDay, 3);
    expect(d.dailyEnd.hour, 21);
    expect(d.restDaysEnabled, false);
    final next = TripDraft();
    await next.loadDefaults();
    expect(next.themes, ['힐링']);
    expect(next.hasDefaults(6), isTrue);
    await t.pumpWidget(const SizedBox());
    api.logout();
  });
  test('고정하지 않은 입력은 다음 요청으로 복사하지 않는다', () async {
    final d = TripDraft()..themes = ['관광'];
    await d.saveDefaults(6);
    d.cities = ['도쿄'];
    d.themes = ['사진'];
    await d.persistPinnedInputs();
    d.resetInputs();
    expect(d.themes, ['사진']);
    expect(d.cities, isEmpty);
    await d.clearDefaults(6);
    d.resetInputs();
    expect(d.themes, isEmpty);
  });
  test('섬 안내는 표시만 바꾸고 요청의 도시명은 유지한다', () {
    expect(islandCityLabel('미야코지마'), contains('섬'));
    expect(islandCityLabel('이시가키'), contains('비행기'));
    expect(islandCityLabel('도쿄'), '도쿄');
    expect(islandCityLabel('삿포로'), '삿포로');
    final d = TripDraft()
      ..periodMode = 'nightsOnly'
      ..nights = 2
      ..cities = ['미야코지마']
      ..themes = ['관광']
      ..transport = '대중교통';
    expect(d.toRequest()['cities'], ['미야코지마']);
  });
  test('계산한 비행시간은 표시하고 적재 안내는 관리자에게만 보인다', () {
    final row = <String, dynamic>{
      'placeName': '비행기 이동 필요',
      'category': '비행기',
      'transit': {
        'mode': '비행기 이동 필요',
        'source': 'distance-flight',
        'minutes': 240,
        'estimated': true,
        'fareYen': null,
        'steps': [
          {
            'type': '승차',
            'category': '비행기',
            'from': '신치토세 공항',
            'to': '미야코 공항',
            'minutes': 240,
          },
        ],
      },
    };
    final text = itineraryDescription(row, admin: true);
    expect(text, contains('240분'));
    expect(text, contains('추후 데이터 적재 필요'));
    expect(
      itineraryVisibleText(text, admin: false),
      isNot(contains('추후 데이터 적재 필요')),
    );
    expect(itineraryVisibleText(text, admin: true), contains('추후 데이터 적재 필요'));
    expect(itineraryVisibleText(text, admin: false), isNot(contains('미확인')));
    expect(
      itineraryTransportSummary(
        itineraryNormalizePlace(row)['transportFromPrevious'],
      ),
      contains('비행기 약 240분'),
    );
  });
}
