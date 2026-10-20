import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/widgets/weather_notifications.dart';

class WeatherAdapter implements HttpClientAdapter {
  final settings = <String, dynamic>{
    'enabled': true,
    'frequency': 'morning',
    'morningTime': '07:30',
    'afternoonTime': '18:00',
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (r.path.endsWith('/login'))
      return ResponseBody.fromString('test.weather.token', 200);
    if (r.method == 'PUT')
      settings.addAll(Map<String, dynamic>.from(r.data as Map));
    return ResponseBody.fromString(
      jsonEncode(
        r.path.endsWith('/alerts')
            ? [
                {'planId': 7, 'precipitationProbability': 80},
              ]
            : settings,
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_travel_planner/weather');
  testWidgets(
    'Settings and rain forecasts reach native alarms; changing settings reschedules and logout clears',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = WeatherAdapter();
      final api = PlannerApi(dio: dio);
      await tester.runAsync(() => api.login('weather@example.com', 'password'));
      await tester.pumpWidget(
        MaterialApp(
          home: WeatherNotifications(api: api, child: const Text('home')),
        ),
      );
      await tester.pumpAndSettle();
      final initial =
          calls.lastWhere((c) => c.method == 'configure').arguments as Map;
      expect(initial['morningTime'], '07:30');
      expect(initial['frequency'], 'morning');
      expect((initial['alerts'] as List).first['precipitationProbability'], 80);
      expect(initial['token'], 'test.weather.token');
      await tester.runAsync(
        () => api.updateWeatherSettings({
          'enabled': true,
          'frequency': 'afternoon',
          'morningTime': '07:30',
          'afternoonTime': '19:15',
        }),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        (calls.lastWhere((c) => c.method == 'configure').arguments
            as Map)['afternoonTime'],
        '19:15',
      );
      api.logout();
      await tester.pumpAndSettle();
      expect(calls.last.method, 'clear');
      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
