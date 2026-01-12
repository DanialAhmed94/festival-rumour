import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/signup_data_service.dart';
import '../../../core/router/app_router.dart';

class UploadPhotosViewModel extends BaseViewModel {
  final ImagePicker _picker = ImagePicker();
  final NavigationService _navigationService = locator<NavigationService>();
  final SignupDataService _signupDataService = SignupDataService();

  dynamic selectedImage; // Use dynamic to support both File (mobile) and XFile (web)
  String? _providerPhotoURL; // Photo URL from Google/Apple

  /// Getter to check if image is picked
  bool get hasImage => selectedImage != null || _providerPhotoURL != null;

  @override
  void init() {
    super.init();
    // Check if there's a provider photo URL from Google/Apple
    _loadProviderPhoto();
  }

  /// Load provider photo URL if available (from Google/Apple)
  Future<void> _loadProviderPhoto() async {
    final providerPhotoURL = _signupDataService.providerPhotoURL;
    if (providerPhotoURL != null && providerPhotoURL.isNotEmpty) {
      _providerPhotoURL = providerPhotoURL;
      if (kDebugMode) {
        print('📸 [UPLOAD PHOTOS] Provider photo URL found: $providerPhotoURL');
        print('   User can change this photo or continue with it');
      }
      notifyListeners();
    }
  }

  /// Get provider photo URL for display
  String? get providerPhotoURL => _providerPhotoURL;

  /// Check if using provider photo (Google/Apple)
  bool get isUsingProviderPhoto => _providerPhotoURL != null && selectedImage == null;

  /// Pick image from gallery
  Future<void> pickImageFromGallery() async {
    await handleAsync(() async {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        selectedImage = kIsWeb ? pickedFile : File(pickedFile.path);
        // Clear provider photo URL when user picks a new image
        _providerPhotoURL = null;
        notifyListeners();
      }
    }, 
    errorMessage: AppStrings.failtouploadimage,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }

  /// Pick image from camera
  Future<void> pickImageFromCamera() async {
    await handleAsync(() async {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        selectedImage = kIsWeb ? pickedFile : File(pickedFile.path);
        // Clear provider photo URL when user picks a new image
        _providerPhotoURL = null;
        notifyListeners();
      }
    }, 
    errorMessage: AppStrings.failedtotakephoto,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }

  /// Reset image
  void clearImage() {
    selectedImage = null;
    notifyListeners();
  }

  /// Continue to next screen
  Future<void> continueToNext() async {
    await handleAsync(() async {
      // Store profile image in signup data service
      if (selectedImage != null) {
        // User selected/changed the image - store the file
        _signupDataService.setProfileImage(selectedImage);
      } else if (_providerPhotoURL != null && _providerPhotoURL!.isNotEmpty) {
        // User is using provider photo - store the URL
        // The URL will be used later to download and upload to Storage
        _signupDataService.setProfileImage(_providerPhotoURL);
      } else {
        // No image selected - store null
        _signupDataService.setProfileImage(null);
      }

      if (kDebugMode) {
        print('📸 [SIGNUP] Upload photos screen completed');
        print('   Current Route: ${AppRoutes.photoUpload}');
        print('   Image selected: ${selectedImage != null}');
        print('   Provider photo URL: $_providerPhotoURL');
        print('   Navigating to: ${AppRoutes.signup}');
      }

      // Navigate to phone number screen
      _navigationService.navigateTo(AppRoutes.signup);
    }, 
    errorMessage: AppStrings.faildtocontiue,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }

  /// Skip photo upload
  Future<void> skipPhotoUpload() async {
    await handleAsync(() async {
      // Store null if user skips photo upload
      _signupDataService.setProfileImage(null);
      _providerPhotoURL = null; // Clear provider photo URL
      selectedImage = null;
      
      if (kDebugMode) {
        print('📸 [SIGNUP] Upload photos screen - skipped');
        print('   Current Route: ${AppRoutes.photoUpload}');
        print('   Navigating to: ${AppRoutes.signup}');
      }
      
      // Navigate to phone number screen
      _navigationService.navigateTo(AppRoutes.signup);
    }, 
    errorMessage: AppStrings.faildtocontiue,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }

  /// Clear signup data (called when user cancels/goes back)
  void clearSignupData() {
    _signupDataService.clearCredentials();
    selectedImage = null;
    _providerPhotoURL = null;
    if (kDebugMode) {
      print('🗑️ [UPLOAD PHOTOS] Signup data cleared (user cancelled)');
    }
  }
}
