import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/di/locator.dart';
import '../../../core/api/performance_api_service.dart';
import '../../../core/models/performance_model.dart';

class PerformanceViewModel extends BaseViewModel {
  final PerformanceApiService _performanceApiService = locator<PerformanceApiService>();

  List<PerformanceModel> _performances = [];
  int? _lastLoadedFestivalId;

  List<PerformanceModel> get performances => _performances;

  @override
  void init() {
    super.init();
  }

  Future<void> loadPerformancesIfNeeded(int? festivalId) async {
    if (festivalId == null) return;
    // Only load once per festival (avoid repeated calls when API returns 0 or view rebuilds)
    if (_lastLoadedFestivalId == festivalId) return;

    _lastLoadedFestivalId = festivalId;
    await _loadPerformances(festivalId);
  }

  Future<void> _loadPerformances(int festivalId) async {
    await handleAsync(
      () async {
        final response = await _performanceApiService.getPerformances(festivalId);
        if (response.success && response.data != null) {
          _performances = response.data!
              .map((json) => PerformanceModel.fromApiJson(json))
              .toList();
          if (kDebugMode) {
            print('PerformanceViewModel: loaded ${_performances.length} performances for festival $festivalId');
          }
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadPerformances);
        }
      },
      errorMessage: AppStrings.failedToLoadPerformances,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }
}
