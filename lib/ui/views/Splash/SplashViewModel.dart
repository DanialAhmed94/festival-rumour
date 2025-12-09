import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/router/app_router.dart';

class SplashViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final StorageService _storageService = locator<StorageService>();

  SplashViewModel() {
    _init();
  }

  Future<void> _init() async {
    setLoading(true);
    await Future.delayed(const Duration(seconds: 3));
    
    // Check if user is logged in
    final isLoggedIn = await _storageService.isLoggedIn();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    
    // If user is logged in (both in storage and Firebase), navigate to festivals
    if (isLoggedIn && firebaseUser != null) {
      // Navigate to Festivals screen and clear stack
      await _navigationService.pushNamedAndRemoveUntil(
        AppRoutes.festivals,
        (route) => false,
      );
    } else {
      // If not logged in, navigate to Welcome screen and clear stack
      await _navigationService.pushNamedAndRemoveUntil(
        AppRoutes.welcome,
        (route) => false,
      );
    }
  }
}
