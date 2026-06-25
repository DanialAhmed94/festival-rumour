import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/api/festival_api_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_photo_cache_service.dart';
import '../../../util/firebase_notification_service.dart';
import 'festival_model.dart';

/// Festival Organiser — App Store
const String caAppStoreUrl =
    'https://apps.apple.com/us/app/festival-organiser/id6686404949';

/// Festival Toilet App — App Store
const String crapAdviserAppStoreUrl =
    'https://apps.apple.com/us/app/festival-toilet-app/id6738211790';

/// Festival Foodie — App Store
const String festieFoodieAppStoreUrl =
    'https://apps.apple.com/us/app/festival-foodie/id6744639737';

/// Play Store (Android) — same three apps as above
const String crapAdviserPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.crapadviser.user';
const String festivalOrganiserPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.crapadviser.orgnaizer';
const String festieFoodiePlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.festiefoodie.app';

class FestivalViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FestivalApiService _festivalApiService = locator<FestivalApiService>();
  final GeocodingService _geocodingService = locator<GeocodingService>();
  final AuthService _authService = locator<AuthService>();

  final List<FestivalModel> festivals = [];
  final List<FestivalModel> allFestivals = []; // Store all festivals
  final List<FestivalModel> _searchResults = []; // API search results
  int currentPage = 0;
  String searchQuery = ''; // Search query
  bool _isSearching = false;
  Timer? _searchDebounce;
  String? _searchError;

  bool _navbarGateBusy = false;

  /// When search is active, returns API search results; otherwise festivals (for slider).
  List<FestivalModel> get filteredFestivals =>
      searchQuery.isNotEmpty ? _searchResults : festivals;

  bool get isSearching => _isSearching;

  /// User-facing error message when search API fails (e.g. no connection). Null when no error.
  String? get searchError => _searchError;

  bool get navbarGateBusy => _navbarGateBusy;

  String currentFilter =
      'live'; // Current filter: live, upcoming, past (default Live)
  late FocusNode searchFocusNode; // Search field focus node
  TextEditingController searchController =
      TextEditingController(); // Search field controller
  String? _userPhotoUrl; // User profile photo URL

  final PageController pageController = PageController(
    viewportFraction: AppDimensions.pageViewportFraction,
  );
  Timer? _autoSlideTimer;

  String? get userPhotoUrl => _userPhotoUrl;

  final UserPhotoCacheService _profileCacheService =
      locator<UserPhotoCacheService>();

  FestivalViewModel() {
    searchFocusNode = FocusNode();
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _userPhotoUrl =
          _profileCacheService.getCachedPhotoUrl(uid) ??
          _authService.cachedUserPhotoUrl;
    }
    _loadUserPhoto();
    _requestNotificationPermission();
    _profileCacheService.addListener(_onProfileCacheUpdated);
  }

  /// Request notification permission once when user lands on festival screen (no prompt on splash).
  void _requestNotificationPermission() {
    FirebaseNotificationService.requestPermissionIfNeeded();
  }

  void _onProfileCacheUpdated() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final cachedPhoto = _profileCacheService.getCachedPhotoUrl(uid);
    if (cachedPhoto != null &&
        cachedPhoto.isNotEmpty &&
        _userPhotoUrl != cachedPhoto) {
      _userPhotoUrl = cachedPhoto;
      _authService.setCachedUserPhotoUrl(_userPhotoUrl);
      notifyListeners();
    }
  }

  /// Load user profile photo URL via the shared profile cache (Firestore-backed).
  Future<void> _loadUserPhoto() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _userPhotoUrl = null;
        notifyListeners();
        return;
      }

      final cachedPhoto = await _profileCacheService.getPhotoUrl(
        currentUser.uid,
      );
      _userPhotoUrl = cachedPhoto ?? currentUser.photoURL;
      _authService.setCachedUserPhotoUrl(_userPhotoUrl);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user photo: $e');
      }
      _userPhotoUrl = null;
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
    final createdPost = await _navigationService.navigateTo<dynamic>(
      AppRoutes.createPost,
    );
    if (createdPost != null) {
      _navigationService.navigateTo(AppRoutes.profile);
    }
  }

  /// Selected tab index for Live (0), Upcoming (1), Past (2).
  int get selectedFilterTab =>
      currentFilter == 'live'
          ? 0
          : currentFilter == 'upcoming'
          ? 1
          : 2;

  Future<void> loadFestivals() async {
    if (kDebugMode) {
      print('🎪 [FestivalViewModel] loadFestivals() started');
    }
    await handleAsync(
      () async {
        // Fetch festivals from API
        final response = await _festivalApiService.getFestivals();

        if (kDebugMode) {
          print(
            '🎪 [FestivalViewModel] API response: success=${response.success}, data is null=${response.data == null}, data length=${response.data?.length ?? 0}',
          );
        }

        if (response.success && response.data != null) {
          // Clear existing festivals
          allFestivals.clear();
          festivals.clear();

          // Convert API response to FestivalModel
          final apiFestivals = response.data!;
          for (var festivalData in apiFestivals) {
            try {
              final festival = FestivalModel.fromApiJson(festivalData);
              allFestivals.add(festival);
            } catch (e, stackTrace) {
              if (kDebugMode) {
                print('🎪 [FestivalViewModel] Error parsing festival: $e');
                print('Stack trace: $stackTrace');
              }
              // Continue with next festival if one fails to parse
            }
          }

          if (kDebugMode) {
            print(
              '🎪 [FestivalViewModel] After parse: allFestivals.length=${allFestivals.length}',
            );
          }

          // Convert coordinates to city and country names
          await _convertCoordinatesToLocation();

          if (kDebugMode) {
            print(
              '🎪 [FestivalViewModel] After _convertCoordinatesToLocation: allFestivals.length=${allFestivals.length}',
            );
          }

          // Apply current filter (Live / Upcoming / Past)
          _applyFilter();

          if (kDebugMode) {
            print(
              '🎪 [FestivalViewModel] After _applyFilter: currentFilter=$currentFilter, festivals.length=${festivals.length}, allFestivals.length=${allFestivals.length}',
            );
          }

          // Propagate to the locator singleton so any screen (profile, edit post, etc.)
          // can access the festival list without needing a BuildContext or waiting for
          // the user to explicitly navigate through the festival-selection flow.
          locator<FestivalProvider>().setAllFestivals(allFestivals);
        } else {
          if (kDebugMode) {
            print('🎪 [FestivalViewModel] API failed or no data: throwing');
          }
          // If API call failed, throw exception to trigger error handling
          throw Exception(response.message ?? 'Failed to load festivals');
        }
      },
      errorMessage: AppStrings.failedToLoadFestivals,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );

    if (kDebugMode) {
      print(
        '🎪 [FestivalViewModel] loadFestivals() finished: isLoading=$isLoading, festivals.length=${festivals.length}, allFestivals.length=${allFestivals.length}',
      );
    }

    if (festivals.isNotEmpty) {
      final int base =
          (festivals.length * AppDimensions.pageBaseMultiplier) + 1;
      currentPage = base;
      _jumpToInitialWhenReady(base);
      // Auto slide disabled
      // _startAutoSlide();
    }
  }

  /// Partner suite icons — opens the native store where possible with fallbacks and user feedback.
  Future<void> openPartnerAppStore(
    BuildContext context, {
    required String iosAppStoreUrl,
    required String androidPlayStoreUrl,
  }) async {
    void informUser(String message) {
      if (!context.mounted) return;
      SnackbarUtil.showErrorSnackBar(context, message);
    }

    final String urlString = _resolvePartnerListingUrl(
      iosAppStoreUrl: iosAppStoreUrl,
      androidPlayStoreUrl: androidPlayStoreUrl,
    );

    final Uri? uri = Uri.tryParse(urlString.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      informUser(AppStrings.storeLinkInvalid);
      return;
    }

    try {
      final launched = await _launchPartnerStoreListing(uri);
      if (!launched) {
        if (context.mounted) {
          informUser(AppStrings.couldNotOpenStoreListing);
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('openPartnerAppStore failed: $e\n$st');
      }
      if (context.mounted) {
        informUser(AppStrings.couldNotOpenStoreListing);
      }
    }
  }

  String _resolvePartnerListingUrl({
    required String iosAppStoreUrl,
    required String androidPlayStoreUrl,
  }) {
    if (Platform.isIOS) return iosAppStoreUrl;
    if (Platform.isAndroid) return androidPlayStoreUrl;
    // Desktop (macOS / Windows / Linux) — Play listing opens in default browser reliably.
    if (Platform.isMacOS) return iosAppStoreUrl;
    return androidPlayStoreUrl;
  }

  Future<bool> _launchPartnerStoreListing(Uri uri) async {
    Future<bool> tryLaunch(Uri target, LaunchMode mode) async {
      try {
        return await launchUrl(target, mode: mode);
      } catch (_) {
        return false;
      }
    }

    final List<Uri> candidates = [..._partnerStoreFallbackUris(uri)];

    for (final target in candidates) {
      if (await tryLaunch(target, LaunchMode.externalApplication)) return true;
    }

    for (final target in candidates) {
      if (await tryLaunch(target, LaunchMode.platformDefault)) return true;
    }

    return false;
  }

  List<Uri> _partnerStoreFallbackUris(Uri primary) {
    final List<Uri> out = [primary];
    if (Platform.isAndroid) {
      final market = _marketUriFromPlayStoreHttps(primary);
      if (market != null) out.add(market);
    }
    if (Platform.isIOS) {
      final itms = _itmsAppsUriFromAppleStoreHttps(primary);
      if (itms != null) out.add(itms);
    }
    return out;
  }

  Uri? _marketUriFromPlayStoreHttps(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'play.google.com' && !host.endsWith('.play.google.com')) {
      return null;
    }
    final id = uri.queryParameters['id'];
    if (id == null || id.isEmpty) return null;
    return Uri.parse('market://details?id=$id');
  }

  /// Prefer native Store app (`itms-apps://`) when the https page handler fails on iOS.
  Uri? _itmsAppsUriFromAppleStoreHttps(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!host.contains('apps.apple.com')) return null;
    final match =
        RegExp(r'/id(\d{6,})').firstMatch('${uri.path} ${uri.fragment}');
    final id = match?.group(1);
    if (id == null) return null;
    return Uri.parse('itms-apps://apps.apple.com/app/id$id');
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

  /// Navigate to home and save selected festival to provider
  Future<void> navigateToHome(
    BuildContext context,
    FestivalModel festival,
  ) async {
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

    // Tapping a festival always opens its detail/home (Location & map, Stage
    // Times, Inner Map, Chat Rooms). This is NOT gated by phone verification.
    _navigationService.navigateTo(AppRoutes.navbaar);
  }

  void goBack() {
    _navigationService.pop();
  }

  /// Navigate to Global Feed (Home)
  /// Updates FestivalProvider with current allFestivals so edit post / other screens have the list.
  void navigateToGlobalFeed(BuildContext context) {
    if (allFestivals.isNotEmpty) {
      final festivalProvider = Provider.of<FestivalProvider>(
        context,
        listen: false,
      );
      festivalProvider.setAllFestivals(allFestivals);
      if (kDebugMode) {
        print(
          '🎪 FestivalProvider updated with ${allFestivals.length} festivals (festival chat tap)',
        );
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

  // Search methods (API-based, debounced)
  void setSearchQuery(String query) {
    searchQuery = query;
    if (query.isEmpty) {
      _searchResults.clear();
      _isSearching = false;
      _searchError = null;
      _searchDebounce?.cancel();
      _searchDebounce = null;
      notifyListeners();
      return;
    }
    _searchError = null;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
    notifyListeners();
  }

  void clearSearch() {
    searchQuery = '';
    searchController.clear();
    _searchResults.clear();
    _isSearching = false;
    _searchError = null;
    _searchDebounce?.cancel();
    _searchDebounce = null;
    notifyListeners();
  }

  Future<void> _performSearch(String query) async {
    if (query != searchQuery || isDisposed) return;
    _isSearching = true;
    _searchError = null;
    notifyListeners();
    try {
      final response = await _festivalApiService.getFestivals(search: query);
      if (query != searchQuery || isDisposed) return;
      if (response.success && response.data != null) {
        final parsed = <FestivalModel>[];
        for (var festivalData in response.data!) {
          try {
            parsed.add(FestivalModel.fromApiJson(festivalData));
          } catch (e) {
            if (kDebugMode) {
              print('🎪 [FestivalViewModel] Error parsing search festival: $e');
            }
          }
        }
        final withLocation = await _convertCoordinatesForFestivalList(parsed);
        if (query != searchQuery || isDisposed) return;
        _searchResults
          ..clear()
          ..addAll(withLocation);
        _searchError = null;
      } else {
        _searchResults.clear();
        if (query == searchQuery && !isDisposed) {
          _searchError =
              response.message ?? 'Something went wrong. Please try again.';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎪 [FestivalViewModel] Search API error: $e');
      }
      if (!isDisposed && query == searchQuery) {
        _searchResults.clear();
        _searchError =
            e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Something went wrong. Please check your connection and try again.';
      }
    } finally {
      if (!isDisposed) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Retry last search (e.g. after connection restored). No-op if searchQuery is empty.
  void retrySearch() {
    if (searchQuery.isEmpty) return;
    _searchError = null;
    _performSearch(searchQuery);
  }

  Future<List<FestivalModel>> _convertCoordinatesForFestivalList(
    List<FestivalModel> list,
  ) async {
    final updated = <FestivalModel>[];
    for (var festival in list) {
      if (festival.latitude != null && festival.longitude != null) {
        try {
          final location = await _geocodingService.getLocationFromCoordinates(
            festival.latitude,
            festival.longitude,
          );
          updated.add(festival.copyWith(location: location));
        } catch (e) {
          if (kDebugMode) {
            print(
              'Error converting coordinates for festival ${festival.id}: $e',
            );
          }
          updated.add(festival);
        }
      } else {
        updated.add(festival);
      }
    }
    return updated;
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

  void _applyFilter() {
    final now = DateTime.now();
    if (kDebugMode) {
      print(
        '🎪 [FestivalViewModel] _applyFilter: currentFilter=$currentFilter, allFestivals.length=${allFestivals.length}, now=$now',
      );
    }

    switch (currentFilter) {
      case 'live':
        festivals.clear();
        final liveList =
            allFestivals.where((festival) => festival.isLive).toList();
        festivals.addAll(liveList);
        if (kDebugMode) {
          print(
            '🎪 [FestivalViewModel] live filter: ${liveList.length} festivals are live',
          );
        }
        break;
      case 'upcoming':
        festivals.clear();
        final upcomingList =
            allFestivals.where((festival) {
              if (festival.startingDate == null) return false;
              try {
                final startDate = DateTime.parse(festival.startingDate!);
                return startDate.isAfter(now) && !festival.isLive;
              } catch (e) {
                return false;
              }
            }).toList();
        festivals.addAll(upcomingList);
        if (kDebugMode) {
          print(
            '🎪 [FestivalViewModel] upcoming filter: ${upcomingList.length} festivals',
          );
        }
        break;
      case 'past':
        festivals.clear();
        final pastList =
            allFestivals.where((festival) {
              if (festival.endingDate == null) return false;
              try {
                final endDate = DateTime.parse(festival.endingDate!);
                return endDate.isBefore(now) && !festival.isLive;
              } catch (e) {
                return false;
              }
            }).toList();
        festivals.addAll(pastList);
        if (kDebugMode) {
          print(
            '🎪 [FestivalViewModel] past filter: ${pastList.length} festivals',
          );
        }
        break;
      default:
        festivals.clear();
        festivals.addAll(allFestivals);
        if (kDebugMode) {
          print(
            '🎪 [FestivalViewModel] default: showing all ${allFestivals.length} festivals',
          );
        }
    }

    if (kDebugMode) {
      print(
        '🎪 [FestivalViewModel] _applyFilter done: festivals.length=${festivals.length}',
      );
    }
  }

  String get currentSearchQuery => searchQuery;

  /// Convert latitude/longitude to city and country for all festivals
  Future<void> _convertCoordinatesToLocation() async {
    if (kDebugMode) {
      print(
        '🎪 [FestivalViewModel] _convertCoordinatesToLocation: starting with ${allFestivals.length} festivals',
      );
    }
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

    if (kDebugMode) {
      print(
        '🎪 [FestivalViewModel] _convertCoordinatesToLocation: done, allFestivals.length=${allFestivals.length}',
      );
    }

    // Update filtered festivals if needed (festivals list not populated until _applyFilter, so this often no-op)
    if (festivals.isNotEmpty) {
      festivals.clear();
      festivals.addAll(allFestivals);
    }

    notifyListeners();
  }

  @override
  void onDispose() {
    _profileCacheService.removeListener(_onProfileCacheUpdated);
    _autoSlideTimer?.cancel();
    _searchDebounce?.cancel();
    pageController.dispose();
    searchFocusNode.dispose();
    searchController.dispose();
    super.onDispose();
  }
}
