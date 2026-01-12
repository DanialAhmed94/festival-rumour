import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/router/app_router.dart';
import 'festivals_job_post_view_model.dart';

class MyJobsViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final NavigationService _navigationService = locator<NavigationService>();

  // Jobs organized by category
  Map<String, List<Map<String, dynamic>>> _jobsByCategory = {};
  Map<String, List<Map<String, dynamic>>> get jobsByCategory => _jobsByCategory;

  // Selected category tab
  int _selectedCategoryIndex = 0;
  int get selectedCategoryIndex => _selectedCategoryIndex;
  List<String> get categories => _jobsByCategory.keys.toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  bool _hasLoaded = false;

  void setSelectedCategoryIndex(int index) {
    _selectedCategoryIndex = index;
    notifyListeners();
  }

  Future<void> loadUserJobs() async {
    final userId = _authService.userUid;
    if (userId == null) {
      setError('User not authenticated');
      return;
    }

    // Prevent multiple simultaneous loads
    if (_isLoading) {
      return;
    }

    await handleAsync(() async {
      _isLoading = true;
      notifyListeners();

      if (kDebugMode) {
        print('💼 Loading jobs for user: $userId');
      }

      _jobsByCategory = await _firestoreService.getUserJobs(userId);

      if (kDebugMode) {
        print('✅ Loaded jobs from ${_jobsByCategory.length} categories');
      }

      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }, errorMessage: 'Failed to load jobs. Please try again.');
  }

  Future<void> deleteJob(String jobId, String category) async {
    await handleAsync(() async {
      if (kDebugMode) {
        print('🗑️ Deleting job: $jobId from category: $category');
      }

      await _firestoreService.deleteJob(jobId, category);

      // Reload jobs after deletion
      await loadUserJobs();

      if (kDebugMode) {
        print('✅ Job deleted successfully');
      }
    }, errorMessage: 'Failed to delete job. Please try again.');
  }

  void editJob(BuildContext context, Map<String, dynamic> job) {
    // Navigate to job post screen with job data for editing
    final category = job['category'] as String?;
    if (category != null) {
      // Reset loaded flag so jobs will reload when returning from edit
      _hasLoaded = false;
      Navigator.pushNamed(
        context,
        AppRoutes.jobpost,
        arguments: {
          'category': category,
          'jobData': job, // Pass job data for editing
        },
      ).then((_) {
        // Reload jobs when returning from edit screen
        if (!_isLoading) {
          loadUserJobs();
        }
      });
    }
  }
}
