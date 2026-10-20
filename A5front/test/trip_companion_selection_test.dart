import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_companion_page.dart';

void main() {
  setUp(() => TripDraft.instance.resetInputs());
  tearDown(() => TripDraft.instance.resetInputs());
  testWidgets('혼자 선택 상태에서 다른 연령대를 선택하면 기존 연령대를 교체한다', (tester) async {
    TripDraft.instance.companions = ['혼자'];
    TripDraft.instance.ageGroups = ['성인'];
    await tester.pumpWidget(const MaterialApp(home: TripCompanionPage()));
    await tester.ensureVisible(find.text('학생'));
    await tester.tap(find.text('학생'));
    await tester.pump();
    expect(TripDraft.instance.ageGroups, ['학생']);
  });
  testWidgets('복원된 혼자 여행에 연령대가 여러 개면 하나로 정리한다', (tester) async {
    TripDraft.instance.companions = ['혼자'];
    TripDraft.instance.ageGroups = ['성인', '학생'];
    await tester.pumpWidget(const MaterialApp(home: TripCompanionPage()));
    expect(TripDraft.instance.ageGroups.length, 1);
  });
  testWidgets('동행자가 있으면 여러 연령대 선택을 유지한다', (tester) async {
    TripDraft.instance.companions = ['친구'];
    TripDraft.instance.ageGroups = ['성인'];
    await tester.pumpWidget(const MaterialApp(home: TripCompanionPage()));
    await tester.ensureVisible(find.text('학생'));
    await tester.tap(find.text('학생'));
    await tester.pump();
    expect(TripDraft.instance.ageGroups, containsAll(['성인', '학생']));
  });
}
