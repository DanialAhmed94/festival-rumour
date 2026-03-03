import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/di/locator.dart';
import '../../../core/api/event_api_service.dart';
import '../../../core/models/event_model.dart';

class EventViewModel extends BaseViewModel {
  final EventApiService _eventApiService = locator<EventApiService>();

  List<EventModel> _events = [];
  int? _lastLoadedFestivalId;

  List<EventModel> get events => _events;

  @override
  void init() {
    super.init();
  }

  Future<void> loadEventsIfNeeded(int? festivalId) async {
    if (festivalId == null) return;
    if (_lastLoadedFestivalId == festivalId) return;

    _lastLoadedFestivalId = festivalId;
    await _loadEvents(festivalId);
  }

  Future<void> _loadEvents(int festivalId) async {
    await handleAsync(
      () async {
        final response = await _eventApiService.getEvents(festivalId);
        if (response.success && response.data != null) {
          _events = response.data!
              .map((json) => EventModel.fromApiJson(json))
              .toList();
          if (kDebugMode) {
            print('EventViewModel: loaded ${_events.length} events for festival $festivalId');
          }
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadEvents);
        }
      },
      errorMessage: AppStrings.failedToLoadEvents,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }
}
