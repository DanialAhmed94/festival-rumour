import 'package:flutter/foundation.dart';
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

  void openHelp() {
    // TODO: Open How to Use section
  }

  void rateApp() {
    // TODO: Launch app store for rating
  }

  void shareApp() {
    // TODO: Implement app sharing logic
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
