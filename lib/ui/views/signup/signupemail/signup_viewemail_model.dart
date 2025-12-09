import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/locator.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/signup_data_service.dart';
import '../../../../core/viewmodels/base_view_model.dart';
import '../../../../core/exceptions/app_exception.dart';

class SignupViewEmailModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final SignupDataService _signupDataService = SignupDataService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? emailError;
  String? passwordError;
  String? confirmPasswordError;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // Focus node getters
  FocusNode get emailFocus => _emailFocus;
  FocusNode get passwordFocus => _passwordFocus;
  FocusNode get confirmPasswordFocus => _confirmPasswordFocus;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  
  // Store error message for snackbar display
  String? _snackbarError;
  String? get snackbarError => _snackbarError;

  /// ✅ Validate fields
  bool validateFields() {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    bool isValid = true;

    // Email validation
    if (email.isEmpty) {
      emailError = "*Email is required";
      isValid = false;
    } else if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email)) {
      emailError = "Enter a valid email";
      isValid = false;
    } else {
      emailError = null;
    }

    // Password validation
    if (password.isEmpty) {
      passwordError = "*Password is required";
      isValid = false;
    } else if (password.length < 8) {
      passwordError = "*Password must be at least 8 characters";
      isValid = false;
    } else {
      passwordError = null;
    }

    // Confirm password validation
    if (confirmPassword.isEmpty) {
      confirmPasswordError = "*Please confirm your password";
      isValid = false;
    } else if (password != confirmPassword) {
      confirmPasswordError = "*Passwords did not match";
      isValid = false;
    } else {
      confirmPasswordError = null;
    }

    notifyListeners();
    return isValid;
  }

  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible = !isConfirmPasswordVisible;
    notifyListeners();
  }

  /// Focus management methods
  void focusEmail() {
    _emailFocus.requestFocus();
  }

  void focusPassword() {
    _passwordFocus.requestFocus();
  }

  void focusConfirmPassword() {
    _confirmPasswordFocus.requestFocus();
  }

  void unfocusAll() {
    _emailFocus.unfocus();
    _passwordFocus.unfocus();
    _confirmPasswordFocus.unfocus();
  }

  /// Handle text input actions
  void handleEmailSubmitted() {
    if (emailController.text.trim().isNotEmpty) {
      focusPassword();
    } else {
      // If email is empty, show error and keep focus
      emailError = "*Email is required";
      notifyListeners();
    }
  }

  void handlePasswordSubmitted() {
    if (passwordController.text.isNotEmpty) {
      focusConfirmPassword();
    } else {
      // If password is empty, show error and keep focus
      passwordError = "*Password is required";
      notifyListeners();
    }
  }

  void handleConfirmPasswordSubmitted() {
    if (confirmPasswordController.text.isNotEmpty) {
      // Validate before submitting
      if (validateFields()) {
        goToOtp();
      } else {
        // If validation fails, focus on the first field with error
        if (emailError != null) {
          focusEmail();
        } else if (passwordError != null) {
          focusPassword();
        } else if (confirmPasswordError != null) {
          focusConfirmPassword();
        }
      }
    } else {
      // If confirm password is empty, show error and keep focus
      confirmPasswordError = "*Please confirm your password";
      notifyListeners();
    }
  }

  /// Enhanced focus management with validation
  void focusNextField() {
    if (emailController.text.trim().isEmpty) {
      focusEmail();
    } else if (passwordController.text.isEmpty) {
      focusPassword();
    } else if (confirmPasswordController.text.isEmpty) {
      focusConfirmPassword();
    } else {
      // All fields have content, validate and submit
      if (validateFields()) {
        goToOtp();
      }
    }
  }

  /// ✅ Verify email availability and store signup data
  /// User will be created in Firebase only after all screens are completed
  Future<void> goToOtp() async {
    if (!validateFields()) return;

    await handleAsync(
      () async {
        final email = emailController.text.trim();
        final password = passwordController.text;
        
        // Validate email format before checking
        if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email)) {
          throw ValidationException.invalidFormat('email');
        }

        // Check if email is already registered in Firebase
        // This will throw AuthException if email is already taken
        await _authService.checkEmailAvailability(email);
        
        // Email is available - store the credentials temporarily
        _signupDataService.setEmailAndPassword(email, password);
        
        if (kDebugMode) {
          print('📧 [SIGNUP] Email signup screen completed');
          print('   Current Route: ${AppRoutes.signupEmail}');
          print('   Navigating to: ${AppRoutes.name}');
          print('   Email stored: $email');
        }
        
        // Navigate to name screen
        // User will be created at the final step after all screens
        _navigationService.navigateTo(AppRoutes.name);
      },
      onException: (exception) {
        // Handle specific exception types for better UX
        _handleSignupException(exception);
      },
      onError: (errorMessage) {
        // Store error for snackbar display in view
        _snackbarError = errorMessage;
        notifyListeners();
      },
    );
  }

  /// Handle signup exceptions with specific field-level error messages
  void _handleSignupException(AppException exception) {
    // Clear previous errors
    emailError = null;
    passwordError = null;
    confirmPasswordError = null;
    _snackbarError = null;

    // Handle specific Firebase Auth exceptions
    if (exception is AuthException) {
      switch (exception.code) {
        case 'email-already-in-use':
          // Email already exists - show on email field
          emailError = exception.message;
          _snackbarError = exception.message;
          break;
        case 'weak-password':
          // Weak password - show on password field
          passwordError = exception.message;
          _snackbarError = exception.message;
          break;
        case 'invalid-email':
          // Invalid email format - show on email field
          emailError = exception.message;
          _snackbarError = exception.message;
          break;
        case 'operation-not-allowed':
          // Sign-up method not enabled
          _snackbarError = exception.message;
          break;
        case 'too-many-requests':
          // Too many requests
          _snackbarError = exception.message;
          break;
        default:
          // Other auth errors - show as snackbar
          _snackbarError = exception.message;
      }
    } else if (exception is NetworkException) {
      // Network errors - show as snackbar
      _snackbarError = exception.message;
    } else {
      // Unknown errors - show as snackbar
      _snackbarError = exception.message;
    }

    notifyListeners();
  }

  /// Clear snackbar error after it's been displayed
  void clearSnackbarError() {
    _snackbarError = null;
    notifyListeners();
  }

  @override
  void onDispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();

    super.onDispose();
  }
}
