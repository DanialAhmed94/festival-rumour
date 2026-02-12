import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/router/app_router.dart';

const Duration _kSplashDuration = Duration(seconds: 3);

class SplashViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final StorageService _storageService = locator<StorageService>();

  SplashViewModel() {
    _init();
  }

  Future<void> _init() async {
    setLoading(true);
    await Future.delayed(_kSplashDuration);

    final isLoggedIn = await _storageService.isLoggedIn();
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (isLoggedIn && firebaseUser != null) {
      _navigationService.pushReplacementNamed(AppRoutes.festivals);
    } else {
      _navigationService.pushReplacementNamed(AppRoutes.welcome);
    }
  }
}
