import 'dart:async';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class AppPermissionService {
  AppPermissionService._();

  static final AppPermissionService instance = AppPermissionService._();

  int? _androidSdkInt() {
    if (!Platform.isAndroid) {
      return null;
    }

    final sdkMatch = RegExp(
      r'SDK\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(Platform.operatingSystemVersion);
    if (sdkMatch != null) {
      return int.tryParse(sdkMatch.group(1)!);
    }

    final apiMatch = RegExp(
      r'API[- ]?(\d+)',
      caseSensitive: false,
    ).firstMatch(Platform.operatingSystemVersion);
    if (apiMatch != null) {
      return int.tryParse(apiMatch.group(1)!);
    }

    return null;
  }

  List<Permission> _requiredPermissions() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const [];
    }

    if (Platform.isAndroid) {
      final sdkInt = _androidSdkInt();
      if (sdkInt != null && sdkInt <= 30) {
        return [Permission.locationWhenInUse];
      }

      return [Permission.bluetoothScan, Permission.bluetoothConnect];
    }

    return [Permission.bluetooth, Permission.locationWhenInUse];
  }

  ({bool granted, bool permanentlyDenied}) _evaluate(
    Map<Permission, PermissionStatus> statuses,
    List<Permission> permissions,
  ) {
    bool isGrantedOrLimited(Permission permission) {
      final status = statuses[permission];
      return status?.isGranted == true || status?.isLimited == true;
    }

    bool isPermanentlyDenied(Permission permission) {
      final status = statuses[permission];
      return status?.isPermanentlyDenied == true;
    }

    final sdkInt = _androidSdkInt();

    final bluetoothGranted = Platform.isAndroid
        ? isGrantedOrLimited(Permission.bluetoothScan) &&
              isGrantedOrLimited(Permission.bluetoothConnect)
        : isGrantedOrLimited(Permission.bluetooth);

    final locationGranted = isGrantedOrLimited(Permission.locationWhenInUse);

    final permanentlyDenied = permissions.any(isPermanentlyDenied);

    final ready = Platform.isAndroid
        ? ((sdkInt != null && sdkInt <= 30)
              ? locationGranted
              : bluetoothGranted)
        : bluetoothGranted && locationGranted;

    return (granted: ready, permanentlyDenied: permanentlyDenied);
  }

  /// Fast, non-interactive check (does NOT prompt the user).
  Future<({bool granted, bool permanentlyDenied})> checkStatus() async {
    final permissions = _requiredPermissions();
    if (permissions.isEmpty) {
      return (granted: true, permanentlyDenied: false);
    }

    final statuses = <Permission, PermissionStatus>{};
    try {
      for (final p in permissions) {
        statuses[p] = await p.status;
      }
    } catch (_) {
      // If status fails, treat as not granted but not permanently denied.
      return (granted: false, permanentlyDenied: false);
    }

    return _evaluate(statuses, permissions);
  }

  /// Requests the runtime permissions needed for Bluetooth discovery/connect.
  ///
  /// On Android 12+ the core permissions are `bluetoothScan` + `bluetoothConnect`.
  /// On Android 11 and below scanning requires location permission.
  Future<({bool granted, bool permanentlyDenied})> ensureReady() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return (granted: true, permanentlyDenied: false);
    }

    final permissions = _requiredPermissions();

    if (permissions.isEmpty) {
      return (granted: true, permanentlyDenied: false);
    }

    Map<Permission, PermissionStatus> requested;
    try {
      // Some OEM ROMs occasionally time out the Android permission controller.
      // Never block app startup indefinitely.
      requested = await permissions.request().timeout(
        const Duration(seconds: 8),
        onTimeout: () => <Permission, PermissionStatus>{},
      );
    } catch (_) {
      requested = <Permission, PermissionStatus>{};
    }

    return _evaluate(requested, permissions);
  }
}
