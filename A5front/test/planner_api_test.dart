import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  String loginBody = 'header.payload.signature';
  int planStatus = 200;
  bool dropOnePoll = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path.endsWith('/login')) {
      return ResponseBody.fromString(
        loginBody,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      );
    }
    if (options.path.startsWith('/api/v1/plans/generation-jobs')) {
      if (dropOnePoll && options.method == 'GET') {
        dropOnePoll = false;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return ResponseBody.fromString(
        jsonEncode({
          'jobId': options.method == 'POST'
              ? options.data['clientRequestId']
              : options.path.split('/').last,
          'status': options.method == 'POST' ? 'RUNNING' : 'SUCCEEDED',
          'response': options.method == 'GET'
              ? {
                  'planId': 8,
                  'timeline': [
                    {'day': 1, 'placeName': '완료 장소'},
                  ],
                }
              : null,
        }),
        planStatus,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/signup')) {
      return ResponseBody.fromString('회원가입 완료!', 200);
    }
    if (options.method == 'GET' && options.path == '/api/v1/plans') {
      return ResponseBody.fromString(
        jsonEncode([
          {'id': 2, 'title': '두 번째 여행'},
          {'id': 1, 'title': '첫 번째 여행'},
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.method == 'GET' && options.path == '/api/v1/plans/2') {
      return ResponseBody.fromString(
        jsonEncode({
          'request': {
            'cities': ['도쿄'],
          },
          'response': {'planId': 2, 'timeline': []},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'isWarning': false, 'timeline': []}),
      planStatus,
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
  late _Adapter adapter;
  late PlannerApi api;
  final plan = <String, dynamic>{
    'startDate': '2026-10-04',
    'endDate': '2026-10-06',
    'cities': ['도쿄', '요코하마'],
    'inCity': '도쿄',
    'outCity': '도쿄',
    'themes': ['맛집'],
    'fixedSchedules': [],
    'accommodations': [],
  };

  setUp(() {
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080'));
    dio.httpClientAdapter = adapter;
    api = PlannerApi(dio: dio, generationPollInterval: Duration.zero);
  });

  test('여러 일정 목록과 상세 요청에 현재 로그인 인증을 전달한다', () async {
    await api.login('test@example.com', 'TestPassword123!');
    final plans = await api.listPlans();
    expect(plans.map((e) => e['id']).toList(), [2, 1]);
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer header.payload.signature',
    );
    final detail = await api.getPlan(2);
    expect((detail['response'] as Map)['planId'], 2);
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer header.payload.signature',
    );
  });

  test('로그인하지 않은 계정의 일정 조회를 차단한다', () async {
    await expectLater(api.listPlans(), throwsA(isA<PlannerApiException>()));
    expect(adapter.requests, isEmpty);
  });

  test('회원가입 필드가 백엔드 DTO와 일치한다', () async {
    await api.signup(
      email: ' test@example.com ',
      password: 'TestPassword123!',
      gender: '남성',
      ageGroup: '20대',
    );
    expect(adapter.requests.single.data, {
      'email': 'test@example.com',
      'password': 'TestPassword123!',
      'gender': '남성',
      'ageGroup': '20대',
    });
  });

  test('문자열 JWT 응답을 처리하고 일정 요청에 인증 헤더를 붙인다', () async {
    await api.login('test@example.com', 'TestPassword123!');
    expect(api.isLoggedIn, isTrue);
    await api.createPlan(plan);
    final submission = adapter.requests.firstWhere(
      (r) => r.path == '/api/v1/plans/generation-jobs',
    );
    expect(submission.data, containsPair('cities', plan['cities']));
    expect(submission.data['clientRequestId'], isNotEmpty);
    expect(
      adapter.requests.last.path,
      startsWith('/api/v1/plans/generation-jobs/'),
    );
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer header.payload.signature',
    );
  });

  test('끊긴 생성 상태 조회를 재시도해 저장된 결과를 받으며 생성은 한 번만 요청한다', () async {
    await api.login('test@example.com', 'password');
    adapter.dropOnePoll = true;
    final progress = <String>[];
    final result = await api.createPlan(plan, onProgress: progress.add);
    expect(result['planId'], 8);
    expect(
      adapter.requests
          .where(
            (r) =>
                r.path == '/api/v1/plans/generation-jobs' && r.method == 'POST',
          )
          .length,
      1,
    );
    expect(adapter.requests.where((r) => r.path.contains('/generation-jobs/') && r.method == 'GET').length, greaterThanOrEqualTo(2));
    expect(progress.any((message) => message.contains('연결하지 못')), isFalse);
  });

  test('HTTP 200 로그인 실패 문구를 토큰으로 취급하지 않는다', () async {
    await api.login('test@example.com', 'correct-password');
    adapter.loginBody = '비밀번호가 일치하지 않습니다.';
    await expectLater(
      api.login('test@example.com', 'wrong-password'),
      throwsA(isA<PlannerApiException>()),
    );
    expect(api.isLoggedIn, isFalse);
  });

  test('일정 검증에 도시 목록과 숙박 일수를 보낸다', () async {
    await api.login('test@example.com', 'password');
    await api.validatePlan(plan);
    expect(adapter.requests.last.queryParameters, {
      'selectedCities': '도쿄,요코하마',
      'inCity': '도쿄',
      'outCity': '도쿄',
      'nights': 2,
    });
  });

  test('미인증 요청은 백엔드로 보내지 않는다', () async {
    await expectLater(
      api.createPlan(plan),
      throwsA(isA<PlannerApiException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('서버 주소가 바뀌면 이전 토큰을 제거한다', () async {
    await api.login('test@example.com', 'password');
    api.setBaseUrl('http://localhost:8080/');
    expect(api.isLoggedIn, isFalse);
    expect(api.baseUrl, 'http://localhost:8080');
    expect(
      () => api.setBaseUrl('http://user:password@localhost:8080'),
      throwsA(isA<PlannerApiException>()),
    );
  });

  test('401 응답을 받으면 인증 세션을 제거한다', () async {
    await api.login('test@example.com', 'password');
    adapter.planStatus = 401;
    await expectLater(
      api.createPlan(plan),
      throwsA(isA<PlannerApiException>()),
    );
    expect(api.isLoggedIn, isFalse);
  });
}
