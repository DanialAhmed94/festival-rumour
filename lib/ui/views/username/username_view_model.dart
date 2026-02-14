import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';

class UsernameViewModel extends BaseViewModel {
  /// Services
  final FirebaseAuthService _authService = FirebaseAuthService();
  final NavigationService _navigationService = locator<NavigationService>();
  final StorageService _storageService = locator<StorageService>();

  /// Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  /// State variables
  bool rememberMe = false;
  bool isPasswordVisible = false;
  bool isEmailValid = false;
  bool isPasswordValid = false;
  bool isFormValid = false;

  /// Error messages
  String? emailError;
  String? passwordError;

  /// Password strength
  String passwordStrength = '';
  Color passwordStrengthColor = AppColors.grey600;

  /// ---------------------------
  /// 🔹 Input Handlers
  /// ---------------------------
  void onUsernameChanged(String value) {
    // Don't validate while typing - only clear previous errors
    if (value.isEmpty) {
      emailError = null;
      isEmailValid = false;
      _updateFormValidity();
      notifyListeners();
    }
  }

  void onPasswordChanged(String value) {
    // Don't validate while typing - only clear previous errors
    if (value.isEmpty) {
      passwordError = null;
      passwordStrength = '';
      passwordStrengthColor = AppColors.grey600;
      isPasswordValid = false;
      _updateFormValidity();
      notifyListeners();
    }
  }

  /// Toggle remember me
  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  /// Focus handlers
  void onUsernameFocusChange(bool hasFocus) {
    if (!hasFocus) {
      _validateEmail(emailController.text);
      _updateFormValidity();
      notifyListeners();
    }
  }

  void onPasswordFocusChange(bool hasFocus) {
    if (!hasFocus) {
      _validatePassword(passwordController.text);
      _updateFormValidity();
      notifyListeners();
    }
  }

  /// Focus management methods
  void focusEmailField() {
    // This will be called from the view to focus email field
  }

  void focusPasswordField() {
    // This will be called from the view to focus password field
  }

  /// ---------------------------
  /// 🔹 Validation Methods
  /// ---------------------------
  void _validateEmail(String email) {
    if (email.isEmpty) {
      emailError = AppStrings.emailRequired;
      isEmailValid = false;
    } else if (!_isValidEmail(email)) {
      emailError = AppStrings.emailInvalid;
      isEmailValid = false;
    } else {
      emailError = null;
      isEmailValid = true;
    }
  }

