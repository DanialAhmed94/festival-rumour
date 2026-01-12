import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';

class AllJobsViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();

  // Jobs organized by category
  Map<String, List<Map<String, dynamic>>> _jobsByCategory = {};
  Map<String, List<Map<String, dynamic>>> get jobsByCategory => _jobsByCategory;

  // Pagination state
  Map<String, DocumentSnapshot> _lastDocuments = {};
  Map<String, bool> _hasMoreByCategory = {};
  Map<String, bool> get hasMoreByCategory => _hasMoreByCategory;
  
  bool hasMoreForCategory(String category) => _hasMoreByCategory[category] ?? false;

  // Selected category tab
  int _selectedCategoryIndex = 0;
  int get selectedCategoryIndex => _selectedCategoryIndex;
  List<String> get categories => _jobsByCategory.keys.toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  void setSelectedCategoryIndex(int index) {
    _selectedCategoryIndex = index;
    notifyListeners();
  }

  Future<void> loadAllJobs({bool loadMore = false}) async {
    // Prevent multiple simultaneous loads
    if (_isLoading || (_isLoadingMore && loadMore)) {
      return;
    }

    await handleAsync(() async {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _jobsByCategory.clear();
        _lastDocuments.clear();
        _hasMoreByCategory.clear();
      }
      notifyListeners();

      if (kDebugMode) {
        print('💼 Loading all jobs from all users (loadMore: $loadMore)');
      }

      final result = await _firestoreService.getAllJobsPaginated(
        limit: 10,
        lastDocuments: loadMore ? _lastDocuments : null,
      );

      final newJobsByCategory = result['jobsByCategory'] as Map<String, List<Map<String, dynamic>>>;
      final newLastDocuments = result['lastDocuments'] as Map<String, DocumentSnapshot>;
      final newHasMoreByCategory = result['hasMoreByCategory'] as Map<String, bool>;

      // Merge with existing jobs if loading more
      if (loadMore) {
        for (final category in newJobsByCategory.keys) {
          final existingJobs = _jobsByCategory[category] ?? [];
          final newJobs = newJobsByCategory[category] ?? [];
          _jobsByCategory[category] = [...existingJobs, ...newJobs];
        }
      } else {
        _jobsByCategory = newJobsByCategory;
      }

      // Update pagination state
      _lastDocuments = newLastDocuments;
      _hasMoreByCategory = newHasMoreByCategory;

      if (kDebugMode) {
        print('✅ Loaded jobs from ${_jobsByCategory.length} categories');
      }

      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }, errorMessage: 'Failed to load jobs. Please try again.');
  }

  Future<void> loadMoreJobs() async {
    await loadAllJobs(loadMore: true);
  }
}
