import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../shared/extensions/context_extensions.dart';

class WelcomeViewModel extends BaseViewModel {
  bool _isLoading = false;
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final StorageService _storageService = locator<StorageService>();

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    setLoading(true);

    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        // User signed in successfully with Firebase
        final user = userCredential.user!;
        if (kDebugMode) {
          print("✅ [LOGIN] Google Sign-In successful: ${user.email}");
          print("   User ID: ${user.uid}");
        }
        
        // Save login state to storage
        await _storageService.setLoggedIn(true, userId: user.uid);
        if (kDebugMode) {
          print('✅ [LOGIN] Login state saved to storage');
        }
        
        // Navigate to festival screen
        _navigationService.navigateTo(AppRoutes.festivals);
      }
    } catch (error) {
      if (kDebugMode) {
        print("❌ [LOGIN] Google Sign-In Error: $error");
      }
      // Error handling is done by the global error handler
    } finally {
      setLoading(false);
    }
  }

  Future<void> loginWithEmail() async {
    _navigationService.navigateTo(AppRoutes.username);
  }

  Future<void> loginWithApple() async {
    setLoading(true);

    try {
      final userCredential = await _authService.signInWithApple();
      if (userCredential != null && userCredential.user != null) {
        // User signed in successfully with Firebase
        final user = userCredential.user!;
        if (kDebugMode) {
          print("✅ [LOGIN] Apple Sign-In successful: ${user.email}");
          print("   User ID: ${user.uid}");
        }
        
        // Save login state to storage
        await _storageService.setLoggedIn(true, userId: user.uid);
        if (kDebugMode) {
          print('✅ [LOGIN] Login state saved to storage');
        }
        
        // Navigate to festival screen
        _navigationService.navigateTo(AppRoutes.festivals);
      }
    } catch (error) {
      if (kDebugMode) {
        print("❌ [LOGIN] Apple Sign-In Error: $error");
      }
      // Error handling is done by the global error handler
    } finally {
      setLoading(false);
    }
  }

  void goToSignup() {
    _navigationService.navigateTo(AppRoutes.signupEmail);
  }
}
