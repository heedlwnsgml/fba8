import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_travel_planner/core/services/generation_background.dart';
import 'package:ai_travel_planner/features/trip/widgets/trip_step_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android registers authenticated background watch, terminal result and logout cleanup', () async {
    final calls = <MethodCall>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), (call) async => 1);
    messenger.setMockMethodCallHandler(GenerationBackground.channel, (call) async { calls.add(call); return null; });
    try {
      await GenerationBackground.watch(id: 'a'*32, title: '30박 여행', baseUrl: 'http://127.0.0.1:8080', token: 'test-session');
      await GenerationBackground.finish(id: 'a'*32, title: '30박 여행', token: 'test-session', status: 'SUCCEEDED', planId: 42);
      await GenerationBackground.clear();
      expect(calls.map((c) => c.method), ['watch', 'finish', 'clear']);
      expect(calls[0].arguments['token'], 'test-session');
      expect(calls[1].arguments['planId'], 42);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(GenerationBackground.channel, null);
      messenger.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), null);
    }
  });
  testWidgets('Default pin notice leaves next button visible and tappable on a phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var next = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const TripStepHeader(currentStep: 6),
      const Expanded(child: Center(child: Text('금지 테마'))),
      FilledButton(onPressed: () => next++, child: const Text('다음')),
      const SizedBox(height: 22),
    ]))));
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(tester.getRect(find.byType(MaterialBanner)).overlaps(tester.getRect(find.text('다음'))), isFalse);
    await tester.tap(find.text('다음'));
    expect(next, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
