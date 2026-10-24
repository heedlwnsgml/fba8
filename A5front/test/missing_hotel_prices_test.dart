import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/mypage/widgets/missing_hotel_prices_card.dart';

class HotelApi extends PlannerApi {
  List<String> names = ['호텔 A', '호텔 B'];
  @override
  Future<List<String>> getHotelPriceFailures() async => names;
}

void main() {
  testWidgets('관리자 적재 목록에는 호텔명만 보이고 새로고침하면 해결된 숙소가 빠진다', (t) async {
    final api = HotelApi();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MissingHotelPricesCard(api: api)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('호텔 A'), findsOneWidget);
    expect(find.text('호텔 B'), findsOneWidget);
    expect(find.textContaining('5회'), findsNothing);
    api.names = ['호텔 B'];
    await t.tap(find.byTooltip('목록 새로고침'));
    await t.pumpAndSettle();
    expect(find.text('호텔 A'), findsNothing);
    expect(find.text('호텔 B'), findsOneWidget);
  });
}
