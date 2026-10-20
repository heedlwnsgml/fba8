import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/widgets/generation_notifications.dart';

class JobsAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final statuses = <String, String>{};
  bool finish = false;
  bool pendingCancel = false;
  final pending = <String, int>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(r);
    if (r.path.endsWith('/login'))
      return ResponseBody.fromString(
        'header.payload.signature',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    final id = r.method == 'POST'
        ? r.data['clientRequestId'] as String
        : r.path.split('/').last;
    if (r.method == 'POST') statuses[id] = 'RUNNING';
    if (r.method == 'DELETE') {
      statuses[id] = 'CANCELLED';
      if (pendingCancel) pending[id] = 5;
    }
    if (r.method == 'GET' && (pending[id] ?? 0) > 0)
      pending[id] = pending[id]! - 1;
    if (r.method == 'GET' && finish && statuses[id] == 'RUNNING')
      statuses[id] = 'SUCCEEDED';
    return ResponseBody.fromString(
      jsonEncode({
        'jobId': id,
        'status': statuses[id],
        'cancellationPending': (pending[id] ?? 0) > 0,
        if (statuses[id] == 'SUCCEEDED')
          'response': {
            'planId': 8,
            'timeline': [
              {'day': 1, 'placeName': '완료 장소'},
            ],
          },
      }),
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
  late PlannerApi api;
  late JobsAdapter adapter;
  const request = {
    'title': '도쿄 여행',
    'cities': ['도쿄'],
    'startDate': '2026-10-14',
    'endDate': '2026-10-15',
  };
  setUp(() async {
    adapter = JobsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = adapter;
    api = PlannerApi(
      dio: dio,
      generationPollInterval: const Duration(milliseconds: 10),
    );
    await api.login('test@example.com', 'test');
  });
  tearDown(() {
    api.logout();
  });
  test(
    'Two independent tasks freeze their own inputs; a third is blocked',
    () async {
      final mutable = Map<String, dynamic>.from(request);
      final first = api.startGeneration(mutable);
      mutable['title'] = '요코하마 여행';
      final second = api.startGeneration(mutable);
      expect(first.id, isNot(second.id));
      expect(first.title, '도쿄 여행');
      expect(second.title, '요코하마 여행');
      expect(
        () => api.startGeneration(request),
        throwsA(isA<PlannerApiException>()),
      );
      await Future.wait([first.submitted.future, second.submitted.future]);
      expect(adapter.statuses.length, 2);
      await api.cancelGeneration(first.id);
      await api.cancelGeneration(second.id);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(first.status, 'CANCELLED');
      expect(second.status, 'CANCELLED');
      expect(first.result, isNull);
    },
  );
  test(
    'Completion remains available after leaving the generation screen',
    () async {
      final task = api.startGeneration(request);
      await task.submitted.future;
      adapter.finish = true;
      for (var i = 0; i < 100 && task.active; i++)
        await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(task.status, 'SUCCEEDED');
      expect(task.result!['request']['title'], '도쿄 여행');
      expect(task.result!['response']['planId'], 8);
    },
  );
  test(
    'Cancel is sent once to the authenticated job endpoint and stops polling',
    () async {
      final task = api.startGeneration(request);
      await api.cancelGeneration(task.id);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final deletes = adapter.requests
          .where((r) => r.method == 'DELETE')
          .toList();
      expect(deletes.length, 1);
      expect(deletes.single.path, endsWith(task.id));
      expect(
        deletes.single.headers['Authorization'],
        'Bearer header.payload.signature',
      );
      expect(task.status, 'CANCELLED');
      expect(task.result, isNull);
    },
  );
  test(
    'Cancellation keeps its slot until the server acknowledges completion',
    () async {
      adapter.pendingCancel = true;
      final first = api.startGeneration(request);
      final second = api.startGeneration(request);
      await api.cancelGeneration(first.id);
      expect(first.status, 'CANCELLING');
      expect(first.active, isTrue);
      expect(
        () => api.startGeneration(request),
        throwsA(isA<PlannerApiException>()),
      );
      await api.cancelGeneration(second.id);
      for (var i = 0; i < 50 && (first.active || second.active); i++)
        await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(first.status, 'CANCELLED');
      expect(second.status, 'CANCELLED');
      expect(first.result, isNull);
    },
  );
  testWidgets(
    'Generation badge respects full-width app button theme and leaves body interactive',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: generationNavigatorKey,
          theme: ThemeData(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ),
          builder: (c, w) => GenerationNotifications(api: api, child: w!),
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('홈으로 이동'),
              ),
            ),
          ),
        ),
      );
      final task = api.startGeneration(request);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('홈으로 이동'));
      await tester.pump();
      expect(taps, 1);
      await tester.tap(find.text('생성 중 1/2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('일정 생성 작업'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('생성 취소'));
      await tester.ensureVisible(find.text('생성 취소'));
      await tester.tap(find.text('생성 취소'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(task.status, 'CANCELLED');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('일정 생성 작업'), findsNothing);
      await tester.tap(find.text('홈으로 이동'));
      await tester.pump();
      expect(taps, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Completion popup appears while another page is open and does not repeat',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: generationNavigatorKey,
          theme: ThemeData(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ),
          builder: (c, w) => GenerationNotifications(api: api, child: w!),
          home: const Scaffold(body: Text('다른 화면')),
        ),
      );
      final task = api.startGeneration(request);
      await tester.pump();
      adapter.finish = true;
      for (var i = 0; i < 20; i++)
        await tester.pump(const Duration(milliseconds: 30));
      expect(task.status, 'SUCCEEDED');
      expect(find.text('일정 생성 완료'), findsOneWidget);
      expect(find.text('다른 화면'), findsOneWidget);
      final closeRect = tester.getRect(find.widgetWithText(TextButton, '닫기'));
      final viewRect = tester.getRect(
        find.widgetWithText(FilledButton, '일정 보기'),
      );
      expect(closeRect.width, closeTo(viewRect.width, 0.1));
      expect(closeRect.height, closeTo(viewRect.height, 0.1));
      expect(closeRect.left, lessThan(viewRect.left));
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('생성 결과'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('생성 결과'), findsNothing);
      expect(find.text('일정 생성 완료'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
