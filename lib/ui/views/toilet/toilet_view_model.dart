import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/api/toilet_api_service.dart';
import '../../../core/models/toilet_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';

class ToiletViewModel extends BaseViewModel {
  final ToiletApiService _toiletApiService = locator<ToiletApiService>();

  List<ToiletModel> _toilets = [];
  bool _showToiletDetail = false;
  ToiletModel? _selectedToilet;
  int? _lastLoadedFestivalId;

  List<ToiletModel> get toilets => _toilets;
  bool get showToiletDetail => _showToiletDetail;
  ToiletModel? get selectedToilet => _selectedToilet;

  @override
  void init() {
    super.init();
  }

  /// Call from view when context is available. Uses festivalId from args or from FestivalProvider.
  Future<void> loadToiletsIfNeeded(int? festivalId) async {
    if (festivalId == null) return;
    if (_lastLoadedFestivalId == festivalId) return;

    _lastLoadedFestivalId = festivalId;
    await loadToilets(festivalId);
  }

  Future<void> loadToilets(int? festivalId) async {
    if (festivalId == null) {
      _toilets = [];
      notifyListeners();
      return;
    }

    await handleAsync(
      () async {
        final response = await _toiletApiService.getToilets(festivalId);

        if (response.success && response.data != null) {
          _toilets = response.data!
              .map((json) => ToiletModel.fromApiJson(json))
              .toList();
          if (kDebugMode) {
            print('ToiletViewModel: loaded ${_toilets.length} toilets for festival $festivalId');
          }
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadToilets);
        }
      },
      errorMessage: AppStrings.failedToLoadToilets,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }

  void set showToiletDetail(bool value) {
    _showToiletDetail = value;
    notifyListeners();
  }

  void set selectedToilet(ToiletModel? toilet) {
    _selectedToilet = toilet;
    notifyListeners();
  }

  void navigateToDetail(ToiletModel toilet) {
    _selectedToilet = toilet;
    _showToiletDetail = true;
    notifyListeners();
  }

  void navigateBackToList() {
    _showToiletDetail = false;
    _selectedToilet = null;
    notifyListeners();
  }
}
