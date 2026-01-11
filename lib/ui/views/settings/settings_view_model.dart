import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';

class SettingsViewModel extends BaseViewModel {
  /// 🔹 Switch states
  bool notifications = true;
  bool privacy = false;

  /// 🔹 Services
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = locator<AuthService>();
  final StorageService _storageService = locator<StorageService>();

  /// 🔹 Toggle methods
  void toggleNotifications(bool value) {
    notifications = value;
    notifyListeners();
  }

  void togglePrivacy(bool value) {
    privacy = value;
    notifyListeners();
  }

  /// 🔹 Navigation / Actions (stub methods for now)
  void editAccount() {
    _navigationService.navigateTo(AppRoutes.editAccount);
  }

  void openBadges() {
    // TODO: Navigate to Badges screen
  }

  void openLeaderboard() {
    // TODO: Navigate to Leaderboard screen
    _navigationService.navigateTo(AppRoutes.leaderboard);
  }

  /// Rate the app - opens Play Store (Android) or App Store (iOS)
  Future<void> rateApp() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String packageName = packageInfo.packageName;
      
      String url;
      if (Platform.isAndroid) {
        // Android Play Store URL
        url = 'https://play.google.com/store/apps/details?id=$packageName';
      } else if (Platform.isIOS) {
        // iOS App Store URL - replace with your actual App Store ID
        const String iosAppStoreId = 'YOUR_IOS_APP_STORE_ID'; // TODO: Replace with actual App Store ID
        url = 'https://apps.apple.com/app/id$iosAppStoreId';
      } else {
        if (kDebugMode) {
          print('⚠️ Rate app not supported on this platform');
        }
        return;
      }

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (kDebugMode) {
          print('❌ Could not launch URL: $url');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error rating app: $e');
      }
    }
  }

  /// Share the app - opens native share dialog
  Future<void> shareApp() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String packageName = packageInfo.packageName;
      final String appName = packageInfo.appName;
      
      String shareText;
      String shareUrl;
      
      if (Platform.isAndroid) {
        shareUrl = 'https://play.google.com/store/apps/details?id=$packageName';
        shareText = 'Check out $appName on Google Play Store!\n$shareUrl';
      } else if (Platform.isIOS) {
        const String iosAppStoreId = 'YOUR_IOS_APP_STORE_ID'; // TODO: Replace with actual App Store ID
        shareUrl = 'https://apps.apple.com/app/id$iosAppStoreId';
        shareText = 'Check out $appName on the App Store!\n$shareUrl';
      } else {
        shareUrl = 'https://play.google.com/store/apps/details?id=$packageName';
        shareText = 'Check out $appName!\n$shareUrl';
      }

      await Share.share(
        shareText,
        subject: 'Check out $appName',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sharing app: $e');
      }
    }
  }

  void openPrivacyPolicy() {
    // TODO: Navigate to Privacy Policy page
  }

  void openTerms() {
    // TODO: Navigate to Terms & Conditions page
  }

  /// Logout user with proper error handling
  Future<void> logout() async {
    await handleAsync(() async {
      if (kDebugMode) {
        print('🚪 [Settings] Starting logout process...');
      }

      try {
        // Sign out from Firebase (handles both Firebase Auth and Google Sign In)
        await _authService.signOut();
        
        if (kDebugMode) {
          print('✅ [Settings] Firebase sign out successful');
        }

        // Clear local storage (logged in state, user ID, etc.)
        await _storageService.clearAll();
        
        if (kDebugMode) {
          print('✅ [Settings] Storage cleared successfully');
        }

        // Navigate to welcome screen and clear navigation stack
        // This removes all previous routes from the stack
        await _navigationService.navigateToLogin();

        if (kDebugMode) {
          print('✅ [Settings] Logout completed successfully');
        }
      } catch (e, stackTrace) {
        // Error is already handled by AuthService.signOut() using global error handler
        // But we still need to handle navigation failure separately
        if (kDebugMode) {
          print('❌ [Settings] Error during logout: $e');
        }
        // Re-throw to let handleAsync show error message to user
        rethrow;
      }
    }, errorMessage: 'Failed to logout. Please try again.');
  }

  /// Delete user account with proper error handling
  Future<void> deleteAccount() async {
    await handleAsync(() async {
      if (kDebugMode) {
        print('🗑️ [Settings] Starting account deletion process...');
      }

      try {
        // Delete user from Firebase Authentication
        await _authService.deleteAccount();
        
        if (kDebugMode) {
          print('✅ [Settings] Firebase account deletion successful');
        }

        // Clear local storage (logged in state, user ID, etc.)
        await _storageService.clearAll();
        
        if (kDebugMode) {
          print('✅ [Settings] Storage cleared successfully');
        }

        // Navigate to welcome screen and clear navigation stack
        // This removes all previous routes from the stack
        await _navigationService.navigateToLogin();

        if (kDebugMode) {
          print('✅ [Settings] Account deletion completed successfully');
        }
      } catch (e, stackTrace) {
        // Error is already handled by AuthService.deleteAccount() using global error handler
        // But we still need to handle navigation failure separately
        if (kDebugMode) {
          print('❌ [Settings] Error during account deletion: $e');
        }
        // Re-throw to let handleAsync show error message to user
        rethrow;
      }
    }, errorMessage: 'Failed to delete account. Please try again.');
  }

  void goToSubscription() {
    _navigationService.navigateTo(AppRoutes.subscription);
  }
}
