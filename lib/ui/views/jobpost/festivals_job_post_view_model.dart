import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/job_url_utils.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';

class FestivalsJobPostViewModel extends BaseViewModel {
  static const String _defaultJobCategory = 'Festival Gizza';

  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  
  // Text Controllers
  late TextEditingController jobTitleController;
  late TextEditingController companyController;
  late TextEditingController locationController;
  late TextEditingController salaryController;
  late TextEditingController descriptionController;
  late TextEditingController requirementsController;
  late TextEditingController contactController;
  late TextEditingController jobUrlController;
  late TextEditingController festivalDateController;

  // Focus Nodes
  late FocusNode jobTitleFocusNode;
  late FocusNode companyFocusNode;
  late FocusNode locationFocusNode;
  late FocusNode salaryFocusNode;
  late FocusNode descriptionFocusNode;
  late FocusNode requirementsFocusNode;
  late FocusNode contactFocusNode;
  late FocusNode jobUrlFocusNode;
  late FocusNode festivalDateFocusNode;
  /// Target for IME "next" from the festival date row; avoids allocating a throwaway node per rebuild.
  late final FocusNode festivalDateDummyNextFocusNode;


  // Job Type Selection
  String selectedJobType = 'Full-time';
  final List<String> jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Temporary',
    'Volunteer',
    'Internship',
  ];

  // Job Category Selection (optional in form; Firestore uses default if unset)
  String? selectedCategory;

  String get _effectiveCategory {
    final trimmed = selectedCategory?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _defaultJobCategory;
    }
    return trimmed;
  }

  // Job Post Model
  JobPost? currentJobPost;
  
  // Editing state
  String? _editingJobId;
  String? get editingJobId => _editingJobId;
  bool get isEditing => _editingJobId != null;

  // Success message
  String? _successMessage;
  String? get successMessage => _successMessage;
  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  FestivalsJobPostViewModel() {
    _initializeControllers();
    _initializeFocusNodes();
  }

  void _initializeControllers() {
    jobTitleController = TextEditingController();
    companyController = TextEditingController();
    locationController = TextEditingController();
    salaryController = TextEditingController();
    descriptionController = TextEditingController();
    requirementsController = TextEditingController();
    contactController = TextEditingController();
    jobUrlController = TextEditingController();
    festivalDateController = TextEditingController();
  }

  void _initializeFocusNodes() {
    jobTitleFocusNode = FocusNode();
    companyFocusNode = FocusNode();
    locationFocusNode = FocusNode();
    salaryFocusNode = FocusNode();
    descriptionFocusNode = FocusNode();
    requirementsFocusNode = FocusNode();
    contactFocusNode = FocusNode();
    jobUrlFocusNode = FocusNode();
    festivalDateFocusNode = FocusNode();
    festivalDateDummyNextFocusNode = FocusNode(skipTraversal: true);
  }

  void setJobType(String jobType) {
    selectedJobType = jobType;
    notifyListeners();
  }

  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  // Set category from navigation (from modal bottom sheet)
  void setCategoryFromNavigation(String category) {
    if (kDebugMode) {
      print('📋 [JobPostViewModel] Setting category from navigation: $category');
    }
    selectedCategory = category;
    notifyListeners();
  }

  // Load job data for editing
  void loadJobForEditing(Map<String, dynamic> jobData) {
    if (kDebugMode) {
      print('✏️ [JobPostViewModel] Loading job for editing: ${jobData['jobId']}');
    }
    
    _editingJobId = jobData['jobId'] as String?;
    
    // Populate form fields
    jobTitleController.text = jobData['title'] as String? ?? '';
    companyController.text = jobData['company'] as String? ?? '';
    locationController.text = jobData['location'] as String? ?? '';
    salaryController.text = jobData['salary'] as String? ?? '';
    descriptionController.text = jobData['description'] as String? ?? '';
    requirementsController.text = jobData['requirements'] as String? ?? '';
    contactController.text = jobData['contact'] as String? ?? '';
    jobUrlController.text = JobUrlUtils.readFromJobMap(jobData) ?? '';

    // Handle festival date - could be string or DateTime
    if (jobData['festivalDate'] != null) {
      final festivalDate = jobData['festivalDate'];
      if (festivalDate is String) {
        festivalDateController.text = festivalDate;
      } else if (festivalDate is DateTime) {
        // Format DateTime as DD/MM/YYYY
        final formattedDate = '${festivalDate.day.toString().padLeft(2, '0')}/${festivalDate.month.toString().padLeft(2, '0')}/${festivalDate.year}';
        festivalDateController.text = formattedDate;
      }
    }
    
    // Set job type
    final jobType = jobData['jobType'] as String?;
    if (jobType != null && jobTypes.contains(jobType)) {
      selectedJobType = jobType;
    }
    
    // Set category (required for Firestore collection when editing existing doc)
    final category = jobData['category'] as String?;
    selectedCategory =
        category != null && category.trim().isNotEmpty
            ? category.trim()
            : _defaultJobCategory;
    
    notifyListeners();
  }

  void unfocusAllFields() {
    jobTitleFocusNode.unfocus();
    companyFocusNode.unfocus();
    locationFocusNode.unfocus();
    salaryFocusNode.unfocus();
    descriptionFocusNode.unfocus();
    requirementsFocusNode.unfocus();
    contactFocusNode.unfocus();
    jobUrlFocusNode.unfocus();
    festivalDateFocusNode.unfocus();
    festivalDateDummyNextFocusNode.unfocus();
  }

  bool _validateForm() {
    if (jobTitleController.text.trim().isEmpty) {
      setError('Please enter a job title');
      jobTitleFocusNode.requestFocus();
      return false;
    }

    clearError();
    return true;
  }

  // Method to select festival date
  Future<void> selectFestivalDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)), // 5 years from now
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.yellow,
              onPrimary: AppColors.black,
              onSurface: Colors.black, // All text in calendar is black
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyLarge: const TextStyle(color: Colors.black),
              bodyMedium: const TextStyle(color: Colors.black),
              bodySmall: const TextStyle(color: Colors.black),
              labelLarge: const TextStyle(color: Colors.black),
              labelMedium: const TextStyle(color: Colors.black),
              labelSmall: const TextStyle(color: Colors.black),
              titleLarge: const TextStyle(color: Colors.black),
              titleMedium: const TextStyle(color: Colors.black),
              titleSmall: const TextStyle(color: Colors.black),
              headlineLarge: const TextStyle(color: Colors.black),
              headlineMedium: const TextStyle(color: Colors.black),
              headlineSmall: const TextStyle(color: Colors.black),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black, // Cancel and OK button text color
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      // Format date as DD/MM/YYYY
      final formattedDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      festivalDateController.text = formattedDate;
      notifyListeners();
    }
  }

  Future<void> postJob(BuildContext? context) async {
    if (!_validateForm()) {
      return;
    }

    await handleAsync(() async {
      // Get current user ID
      final currentUser = _authService.currentUser;
      final userId = currentUser?.uid;
      
      if (userId == null) {
        setError('User not authenticated. Please log in again.');
        return;
      }

      if (kDebugMode) {
        print('💼 Posting job with category: $_effectiveCategory (nav: $selectedCategory)');
        print('   User ID: $userId');
      }

      final jobUrlForStore = JobUrlUtils.forFirestore(jobUrlController.text);
      final categoryForFirestore = _effectiveCategory;

      // Create job post object
      currentJobPost = JobPost(
        title: jobTitleController.text.trim(),
        company: companyController.text.trim(),
        location: locationController.text.trim(),
        jobType: selectedJobType,
        salary: salaryController.text.trim(),
        description: descriptionController.text.trim(),
        requirements: requirementsController.text.trim(),
        contact: contactController.text.trim(),
        festivalDate: festivalDateController.text.trim(),
        postedDate: DateTime.now(),
        isActive: true,
        userId: userId,
        category: categoryForFirestore,
        jobUrl: jobUrlForStore,
      );

      // Convert to Firestore format
      final jobData = currentJobPost!.toJson();
      // Convert DateTime to Timestamp format for Firestore
      jobData['postedDate'] = currentJobPost!.postedDate;
      jobData['createdAt'] = DateTime.now();

      if (isEditing && _editingJobId != null) {
        jobData['jobUrl'] =
            jobUrlForStore ?? FieldValue.delete();
      }

      // Save or update job in Firestore
      if (isEditing && _editingJobId != null) {
        // Update existing job
        if (kDebugMode) {
          print('💾 Updating job in Firestore');
          print('   JobId: $_editingJobId');
          print('   Category: $_effectiveCategory');
        }

        await _firestoreService.updateJob(
          _editingJobId!,
          _effectiveCategory,
          jobData,
        );

        if (kDebugMode) {
          print('✅ Job updated successfully');
        }
      } else {
        // Save new job
        if (kDebugMode) {
          print('💾 Saving job to Firestore');
          print('   Category: $_effectiveCategory');
          print('   UserId: $userId');
        }

        await _firestoreService.saveJob(
          jobData,
          category: _effectiveCategory,
        );

        if (kDebugMode) {
          print('✅ Job saved successfully');
        }
      }

      _successMessage = isEditing ? 'Job updated successfully!' : 'Job posted successfully!';
      _applyClearFormMutations();
      notifyListeners();

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_successMessage!),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _navigationService.pop();
    }, errorMessage: 'Failed to post job. Please try again.');
  }

  void _applyClearFormMutations() {
    jobTitleController.clear();
    companyController.clear();
    locationController.clear();
    salaryController.clear();
    descriptionController.clear();
    requirementsController.clear();
    contactController.clear();
    jobUrlController.clear();
    festivalDateController.clear();
    selectedJobType = 'Full-time';
    selectedCategory = null;
    _editingJobId = null; // Clear editing state
  }

  @override
  void dispose() {
    // Dispose controllers
    jobTitleController.dispose();
    companyController.dispose();
    locationController.dispose();
    salaryController.dispose();
    descriptionController.dispose();
    requirementsController.dispose();
    contactController.dispose();
    jobUrlController.dispose();
    festivalDateController.dispose();

    // Dispose focus nodes
    jobTitleFocusNode.dispose();
    companyFocusNode.dispose();
    locationFocusNode.dispose();
    salaryFocusNode.dispose();
    descriptionFocusNode.dispose();
    requirementsFocusNode.dispose();
    contactFocusNode.dispose();
    jobUrlFocusNode.dispose();
    festivalDateFocusNode.dispose();
    festivalDateDummyNextFocusNode.dispose();

    super.dispose();
  }
}

