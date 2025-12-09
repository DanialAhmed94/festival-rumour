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

  /// Getter to check if image is picked
  bool get hasImage => selectedImage != null;

  /// Pick image from gallery
  Future<void> pickImageFromGallery() async {
    await handleAsync(() async {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        selectedImage = kIsWeb ? pickedFile : File(pickedFile.path);
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
        // Store the image file directly (will be uploaded when user is created)
        _signupDataService.setProfileImage(selectedImage);
      }

      if (kDebugMode) {
        print('📸 [SIGNUP] Upload photos screen completed');
        print('   Current Route: ${AppRoutes.photoUpload}');
        print('   Image selected: ${selectedImage != null}');
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
}
