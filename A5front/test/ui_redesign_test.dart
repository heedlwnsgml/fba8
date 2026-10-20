import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/features/trip/widgets/city_selection_map.dart';
import 'package:ai_travel_planner/features/trip/widgets/lodging_budget_fields.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_preferences_page.dart';
import 'package:ai_travel_planner/features/auth/pages/email_login_page.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/core/state/city_coordinates.dart';

void main() {
  setUp(() => TripDraft.instance.resetInputs());
  testWidgets('로그인에 연결 테스트 버튼이나 예제 계정이 없다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EmailLoginPage()));
    expect(find.text('서비스 연결 확인'), findsNothing);
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    ))
      expect(field.controller!.text, isEmpty);
  });
  testWidgets('지도와 목록 선택이 양방향으로 파란 핀과 빨간 핀에 반영된다', (tester) async {
    final selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                CitySelectionMap(
                  cities: const ['도쿄', '삿포로'],
                  selected: selected,
                  anchorCity: '도쿄',
                  loadTiles: false,
                  onToggle: (s) => setState(
                    () => selected.contains(s)
                        ? selected.remove(s)
                        : selected.add(s),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => selected.contains('도쿄')
                        ? selected.remove('도쿄')
                        : selected.add('도쿄'),
                  ),
                  child: const Text('목록에서 도쿄 선택'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Color? pinColor() => tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('city-pin-도쿄')),
            matching: find.byType(Icon),
          ),
        )
        .color;
    expect(pinColor(), const Color(0xFF2563EB));
    await tester.tap(find.byKey(const ValueKey('city-pin-도쿄')));
    await tester.pumpAndSettle();
    expect(selected, contains('도쿄'));
    expect(pinColor(), const Color(0xFFEF4444));
    await tester.tap(find.text('목록에서 도쿄 선택'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(pinColor(), const Color(0xFF2563EB));
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      2,
    );
    expect(tester.takeException(), isNull);
  });
  test('모든 목록 선택 도시에 좌표가 있다', () {
    for (final city in ['도쿄', '지바', '니가타', '가고시마', '나고', '아사히카와', '가마쿠라'])
      expect(cityCoordinates[city], isNotNull, reason: city);
  });
  testWidgets('숙소 예산 표현과 미기입 안내가 항상 보인다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LodgingBudgetFields())),
    );
    expect(find.text('하루 숙박비'), findsOneWidget);
    expect(find.text('1박 숙소 요금'), findsOneWidget);
    expect(find.text('미기입 시 숙소 요금 제한 없이 일정을 생성합니다.'), findsOneWidget);
    expect(find.textContaining('식비·교통비·관광 비용은 포함하지 않습니다'), findsOneWidget);
  });
  testWidgets('취향 카드의 설명과 두 열 크기가 유지되고 탭을 바꿔도 선택이 남는다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TripPreferencesPage()));
    expect(find.text('현지 음식과 인기 식당 탐방'), findsOneWidget);
    final first = tester.getSize(
      find.ancestor(of: find.text('맛집'), matching: find.byType(Material)).first,
    );
    final second = tester.getSize(
      find.ancestor(of: find.text('쇼핑'), matching: find.byType(Material)).first,
    );
    expect(first, second);
    await tester.tap(find.text('맛집'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이동'));
    await tester.pumpAndSettle();
    expect(find.text('전철·버스와 도보를 이용해 이동합니다.'), findsOneWidget);
    await tester.tap(find.text('도보·대중교통'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('하루 일정'));
    await tester.pumpAndSettle();
    expect(find.textContaining('시작은 숙소를 나오는 시간'), findsOneWidget);
    expect(TripDraft.instance.themes, ['맛집']);
    expect(TripDraft.instance.transport, '도보 및 대중교통');
    expect(tester.takeException(), isNull);
  });
}
