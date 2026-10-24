import 'package:ai_travel_planner/core/network/planner_base_url.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('web login stays on current origin instead of host api', () {
    final base = resolvePlannerBaseUrl('/', isWeb: true,
        pageUri: Uri.parse('http://127.0.0.1:5173/#/login'));
    final uri = RequestOptions(baseUrl: base, path: '/api/v1/auth/login').uri;
    expect(uri.host, '127.0.0.1');
    expect(uri.port, 5173);
    expect(uri.path, '/api/v1/auth/login');
  });
  test('native relative config resolves to USB backend', () {
    final base = resolvePlannerBaseUrl('/', isWeb: false);
    final uri = RequestOptions(baseUrl: base, path: '/api/v1/auth/login').uri;
    expect(uri.toString(), 'http://127.0.0.1:8080/api/v1/auth/login');
  });
  test('explicit HTTP server works on either client', () {
    for (final web in [true, false]) {
      expect(resolvePlannerBaseUrl('https://planner.example/', isWeb: web),
          'https://planner.example');
    }
  });
}
