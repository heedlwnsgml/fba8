import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/schedule/pages/itinerary_result_page.dart';
import 'package:ai_travel_planner/features/schedule/widgets/directions_preview.dart';
import 'package:ai_travel_planner/features/schedule/widgets/directions_surface_native.dart'
    as native;

class ListMapApi extends PlannerApi {
  @override
  Future<String> getHotelCurrencyPreference() async => 'JPY';
  @override
  Future<Map<String, dynamic>> getExchangeRate() async => {'krwPerJpy': 8.5};
}

class RecordingPlatform extends WebViewPlatform {
  RecordingController? controller;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = RecordingController(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => RecordingDelegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => RecordingWidget(params);
}

class RecordingController extends PlatformWebViewController {
  RecordingController(super.params) : super.implementation();
  Uri? loaded;
  String? html;
  String? agent;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setUserAgent(String? value) async {
    agent = value;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadHtmlString(String value, {String? baseUrl}) async {
    html = value;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loaded = params.uri;
  }
}

class RecordingDelegate extends PlatformNavigationDelegate {
  RecordingDelegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class RecordingWidget extends PlatformWebViewWidget {
  RecordingWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.blue);
}

void main() {
  testWidgets(
    'unlocking keeps the map visible, scrolls it with the list and preserves its camera',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: ItineraryResultPage(
            api: ListMapApi(),
            loadMapTiles: false,
            showInitialCityRoute: false,
            request: {
              'title': '지도 모드',
              'tripDays': 1,
              'cities': ['도쿄'],
            },
            response: {
              'planId': 1,
              'timeline': [
                for (var i = 0; i < 10; i++)
                  {
                    'day': 1,
                    'time': '09:00',
                    'placeName': '방문 장소 $i',
                    'category': '관광지',
                    'latitude': 35.68,
                    'longitude': 139.76,
                  },
              ],
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('지도 고정'), findsOneWidget);
      expect(find.byKey(const ValueKey('itinerary-title-toolbar')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('toggle-fixed-map')));
      await t.pumpAndSettle();
      final controller = t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(35.7, 139.8), 16);
      await t.pumpAndSettle();
      final mapTop = t.getTopLeft(find.byType(FlutterMap)).dy;
      final button = find.byKey(const ValueKey('toggle-fixed-map'));
      final mapRect = t.getRect(find.byType(FlutterMap));
      expect(mapRect.height, closeTo((852 * .42) * .75 - 2, .1));
      expect(t.getBottomLeft(button).dy, lessThanOrEqualTo(mapRect.top));
      expect(t.getCenter(button).dx, greaterThan(mapRect.center.dx));
      expect(
        find.byKey(const ValueKey('itinerary-title-toolbar')),
        findsNothing,
      );
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('지도 고정'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('itinerary-title-toolbar')),
        findsOneWidget,
      );
      expect(t.getTopLeft(find.byType(FlutterMap)).dy, greaterThan(mapTop));
      final scroll = find.byKey(const ValueKey('itinerary-day-scroll'));
      await t.dragFrom(
        t.getBottomLeft(scroll) + const Offset(180, -30),
        const Offset(0, -650),
      );
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.byType(FlutterMap, skipOffstage: false)).dy,
        lessThan(mapTop - 250),
      );
      final scrollable = t.state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
      );
      scrollable.position.jumpTo(0);
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.text('지도 고정 해제'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('itinerary-title-toolbar')),
        findsNothing,
      );
      expect(t.getTopLeft(find.byType(FlutterMap)).dy, closeTo(mapTop, .1));
      expect(
        t.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
        same(controller),
      );
      expect(controller.camera.zoom, 16);
      expect(controller.camera.center.latitude, closeTo(35.7, .001));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Android preview loads the embedded route map with desktop map rendering',
    (t) async {
      final platform = RecordingPlatform();
      WebViewPlatform.instance = platform;
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      final route = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=35.68,139.76&destination=35.45,139.63&travelmode=transit',
      );
      final embedded = itineraryEmbeddedDirections(route);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: native.directionsSurface(route, embedded)),
        ),
      );
      await t.pump();
      // A native WebView is not itself an iframe. Never navigate directly
      // to Google's embed endpoint: it returns the iframe-only error page.
      expect(platform.controller!.loaded, isNull);
      final html = platform.controller!.html!;
      expect(html, contains('<iframe'));
      final source = RegExp(
        r'src="([^"]+)"',
      ).firstMatch(html)!.group(1)!.replaceAll('&amp;', '&');
      final iframe = Uri.parse(source);
      expect(iframe.queryParameters['output'], 'embed');
      expect(iframe.queryParameters['dirflg'], 'r');
      expect(iframe.queryParameters['saddr'], '35.68,139.76');
      expect(iframe.queryParameters['daddr'], '35.45,139.63');
      expect(html, contains('height:100%'));
      expect(platform.controller!.agent, contains('X11'));
      expect(platform.controller!.agent, isNot(contains('Mobile')));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = previousPlatform;
    },
  );
}
