import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/features/auth/pages/email_login_page.dart';

class SignupAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? f,
  ) async => ResponseBody.fromString('회원가입 완료', 200);
}

void main() {
  testWidgets(
    'successful signup clears credentials and demographic selections',
    (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = SignupAdapter();
      await tester.pumpWidget(
        MaterialApp(
          home: EmailLoginPage(api: PlannerApi(dio: dio)),
        ),
      );
      await tester.tap(find.text('새 계정 만들기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'new@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('여성').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('40대').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
      await tester.pumpAndSettle();
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      ))
        expect(field.controller!.text, isEmpty);
      await tester.tap(find.text('새 계정 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('여성'), findsNothing);
      expect(find.text('40대'), findsNothing);
    },
  );
}
