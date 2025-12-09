import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/signup_data_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';

class NameViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final SignupDataService _signupDataService = SignupDataService();

  String _firstName = "";
  String get firstName => _firstName;

  String? _nameError;
  String? get nameError => _nameError;

  bool get isNameEntered => _firstName.trim().isNotEmpty;

  bool _showWelcome = false;
  bool get showWelcome => _showWelcome;

  // Focus management
  final FocusNode _nameFocus = FocusNode();
  FocusNode get nameFocus => _nameFocus;

  /// Focus management methods
  void focusName() {
    if (isDisposed) return;
    
    try {
      _nameFocus.requestFocus();
    } catch (e) {
      if (kDebugMode) print('Error focusing name field: $e');
    }
  }

  void unfocusName() {
    if (isDisposed) return;
    
    try {
      _nameFocus.unfocus();
    } catch (e) {
      if (kDebugMode) print('Error unfocusing name field: $e');
    }
  }

  @override
  void init() {
    super.init();
    // Auto-focus name field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isDisposed) {
        focusName();
      }
    });
  }

  /// ✅ Validate name on change
  void onNameChanged(String value) {
    _firstName = value;
    if (_firstName.trim().isEmpty) {
      _nameError = AppStrings.nameEmptyError;
    } else if (_firstName.trim().length < 4) {
      _nameError = AppStrings.nameTooShortError;
    } else if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(_firstName)) {
      _nameError = AppStrings.nameInvalidError;
    } else {
      _nameError = null;
    }
    notifyListeners();
  }

  Future<void> onNextPressed() async {
    if (_nameError != null || _firstName.trim().isEmpty) return;

    // Dismiss keyboard when next is pressed
    unfocusName();

    await handleAsync(() async {
      // Store name in signup data service (don't create Firebase user yet)
      _signupDataService.setDisplayName(_firstName.trim());
      
      if (kDebugMode) {
        print('👤 [SIGNUP] Name screen completed');
        print('   Current Route: ${AppRoutes.name}');
        print('   Display Name: ${_firstName.trim()}');
        print('   Next Route: ${AppRoutes.uploadphotos}');
      }
      
      await Future.delayed(AppDurations.buttonLoadingDuration);
      
      // Show welcome dialog - navigation will happen from dialog
      _showWelcome = true;
      notifyListeners();
    }, errorMessage: AppStrings.saveNameError);
  }

  void onEditName() {
    _showWelcome = false;
    notifyListeners();
  }

  Future<void> continueToNext() async {
    await handleAsync(() async {
      if (kDebugMode) {
        print('👤 [SIGNUP] Name screen - continuing to next');
        print('   Current Route: ${AppRoutes.name}');
        print('   Navigating to: ${AppRoutes.photoUpload}');
      }
      
      // Navigate to profile image upload screen
      _navigationService.navigateTo(AppRoutes.photoUpload);
    }, errorMessage: AppStrings.continueError);
  }

  void goBack() {
    _navigationService.pop();
  }

  @override
  void onDispose() {
    _nameFocus.dispose();
    super.onDispose();
  }
}
