import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/money_display.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/mypage/widgets/hotel_currency_preference_card.dart';

class YenPreferenceApi extends PlannerApi {
  String? saved;
  @override
  Future<String> getHotelCurrencyPreference() async => 'JPY';
  @override
  Future<void> saveHotelCurrencyPreference(String value) async {
    saved = value;
  }
}

void main() {
  test('원화 기본값, 100원 단위 올림과 엔화 선택은 원본 금액을 유지한다', () {
    final money = MoneyDisplay()..configure(rate: 8.5);
    expect(money.currency, 'KRW');
    expect(MoneyDisplay.roundWon(12341), 12400);
    expect(MoneyDisplay.roundWon(12400), 12400);
    expect(MoneyDisplay.roundWon(0), 0);
    expect(MoneyDisplay.roundWon(1), 100);
    expect(money.yen(24300), '206,600원');
    expect(
      money.text('숙박 ¥10,000 · 승차권 3000엔 · 패스 ￥1,500'),
      '숙박 85,000원 · 승차권 25,500원 · 패스 12,800원',
    );
    expect(
      money.text('체류시간: 90분 · 1박 · 2026.10.18'),
      '체류시간: 90분 · 1박 · 2026.10.18',
    );
    money.configure(currency: 'JPY');
    expect(money.yen(24300), '24,300엔');
    expect(money.text('패스 ¥1,500'), '패스 1,500엔');
  });
  test('환율이 없거나 잘못되면 임의 환율과 엔화 금액을 원화로 오인시키지 않는다', () {
    final money = MoneyDisplay();
    expect(money.yen(1000), '환율 확인 필요');
    money.configure(rate: -1);
    expect(money.krwPerJpy, isNull);
    money.configure(rate: 8.5);
    money.reset();
    expect(money.currency, 'KRW');
    expect(money.krwPerJpy, isNull);
  });
  testWidgets('원화 변경 전 올림 안내를 확인하고 취소하면 엔화를 유지한다', (tester) async {
    final api = YenPreferenceApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HotelCurrencyPreferenceCard(api: api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('원 (KRW)'));
    await tester.pumpAndSettle();
    expect(find.text('원화로 표시할까요?'), findsOneWidget);
    expect(api.saved, isNull);
    await tester.tap(find.widgetWithText(OutlinedButton, '취소'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'JPY'},
    );
    expect(api.saved, isNull);
    await tester.tap(find.text('원 (KRW)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '원화로 변경'));
    await tester.pumpAndSettle();
    expect(api.saved, 'KRW');
    expect(api.money.currency, 'KRW');
  });
}
