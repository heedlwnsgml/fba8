import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/router/app_router.dart';
import 'package:ai_travel_planner/core/widgets/generation_notifications.dart';

class ApprovalAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String status = 'WAITING_APPROVAL';
  bool alternativeFails = false, failDecisionOnce = false;
  @override
  Future<ResponseBody> fetch(RequestOptions r, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(r);
    if (r.path.endsWith('/login')) return ResponseBody.fromString('header.payload.signature', 200, headers: {Headers.contentTypeHeader: ['text/plain']});
    if (r.path.endsWith('/end-time-decision')) {
      if (failDecisionOnce) { failDecisionOnce = false; return ResponseBody.fromString('temporary error', 503); }
      status = r.data['allow'] == true || !alternativeFails ? 'SUCCEEDED' : 'FAILED';
    }
    return ResponseBody.fromString(jsonEncode({
      'jobId': 'job', 'status': status,
      if (status == 'WAITING_APPROVAL') 'approval': {'decisionId': 'decision-3', 'day': 3, 'date': '2026-10-23', 'plannedEndTime': '22:00', 'expectedEndTime': '23:20', 'overtimeMinutes': 80, 'from': '출발 숙소', 'to': '도착 숙소'},
      if (status == 'FAILED') 'error': '종료 시각 안에 맞는 대안을 찾지 못했습니다.',
      if (status == 'SUCCEEDED') 'response': {'planId': 42, 'timeline': [{'day': 3, 'placeName': '도착 숙소'}]},
    }), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }
  @override void close({bool force = false}) {}
}

void main() {
  late PlannerApi api;
  late ApprovalAdapter adapter;
  setUp(() async {
    adapter = ApprovalAdapter(); final dio = Dio(BaseOptions(baseUrl: 'http://test'));dio.httpClientAdapter = adapter;
    api = PlannerApi(dio: dio, generationPollInterval: const Duration(milliseconds: 10));
    await api.login('test@example.com', 'test');
  });
  tearDown(() => api.logout());
  Future<GenerationTask> start(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 780);t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(navigatorKey: generationNavigatorKey, builder: (_, child) => GenerationNotifications(api: api, child: child!), home: const Scaffold(body: Text('홈 화면'))));
    final task = api.startGeneration({'title': '여행', 'preferredEndTime': '22:00', 'tripDays': 5, 'cities': ['도쿄']});
    for (var i = 0; i < 25; i++) { await t.pump(const Duration(milliseconds: 20)); }
    expect(task.status, 'WAITING_APPROVAL');expect(task.active, isTrue);
    expect(find.text('3일차 종료 시간 확인'), findsOneWidget);
    expect(find.textContaining('80분 초과'), findsOneWidget);
    expect(find.textContaining('실패할 수 있습니다'), findsOneWidget);
    return task;
  }
  Future<void> finish(WidgetTester t, GenerationTask task) async {
    for (var i = 0; i < 30 && task.active; i++) { await t.pump(const Duration(milliseconds: 20)); }
    for (var i = 0; i < 5; i++) { await t.pump(const Duration(milliseconds: 30)); }
  }
  testWidgets('Allow is explicit, day-scoped, equal-sized and resumes the same generation job', (t) async {
    final task = await start(t);
    final reject = t.getRect(find.widgetWithText(OutlinedButton, '거부'));
    final allow = t.getRect(find.widgetWithText(FilledButton, '허용'));
    expect(reject.width, closeTo(allow.width, .1));expect(reject.height, closeTo(allow.height, .1));expect(reject.left, lessThan(allow.left));
    await t.tap(find.text('허용'));await finish(t, task);
    expect(task.status, 'SUCCEEDED');expect(task.request['preferredEndTime'], '22:00');
    final choices = adapter.requests.where((r) => r.path.endsWith('/end-time-decision')).toList();
    expect(choices.length, 1);expect(choices.single.data, {'decisionId': 'decision-3', 'allow': true});
    expect(choices.single.headers['Authorization'], 'Bearer header.payload.signature');
    expect(adapter.requests.where((r) => r.method == 'POST' && r.path.endsWith('/generation-jobs')).length, 1);
    expect(find.text('일정 생성 완료'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Reject searches an alternative and may then display generation failure', (t) async {
    adapter.alternativeFails = true;final task = await start(t);
    await t.tap(find.text('거부'));await finish(t, task);
    expect(task.status, 'FAILED');expect(find.text('작업 실패'), findsOneWidget);
    expect(adapter.requests.singleWhere((r) => r.path.endsWith('/end-time-decision')).data['allow'], isFalse);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('A dismissed choice stays pending and can be reopened from generation jobs', (t) async {
    final task = await start(t);await t.tap(find.byTooltip('나중에 선택'));
    for (var i = 0; i < 15; i++) { await t.pump(const Duration(milliseconds: 30)); }
    expect(find.text('3일차 종료 시간 확인'), findsNothing);expect(task.status, 'WAITING_APPROVAL');
    await t.tap(find.text('확인 필요 1'));await t.pumpAndSettle();
    await t.tap(find.text('종료 시간 선택'));await t.pumpAndSettle();
    expect(find.text('3일차 종료 시간 확인'), findsOneWidget);
    await t.tap(find.text('거부'));await finish(t, task);expect(task.status, 'SUCCEEDED');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Decision errors remain in the dialog and are retryable without losing the job', (t) async {
    final task = await start(t);adapter.failDecisionOnce = true;
    await t.tap(find.text('허용'));for (var i = 0; i < 15; i++) { await t.pump(const Duration(milliseconds: 20)); }
    expect(find.text('3일차 종료 시간 확인'), findsOneWidget);expect(task.active, isTrue);
    await t.tap(find.text('허용'));await finish(t, task);expect(task.status, 'SUCCEEDED');
    await t.pumpWidget(const SizedBox());
  });
}