class JobPost {
  final String title;
  final String company;
  final String location;
  final String jobType;
  final String salary;
  final String description;
  final String requirements;
  final String contact;
  final String festivalDate;
  final DateTime postedDate;
  final bool isActive;
  final String? userId; // User ID who posted the job
  final String? category; // Job category (e.g., 'Festival Gizza', 'Festie Heroes')
  final String? jobUrl; // Optional external listing / apply link

  JobPost({
    required this.title,
    required this.company,
    required this.location,
    required this.jobType,
    required this.salary,
    required this.description,
    required this.requirements,
    required this.contact,
    required this.festivalDate,
    required this.postedDate,
    required this.isActive,
    this.userId,
    this.category,
    this.jobUrl,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'company': company,
      'location': location,
      'jobType': jobType,
      'salary': salary,
      'description': description,
      'requirements': requirements,
      'contact': contact,
      'festivalDate': festivalDate,
      'postedDate': postedDate.toIso8601String(),
      'isActive': isActive,
      'userId': userId,
      'category': category,
    };
    final url = jobUrl;
    if (url != null && url.isNotEmpty) {
      map['jobUrl'] = url;
    }
    return map;
  }

  factory JobPost.fromJson(Map<String, dynamic> json) {
    return JobPost(
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      location: json['location'] ?? '',
      jobType: json['jobType'] ?? '',
      salary: json['salary'] ?? '',
      description: json['description'] ?? '',
      requirements: json['requirements'] ?? '',
      contact: json['contact'] ?? '',
      festivalDate: json['festivalDate'] ?? '',
      postedDate: DateTime.parse(json['postedDate'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
      userId: json['userId'] as String?,
      category: json['category'] as String?,
      jobUrl: json['jobUrl'] as String?,
    );
  }
}
