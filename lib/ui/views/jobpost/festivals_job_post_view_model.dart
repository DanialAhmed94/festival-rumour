import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';

class FestivalsJobPostViewModel extends BaseViewModel {
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
  late TextEditingController festivalDateController;

  // Focus Nodes
  late FocusNode jobTitleFocusNode;
  late FocusNode companyFocusNode;
  late FocusNode locationFocusNode;
  late FocusNode salaryFocusNode;
  late FocusNode descriptionFocusNode;
  late FocusNode requirementsFocusNode;
  late FocusNode contactFocusNode;
  late FocusNode festivalDateFocusNode;

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

  // Job Category Selection (set from navigation, not from form)
  String? selectedCategory;

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
    festivalDateFocusNode = FocusNode();
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
    
    // Set category
    final category = jobData['category'] as String?;
    if (category != null) {
      selectedCategory = category;
    }
    
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
    festivalDateFocusNode.unfocus();
  }

  bool _validateForm() {
    // Validate Job Title
    if (jobTitleController.text.trim().isEmpty) {
      setError('Please enter a job title');
      jobTitleFocusNode.requestFocus();
      return false;
    }
    if (jobTitleController.text.trim().length < 3) {
      setError('Job title must be at least 3 characters long');
      jobTitleFocusNode.requestFocus();
      return false;
    }

    // Validate Company
    if (companyController.text.trim().isEmpty) {
      setError('Please enter company/organization name');
      companyFocusNode.requestFocus();
      return false;
    }
    if (companyController.text.trim().length < 2) {
      setError('Company name must be at least 2 characters long');
      companyFocusNode.requestFocus();
      return false;
    }

    // Validate Location
    if (locationController.text.trim().isEmpty) {
      setError('Please enter job location');
      locationFocusNode.requestFocus();
      return false;
    }
    if (locationController.text.trim().length < 3) {
      setError('Location must be at least 3 characters long');
      locationFocusNode.requestFocus();
      return false;
    }

    // Validate Salary (required unless job type is Volunteer)
    if (selectedJobType != 'Volunteer') {
      if (salaryController.text.trim().isEmpty) {
        setError('Please enter salary information');
        salaryFocusNode.requestFocus();
        return false;
      }
    }

    // Validate Description
    if (descriptionController.text.trim().isEmpty) {
      setError('Please enter job description');
      descriptionFocusNode.requestFocus();
      return false;
    }
    if (descriptionController.text.trim().length < 10) {
      setError('Job description must be at least 10 characters long');
      descriptionFocusNode.requestFocus();
      return false;
    }

    // Validate Requirements (optional but if provided, should be meaningful)
    if (requirementsController.text.trim().isNotEmpty && 
        requirementsController.text.trim().length < 5) {
      setError('Requirements must be at least 5 characters if provided');
      requirementsFocusNode.requestFocus();
      return false;
    }

    // Validate Contact Information
    if (contactController.text.trim().isEmpty) {
      setError('Please enter contact information');
      contactFocusNode.requestFocus();
      return false;
    }
    // Check if it's an email or phone number
    final contactText = contactController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]+$');
    if (!emailRegex.hasMatch(contactText) && !phoneRegex.hasMatch(contactText)) {
      setError('Please enter a valid email address or phone number');
      contactFocusNode.requestFocus();
      return false;
    }

    // Validate Festival Date (required + format DD/MM/YYYY + not in past)
    final festivalDateStr = festivalDateController.text.trim();
    if (festivalDateStr.isEmpty) {
      setError('Please select festival date');
      festivalDateFocusNode.requestFocus();
      return false;
    }
    final parsedDate = _parseFestivalDate(festivalDateStr);
    if (parsedDate == null) {
      setError('Festival date must be in DD/MM/YYYY format (e.g. 25/12/2025)');
      festivalDateFocusNode.requestFocus();
      return false;
    }
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (parsedDate.isBefore(today)) {
      setError('Festival date cannot be in the past');
      festivalDateFocusNode.requestFocus();
      return false;
    }

    // Validate Category (should be set from navigation)
    if (selectedCategory == null || selectedCategory!.isEmpty) {
      setError('Job category is required');
      if (kDebugMode) {
        print('❌ [JobPostViewModel] Category validation failed: selectedCategory is null or empty');
      }
      return false;
    }

    clearError();
    return true;
  }

  /// Parses festival date string DD/MM/YYYY; returns null if invalid.
  DateTime? _parseFestivalDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    try {
      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || date.year != year) return null;
      return date;
    } catch (_) {
      return null;
    }
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
        print('💼 Posting job with category: $selectedCategory');
        print('   User ID: $userId');
      }

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
        category: selectedCategory,
      );

      // Convert to Firestore format
      final jobData = currentJobPost!.toJson();
      // Convert DateTime to Timestamp format for Firestore
      jobData['postedDate'] = currentJobPost!.postedDate;
      jobData['createdAt'] = DateTime.now();

      // Save or update job in Firestore
      if (isEditing && _editingJobId != null) {
        // Update existing job
        if (kDebugMode) {
          print('💾 Updating job in Firestore');
          print('   JobId: $_editingJobId');
          print('   Category: $selectedCategory');
        }
        
        await _firestoreService.updateJob(
          _editingJobId!,
          selectedCategory!,
          jobData,
        );

        if (kDebugMode) {
          print('✅ Job updated successfully');
        }
      } else {
        // Save new job
        if (kDebugMode) {
          print('💾 Saving job to Firestore');
          print('   Category: $selectedCategory');
          print('   UserId: $userId');
        }
        
        await _firestoreService.saveJob(
          jobData,
          category: selectedCategory!,
        );

        if (kDebugMode) {
          print('✅ Job saved successfully');
        }
      }

      _successMessage = isEditing ? 'Job updated successfully!' : 'Job posted successfully!';
      notifyListeners();
      _clearForm();

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

  void _clearForm() {
    jobTitleController.clear();
    companyController.clear();
    locationController.clear();
    salaryController.clear();
    descriptionController.clear();
    requirementsController.clear();
    contactController.clear();
    festivalDateController.clear();
    selectedJobType = 'Full-time';
    selectedCategory = null;
    _editingJobId = null; // Clear editing state
    notifyListeners();
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
    festivalDateController.dispose();

    // Dispose focus nodes
    jobTitleFocusNode.dispose();
    companyFocusNode.dispose();
    locationFocusNode.dispose();
    salaryFocusNode.dispose();
    descriptionFocusNode.dispose();
    requirementsFocusNode.dispose();
    contactFocusNode.dispose();
    festivalDateFocusNode.dispose();

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
  });

  Map<String, dynamic> toJson() {
    return {
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
    );
  }
}
