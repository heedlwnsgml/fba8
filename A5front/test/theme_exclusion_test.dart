import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_preferences_page.dart';

void main() {
  testWidgets('preferred and forbidden themes cannot replace one another; forbidden choices are red', (t) async {
    SharedPreferences.setMockInitialValues({});
    final draft = TripDraft.instance;
    await draft.loadDefaults();
    draft.resetInputs();
    draft.themes = ['관광'];
    draft.excludedThemes = ['사진'];
    await t.pumpWidget(const MaterialApp(home: TripPreferencesPage()));
    await t.pumpAndSettle();
    Future<void> show(String text) async {
      await Scrollable.ensureVisible(t.element(find.text(text).first), alignment: .4);
      await t.pumpAndSettle();
    }
    InkWell tile(String text) => t.widget<InkWell>(find.ancestor(of: find.text(text).first, matching: find.byType(InkWell)).first);
    await show('사진');
    expect(tile('사진').onTap, isNull);
    expect(draft.excludedThemes, ['사진']);
    await show('금지 테마');
    await t.tap(find.text('금지 테마'));
    await t.pumpAndSettle();
    await show('관광');
    expect(tile('관광').onTap, isNull);
    expect(draft.themes, ['관광']);
    await show('자연');
    await t.tap(find.text('자연').first);
    await t.pumpAndSettle();
    expect(draft.excludedThemes, ['사진', '자연']);
    final material = t.widget<Material>(find.ancestor(of: find.text('자연').first, matching: find.byType(Material)).first);
    expect(material.color, const Color(0xFFFFEBEE));
    await show('선호 테마');
    await t.tap(find.text('선호 테마'));
    await t.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(t.getTopLeft(find.text('필수')).dx, t.getTopLeft(find.text('제외')).dx);
    expect(tile('자연').onTap, isNull);
    await t.pumpWidget(const SizedBox());
  });
}
