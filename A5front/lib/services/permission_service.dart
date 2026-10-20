import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  const PermissionService._();

  static PermissionStatus webLocation(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse
      ? PermissionStatus.granted
      : p == LocationPermission.deniedForever
      ? PermissionStatus.permanentlyDenied
      : PermissionStatus.denied;
  static Future<PermissionStatus> getLocationStatus() async {
    if (kIsWeb) {
      try {
        return webLocation(await Geolocator.checkPermission());
      } catch (_) {
        return PermissionStatus.denied;
      }
    }
    return Permission.locationWhenInUse.status;
  }

  static Future<PermissionStatus> getNotificationStatus() {
    return Permission.notification.status;
  }

  static Future<PermissionStatus> requestLocationPermission() async {
    if (kIsWeb) {
      try {
        return webLocation(await Geolocator.requestPermission());
      } catch (_) {
        return PermissionStatus.denied;
      }
    }
    return Permission.locationWhenInUse.request();
  }

  static Future<PermissionStatus> requestNotificationPermission() {
    return Permission.notification.request();
  }

  static Future<bool> isLocationGranted() async {
    final status = await getLocationStatus();
    return status == PermissionStatus.granted;
  }

  static Future<bool> isNotificationGranted() async {
    final status = await getNotificationStatus();
    return status == PermissionStatus.granted;
  }

  static Future<void> openAppPermissionSettings() {
    return openAppSettings();
  }
}
