import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/api/festival_api_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'festival_model.dart';

const String caAppStoreUrl =
    'https://apps.apple.com/us/app/organiser-toolkit/id6686404949';
const String crapAdviserAppStoreUrl =
    'https://apps.apple.com/us/app/crap-adviser/id6738211790';
const String festieFoodieAppStoreUrl =
    'https://apps.apple.com/us/app/festiefoodie/id6744639737';

class FestivalViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FestivalApiService _festivalApiService = locator<FestivalApiService>();
  final GeocodingService _geocodingService = locator<GeocodingService>();
  final AuthService _authService = locator<AuthService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();

  final List<FestivalModel> festivals = [];
  final List<FestivalModel> allFestivals = []; // Store all festivals
  List<FestivalModel> filteredFestivals = []; // Filtered festivals for search
  int currentPage = 0;
  String searchQuery = ''; // Search query
  String currentFilter = 'live'; // Current filter: live, upcoming, past (default Live)
  late FocusNode searchFocusNode; // Search field focus node
  TextEditingController searchController =
      TextEditingController(); // Search field controller
  String? _userPhotoUrl; // User profile photo URL

  final PageController pageController = PageController(
    viewportFraction: AppDimensions.pageViewportFraction,
  );
  Timer? _autoSlideTimer;

  String? get userPhotoUrl => _userPhotoUrl;

  FestivalViewModel() {
    searchFocusNode = FocusNode();
    // Use cached photo immediately so it doesn't reload when returning from create post etc.
    _userPhotoUrl = _authService.cachedUserPhotoUrl;
    _loadUserPhoto();
  }

  /// Load user profile photo URL and update cache so it's available when returning to this screen.
  Future<void> _loadUserPhoto() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _userPhotoUrl = null;
        _authService.setCachedUserPhotoUrl(null);
        notifyListeners();
        return;
      }

      // Try to get from Firestore first (where uploaded images are stored)
      try {
        final userData = await _firestoreService.getUserData(currentUser.uid);
        if (userData != null &&
            userData['photoUrl'] != null &&
            (userData['photoUrl'] as String).isNotEmpty) {
          _userPhotoUrl = userData['photoUrl'] as String;
          _authService.setCachedUserPhotoUrl(_userPhotoUrl);
          notifyListeners();
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Could not fetch user photo from Firestore: $e');
        }
      }

      // Fallback to Firebase Auth photoURL
      _userPhotoUrl = currentUser.photoURL;
      _authService.setCachedUserPhotoUrl(_userPhotoUrl);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user photo: $e');
      }
      _userPhotoUrl = null;
      _authService.setCachedUserPhotoUrl(null);
      notifyListeners();
    }
  }

  /// Navigate to profile screen
  void navigateToProfile(BuildContext context) {
    _navigationService.navigateTo(AppRoutes.profile);
  }

  /// Navigate to settings screen
  void navigateToSettings(BuildContext context) {
    _navigationService.navigateTo(AppRoutes.settings);
  }

  /// Navigate to create post screen; on success go to Profile (back from Profile → Festival)
  Future<void> navigateToCreatePost(BuildContext context) async {
    final createdPost = await _navigationService.navigateTo<dynamic>(AppRoutes.createPost);
    if (createdPost != null) {
      _navigationService.navigateTo(AppRoutes.profile);
    }
  }

  /// Selected tab index for Live (0), Upcoming (1), Past (2).
  int get selectedFilterTab =>
      currentFilter == 'live' ? 0 : currentFilter == 'upcoming' ? 1 : 2;

  Future<void> loadFestivals() async {
    await handleAsync(
      () async {
        // Fetch festivals from API
        final response = await _festivalApiService.getFestivals();

        if (response.success && response.data != null) {
          // Clear existing festivals
          allFestivals.clear();

          // Convert API response to FestivalModel
          final apiFestivals = response.data!;
          for (var festivalData in apiFestivals) {
            try {
              final festival = FestivalModel.fromApiJson(festivalData);
              allFestivals.add(festival);
            } catch (e, stackTrace) {
              if (kDebugMode) {
                print('Error parsing festival: $e');
                print('Stack trace: $stackTrace');
              }
              // Continue with next festival if one fails to parse
            }
          }

          // Convert coordinates to city and country names
          await _convertCoordinatesToLocation();

          if (kDebugMode) {
            print('Loaded ${allFestivals.length} festivals from API');
          }
        } else {
          // If API call failed, throw exception to trigger error handling
          throw Exception(response.message ?? 'Failed to load festivals');
        }

        // Apply current filter (Live / Upcoming / Past)
        _applyFilter();
      },
      errorMessage: AppStrings.failedToLoadFestivals,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );

    if (festivals.isNotEmpty) {
      final int base =
          (festivals.length * AppDimensions.pageBaseMultiplier) + 1;
      currentPage = base;
      _jumpToInitialWhenReady(base);
      // Auto slide disabled
      // _startAutoSlide();
    }
  }

  Future<void> openAppStoreIOS(String appStoreUrl) async {
    if (!Platform.isIOS) return;

    final uri = Uri.parse(appStoreUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void setPage(int index) {
    currentPage = index;
    notifyListeners();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (festivals.isEmpty || isDisposed) {
      return;
    }

    _autoSlideTimer = Timer.periodic(AppDurations.autoSlideInterval, (_) {
      if (isDisposed ||
          pageController.positions.isEmpty ||
          !pageController.hasClients) {
        _autoSlideTimer?.cancel();
        return;
      }

      try {
        final int nextPage = currentPage + 1;
        pageController.animateToPage(
          nextPage,
          duration: AppDurations.slideAnimationDuration,
          curve: Curves.easeInOut,
        );
        currentPage = nextPage;
        if (!isDisposed) {
          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) print('Error in auto slide: $e');
        _autoSlideTimer?.cancel();
      }
    });
  }

  /// Check if phone number exists in Firestore
  Future<bool> isPhoneMissing() async {
    final user = _authService.currentUser;
    if (user == null) return true;

    final data = await _firestoreService.getUserData(user.uid);
    if (data == null) return true;

    final phone = data["phoneNumber"];
    return phone == null || phone.toString().isEmpty;
  }

  /// Navigate to home and save selected festival to provider
  /// Navigate to home and check if phone number exists
  Future<void> navigateToHome(
    BuildContext context,
    FestivalModel festival,
  ) async {
    // Save selected festival and list
    final festivalProvider = Provider.of<FestivalProvider>(
      context,
      listen: false,
    );
    festivalProvider.setSelectedFestival(festival);
    festivalProvider.setAllFestivals(allFestivals);

    if (kDebugMode) {
      print('🎪 Saved festival to provider: ${festival.title}');
      print('🎪 Saved ${allFestivals.length} festivals to provider');
    }

    // 1️⃣ Check if phone number is missing
    final missing = await isPhoneMissing();

    if (missing) {
      print("📱 Phone missing → redirecting to phone screen");

      // Navigate to Signup Phone screen → NOW FIXED
      _navigationService.navigateTo(AppRoutes.signup, arguments: true);

      return;
    }

    // 2️⃣ Phone exists → proceed normally
    _navigationService.navigateTo(AppRoutes.navbaar);
  }

  void goBack() {
    _navigationService.pop();
  }

  /// Navigate to Global Feed (Home)
  /// Updates FestivalProvider with current allFestivals so edit post / other screens have the list.
  void navigateToGlobalFeed(BuildContext context) {
    if (allFestivals.isNotEmpty) {
      final festivalProvider =
          Provider.of<FestivalProvider>(context, listen: false);
      festivalProvider.setAllFestivals(allFestivals);
      if (kDebugMode) {
        print('🎪 FestivalProvider updated with ${allFestivals.length} festivals (festival chat tap)');
      }
    }
    _navigationService.navigateTo(AppRoutes.home);
  }

  /// Navigate to Chat (chat rooms list)
  void navigateToChat(BuildContext context) {
    _navigationService.navigateTo(AppRoutes.chat);
  }

  void goToNextSlide() {
    if (isDisposed ||
        pageController.positions.isEmpty ||
        !pageController.hasClients)
      return;

    try {
      final int nextPage = currentPage + 1;
      pageController.animateToPage(
        nextPage,
        duration: AppDurations.slideAnimationDuration,
        curve: Curves.easeInOut,
      );
      currentPage = nextPage;
      if (!isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error in goToNextSlide: $e');
    }
  }

  void _jumpToInitialWhenReady(int page) {
    if (isDisposed) return;

    if (pageController.hasClients) {
      try {
        pageController.jumpToPage(page);
      } catch (e) {
        if (kDebugMode) print('Error jumping to page: $e');
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isDisposed) {
          _jumpToInitialWhenReady(page);
        }
      });
    }
  }

  // Search methods
  void setSearchQuery(String query) {
    searchQuery = query;
    _applySearchFilter();
    notifyListeners();
  }

  void clearSearch() {
    searchQuery = '';
    searchController.clear();
    _applySearchFilter();
    notifyListeners();
  }

  void setFilter(BuildContext context, String filter) {
    currentFilter = filter;
    _applyFilter();

    // Reset to first page when tab changes
    if (festivals.isNotEmpty) {
      final int base =
          (festivals.length * AppDimensions.pageBaseMultiplier) + 1;
      currentPage = base;
      _jumpToInitialWhenReady(base);
    } else {
      currentPage = 0;
      if (pageController.hasClients) {
        try {
          pageController.jumpToPage(0);
        } catch (e) {
          if (kDebugMode) print('Error jumping to page: $e');
        }
      }
    }

    notifyListeners();
  }

  void unfocusSearch() {
    if (isDisposed) return;

    try {
      searchFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) print('Error unfocusing search: $e');
    }
  }

  void _applySearchFilter() {
    if (searchQuery.isEmpty) {
      filteredFestivals = List.from(festivals);
    } else {
      filteredFestivals =
          festivals.where((festival) {
            return festival.title.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                festival.location.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                festival.date.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
    }
  }

  void _applyFilter() {
    final now = DateTime.now();

    switch (currentFilter) {
      case 'live':
        festivals.clear();
        festivals.addAll(
          allFestivals.where((festival) => festival.isLive).toList(),
        );
        break;
      case 'upcoming':
        festivals.clear();
        festivals.addAll(
          allFestivals.where((festival) {
            if (festival.startingDate == null) return false;
            try {
              final startDate = DateTime.parse(festival.startingDate!);
              return startDate.isAfter(now) && !festival.isLive;
            } catch (e) {
              return false;
            }
          }).toList(),
        );
        break;
      case 'past':
        festivals.clear();
        festivals.addAll(
          allFestivals.where((festival) {
            if (festival.endingDate == null) return false;
            try {
              final endDate = DateTime.parse(festival.endingDate!);
              return endDate.isBefore(now) && !festival.isLive;
            } catch (e) {
              return false;
            }
          }).toList(),
        );
        break;
      default:
        festivals.clear();
        festivals.addAll(allFestivals);
    }
    _applySearchFilter();
  }

  String get currentSearchQuery => searchQuery;

  /// Convert latitude/longitude to city and country for all festivals
  Future<void> _convertCoordinatesToLocation() async {
    final updatedFestivals = <FestivalModel>[];

    for (var festival in allFestivals) {
      if (festival.latitude != null && festival.longitude != null) {
        try {
          final location = await _geocodingService.getLocationFromCoordinates(
            festival.latitude,
            festival.longitude,
          );

          // Update the location using copyWith
          updatedFestivals.add(festival.copyWith(location: location));
        } catch (e) {
          if (kDebugMode) {
            print(
              'Error converting coordinates for festival ${festival.id}: $e',
            );
          }
          // Keep the original festival if conversion fails
          updatedFestivals.add(festival);
        }
      } else {
        // Keep festivals without coordinates as is
        updatedFestivals.add(festival);
      }
    }

    // Replace all festivals with updated ones
    allFestivals.clear();
    allFestivals.addAll(updatedFestivals);

    // Update filtered festivals if needed
    if (festivals.isNotEmpty) {
      festivals.clear();
      festivals.addAll(allFestivals);
      _applySearchFilter();
    }

    notifyListeners();
  }

  @override
  void onDispose() {
    _autoSlideTimer?.cancel();
    pageController.dispose();
    searchFocusNode.dispose();
    searchController.dispose();
    super.onDispose();
  }
}
