import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionOnboarding {
  static const completedKey = 'permission_onboarding_completed_v2';
  static Future<bool> shouldShow() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(completedKey) ?? false);
  }

  static Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedKey, true);
  }
}
