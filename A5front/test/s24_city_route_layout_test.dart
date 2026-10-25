import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_travel_planner/core/state/trip_draft.dart';
import 'package:ai_travel_planner/features/trip/pages/trip_region_page.dart';
import 'package:ai_travel_planner/features/trip/widgets/city_selection_map.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_route_map.dart';

void main() {
  testWidgets('S24 untitled city selection keeps heading, map and selected list visible', (t) async {
    SharedPreferences.setMockInitialValues({});
    TripDraft.instance.resetInputs();
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: TripRegionPage()));
    await t.pumpAndSettle();
    final map = find.byType(CitySelectionMap);
    final title = find.text('어느 도시로 떠나시나요?');
    final mapRect = t.getRect(map);
    expect(t.getRect(title).bottom, lessThan(mapRect.top));
    expect(mapRect.height, inInclusiveRange(140, 250));
    final tile = find.byType(ExpansionTile).first;
    expect(t.getRect(tile).top, greaterThan(mapRect.bottom));
    expect(t.getRect(tile).bottom, lessThan(t.getRect(find.text('도시 고정')).top));
    await t.tap(find.descendant(of: tile, matching: find.text('홋카이도')));
    await t.pumpAndSettle();
    final city = find.byWidgetPredicate((w) => w is CheckboxListTile && (w.title as Text).data == '삿포로');
    await t.ensureVisible(city);
    await t.tap(city);
    await t.pumpAndSettle();
    expect(TripDraft.instance.title, isEmpty);
    expect(TripDraft.instance.cities, contains('삿포로'));
    expect(t.getRect(map), mapRect);
    expect(t.getRect(city).top, greaterThan(mapRect.bottom));
    expect(t.getRect(city).bottom, lessThan(t.getRect(find.text('도시 고정')).top));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('detail map frames the full route on opening', (t) async {
    const stops = [
      RouteMapStop(name:'삿포로',detail:'',latitude:43.06,longitude:141.35),
      RouteMapStop(name:'도쿄',detail:'',latitude:35.68,longitude:139.76),
      RouteMapStop(name:'요코하마',detail:'',latitude:35.45,longitude:139.63),
    ];
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(
      width:393,height:260,child:ItineraryRouteMap(stops:stops,loadTiles:false)))));
    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCameraFit, isNotNull);
    await t.pumpAndSettle();
    for (final stop in stops) {
      expect(map.mapController!.camera.visibleBounds.contains(stop.position), isTrue);
    }
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