  void _validatePassword(String password) {
    if (password.isEmpty) {
      passwordError = AppStrings.passwordRequired;
      passwordStrength = '';
      passwordStrengthColor = AppColors.grey600;
      isPasswordValid = false;
    } else if (password.length < 6) {
      passwordError = AppStrings.passwordMinLength;
      passwordStrength = AppStrings.passwordWeak;
      passwordStrengthColor = AppColors.error;
      isPasswordValid = false;
    } else if (password.length > 50) {
      passwordError = AppStrings.passwordMaxLength;
      passwordStrength = AppStrings.passwordWeak;
      passwordStrengthColor = AppColors.error;
      isPasswordValid = false;
    } else {
      passwordError = null;
      _calculatePasswordStrength(password);
      isPasswordValid = true;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  void _calculatePasswordStrength(String password) {
    int score = 0;

    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character variety checks
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) {
      passwordStrength = AppStrings.passwordWeak;
      passwordStrengthColor = AppColors.error;
    } else if (score <= 4) {
      passwordStrength = AppStrings.passwordMedium;
      passwordStrengthColor = AppColors.warning;
    } else {
      passwordStrength = AppStrings.passwordStrong;
      passwordStrengthColor = AppColors.success;
    }
  }

  void _updateFormValidity() {
    isFormValid = isEmailValid && isPasswordValid;
  }

  /// ---------------------------
  /// 🔹 Validation + Login Logic
  /// ---------------------------
  Future<void> validateAndLogin(BuildContext context) async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // Always validate all fields when login button is clicked
    _validateEmail(email);
    _validatePassword(password);
    _updateFormValidity();

    // Notify listeners to update UI with error messages
    notifyListeners();

    // If any error found, show specific error messages
    if (!isFormValid) {
      // Show specific error message based on what's missing
      String errorMessage = '';
      if (email.isEmpty) {
        errorMessage = AppStrings.emailRequired;
      } else if (!_isValidEmail(email)) {
        errorMessage = AppStrings.emailInvalid;
      } else if (password.isEmpty) {
        errorMessage = AppStrings.passwordRequired;
      } else if (password.length < 6) {
        errorMessage = AppStrings.passwordMinLength;
      } else {
        errorMessage = AppStrings.fixErrors;
      }

      _showErrorSnackBar(context, errorMessage);
      return;
    }

    await handleAsync(
      () async {
        // Simulate API delay
        await Future.delayed(AppDurations.loginLoadingDuration);

        // Firebase login validation
        if (kDebugMode) {
          print('🔐 [LOGIN] Attempting email/password login...');
          print('   Email: $email');
          print('   Route: ${AppRoutes.username}');
        }

        final result = await _authService.signInWithEmail(
          email: email,
          password: password,
        );

        if (result.isSuccess) {
          final user = _authService.currentUser;
          if (kDebugMode) {
            print('✅ [LOGIN] Email/Password login successful!');
            print('   User ID: ${user?.uid}');
            print('   Email: ${user?.email}');
            print('   Display Name: ${user?.displayName ?? 'N/A'}');
            print('   Navigating to: ${AppRoutes.festivals}');
          }

          // Save login state to storage (name and picture from auth)
          if (user != null) {
            await _storageService.setLoggedIn(
              true,
              userId: user.uid,
              displayName: user.displayName,
              photoUrl: user.photoURL,
            );
            await updateFcmTokenForUser();

            if (kDebugMode) {
              print('✅ [LOGIN] Login state saved to storage');
            }
          }

          _showSuccessSnackBar(context, AppStrings.loginSuccess);
          // Navigate to Festival Screen using navigation service
          _navigationService.navigateTo(AppRoutes.festivals);
        } else {
          if (kDebugMode) {
            print('❌ [LOGIN] Email/Password login failed!');
            print('   Error: ${result.errorMessage}');
          }
          // Error message is already set by handleAsync from the exception
          // The error will be displayed via BaseView's onError handler
          if (result.errorMessage != null) {
            _showErrorSnackBar(context, result.errorMessage!);
          }
        }
      },
      minimumLoadingDuration: AppDurations.loginLoadingDuration,
      onError: (error) {
        // Additional error handling if needed
        _showErrorSnackBar(context, error);
      },
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: AppDimensions.spaceS),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success.withOpacity(0.1),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<void> updateFcmTokenForUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token, // ✅ single token
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // merge keeps other fields safe

    print("✅ FCM token replaced in Firestore");
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    // Make error message more user-friendly
    String userFriendlyMessage = _getUserFriendlyErrorMessage(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: AppColors.error),
            const SizedBox(width: AppDimensions.spaceS),
            Expanded(
              child: Text(
                userFriendlyMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error.withOpacity(0.1),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Convert technical error messages to user-friendly messages
  String _getUserFriendlyErrorMessage(String errorMessage) {
    final lowerMessage = errorMessage.toLowerCase();

    // Handle invalid credentials
    if (lowerMessage.contains('invalid-credential') ||
        lowerMessage.contains('incorrect, malformed or has expired') ||
        lowerMessage.contains('wrong-password') ||
        lowerMessage.contains('invalid password')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }

    // Handle user not found
    if (lowerMessage.contains('user-not-found') ||
        lowerMessage.contains('there is no user record')) {
      return 'No account found with this email. Please sign up first.';
    }

    // Handle network errors
    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('timeout')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    // Handle too many requests
    if (lowerMessage.contains('too-many-requests') ||
        lowerMessage.contains('too many attempts')) {
      return 'Too many login attempts. Please try again later.';
    }

    // Handle email not verified
    if (lowerMessage.contains('email-not-verified') ||
        lowerMessage.contains('email is not verified')) {
      return 'Please verify your email address before logging in.';
    }

    // Default: return original message if no specific match
    return errorMessage;
  }

  /// ---------------------------
  /// 🔹 Navigate to Sign Up
  /// ---------------------------
  void goToSignUp(BuildContext context) {
    _navigationService.navigateTo(AppRoutes.signupEmail);
  }

  /// ---------------------------
  /// 🔹 Firebase Auth State Management
  /// ---------------------------
  void checkAuthState() {
    // Check if user is already signed in
    if (_authService.isSignedIn) {
      // User is already signed in, navigate to home
      _navigationService.navigateTo(AppRoutes.festivals);
    }
  }

  /// Sign out method
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      // Navigate back to welcome/login screen
      _navigationService.navigateTo(AppRoutes.welcome);
    } catch (e) {
      // Handle sign out error
      print('Sign out error: $e');
    }
  }

  /// ---------------------------
  /// 🔹 Cleanup
  /// ---------------------------
  @override
  void onDispose() {
    emailController.dispose();
    passwordController.dispose();
    super.onDispose();
  }
}
