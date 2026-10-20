import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/mypage/widgets/long_trip_settings_card.dart';

class RestApi extends PlannerApi {
  Map<String, dynamic> settings = {
    'restDaysEnabled': false,
    'liveRestEveryDays': 5,
    'liveRestSightHours': 0.0,
    'tourLightEveryDays': 7,
    'tourLightSightHours': 3.0,
  };
  int saves = 0;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> getLongTripSettings() async => Map.of(settings);
  @override
  Future<Map<String, dynamic>> updateLongTripSettings(
    Map<String, dynamic> value,
  ) async {
    if (fail) throw Exception('save failed');
    saves++;
    settings = Map.of(value);
    return Map.of(settings);
  }
}

void main() {
  setUp(() => TripDraft.instance.restDaysEnabled = null);
  testWidgets('기본 끄기와 간격을 함께 저장하고 다시 열면 유지한다', (t) async {
    final api = RestApi();
    Widget card() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: LongTripSettingsCard(api: api)),
      ),
    );
    await t.pumpWidget(card());
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, false);
    expect(find.text('여유일 설정'), findsNothing);
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(find.text('여유일 설정'), findsOneWidget);
    await t.ensureVisible(find.text('기본 설정 저장'));
    await t.tap(find.text('기본 설정 저장'));
    await t.pumpAndSettle();
    expect(api.settings['restDaysEnabled'], true);
    expect(api.settings['liveRestEveryDays'], 7);
    expect(
      api.settings['liveRestSightHours'],
      api.settings['tourLightSightHours'],
    );
    expect(api.settings['tourLightSightHours'], 3.0);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(card());
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, true);
    expect(t.takeException(), isNull);
  });
  testWidgets('이번 일정에서만 켜도 마이페이지 기본 끄기는 유지한다', (t) async {
    final api = RestApi();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TripRestDaysToggle(api: api)),
      ),
    );
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, false);
    expect(TripDraft.instance.restDaysEnabled, isNull);
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(TripDraft.instance.restDaysEnabled, true);
    expect(api.settings['restDaysEnabled'], false);
    expect(api.saves, 0);
  });
  testWidgets('저장 실패를 표시하고 기존 서버 기본값은 유지한다', (t) async {
    final api = RestApi()..fail = true;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: LongTripSettingsCard(api: api)),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('기본 설정 저장'));
    await t.tap(find.text('기본 설정 저장'));
    await t.pumpAndSettle();
    expect(find.text('저장하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(api.settings['restDaysEnabled'], false);
  });
}
