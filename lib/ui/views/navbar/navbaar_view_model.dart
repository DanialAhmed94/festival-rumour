import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/viewmodels/base_view_model.dart';

class NavBaarViewModel extends BaseViewModel {
  int _currentIndex = 0;
  String? _subNavigation; // For handling sub-navigation within tabs
  final NavigationService _navigationService = locator<NavigationService>();

  int get currentIndex => _currentIndex;
  String? get subNavigation => _subNavigation;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    _subNavigation = null; // Clear sub-navigation when switching tabs
    notifyListeners();
  }

  void setSubNavigation(String? subNav) {
    _subNavigation = subNav;
    notifyListeners();
  }

  void goToRumours() {
    setIndex(1); // Rumours is second tab (index 1)
  }

  void goToDiscover() {
    setIndex(0); // Discover is first tab (index 0)
  }

  /// Call before goToDiscover() when RumorsView handles device back, so NavBaar skips navigateToFestival.

  /// Navigate to Festival screen and clear the stack (used when back from Discover).
  void navigateToFestival() {
    _navigationService.pushNamedAndRemoveUntil(
      AppRoutes.festivals,
      (route) => false,
    );
  }

  @override
  void init() {
    super.init();
    _currentIndex = 0; // Start on Discover (first tab)
  }

  NavigationService get navigationService => _navigationService;
}
