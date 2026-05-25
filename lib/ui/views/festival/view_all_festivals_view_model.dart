import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/api/festival_api_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/navigation/apply_festival_navbar_gate_outcome.dart';
import '../../../core/services/profile_readiness_service.dart';
import 'festival_model.dart';

class ViewAllFestivalsViewModel extends BaseViewModel {
  ViewAllFestivalsViewModel() {
    searchFocusNode = FocusNode();
  }

  final FestivalApiService _festivalApiService = locator<FestivalApiService>();
  final GeocodingService _geocodingService = locator<GeocodingService>();
  final NavigationService _navigationService = locator<NavigationService>();

  final List<FestivalModel> _festivals = [];
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _navbarGateBusy = false;
  int _selectedTab = 0; // 0: Live, 1: Upcoming, 2: Past

  /// API search (discover-style), debounced — separate from paginated list body.
  late final FocusNode searchFocusNode;
  final TextEditingController searchController = TextEditingController();
  final List<FestivalModel> _searchResults = [];
  String searchQuery = '';
  Timer? _searchDebounce;
  bool _isSearching = false;
  String? _searchError;

  List<FestivalModel> get festivals => List.unmodifiable(_festivals);
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get navbarGateBusy => _navbarGateBusy;
  int get selectedTab => _selectedTab;

  List<FestivalModel> get searchResults => List.unmodifiable(_searchResults);

  bool get isSearching => _isSearching;

  String? get searchError => _searchError;

  String get currentSearchQuery => searchQuery;

  List<FestivalModel> get filteredFestivals {
    final status = _selectedTab == 0
        ? FestivalStatus.live
        : _selectedTab == 1
            ? FestivalStatus.upcoming
            : FestivalStatus.past;
    return _festivals.where((f) => f.status == status).toList();
  }

  void setSelectedTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    unfocusSearch();
    notifyListeners();
  }

  /// Merges paginated list + any search hits for [FestivalProvider] (dedup by id).
  List<FestivalModel> _combinedFestivalsForProvider() {
    final byId = <int, FestivalModel>{};
    for (final f in _festivals) {
      byId[f.id] = f;
    }
    for (final f in _searchResults) {
      byId.putIfAbsent(f.id, () => f);
    }
    return byId.values.toList();
  }

  Future<void> loadInitial() async {
    if (isLoading) return;
    _festivals.clear();
    _currentPage = 0;
    _hasMore = true;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || isLoading) return;
    final nextPage = _currentPage + 1;

    if (_currentPage == 0) {
      await handleAsync(
        () async {
          await _fetchPage(nextPage);
        },
        errorMessage: AppStrings.failedToLoadFestivals,
        minimumLoadingDuration: AppDurations.minimumLoadingDuration,
      );
    } else {
      _isLoadingMore = true;
      notifyListeners();
      try {
        await _fetchPage(nextPage);
      } catch (e) {
        if (kDebugMode) print('ViewAllFestivalsViewModel loadMore error: $e');
        setError(e.toString());
      } finally {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _fetchPage(int page) async {
    final response = await _festivalApiService.getFestivalsPage(page);
    if (!response.success || response.data == null) {
      throw Exception(response.message ?? AppStrings.failedToLoadFestivals);
    }
    final result = response.data!;
    _currentPage = result.currentPage;
    _hasMore = result.hasMore;
    for (final json in result.list) {
      try {
        var festival = FestivalModel.fromApiJson(json);
        if (festival.latitude != null && festival.longitude != null) {
          try {
            final location = await _geocodingService.getLocationFromCoordinates(
              festival.latitude,
              festival.longitude,
            );
            festival = festival.copyWith(location: location);
          } catch (_) {
            // Keep lat/long string if geocoding fails
          }
        }
        _festivals.add(festival);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> navigateToHome(BuildContext context, FestivalModel festival) async {
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.setSelectedFestival(festival);
    festivalProvider.setAllFestivals(_combinedFestivalsForProvider());

    _navbarGateBusy = true;
    notifyListeners();
    try {
      final outcome =
          await locator<ProfileReadinessService>().evaluateFestivalNavbarGate();
      if (!context.mounted) return;

      if (kDebugMode) {
        print(
          '🧭 [ViewAllFestivals.navigateToHome] Gate outcome=${outcome.name}',
        );
      }

      await applyFestivalNavbarGateOutcome(
        context,
        outcome,
        onAuthenticatedNavigate:
            () => _navigationService.navigateTo(AppRoutes.navbaar),
      );
    } finally {
      _navbarGateBusy = false;
      if (!isDisposed) notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults.clear();
      _isSearching = false;
      _searchError = null;
      _searchDebounce?.cancel();
      _searchDebounce = null;
      notifyListeners();
      return;
    }
    final q = query.trim();
    _searchError = null;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(q);
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

  void retrySearch() {
    if (searchQuery.trim().isEmpty) return;
    _searchError = null;
    _performSearch(searchQuery.trim());
  }

  Future<void> _performSearch(String query) async {
    if (query != searchQuery.trim() || isDisposed) return;
    _isSearching = true;
    _searchError = null;
    notifyListeners();
    try {
      final response = await _festivalApiService.getFestivals(search: query);
      if (query != searchQuery.trim() || isDisposed) return;
      if (response.success && response.data != null) {
        final parsed = <FestivalModel>[];
        for (final festivalData in response.data!) {
          try {
            parsed.add(FestivalModel.fromApiJson(festivalData));
          } catch (e) {
            if (kDebugMode) {
              print('[ViewAllFestivals] Search parse error: $e');
            }
          }
        }
        final withLocation = await _convertCoordinatesForFestivalList(parsed);
        if (query != searchQuery.trim() || isDisposed) return;
        _searchResults
          ..clear()
          ..addAll(withLocation);
        _searchError = null;
      } else {
        _searchResults.clear();
        if (query == searchQuery.trim() && !isDisposed) {
          _searchError =
              response.message ?? 'Something went wrong. Please try again.';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ViewAllFestivals] Search API error: $e');
      }
      if (!isDisposed && query == searchQuery.trim()) {
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

  Future<List<FestivalModel>> _convertCoordinatesForFestivalList(
    List<FestivalModel> list,
  ) async {
    final updated = <FestivalModel>[];
    for (final festival in list) {
      if (festival.latitude != null && festival.longitude != null) {
        try {
          final location = await _geocodingService.getLocationFromCoordinates(
            festival.latitude,
            festival.longitude,
          );
          updated.add(festival.copyWith(location: location));
        } catch (_) {
          updated.add(festival);
        }
      } else {
        updated.add(festival);
      }
    }
    return updated;
  }

  void unfocusSearch() {
    if (isDisposed) return;
    try {
      searchFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) {
        print('ViewAllFestivals unfocusSearch: $e');
      }
    }
  }

  void goBack() {
    clearSearch();
    _navigationService.pop();
  }

  @override
  void onDispose() {
    _searchDebounce?.cancel();
    searchFocusNode.dispose();
    searchController.dispose();
    super.onDispose();
  }
}
