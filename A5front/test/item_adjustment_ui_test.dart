import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';

Map<String, dynamic> request() => {
  'title': '대체 장소 확인',
  'tripDays': 2,
  'cities': ['도쿄', '요코하마'],
  'companion': '친구',
};
Map<String, dynamic> response() => {
  'planId': 1,
  'days': [
    {'day': 1, 'city': '도쿄'},
    {'day': 2, 'city': '요코하마'},
  ],
  'timeline': [
    {
      'id': 11,
      'day': 1,
      'time': '09:00',
      'endTime': '10:00',
      'placeName': '기존 관광지',
      'category': '관광지',
      'latitude': 35.68,
      'longitude': 139.76,
    },
    {
      'id': 12,
      'day': 1,
      'time': '11:00',
      'placeName': '나리타 공항',
      'category': '공항',
      'latitude': 35.76,
      'longitude': 140.38,
    },
    {
      'id': 21,
      'day': 2,
      'time': '09:00',
      'endTime': '10:00',
      'placeName': '다음 날 관광지',
      'category': '관광지',
      'latitude': 35.45,
      'longitude': 139.63,
    },
  ],
};

class AdjustmentApi extends PlannerApi {
  int writes = 0;
  Map<String, String>? preferences;
  @override
  Future<String> getHotelCurrencyPreference() async => 'JPY';
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {'krwPerJpy': 8.5};
  @override
  Future<List<Map<String, dynamic>>> planItemAlternatives(
    int id,
    int itemId, {
    Map<String, String> preferences = const {},
  }) async {
    this.preferences = preferences;
    return [
      {'placeId': 'new', 'placeName': '새 관광지', 'address': '도쿄'},
    ];
  }

  @override
  Future<Map<String, dynamic>> replacePlanItem(
    int id,
    int itemId,
    String placeId, {
    Map<String, String> preferences = const {},
  }) async {
    writes++;
    final data = response();
    (data['timeline'] as List).first['placeName'] = '새 관광지';
    return {'request': request(), 'response': data};
  }
}

void main() {
  testWidgets('도시 핀 선택이 해당 일차 페이지를 연다', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          api: AdjustmentApi(),
          loadMapTiles: false,
          request: request(),
          response: response(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('city-route-pin-1')));
    await t.pumpAndSettle();
    expect(find.text('전체 도시 경로'), findsNothing);
    expect(find.text('2일차 일정'), findsOneWidget);
    expect(find.text('다음 날 관광지'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('공항 메뉴를 숨기며 대체 장소 취소는 저장하지 않고 확인만 저장한다', (t) async {
    final api = AdjustmentApi();
    await t.pumpWidget(
      MaterialApp(
        home: ItineraryResultPage(
          api: api,
          loadMapTiles: false,
          showInitialCityRoute: false,
          request: request(),
          response: response(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byTooltip('일정 메뉴'), findsOneWidget);
    Future<void> choose() async {
      await Scrollable.ensureVisible(t.element(find.byTooltip('일정 메뉴')), alignment: 1);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('일정 메뉴'));
      await t.pumpAndSettle();
      await t.tap(find.text('대체 장소 추천'));
      await t.pumpAndSettle();
      expect(find.text('테마'), findsOneWidget);
      expect(find.text('동행인'), findsOneWidget);
      await t.tap(find.text('추천 장소 찾기'));
      await t.pumpAndSettle();
      await t.tap(find.text('새 관광지'));
      await t.pumpAndSettle();
      expect(find.textContaining('남은 일정의 시간이 조정될 수 있습니다'), findsOneWidget);
    }

    await choose();
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(api.writes, 0);
    expect(find.byType(AlertDialog), findsNothing);
    await choose();
    await t.tap(find.text('재설정'));
    await t.pumpAndSettle();
    expect(api.writes, 1);
    expect(api.preferences?['companion'], '친구');
    expect(find.text('새 관광지'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
