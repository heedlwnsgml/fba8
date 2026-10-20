import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/mypage/widgets/hotel_currency_preference_card.dart';
import 'package:ai_travel_planner/features/trip/widgets/lodging_budget_fields.dart';

class PreferenceApi extends PlannerApi {
  String preference = 'KRW';
  String? saved;
  bool failSave = false;
  @override
  Future<String> getHotelCurrencyPreference() async => preference;
  @override
  Future<void> saveHotelCurrencyPreference(String currency) async {
    if (failSave) throw const PlannerApiException('failure');
    saved = currency;
    preference = currency;
  }

  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {
    'krwPerJpy': 8.5,
    'rateDate': '2026-10-18',
  };
}

void main() {
  testWidgets('마이페이지에서 기본 통화를 저장하고 다시 열어도 표시한다', (tester) async {
    final api = PreferenceApi();
    Widget card() => MaterialApp(
      home: Scaffold(body: HotelCurrencyPreferenceCard(api: api)),
    );
    await tester.pumpWidget(card());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'KRW'},
    );
    await tester.tap(find.text('엔 (JPY)'));
    await tester.pumpAndSettle();
    expect(api.saved, 'JPY');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(card());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'JPY'},
    );
  });
  testWidgets('저장 실패 시 기존 기본 통화를 유지한다', (tester) async {
    final api = PreferenceApi()..failSave = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelCurrencyPreferenceCard(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('엔 (JPY)'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'KRW'},
    );
    expect(find.textContaining('저장하지 못했습니다'), findsOneWidget);
  });
  testWidgets('저장한 엔화 기본값을 적용하고 여행 중 직접 선택한 통화는 유지한다', (tester) async {
    final d = TripDraft.instance;
    d.defaultHotelBudgetCurrency = 'KRW';
    d.resetInputs();
    final api = PreferenceApi()..preference = 'JPY';
    Widget input() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: LodgingBudgetFields(api: api)),
      ),
    );
    await tester.pumpWidget(input());
    await tester.pumpAndSettle();
    expect(d.hotelBudgetCurrency, 'JPY');
    await tester.enterText(find.byType(TextFormField), '10000');
    await tester.pump();
    expect(d.hotelBudgetYen, 10000);
    await tester.tap(find.text('원 (KRW)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '변경'));
    await tester.pumpAndSettle();
    expect(d.hotelBudgetCurrencyChosen, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(input());
    await tester.pumpAndSettle();
    expect(d.hotelBudgetCurrency, 'KRW');
    expect(tester.takeException(), isNull);
  });
  testWidgets('기본 통화가 엔인 경우에도 고정해 둔 숙소 예산은 유지한다', (tester) async {
    final d = TripDraft.instance;
    d.defaultHotelBudgetCurrency = 'KRW';
    d.resetInputs();
    d.hotelBudgetYen = 23000;
    d.hotelBudgetInput = null;
    final api = PreferenceApi()..preference = 'JPY';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: LodgingBudgetFields(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(d.hotelBudgetCurrency, 'JPY');
    expect(d.hotelBudgetYen, 23000);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '23000',
    );
  });
}
