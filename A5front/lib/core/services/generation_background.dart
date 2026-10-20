import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android owns the status check while Flutter is paused by the Home button.
class GenerationBackground {
  static const channel = MethodChannel('ai_travel_planner/generation');
  static bool get enabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> watch({
    required String id,
    required String title,
    required String baseUrl,
    required String token,
  }) async {
    if (!enabled) return;
    // Register before asking permission so a permission sheet never delays generation.
    try {
      await channel.invokeMethod('watch', {
        'id': id,
        'title': title,
        'baseUrl': baseUrl,
        'token': token,
      });
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
    try {
      if (await Permission.notification.status == PermissionStatus.denied) {
        await Permission.notification.request();
      }
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  static Future<void> finish({
    required String id,
    required String title,
    required String token,
    required String status,
    dynamic planId,
  }) async {
    if (!enabled) return;
    try {
      await channel.invokeMethod('finish', {
        'id': id,
        'title': title,
        'token': token,
        'status': status,
        'planId': planId,
      });
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  static Future<void> clear() async {
    if (!enabled) return;
    try {
      await channel.invokeMethod('clear');
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }
}
