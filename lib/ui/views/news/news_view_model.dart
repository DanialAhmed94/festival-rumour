import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/api/news_api_service.dart';
import '../../../core/models/bulletin_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';

class NewsViewModel extends BaseViewModel {
  final NewsApiService _newsApiService = locator<NewsApiService>();

  List<BulletinModel> _bulletins = [];
  BulletinModel? _selectedBulletin;
  bool _showBulletinPreview = false;
  bool _showPerformancePreview = false;

  List<BulletinModel> get bulletins => _bulletins;
  BulletinModel? get selectedBulletin => _selectedBulletin;
  bool get showBulletinPreview => _showBulletinPreview;
  bool get showPerformancePreview => _showPerformancePreview;

  @override
  void init() {
    super.init();
    loadBulletins();
  }

  Future<void> loadBulletins() async {
    await handleAsync(
      () async {
        final response = await _newsApiService.getBulletins();

        if (response.success && response.data != null) {
          _bulletins = response.data!
              .map((json) => BulletinModel.fromApiJson(json))
              .toList();
          if (kDebugMode) {
            print('NewsViewModel: loaded ${_bulletins.length} bulletins from API');
          }
        } else {
          throw Exception(response.message ?? AppStrings.failedToLoadNews);
        }
      },
      errorMessage: AppStrings.failedToLoadNews,
      minimumLoadingDuration: AppDurations.minimumLoadingDuration,
    );
  }

  void setSelectedBulletin(BulletinModel? bulletin) {
    _selectedBulletin = bulletin;
    notifyListeners();
  }

  void set showBulletinPreview(bool value) {
    _showBulletinPreview = value;
    notifyListeners();
  }

  void set showPerformancePreview(bool value) {
    _showPerformancePreview = value;
    notifyListeners();
  }

  void navigateToBulletinPreview() {
    _showBulletinPreview = true;
    notifyListeners();
  }

  void navigateBackFromBulletinPreview() {
    _showBulletinPreview = false;
    notifyListeners();
  }

  void openBulletinDetail(BulletinModel bulletin) {
    _selectedBulletin = bulletin;
    _showPerformancePreview = true;
    notifyListeners();
  }

  void navigateBackFromPerformancePreview() {
    _showPerformancePreview = false;
    _selectedBulletin = null;
    notifyListeners();
  }
}
