import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/api/festival_api_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/festival_provider.dart';
import 'festival_model.dart';

class ViewAllFestivalsViewModel extends BaseViewModel {
  final FestivalApiService _festivalApiService = locator<FestivalApiService>();
  final GeocodingService _geocodingService = locator<GeocodingService>();
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = locator<AuthService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();

  final List<FestivalModel> _festivals = [];
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<FestivalModel> get festivals => List.unmodifiable(_festivals);
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

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

  Future<bool> isPhoneMissing() async {
    final user = _authService.currentUser;
    if (user == null) return true;
    final data = await _firestoreService.getUserData(user.uid);
    if (data == null) return true;
    final phone = data['phoneNumber'];
    return phone == null || phone.toString().isEmpty;
  }

  Future<void> navigateToHome(BuildContext context, FestivalModel festival) async {
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.setSelectedFestival(festival);
    festivalProvider.setAllFestivals(_festivals);

    final missing = await isPhoneMissing();
    if (missing) {
      _navigationService.navigateTo(AppRoutes.signup, arguments: true);
      return;
    }
    _navigationService.navigateTo(AppRoutes.navbaar);
  }

  void goBack() {
    _navigationService.pop();
  }
}
