import 'package:flutter/material.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/di/locator.dart';
import '../../../core/api/news_api_service.dart';
import '../../../core/api/toilet_api_service.dart';
import '../../../core/api/event_api_service.dart';
import '../../../core/api/performance_api_service.dart';
import '../../../core/models/bulletin_model.dart';
import '../../../core/models/toilet_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/performance_model.dart';

class ViewAllViewModel extends BaseViewModel {
  final int? _initialTab;
  final int? _festivalIdForToilets;
  int _selectedTab = 0;
  List<EventModel> _events = [];
  List<PerformanceModel> _performances = [];
  List<BulletinModel> _bulletins = [];
  List<ToiletModel> _toilets = [];
  int? _lastToiletsFestivalId;
  int? _lastEventsFestivalId;
  int? _lastPerformancesFestivalId;

  final NewsApiService _newsApiService = locator<NewsApiService>();
  final ToiletApiService _toiletApiService = locator<ToiletApiService>();
  final EventApiService _eventApiService = locator<EventApiService>();
  final PerformanceApiService _performanceApiService = locator<PerformanceApiService>();

  ViewAllViewModel({int? initialTab, int? festivalIdForToilets})
      : _initialTab = initialTab,
        _festivalIdForToilets = festivalIdForToilets;

  int get selectedTab => _selectedTab;
  List<EventModel> get events => _events;
  List<PerformanceModel> get performances => _performances;
  List<BulletinModel> get bulletins => _bulletins;
  List<ToiletModel> get toilets => _toilets;
  int? get festivalIdForToilets => _festivalIdForToilets;
  bool get showTabSelector => _initialTab == null;

  @override
  void init() {
    super.init();
    if (_initialTab != null && _initialTab! >= 0 && _initialTab! <= 3) {
      _selectedTab = _initialTab!;
    }
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (_selectedTab == 0 && _festivalIdForToilets != null) {
      await loadEventsIfNeeded(_festivalIdForToilets);
    } else if (_selectedTab == 1) {
      await _loadBulletins();
    } else if (_selectedTab == 2 && _festivalIdForToilets != null) {
      await loadPerformancesIfNeeded(_festivalIdForToilets);
    } else if (_selectedTab == 3 && _festivalIdForToilets != null) {
      await loadToiletsIfNeeded(_festivalIdForToilets);
    } else {
      notifyListeners();
    }
  }

  Future<void> _loadBulletins() async {
    await handleAsync(
      () async {
        final response = await _newsApiService.getBulletins();
        if (response.success && response.data != null) {
          _bulletins = response.data!.map((json) => BulletinModel.fromApiJson(json)).toList();
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadNews);
        }
      },
      errorMessage: AppStrings.failedToLoadNews,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }

  Future<void> _loadToilets(int festivalId) async {
    _lastToiletsFestivalId = festivalId;
    await handleAsync(
      () async {
        final response = await _toiletApiService.getToilets(festivalId);
        if (response.success && response.data != null) {
          _toilets = response.data!.map((json) => ToiletModel.fromApiJson(json)).toList();
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadToilets);
        }
      },
      errorMessage: AppStrings.failedToLoadToilets,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }

  Future<void> _loadEvents(int festivalId) async {
    _lastEventsFestivalId = festivalId;
    await handleAsync(
      () async {
        final response = await _eventApiService.getEvents(festivalId);
        if (response.success && response.data != null) {
          _events = response.data!.map((json) => EventModel.fromApiJson(json)).toList();
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadEvents);
        }
      },
      errorMessage: AppStrings.failedToLoadEvents,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }

  Future<void> _loadPerformances(int festivalId) async {
    _lastPerformancesFestivalId = festivalId;
    await handleAsync(
      () async {
        final response = await _performanceApiService.getPerformances(festivalId);
        if (response.success && response.data != null) {
          _performances = response.data!.map((json) => PerformanceModel.fromApiJson(json)).toList();
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadPerformances);
        }
      },
      errorMessage: AppStrings.failedToLoadPerformances,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }

  Future<void> loadToiletsIfNeeded(int? festivalId) async {
    if (festivalId == null) return;
    if (_lastToiletsFestivalId == festivalId) return;
    await _loadToilets(festivalId);
  }

  Future<void> loadEventsIfNeeded(int? festivalId) async {
    if (festivalId == null) return;
    if (_lastEventsFestivalId == festivalId) return;
    await _loadEvents(festivalId);
  }

  Future<void> loadPerformancesIfNeeded(int? festivalId) async {
    if (festivalId == null) return;
    if (_lastPerformancesFestivalId == festivalId) return;
    await _loadPerformances(festivalId);
  }

  void setSelectedTab(int index) {
    _selectedTab = index;
    notifyListeners();
    if (index == 1 && _bulletins.isEmpty && !isLoading) {
      _loadBulletins();
    } else if (index == 0 && _festivalIdForToilets != null && _events.isEmpty && !isLoading) {
      loadEventsIfNeeded(_festivalIdForToilets);
    } else if (index == 2 && _festivalIdForToilets != null && _performances.isEmpty && !isLoading) {
      loadPerformancesIfNeeded(_festivalIdForToilets);
    }
  }
}
