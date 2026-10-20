import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ai_travel_planner/features/schedule/widgets/city_route_overview.dart';
import 'package:ai_travel_planner/features/schedule/widgets/replacement_preferences_dialog.dart';

void main() {
  const stops = [
    CityRouteStop('도쿄', 1, LatLng(35.68, 139.76)),
    CityRouteStop('요코하마', 2, LatLng(35.45, 139.63)),
  ];
  testWidgets('city map zooms once after opening and restores its framing', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CityRouteOverview(stops: stops, loadTiles: false)),
      ),
    );
    final controller = t
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final initial = controller.camera.zoom;
    final center = controller.camera.center;
    await t.pump(const Duration(milliseconds: 350));
    expect(controller.camera.zoom, closeTo(initial + 1, .001));
    await t.pump(const Duration(milliseconds: 80));
    expect(controller.camera.zoom, closeTo(initial, .001));
    expect(controller.camera.center, center);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'opening refresh does not override a user who has already moved the map',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CityRouteOverview(stops: stops, loadTiles: false),
          ),
        ),
      );
      final map = t.widget<FlutterMap>(find.byType(FlutterMap));
      map.options.onPositionChanged!(map.mapController!.camera, true);
      map.mapController!.move(const LatLng(35.7, 139.8), 12);
      await t.pump(const Duration(seconds: 1));
      expect(map.mapController!.camera.zoom, 12);
      expect(map.mapController!.camera.center.latitude, closeTo(35.7, .001));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'recommend button stays on one line at phone width with enlarged text',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(393, 852),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const Scaffold(body: ReplacementPreferencesDialog()),
          ),
        ),
      );
      final label = find.text('추천 장소 찾기');
      expect(t.widget<Text>(label).maxLines, 1);
      final button = find.ancestor(
        of: label,
        matching: find.byType(FilledButton),
      );
      final fitted = find.ancestor(of: label, matching: find.byType(FittedBox));
      expect(t.getRect(button).contains(t.getCenter(fitted)), true);
      expect(t.getSize(button).height, greaterThanOrEqualTo(52));
      expect(t.takeException(), isNull);
    },
  );
}
