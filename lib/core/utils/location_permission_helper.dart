import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_strings.dart';

/// Result of requesting location permission.
enum LocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

/// Professional location permission handling for Android and iOS.
/// Request permission, show rationale when denied (before re-request), and
/// open settings when permanently denied.
class LocationPermissionHelper {
  LocationPermissionHelper._();

  /// Request location permission with platform-appropriate flow.
  /// - If already granted: returns immediately.
  /// - If permanently denied: shows dialog with [AppStrings.openSettings] and
  ///   opens app settings when user confirms.
  /// - If denied (e.g. user said no once): shows rationale dialog then re-requests.
  /// - Otherwise: requests permission.
  /// Returns [LocationPermissionResult.granted] if location can be used.
  static Future<LocationPermissionResult> requestLocationPermission(
    BuildContext context,
  ) async {
    final status = await Permission.locationWhenInUse.status;

    if (status.isGranted) {
      return LocationPermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermanentlyDeniedDialog(context);
      }
      return LocationPermissionResult.permanentlyDenied;
    }

    // When denied (user said no once), show rationale before asking again
    if (status.isDenied && context.mounted) {
      final showRequest = await _showRationaleDialog(context);
      if (!showRequest) return LocationPermissionResult.denied;
    }

    // Request permission
    final result = await Permission.locationWhenInUse.request();

    if (result.isGranted) {
      return LocationPermissionResult.granted;
    }

    if (result.isPermanentlyDenied && context.mounted) {
      await _showPermanentlyDeniedDialog(context);
      return LocationPermissionResult.permanentlyDenied;
    }

    return LocationPermissionResult.denied;
  }

  static Future<bool> _showRationaleDialog(BuildContext context) async {
    final value = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.shareMyLocation, style: TextStyle(color: Colors.black)),
        content: const Text(AppStrings.locationPermissionRequired, style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel, style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.ok, style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    return value ?? false;
  }

  static Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.shareMyLocation, style: TextStyle(color: Colors.black)),
        content: const Text(AppStrings.locationPermissionPermanentlyDenied, style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel, style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text(AppStrings.openSettings, style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
