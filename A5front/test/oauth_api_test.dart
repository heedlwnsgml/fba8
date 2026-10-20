import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';

class OAuthAdapter implements HttpClientAdapter {
  Map<String, dynamic> poll = {
    'status': 'SUCCEEDED',
    'token': 'header.payload.signature',
  };
  RequestOptions? last;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? f,
  ) async {
    last = o;
    final data = o.path.endsWith('/begin')
        ? {
            'id': 'id',
            'secret': 'secret',
            'startUrl':
                'http://localhost:8080/api/v1/auth/oauth/start?id=id&key=browser',
          }
        : poll;
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OAuthAdapter a;
  late PlannerApi api;
  setUp(() {
    a = OAuthAdapter();
    api = PlannerApi(dio: Dio()..httpClientAdapter = a);
  });
  tearDown(() => api.dispose());
  test(
    'Social exchange posts polling secret in body and accepts a valid JWT',
    () async {
      final t = await api.beginSocialLogin('google');
      expect(a.last!.data, {'provider': 'google'});
      expect(
        await api.pollSocialLogin(t, revision: api.sessionRevision),
        isTrue,
      );
      expect(api.isLoggedIn, isTrue);
      expect(a.last!.data, {'id': 'id', 'secret': 'secret'});
      expect(a.last!.queryParameters, isEmpty);
    },
  );
  test('Cancelled or stale response cannot replace login state', () async {
    final t = await api.beginSocialLogin('google');
    await expectLater(
      api.pollSocialLogin(
        t,
        revision: api.sessionRevision,
        isActive: () => false,
      ),
      throwsA(isA<PlannerApiException>()),
    );
    expect(api.isLoggedIn, isFalse);
    final old = api.sessionRevision;
    api.logout();
    await expectLater(
      api.pollSocialLogin(t, revision: old),
      throwsA(isA<PlannerApiException>()),
    );
    expect(api.isLoggedIn, isFalse);
  });
  test('Pending, failure and invalid token do not log user in', () async {
    final t = await api.beginSocialLogin('kakao');
    a.poll = {'status': 'PENDING'};
    expect(
      await api.pollSocialLogin(t, revision: api.sessionRevision),
      isFalse,
    );
    a.poll = {'status': 'FAILED', 'message': '동의 취소'};
    await expectLater(
      api.pollSocialLogin(t, revision: api.sessionRevision),
      throwsA(isA<PlannerApiException>()),
    );
    a.poll = {'status': 'SUCCEEDED', 'token': 'invalid'};
    await expectLater(
      api.pollSocialLogin(t, revision: api.sessionRevision),
      throwsA(isA<PlannerApiException>()),
    );
    expect(api.isLoggedIn, isFalse);
  });
}
