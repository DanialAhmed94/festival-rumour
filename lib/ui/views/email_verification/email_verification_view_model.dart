import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/signup_data_service.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/exceptions/app_exception.dart';

class EmailVerificationViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = locator<AuthService>();
  final SignupDataService _signupDataService = SignupDataService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _canResend = true;
  bool get canResend => _canResend;

  int _secondsRemaining = 0;
  Timer? _resendTimer;
  Timer? _verificationCheckTimer;

  bool _isEmailVerified = false;
  bool get isEmailVerified => _isEmailVerified;

  /// Get email from signup data service or Firebase user
  String? get userEmail => _authService.userEmail ?? _signupDataService.email;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void init() {
    super.init();
    
    // Check if user already exists (might have been created previously)
    if (_authService.isSignedIn) {
      // User already exists, check verification status
      _checkVerificationStatus();
      // Start checking verification status periodically
      _startVerificationCheck();
    } else {
      // Create Firebase user and send verification email when screen loads
      _createUserAndSendVerificationEmail();
      // Start checking verification status periodically
      _startVerificationCheck();
    }
  }

  /// Check current verification status
  Future<void> _checkVerificationStatus() async {
    try {
      await _authService.reloadUser();
      _isEmailVerified = _authService.isEmailVerified;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking verification status: $e');
      }
    }
  }

  /// Create Firebase user and send verification email
  Future<void> _createUserAndSendVerificationEmail() async {
    final email = _signupDataService.email;
    final password = _signupDataService.password;

    if (email == null || password == null) {
      _showErrorSnackBar('Email and password are required. Please start signup again.');
      return;
    }

    await handleAsync(() async {
      // Create Firebase user account (required to send verification email)
      final userCredential = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (userCredential != null) {
        // Send verification email immediately
        await _authService.sendEmailVerification();
        _showSuccessSnackBar('Verification email sent! Please check your inbox.');
      } else {
        throw UnknownException(
          message: 'Failed to create account. Please try again.',
        );
      }
    }, onError: (error) {
      _showErrorSnackBar(error);
    });
  }

  /// Start periodic check for email verification
  void _startVerificationCheck() {
    _verificationCheckTimer?.cancel();
    _verificationCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (isDisposed) {
        timer.cancel();
        return;
      }

      try {
        // Reload user to get latest verification status
        await _authService.reloadUser();
        final verified = _authService.isEmailVerified;

        if (verified != _isEmailVerified) {
          _isEmailVerified = verified;
          notifyListeners();

          if (verified) {
            timer.cancel();
            _showSuccessSnackBar('Email verified successfully!');
          }
        }
      } catch (e) {
        // Silently continue checking
        if (kDebugMode) {
          print('Error checking verification status: $e');
        }
      }
    });
  }

  /// 🔹 Check if email verified when pressing Continue
  /// Only allows navigation if email is verified
  Future<void> checkEmailVerification() async {
    if (!_isEmailVerified) {
      _showErrorSnackBar('Please verify your email first. Check your inbox and click the verification link.');
      return;
    }

    await handleAsync(() async {
      // Reload user to ensure we have latest verification status
      await _authService.reloadUser();

      if (!_authService.isEmailVerified) {
        _isEmailVerified = false;
        notifyListeners();
        _showErrorSnackBar('Email is not verified yet. Please check your inbox and click the verification link.');
        return;
      }

      // Email is verified - navigate to phone number screen
      _navigationService.navigateTo(AppRoutes.signup);
    }, onError: (error) {
      _showErrorSnackBar(error);
    });
  }

  /// 🔹 Resend verification email (with cooldown)
  Future<void> resendVerificationEmail() async {
    if (!_canResend) return; // prevent spam

    await handleAsync(() async {
      // Check if user exists (should exist since we create it in init)
      if (!_authService.isSignedIn) {
        // User doesn't exist, create it and send verification
        await _createUserAndSendVerificationEmail();
      } else {
        // User exists, just resend verification email
        await _authService.sendEmailVerification();
        _showSuccessSnackBar('Verification email sent! Please check your inbox.');
      }

      _startResendCooldown();
    }, onError: (error) {
      _showErrorSnackBar('Failed to send verification email. $error');
    });
  }

  /// 🔹 Start 30-second cooldown for resend button
  void _startResendCooldown() {
    _secondsRemaining = 20;
    _canResend = false;
    notifyListeners();

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsRemaining--;
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _canResend = true;
      }
      notifyListeners();
    });
  }

  /// 🔹 Text for button (e.g., “Resend in 25s”)
  String get resendButtonText =>
      _canResend ? "Resend Verification Email" : "Resend in $_secondsRemaining s";

  /// 🔹 Handle success/error messages
  void _showErrorSnackBar(String message) {
    // In production, use your SnackbarService or context-based snackbar
    debugPrint('❌ Error: $message');
    _navigationService.showSnackbar(message, isError: true);
  }

  void _showSuccessSnackBar(String message) {
    debugPrint('✅ Success: $message');
    _navigationService.showSnackbar(message);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }
}
