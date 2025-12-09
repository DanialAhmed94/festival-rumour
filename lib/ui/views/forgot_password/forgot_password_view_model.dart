import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/router/app_router.dart';

class ForgotPasswordViewModel extends BaseViewModel {
  /// Services
  final AuthService _authService = AuthService();
  final NavigationService _navigationService = locator<NavigationService>();

  /// Controllers
  final TextEditingController emailController = TextEditingController();

  /// State variables
  bool isEmailValid = false;
  bool isEmailSent = false;
  String? emailError;
  int resendCountdown = 0;
  bool canResend = true;

  /// Focus management
  final FocusNode _emailFocus = FocusNode();
  FocusNode get emailFocus => _emailFocus;

  @override
  void init() {
    super.init();
    // Auto-focus email field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isDisposed) {
        _emailFocus.requestFocus();
      }
    });
  }

  @override
  void onDispose() {
    emailController.dispose();
    _emailFocus.dispose();
    super.onDispose();
  }

  /// ---------------------------
  /// 🔹 Email Validation
  /// ---------------------------
  void onEmailChanged(String value) {
    if (value.isEmpty) {
      emailError = null;
      isEmailValid = false;
      notifyListeners();
      return;
    }

    // Clear previous errors
    emailError = null;

    // Validate email format
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      isEmailValid = false;
      notifyListeners();
      return;
    }

    isEmailValid = true;
    notifyListeners();
  }

  void onEmailFocusChange(bool hasFocus) {
    if (!hasFocus && emailController.text.isNotEmpty) {
      _validateEmail();
    }
    notifyListeners();
  }

  void _validateEmail() {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      emailError = AppStrings.emailRequired;
      isEmailValid = false;
    } else {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        emailError = AppStrings.invalidEmailFormat;
        isEmailValid = false;
      } else {
        emailError = null;
        isEmailValid = true;
      }
    }
    notifyListeners();
  }

  /// ---------------------------
  /// 🔹 Password Reset
  /// ---------------------------
  Future<void> sendPasswordResetEmail() async {
    if (!isEmailValid || isLoading) return;

    final email = emailController.text.trim();
    
    await handleAsync(
      () async {
        final result = await _authService.sendPasswordResetEmail(email);
        
        if (result.isSuccess) {
          isEmailSent = true;
          _startResendCountdown();
        } else {
          // Error message is already set by handleAsync from the exception
          // Set email error for form validation
          if (result.errorMessage != null) {
            _handlePasswordResetError(result.errorMessage!);
          }
        }
      },
      onError: (error) {
        // Additional error handling if needed
        _handlePasswordResetError(error);
      },
    );
  }

  Future<void> resendPasswordResetEmail() async {
    if (!canResend || isLoading) return;

    await sendPasswordResetEmail();
  }

  void _handlePasswordResetError(String error) {
    emailError = error;
    isEmailValid = false;
    notifyListeners();
  }

  /// ---------------------------
  /// 🔹 Resend Countdown
  /// ---------------------------
  void _startResendCountdown() {
    resendCountdown = 60; // 60 seconds countdown
    canResend = false;
    notifyListeners();

    // Start countdown timer
    _countdownTimer();
  }

  void _countdownTimer() {
    if (isDisposed) return;

    if (resendCountdown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!isDisposed) {
          resendCountdown--;
          notifyListeners();
          _countdownTimer();
        }
      });
    } else {
      canResend = true;
      notifyListeners();
    }
  }

  /// ---------------------------
  /// 🔹 Navigation
  /// ---------------------------
  void goBackToLogin() {
    //_navigationService.goBack();
  }

  void goToSignUp() {
    _navigationService.navigateTo(AppRoutes.signupEmail);
  }

  /// ---------------------------
  /// 🔹 Form Validation
  /// ---------------------------
  bool get canSendResetEmail => isEmailValid && !isLoading && !isEmailSent;
  bool get canResendEmail => canResend && !isLoading && isEmailSent;

  /// ---------------------------
  /// 🔹 UI State
  /// ---------------------------
  String get resendButtonText {
    if (isLoading) {
      return AppStrings.resendingEmail;
    } else if (resendCountdown > 0) {
      return 'Resend in ${resendCountdown}s';
    } else {
      return AppStrings.resendEmail;
    }
  }

  String get sendButtonText {
    if (isLoading) {
      return AppStrings.sendingResetLink;
    } else {
      return AppStrings.sendResetLink;
    }
  }

  /// ---------------------------
  /// 🔹 Error Handling
  /// ---------------------------
  void clearError() {
    emailError = null;
    notifyListeners();
  }

  void resetForm() {
    emailController.clear();
    isEmailValid = false;
    isEmailSent = false;
    emailError = null;
    resendCountdown = 0;
    canResend = true;
    notifyListeners();
  }
}
