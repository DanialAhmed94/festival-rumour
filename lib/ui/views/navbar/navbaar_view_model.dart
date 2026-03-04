import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/viewmodels/base_view_model.dart';

class NavBaarViewModel extends BaseViewModel {
  int _currentIndex = 0;
  String? _subNavigation; // For handling sub-navigation within tabs
  bool _fromProfileList = false;
  final NavigationService _navigationService = locator<NavigationService>();

  int get currentIndex => _currentIndex;
  String? get subNavigation => _subNavigation;
  bool get fromProfileList => _fromProfileList;

  /// Set when NavBar route is built (from route arguments). When true, back from Discover pops to profile list.
  void setFromProfileList(bool value) {
    if (_fromProfileList == value) return;
    _fromProfileList = value;
    notifyListeners();
  }

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

  /// When opened from profile list (Favourites/Attended), back goes to profile list. Otherwise go to Festival screen.
  void navigateToFestival() {
    if (_fromProfileList) {
      _navigationService.pop();
      return;
    }
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
