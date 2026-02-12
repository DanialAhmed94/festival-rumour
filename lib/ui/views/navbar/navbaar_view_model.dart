import '../../../core/di/locator.dart';
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

  void goToHome() {
    setIndex(0);
  }

  void goToDiscover() {
    setIndex(1);
  }

  @override
  void init() {
    super.init();
    _currentIndex = 0; // Initialize with first tab selected
  }

  NavigationService get navigationService => _navigationService;
}
