import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/features/schedule/widgets/itinerary_route_map.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';

class CameraApi extends PlannerApi {
  @override Future<String> getHotelCurrencyPreference() async => 'JPY';
  @override Future<Map<String,dynamic>> getExchangeRate() async => {'krwPerJpy':8.5};
}
void main() {
  testWidgets('pan and zoom survive newly allocated paths and pin selection focuses instead of fitting', (t) async {
    late StateSetter rebuild;
    int? selected; int revision=0;
    await t.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(_,set){
      rebuild=set;
      return SizedBox(height:400,child:ItineraryRouteMap(
        loadTiles:false,
        stops:const [RouteMapStop(name:'도쿄',detail:'',latitude:35.68,longitude:139.76),RouteMapStop(name:'요코하마',detail:'',latitude:35.45,longitude:139.63)],
        paths:[const RouteMapPath(coordinates:[[35.68,139.76],[35.45,139.63]],source:'test')],
        selectedStopIndex:selected,selectionRevision:revision,
        onStopSelected:(i)=>set((){selected=i;revision++;}),
      ));
    }))));
    await t.pumpAndSettle();
    final controller=t.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    controller.move(const LatLng(35.72,139.81),16);
    await t.pumpAndSettle();
    rebuild((){});await t.pumpAndSettle();
    expect(controller.camera.zoom,16);
    expect(controller.camera.center.latitude,closeTo(35.72,.00001));
    // Select through the same callback used by a marker or the place list.
    t.widget<ItineraryRouteMap>(find.byType(ItineraryRouteMap)).onStopSelected!(1);
    await t.pumpAndSettle();
    expect(controller.camera.zoom,14);
    expect(controller.camera.center.latitude,closeTo(35.45,.00001));
    controller.move(const LatLng(35.48,139.66),17);
    await t.pumpAndSettle();rebuild((){});await t.pumpAndSettle();
    expect(controller.camera.zoom,17);
    expect(controller.camera.center.longitude,closeTo(139.66,.00001));
    expect(t.takeException(),isNull);
  });
  testWidgets('matching navigation bars at top and bottom move days with arrows on the outside', (t) async {
    t.view.physicalSize=const Size(393,852);t.view.devicePixelRatio=1;
    addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home:ItineraryResultPage(api:CameraApi(),showInitialCityRoute:false,loadMapTiles:false,
      request:{'title':'일차 이동 확인','tripDays':2,'cities':['도쿄']},
      response:{'planId':1,'timeline':[for(int d=1;d<=2;d++)for(int i=0;i<4;i++)
        {'day':d,'time':'${10+i}:00','placeName':'$d일차 장소 $i','category':'관광지','latitude':35.6+i*.01,'longitude':139.7}]},
    )));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-navigation-top')),findsOneWidget);
    expect(find.byKey(const ValueKey('day-navigation-bottom')),findsOneWidget);
    final bottom=find.byKey(const ValueKey('day-bottom-next'));
    await t.ensureVisible(bottom);await t.pumpAndSettle();
    final label=find.descendant(of:bottom,matching:find.text('다음 일차'));
    final arrow=find.descendant(of:bottom,matching:find.byIcon(Icons.arrow_forward));
    expect(t.getRect(arrow).left,greaterThan(t.getRect(label).right));
    expect(t.getSize(bottom).width,closeTo(t.getSize(find.byKey(const ValueKey('day-bottom-previous'))).width,.01));
    await t.tap(bottom);await t.pumpAndSettle();
    expect(find.text('2/2일차'),findsNWidgets(2));
    expect(t.widget<TextButton>(find.byKey(const ValueKey('day-bottom-next'))).onPressed,isNull);
    final previous=find.byKey(const ValueKey('day-bottom-previous'));
    await t.ensureVisible(previous);await t.pumpAndSettle();await t.tap(previous);await t.pumpAndSettle();
    expect(find.text('1/2일차'),findsNWidgets(2));
    expect(t.takeException(),isNull);
  });
}
