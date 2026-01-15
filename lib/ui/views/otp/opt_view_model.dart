import 'package:festival_rumour/core/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/phone_auth_service.dart';
import '../../../core/services/signup_data_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/exceptions/exception_mapper.dart';

/// Error type for better error categorization and handling
enum OtpErrorType {
  none,
  invalidCode,
  expiredSession,
  networkError,
  tooManyAttempts,
  missingData,
  unknown,
}

/// Error information with type and recovery suggestions
class OtpErrorInfo {
  final OtpErrorType type;
  final String message;
  final String? recoverySuggestion;
  final bool canRetry;
  final bool requiresResend;

  const OtpErrorInfo({
    required this.type,
    required this.message,
    this.recoverySuggestion,
    this.canRetry = false,
    this.requiresResend = false,
  });
}

class OtpViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final PhoneAuthService _phoneAuthService = PhoneAuthService();
  final SignupDataService _signupDataService = SignupDataService();

  String _otpCode = "";
  String? _errorText;
  OtpErrorInfo? _errorInfo;
  bool _isLoading = false;
  bool _isResending = false;
  final FocusNode _otpFocus = FocusNode();
  bool _isFocusChanging = false;
  bool _isOtpVerified = false;
  bool _isInitialized = false; // Guard to prevent multiple initializations

  // Retry mechanism
  int _verificationAttempts = 0;
  static const int _maxVerificationAttempts = 5;
  DateTime? _lastVerificationAttempt;
  DateTime? _lastResendAttempt;
  static const Duration _resendCooldown = Duration(seconds: 60);

  bool fromFestival = false;

  // Phone verification state
  String? _phoneNumber;
  String? _verificationId;

  String get otpCode => _otpCode;
  String? get errorText => _errorText;
  OtpErrorInfo? get errorInfo => _errorInfo;
  bool get isLoading => _isLoading || busy;
  bool get isResending => _isResending;
  FocusNode get otpFocus => _otpFocus;
  String? get phoneNumber => _phoneNumber;
  bool get isOtpVerified => _isOtpVerified;
  bool get canResend =>
      _lastResendAttempt == null ||
      DateTime.now().difference(_lastResendAttempt!) >= _resendCooldown;
  int get remainingAttempts => _maxVerificationAttempts - _verificationAttempts;
  bool get hasRemainingAttempts =>
      _verificationAttempts < _maxVerificationAttempts;

  String get formattedPhoneNumber {
    if (_phoneNumber == null) return '+1234567890';
    return _phoneNumber!;
  }

  String get displayPhoneNumber {
    if (_phoneNumber == null) return '+1234567890';
    return _phoneNumber!;
  }

  bool get isOtpValid => _otpCode.length == 6;
  bool get canVerify => isOtpValid && !isLoading && hasRemainingAttempts;

  /// Clear error text and info
  void clearErrorText() {
    _errorText = null;
    _errorInfo = null;
    notifyListeners();
  }

  /// Auto-focus OTP field when screen loads
  void focusOtpField() {
    if (isDisposed || _isFocusChanging || _otpFocus.hasFocus) return;

    try {
      _isFocusChanging = true;
      _otpFocus.requestFocus();
      Future.delayed(AppDurations.shortDelay, () {
        if (!isDisposed) {
          _isFocusChanging = false;
        }
      });
    } catch (e) {
      if (kDebugMode) print('Error focusing OTP field: $e');
      _isFocusChanging = false;
    }
  }

  /// Unfocus OTP field
  void unfocusOtpField() {
    if (isDisposed || _isFocusChanging || !_otpFocus.hasFocus) return;

    try {
      _isFocusChanging = true;
      _otpFocus.unfocus();
      Future.delayed(AppDurations.shortDelay, () {
        if (!isDisposed) {
          _isFocusChanging = false;
        }
      });
    } catch (e) {
      if (kDebugMode) print('Error unfocusing OTP field: $e');
      _isFocusChanging = false;
    }
  }

  @override
  void init() {
    super.init();

    // Prevent multiple initializations
    if (_isInitialized && !isDisposed) {
      if (kDebugMode) {
        print('⚠️ [OTP] init() called multiple times, resetting state');
      }
      _resetState();
      return;
    }

    _isInitialized = true;

    // Reset state when screen is revisited
    _resetState();

    _initializePhoneNumber();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isDisposed) {
        // Only focus if we have valid verification data
        if (_verificationId != null &&
            _verificationId!.isNotEmpty &&
            !_otpFocus.hasFocus) {
          focusOtpField();
        }

        // Re-check phone data after a delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!isDisposed) {
            _initializePhoneNumber();
            notifyListeners();
          }
        });
      }
    });
  }

  /// Reset all state when screen is revisited
  void _resetState() {
    _otpCode = "";
    _errorText = null;
    _errorInfo = null;
    _isLoading = false;
    _isResending = false;
    _isOtpVerified = false;
    _verificationAttempts = 0;
    _lastVerificationAttempt = null;
    // Don't reset _lastResendAttempt to maintain cooldown
    // Don't reset _phoneNumber and _verificationId - they should be retrieved from service
    clearErrorSilently(); // Use silent clear to avoid triggering listeners during init
  }

  void _initializePhoneNumber() {
    try {
      _phoneNumber = _phoneAuthService.phoneNumber;
      _verificationId = _phoneAuthService.verificationId;

      if (kDebugMode) {
        print('=== OTP View Phone Data ===');
        print('Phone number retrieved: $_phoneNumber');
        print(
          'Verification ID retrieved: ${_verificationId != null ? "${_verificationId!.substring(0, 20)}..." : "NULL"}',
        );
        print('==========================');
      }

      // Check if verification data is missing when returning to screen
      if (_verificationId == null || _verificationId!.isEmpty) {
        if (_phoneNumber != null) {
          // Phone number exists but verification ID is missing - session expired
          if (kDebugMode) {
            print(
              '⚠️ [OTP] Verification ID is missing - session may have expired',
            );
          }
          _setError(
            const OtpErrorInfo(
              type: OtpErrorType.expiredSession,
              message: 'Verification session expired.',
              recoverySuggestion: 'Please request a new verification code.',
              requiresResend: true,
              canRetry: false,
            ),
          );
        } else {
          // Both phone number and verification ID are missing
          if (kDebugMode) {
            print('⚠️ [OTP] Both phone number and verification ID are missing');
          }
          _setError(
            const OtpErrorInfo(
              type: OtpErrorType.missingData,
              message: 'Verification data not available.',
              recoverySuggestion:
                  'Please go back and request a new verification code.',
              requiresResend: true,
              canRetry: false,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error getting phone number: $e');
      _setError(
        OtpErrorInfo(
          type: OtpErrorType.unknown,
          message: 'Failed to load verification data. Please try again.',
          canRetry: false,
          requiresResend: true,
        ),
      );
    }
  }

  /// Called when OTP input changes
  void onCodeChanged(String value) {
    _otpCode = value;
    // Clear errors when user starts typing
    if (_errorText != null) {
      clearErrorText();
    }
    notifyListeners();
  }

  /// Set error with type and recovery information
  void _setError(OtpErrorInfo errorInfo) {
    clearError();
    _errorText = errorInfo.message;
    _errorInfo = errorInfo;
    notifyListeners();
  }

  /// Verify phone OTP with comprehensive error handling
  Future<void> verifyCode() async {
    if (!isOtpValid) {
      _setError(
        const OtpErrorInfo(
          type: OtpErrorType.invalidCode,
          message: 'Please enter a complete 6-digit code.',
          canRetry: true,
        ),
      );
      return;
    }

    if (!hasRemainingAttempts) {
      _setError(
        const OtpErrorInfo(
          type: OtpErrorType.tooManyAttempts,
          message: 'Too many verification attempts. Please request a new code.',
          recoverySuggestion:
              'Tap "Resend Code" to get a new verification code.',
          requiresResend: true,
        ),
      );
      return;
    }

    // Track verification attempt
    _verificationAttempts++;
    _lastVerificationAttempt = DateTime.now();

    bool verificationSuccessful = false;

    await handleAsync(
      () async {
        _verificationId = _phoneAuthService.verificationId;
        _phoneNumber = _phoneAuthService.phoneNumber;

        if (kDebugMode) {
          print(
            '🔍 [SIGNUP] Verifying OTP (Attempt $_verificationAttempts/$_maxVerificationAttempts)',
          );
          print(
            '   Verification ID: ${_verificationId != null ? "${_verificationId!.substring(0, 20)}..." : "NULL"}',
          );
          print('   Phone Number: $_phoneNumber');
        }

        if (_verificationId == null ||
            _phoneNumber == null ||
            _verificationId!.isEmpty) {
          throw ValidationException(
            message: 'No verification data available.',
            code: 'MISSING_VERIFICATION_DATA',
          );
        }

        final result = await _authService.verifyPhoneNumber(
          verificationId: _verificationId!,
          smsCode: _otpCode,
        );

        if (!result.isSuccess) {
          throw AuthException(
            message: result.errorMessage ?? AppStrings.otpVerificationError,
            code: 'OTP_VERIFICATION_FAILED',
          );
        }

        verificationSuccessful = true;

        if (kDebugMode) {
          print('✅ [SIGNUP] OTP verification SUCCESSFUL');
        }

        _signupDataService.setPhoneNumber(_phoneNumber!);

        // try {
        //   await _authService.signOut();
        // } catch (e) {
        //   if (kDebugMode) {
        //     print('Warning: Could not sign out temporary user: $e');
        //   }
        // }

        clearErrorText();
        _isOtpVerified = true;
        _verificationAttempts = 0; // Reset on success
        notifyListeners();
      },
      onException: (exception) {
        _isOtpVerified = false;
        verificationSuccessful = false;
        _handleOtpException(exception);
      },
      onError: (errorMessage) {
        _isOtpVerified = false;
        verificationSuccessful = false;
        clearError();
        _setError(
          OtpErrorInfo(
            type: OtpErrorType.unknown,
            message: errorMessage,
            canRetry: hasRemainingAttempts,
            recoverySuggestion:
                hasRemainingAttempts
                    ? 'Please check your code and try again.'
                    : 'Please request a new code.',
          ),
        );
      },
      minimumLoadingDuration: AppDurations.otpVerificationDuration,
    );
    if (verificationSuccessful && _isOtpVerified) {
      if (kDebugMode) {
        print('🚀 [SIGNUP] Navigating to interest/festival screen');
      }

      print("fromFestival${fromFestival}");

      if (fromFestival) {
        final StorageService storageService = locator<StorageService>();

        final uid = await storageService.getUserId(); // <-- FIXED
        print("🔥 Current UID: $uid");

        if (uid != null && _phoneNumber != null) {
          await _authService.savePhoneToFirestore(uid, _phoneNumber!);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigationService.navigateTo(AppRoutes.festivals);
        });

        return;
      }

      // Normal signup → interest
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigationService.navigateTo(AppRoutes.interest);
      });
    }
  }

  /// Resend phone OTP with cooldown and error handling
  Future<void> resendCode() async {
    if (!canResend) {
      final remainingSeconds =
          _resendCooldown.inSeconds -
          DateTime.now().difference(_lastResendAttempt!).inSeconds;
      _setError(
        OtpErrorInfo(
          type: OtpErrorType.tooManyAttempts,
          message:
              'Please wait ${remainingSeconds}s before requesting a new code.',
          canRetry: false,
        ),
      );
      return;
    }

    _isResending = true;
    _verificationAttempts = 0; // Reset attempts on resend
    clearErrorText();
    notifyListeners();

    await handleAsync(
      () async {
        _phoneNumber = _phoneAuthService.phoneNumber;

        if (_phoneNumber == null) {
          throw ValidationException(
            message: 'No phone number available. Please start over.',
            code: 'MISSING_PHONE_NUMBER',
          );
        }

        final result = await _authService.signInWithPhone(
          phoneNumber: _phoneNumber!,
          verificationCompleted: (credential) {
            if (kDebugMode) print('Auto-verification completed');
          },
          verificationFailed: (e) {
            final exception = ExceptionMapper.mapToAppException(e);
            _handleOtpException(exception);
          },
          codeSent: (verificationId, resendToken) {
            _verificationId = verificationId;
            _phoneAuthService.setPhoneData(_phoneNumber!, verificationId);
            _lastResendAttempt = DateTime.now();
            _otpCode = ''; // Clear OTP code for new entry
            if (kDebugMode) {
              print('✅ [SIGNUP] Verification code resent');
            }
          },
          codeAutoRetrievalTimeout: (verificationId) {
            _verificationId = verificationId;
            if (_phoneNumber != null) {
              _phoneAuthService.setPhoneData(_phoneNumber!, verificationId);
              _lastResendAttempt = DateTime.now();
            }
          },
        );

        if (!result.isSuccess) {
          throw AuthException(
            message: result.errorMessage ?? AppStrings.resendCodeError,
            code: 'RESEND_CODE_FAILED',
          );
        }

        clearErrorText();
      },
      onException: (exception) {
        _handleOtpException(exception);
      },
      onError: (errorMessage) {
        clearError();
        _setError(
          OtpErrorInfo(
            type: OtpErrorType.unknown,
            message: errorMessage,
            canRetry: true,
            recoverySuggestion: 'Please try again in a moment.',
          ),
        );
      },
      minimumLoadingDuration: AppDurations.buttonLoadingDuration,
    );

    _isResending = false;
    notifyListeners();
  }

  /// Handle OTP exceptions with comprehensive error categorization
  void _handleOtpException(AppException exception) {
    clearError();
    _errorText = null;

    if (exception is AuthException) {
      final errorMessage = exception.message.toLowerCase();

      if (errorMessage.contains('blocked') ||
          errorMessage.contains('unusual activity') ||
          errorMessage.contains('too many requests')) {
        _setError(
          const OtpErrorInfo(
            type: OtpErrorType.tooManyAttempts,
            message: 'Too many requests. Please try again later.',
            recoverySuggestion: 'Wait a few minutes before trying again.',
            canRetry: false,
          ),
        );
      } else if (errorMessage.contains('expired') ||
          errorMessage.contains('session-expired') ||
          exception.code == 'session-expired' ||
          exception.code == 'SESSION_EXPIRED') {
        _verificationId = null;
        _phoneAuthService.clearPhoneData();
        _otpCode = '';
        _verificationAttempts = 0;

        _setError(
          const OtpErrorInfo(
            type: OtpErrorType.expiredSession,
            message: 'Verification session expired.',
            recoverySuggestion: 'Please request a new verification code.',
            requiresResend: true,
            canRetry: false,
          ),
        );
      } else if (errorMessage.contains('invalid') ||
          exception.code == 'invalid-verification-code' ||
          exception.code == 'INVALID_VERIFICATION_CODE') {
        _setError(
          OtpErrorInfo(
            type: OtpErrorType.invalidCode,
            message: 'Invalid verification code. Please check and try again.',
            recoverySuggestion:
                hasRemainingAttempts
                    ? 'You have ${remainingAttempts} attempt${remainingAttempts > 1 ? 's' : ''} remaining.'
                    : 'Please request a new code.',
            canRetry: hasRemainingAttempts,
            requiresResend: !hasRemainingAttempts,
          ),
        );
      } else {
        _setError(
          OtpErrorInfo(
            type: OtpErrorType.unknown,
            message: exception.message,
            canRetry: hasRemainingAttempts,
          ),
        );
      }
    } else if (exception is NetworkException) {
      _setError(
        OtpErrorInfo(
          type: OtpErrorType.networkError,
          message: 'Network error. Please check your connection.',
          recoverySuggestion:
              'Ensure you have a stable internet connection and try again.',
          canRetry: true,
        ),
      );
    } else if (exception is ValidationException) {
      if (exception.code == 'MISSING_VERIFICATION_DATA') {
        _setError(
          const OtpErrorInfo(
            type: OtpErrorType.missingData,
            message: 'Verification data not available.',
            recoverySuggestion: 'Please request a new verification code.',
            requiresResend: true,
            canRetry: false,
          ),
        );
      } else {
        _setError(
          OtpErrorInfo(
            type: OtpErrorType.unknown,
            message: exception.message,
            canRetry: true,
          ),
        );
      }
    } else {
      _setError(
        OtpErrorInfo(
          type: OtpErrorType.unknown,
          message: exception.message,
          canRetry: hasRemainingAttempts,
        ),
      );
    }

    notifyListeners();
  }

  @override
  void onDispose() {
    _isInitialized = false; // Reset initialization flag
    _otpFocus.dispose();
    super.onDispose();
  }
}
