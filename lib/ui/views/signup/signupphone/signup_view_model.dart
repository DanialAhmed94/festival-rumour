import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../../../core/di/locator.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/phone_auth_service.dart';
import '../../../../core/viewmodels/base_view_model.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/exceptions/exception_mapper.dart';

class SignupViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  /// 🔹 Controllers
  final TextEditingController phoneNumberController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  /// 🔹 Country Code Selection
  CountryCode _selectedCountryCode = CountryCode(
    name: 'United Kingdom',
    code: 'GB',
    dialCode: '+44',
  );

  /// 🔹 Validation error
  String? phoneNumberError;

  /// 🔹 Firebase Auth state
  String? _verificationId;
  String? _phoneNumber;

  bool fromFestival = false;

  /// Focus node getter
  FocusNode get phoneFocus => _phoneFocus;

  /// Country code getter
  CountryCode get selectedCountryCode => _selectedCountryCode;

  /// Focus management methods
  void focusPhone() {
    if (isDisposed) return;

    try {
      _phoneFocus.requestFocus();
    } catch (e) {
      if (kDebugMode) print('Error focusing phone field: $e');
    }
  }

  void unfocusPhone() {
    if (isDisposed) return;

    try {
      _phoneFocus.unfocus();
    } catch (e) {
      if (kDebugMode) print('Error unfocusing phone field: $e');
    }
  }

  /// Handle country code selection
  void onCountryChanged(CountryCode countryCode) {
    _selectedCountryCode = countryCode;
    if (kDebugMode) {
      print('Country selected: ${countryCode.name} (${countryCode.dialCode})');
    }
    notifyListeners();
  }

  @override
  void init() {
    super.init();
    // Auto-focus phone field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isDisposed) {
        focusPhone();
      }
    });
  }

  /// 🔹 Validate phone number
  bool validatePhone() {
    final phone = phoneNumberController.text.trim();

    if (phone.isEmpty) {
      phoneNumberError = "*Phone number is required";
    } else if (!RegExp(r'^[0-9]{10,15}$').hasMatch(phone)) {
      phoneNumberError = "Enter a valid phone number";
    } else {
      phoneNumberError = null;
    }

    notifyListeners();
    return phoneNumberError == null;
  }

  /// 🔹 Continue to OTP screen with Firebase Auth
  Future<void> goToOtp() async {
    if (!validatePhone()) return;

    unfocusPhone();
    setLoading(true);
    clearError();

    try {
      String phoneText = phoneNumberController.text.trim();

      if (phoneText.startsWith('+')) phoneText = phoneText.substring(1);

      String countryCode = _selectedCountryCode.dialCode!;
      String phoneNumber;

      if (phoneText.startsWith(countryCode.substring(1))) {
        phoneNumber = '+$phoneText';
      } else if (phoneText.startsWith('0')) {
        phoneNumber = '$countryCode${phoneText.substring(1)}';
      } else {
        phoneNumber = '$countryCode$phoneText';
      }

      _phoneNumber = phoneNumber;

      // Store number but DO NOT navigate yet
      _phoneAuthService.setPhoneData(phoneNumber, "");

      await _authService.signInWithPhone(
        phoneNumber: phoneNumber,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent, // ❗ ONLY this should navigate
        codeAutoRetrievalTimeout: _onCodeAutoRetrievalTimeout,
      );
    } catch (e) {
      setLoading(false);
      setError('Failed to send verification code. Please try again.');
    }
    // Note: Loading is cleared in _onCodeSent or _onVerificationFailed callbacks
  }

  /// 🔹 Firebase Auth callbacks
  /// Note: Auto-verification will be handled in OTP screen
  void _onVerificationCompleted(PhoneAuthCredential credential) async {
    // Don't auto-verify here - let user enter OTP manually
    // This prevents premature Firebase user creation
    if (kDebugMode) {
      print('Auto-verification received, but will be handled in OTP screen');
    }
  }

  void _onVerificationFailed(FirebaseAuthException e) {
    // Use centralized exception handling to map the error
    final exception = ExceptionMapper.mapToAppException(e);

    // Handle specific error codes
    String errorMsg;
    if (exception is AuthException) {
      switch (exception.code) {
        case 'too-many-requests':
        case 'TOO_MANY_REQUESTS':
          errorMsg = 'Too many requests. Please try again later.';
          break;
        case 'invalid-phone-number':
        case 'INVALID_PHONE_NUMBER':
          errorMsg = 'Invalid phone number. Please check and try again.';
          break;
        case 'quota-exceeded':
        case 'QUOTA_EXCEEDED':
          errorMsg = 'SMS quota exceeded. Please try again later.';
          break;
        default:
          errorMsg = exception.message;
      }
    } else if (exception is NetworkException) {
      errorMsg = exception.message;
    } else {
      errorMsg = exception.message;
    }

    // Stop loading and show error
    setLoading(false);
    setError(errorMsg);
  }

  void _onCodeSent(String verificationId, int? resendToken) {
    _verificationId = verificationId;

    if (_phoneNumber != null) {
      _phoneAuthService.setPhoneData(_phoneNumber!, verificationId);
    }

    // Stop loading before navigation
    setLoading(false);

    // 🚀 Only navigate HERE, nowhere else
    _navigationService.navigateTo(AppRoutes.otp, arguments: fromFestival);
  }

  void _onCodeAutoRetrievalTimeout(String verificationId) {
    _verificationId = verificationId;

    // CRITICAL: Also store verification ID from timeout callback
    // This is a fallback in case codeSent callback doesn't fire
    if (_phoneNumber != null) {
      _phoneAuthService.setPhoneData(_phoneNumber!, verificationId);

      if (kDebugMode) {
        print('⏱️ [SIGNUP] Code auto-retrieval timeout');
        print('   Phone Number: $_phoneNumber');
        print('   Verification ID: ${verificationId.substring(0, 20)}...');
        print(
          '   Verification ID stored in PhoneAuthService (from timeout callback)',
        );
      }
    } else {
      if (kDebugMode) {
        print('⚠️ [SIGNUP] Warning: Phone number is null on timeout');
        print('   Verification ID: ${verificationId.substring(0, 20)}...');
        print('   Verification ID NOT stored in PhoneAuthService');
      }
    }
  }

  /// 🔹 Verify OTP code
  Future<bool> verifyOtpCode(String smsCode) async {
    if (_verificationId == null) {
      setError('No verification ID available. Please try again.');
      return false;
    }

    setLoading(true);
    clearError();

    try {
      final result = await _authService.verifyPhoneNumber(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      if (result.isSuccess) {
        _navigationService.navigateTo(AppRoutes.home);
        return true;
      } else {
        setError(result.errorMessage);
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('Error verifying OTP: $e');
      setError('Failed to verify code. Please try again.');
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// 🔹 Get verification ID for OTP screen
  String? get verificationId => _verificationId;

  /// 🔹 Get phone number for OTP screen
  String? get phoneNumber => _phoneNumber;

  @override
  void onDispose() {
    phoneNumberController.dispose();
    _phoneFocus.dispose();
    super.onDispose();
  }
}
