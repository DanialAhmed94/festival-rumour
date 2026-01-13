import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/di/locator.dart';
import '../../../core/constants/app_strings.dart';
import 'package:http/http.dart' as http;

class EditAccountViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = locator<AuthService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final StorageService _storageService = locator<StorageService>();
  final ImagePicker _picker = ImagePicker();

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Focus nodes for personal information fields
  final FocusNode nameFocus = FocusNode();
  final FocusNode bioFocus = FocusNode();

  // Focus nodes for password fields
  final FocusNode currentPasswordFocus = FocusNode();
  final FocusNode newPasswordFocus = FocusNode();
  final FocusNode confirmPasswordFocus = FocusNode();

  // Form validation
  final GlobalKey<FormState> formKey =
      GlobalKey<FormState>(); // For personal information
  final GlobalKey<FormState> passwordFormKey =
      GlobalKey<FormState>(); // For password section

  // UI state
  bool isPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  // Profile image
  String? profileImageUrl; // Firebase Storage URL
  File? profileImageFile; // Local file for new upload
  String? profileImagePath; // Keep for backward compatibility

  // Original user data for restoration
  String? _originalName;
  String? _originalBio;
  String? _originalPhone;

  // Success message for snackbar
  String? _successMessage;
  String? get successMessage => _successMessage;

  /// Clear success message
  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  // Preferences
  String selectedLanguage = "English";
  String selectedTimezone = "UTC";
  bool emailNotifications = true;
  bool pushNotifications = true;

  EditAccountViewModel() {
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    emailController.dispose();
    phoneController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    nameFocus.dispose();
    bioFocus.dispose();
    currentPasswordFocus.dispose();
    newPasswordFocus.dispose();
    confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    await handleAsync(() async {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('⚠️ No user logged in');
        }
        return;
      }

      // Load user data from Firestore
      final userData = await _firestoreService.getUserData(currentUser.uid);

      // Set name and store original
      if (userData != null && userData['displayName'] != null) {
        nameController.text = userData['displayName'] as String;
        _originalName = userData['displayName'] as String;
      } else if (currentUser.displayName != null) {
        nameController.text = currentUser.displayName!;
        _originalName = currentUser.displayName!;
      }

      // Set bio and store original
      if (userData != null && userData['bio'] != null) {
        bioController.text = userData['bio'] as String;
        _originalBio = userData['bio'] as String;
      }

      // Set email (read-only)
      if (currentUser.email != null) {
        emailController.text = currentUser.email!;
      }

      // Set phone and store original
      if (userData != null && userData['phoneNumber'] != null) {
        phoneController.text = userData['phoneNumber'] as String;
        _originalPhone = userData['phoneNumber'] as String;
      } else if (currentUser.phoneNumber != null) {
        phoneController.text = currentUser.phoneNumber!;
        _originalPhone = currentUser.phoneNumber!;
      }

      // Set profile image URL
      if (userData != null && userData['photoUrl'] != null) {
        profileImageUrl = userData['photoUrl'] as String;
        profileImagePath = profileImageUrl; // For backward compatibility
      } else if (currentUser.photoURL != null) {
        profileImageUrl = currentUser.photoURL;
        profileImagePath = profileImageUrl;
      }

      notifyListeners();
    }, errorMessage: 'Failed to load user data');
  }

  // Form validation methods
  String? validateName(String? value) {
    // Allow empty
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length < 2) {
      return AppStrings.usernameMinLength;
    }
    // Allow letters only OR combination of letters and numbers, no special characters
    if (!RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and numbers';
    }
    // Must contain at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Name must contain at least one letter';
    }
    return null;
  }

  // Focus navigation methods
  void handleNameSubmitted() {
    bioFocus.requestFocus();
  }

  void handleBioSubmitted() {
    bioFocus.unfocus();
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.emailRequired;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
      return AppStrings.mustBePhone;
    }
    return null;
  }

  String? validateCurrentPassword(String? value) {
    // Required when changing password
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    return null;
  }

  String? validateNewPassword(String? value) {
    // Required when changing password
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value.length < 6) {
      return AppStrings.passwordMinLength;
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    // Required when changing password
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value != newPasswordController.text) {
      return AppStrings.passwordsDoNotMatch;
    }
    return null;
  }

  String? validateBio(String? value) {
    if (value != null && value.length > 500) {
      return AppStrings.bioTooLong;
    }
    return null;
  }

  String? validateWebsite(String? value) {
    if (value != null && value.isNotEmpty) {
      if (!RegExp(r'^https?://').hasMatch(value)) {
        return AppStrings.websiteInvalidFormat;
      }
    }
    return null;
  }

  // UI state methods
  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  void toggleNewPasswordVisibility() {
    isNewPasswordVisible = !isNewPasswordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible = !isConfirmPasswordVisible;
    notifyListeners();
  }

  // Focus navigation methods
  void focusCurrentPassword() {
    currentPasswordFocus.requestFocus();
  }

  void focusNewPassword() {
    newPasswordFocus.requestFocus();
  }

  void focusConfirmPassword() {
    confirmPasswordFocus.requestFocus();
  }

  void handleCurrentPasswordSubmitted() {
    if (currentPasswordController.text.isNotEmpty) {
      focusNewPassword();
    }
  }

  void handleNewPasswordSubmitted() {
    if (newPasswordController.text.isNotEmpty) {
      focusConfirmPassword();
    }
  }

  void handleConfirmPasswordSubmitted() {
    confirmPasswordFocus.unfocus();
  }

  // Action methods
  Future<void> pickProfileImageFromCamera() async {
    await handleAsync(
      () async {
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          profileImageFile = File(pickedFile.path);
          profileImagePath = pickedFile.path; // For backward compatibility
          notifyListeners();
          // Don't upload immediately - wait for save button
        } else {
          // User cancelled - not an error, just return
          return;
        }
      },
      showLoading: false, // Don't show loading for image picker
      errorMessage: 'Failed to pick image from camera. Please try again.',
    );
  }

  Future<void> pickProfileImageFromGallery() async {
    await handleAsync(
      () async {
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          profileImageFile = File(pickedFile.path);
          profileImagePath = pickedFile.path; // For backward compatibility
          notifyListeners();
          // Don't upload immediately - wait for save button
        } else {
          // User cancelled - not an error, just return
          return;
        }
      },
      showLoading: false, // Don't show loading for image picker
      errorMessage: 'Failed to pick image from gallery. Please try again.',
    );
  }

  Future<void> uploadProfilePicture() async {
    if (profileImageFile == null) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('No user logged in');
    }

    // Upload to Firebase Storage
    final photoUrl = await _authService.uploadProfilePhoto(profileImageFile!);

    if (photoUrl == null) {
      throw Exception('Failed to upload profile picture. Please try again.');
    }

    // Update Firebase Auth profile
    await _authService.updateProfilePhoto(photoUrl);

    // Update Firestore user data
    await _firestoreService.updateUserData(
      userId: currentUser.uid,
      photoUrl: photoUrl,
    );

    // Update local state
    profileImageUrl = photoUrl;
    profileImagePath = photoUrl;
    profileImageFile = null; // Clear local file after upload
    notifyListeners();

    if (kDebugMode) {
      print('✅ Profile picture uploaded successfully: $photoUrl');
    }
  }

  Future<void> saveChanges() async {
    // Validate form first - this will show errors on screen
    if (!formKey.currentState!.validate()) {
      if (kDebugMode) {
        print('❌ [EditAccount] Form validation failed');
      }
      setError('Please fix the validation errors before saving');
      return;
    }

    // Additional validation check (backup)
    if (nameController.text.isNotEmpty) {
      final nameError = validateName(nameController.text);
      if (nameError != null) {
        if (kDebugMode) {
          print('❌ [EditAccount] Validation failed: $nameError');
        }
        setError(nameError);
        return;
      }
    }

    // Use original name if field is empty
    final nameToSave =
        nameController.text.isEmpty && _originalName != null
            ? _originalName!
            : nameController.text;

    if (kDebugMode) {
      print('📝 [EditAccount] Proceeding with save, nameToSave: "$nameToSave"');
    }

    await handleAsync(
      () async {
        final currentUser = _authService.currentUser;
        if (currentUser == null) {
          throw Exception('No user logged in. Please sign in again.');
        }

        // Upload profile picture if there's a new one
        if (profileImageFile != null) {
          try {
            await uploadProfilePicture();
          } catch (e) {
            // Re-throw with more context
            throw Exception(
              'Failed to upload profile picture: ${e.toString()}',
            );
          }
        }

        // Update display name in Firebase Auth
        if (nameToSave.isNotEmpty) {
          try {
            await _authService.updateDisplayName(nameToSave);
          } catch (e) {
            // Re-throw with more context
            throw Exception('Failed to update display name: ${e.toString()}');
          }
        }

        // Update user data in Firestore
        try {
          await _firestoreService.updateUserData(
            userId: currentUser.uid,
            displayName: nameToSave.isNotEmpty ? nameToSave : null,
            phoneNumber:
                phoneController.text.isNotEmpty ? phoneController.text : null,
            additionalData: {
              'bio': bioController.text.isNotEmpty ? bioController.text : null,
            },
          );
        } catch (e) {
          // Re-throw with more context
          throw Exception('Failed to update user data: ${e.toString()}');
        }

        // Update original values after successful save
        _originalName = nameToSave;
        _originalBio = bioController.text;
        _originalPhone = phoneController.text;

        // Set success message
        _successMessage = 'Profile updated successfully';
        notifyListeners();

        if (kDebugMode) {
          print('✅ User data saved successfully');
        }
      },
      errorMessage:
          'Failed to save changes. Please check your connection and try again.',
    );
  }

  Future<void> changePassword() async {
    // Form validation is already done in the view before calling this method
    // Additional validation checks
    if (currentPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setError('Please fill in all password fields');
      // Trigger form validation to show errors on screen
      passwordFormKey.currentState?.validate();
      return;
    }

    // Validate passwords match
    if (newPasswordController.text != confirmPasswordController.text) {
      setError('New passwords do not match');
      passwordFormKey.currentState?.validate();
      return;
    }

    // Validate new password meets requirements
    final passwordError = validateNewPassword(newPasswordController.text);
    if (passwordError != null) {
      setError(passwordError);
      passwordFormKey.currentState?.validate();
      return;
    }

    // Validate new password is different from current
    if (currentPasswordController.text == newPasswordController.text) {
      setError('New password must be different from current password');
      passwordFormKey.currentState?.validate();
      return;
    }

    await handleAsync(() async {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in. Please sign in again.');
      }

      // Check if user has email/password provider
      // Users who signed up with Google/Apple don't have passwords
      final hasEmailPassword = currentUser.providerData.any(
        (provider) => provider.providerId == 'password',
      );

      if (!hasEmailPassword) {
        throw Exception(
          'Password change is only available for users who signed up with email and password. You signed up with a social account (Google/Apple).',
        );
      }

      // Get user email for re-authentication
      // Use the exact email from the user's provider data to ensure consistency
      final userEmail = currentUser.email;
      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('User email not found. Cannot change password.');
      }

      if (kDebugMode) {
        print('🔐 [Password Change] Re-authenticating with email: $userEmail');
        print(
          '   User providers: ${currentUser.providerData.map((p) => p.providerId).toList()}',
        );
      }

      // Step 1: Re-authenticate user with current password
      // This confirms the user knows their current password
      // This uses the same email/password that was used during signup
      try {
        await _authService.reauthenticateWithEmailPassword(
          email: userEmail.trim(), // Trim to handle any whitespace
          password: currentPasswordController.text,
        );

        if (kDebugMode) {
          print('✅ User re-authenticated successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ [Password Change] Re-authentication error: $e');
          print('   Error type: ${e.runtimeType}');
        }

        // Check if it's an AppException with wrong password code
        if (e is AppException) {
          final errorCode = (e.code ?? '').toUpperCase();
          final errorMessage = e.message.toLowerCase();

          if (kDebugMode) {
            print(
              '🔍 [Password Change] AppException - code: $errorCode, message: ${e.message}',
            );
          }

          // Check for wrong password or invalid credential errors
          // Firebase Auth codes: WRONG_PASSWORD, INVALID_CREDENTIAL, etc.
          if (errorCode == 'WRONG_PASSWORD' ||
              errorCode == 'INVALID_CREDENTIAL' ||
              errorCode == 'WRONG-PASSWORD' ||
              errorCode == 'INVALID-CREDENTIAL' ||
              errorMessage.contains('wrong password') ||
              errorMessage.contains('incorrect password') ||
              errorMessage.contains('invalid password') ||
              errorMessage.contains('invalid credential') ||
              errorMessage.contains('invalid email or password') ||
              errorMessage.contains('the password is invalid') ||
              errorMessage.contains('password is incorrect')) {
            // Re-throw with clear error message - this will be caught by handleAsync
            if (kDebugMode) {
              print(
                '🚫 [Password Change] Wrong password detected - throwing error',
              );
            }
            throw AuthException(
              message: 'Current password is incorrect. Please try again.',
              code: 'WRONG_PASSWORD',
            );
          }
        }

        // Check string representation as fallback (for any non-AppException errors)
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('wrong-password') ||
            errorString.contains('invalid-credential') ||
            errorString.contains('user-mismatch') ||
            errorString.contains('incorrect password') ||
            errorString.contains('wrong password') ||
            errorString.contains('invalid password') ||
            errorString.contains('the password is invalid') ||
            errorString.contains('password is incorrect')) {
          if (kDebugMode) {
            print(
              '🚫 [Password Change] Wrong password detected from string - throwing error',
            );
          }
          throw AuthException(
            message: 'Current password is incorrect. Please try again.',
            code: 'WRONG_PASSWORD',
          );
        }

        // Re-throw with user-friendly message for other errors
        // This ensures the error is displayed to the user
        if (kDebugMode) {
          print(
            '⚠️ [Password Change] Other error - re-throwing with generic message',
          );
        }
        throw Exception(
          'Failed to verify current password. Please check your connection and try again.',
        );
      }

      // Step 2: Update password to new password
      // Only after successful re-authentication
      try {
        await _authService.updatePassword(newPasswordController.text);

        if (kDebugMode) {
          print('✅ Password updated successfully');
        }

        // Clear password fields after successful change
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        // Set success message
        _successMessage = '✅ Password updated successfully';
        notifyListeners();

        // Clear success message after a delay
        Future.delayed(const Duration(milliseconds: 100), () {
          _successMessage = null;
          notifyListeners();
        });
      } catch (e) {
        // Re-throw with user-friendly message
        if (e.toString().contains('weak-password')) {
          throw Exception(
            'New password is too weak. Please choose a stronger password.',
          );
        }
        throw Exception('Failed to update password: ${e.toString()}');
      }
    }, errorMessage: 'Failed to change password. Please try again.');
  }

  Future<void> deleteAccountFromServer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final idToken = await user.getIdToken(true);

    final url = Uri.parse(
      'https://us-central1-crapapps-65472.cloudfunctions.net/deleteAuthAccount',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete account: ${response.body}');
    }
  }

  /// Delete user account with proper error handling
  Future<void> deleteAccount() async {
    await handleAsync(() async {
      if (kDebugMode) {
        print('🗑️ [Settings] Starting account deletion process...');
      }

      // 🔐 Get user ID BEFORE deletion
      final userId = _authService.userUid;

      if (userId != null) {
        // 1️⃣ Delete all user posts
        try {
          await _firestoreService.deleteAllUserPosts(userId);
          if (kDebugMode) {
            print('✅ [Settings] User posts deleted');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [Settings] Error deleting posts: $e');
          }
        }

        // 2️⃣ Delete all user jobs
        try {
          await _firestoreService.deleteAllUserJobs(userId);
          if (kDebugMode) {
            print('✅ [Settings] User jobs deleted');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [Settings] Error deleting jobs: $e');
          }
        }

        // 3️⃣ Cleanup chat rooms
        try {
          await _firestoreService.cleanupUserChatRooms(userId);
          if (kDebugMode) {
            print('✅ [Settings] Chat rooms cleaned');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [Settings] Error cleaning chats: $e');
          }
        }

        // 4️⃣ Delete user profile
        try {
          await _firestoreService.deleteUserProfile(userId);
          if (kDebugMode) {
            print('✅ [Settings] User profile deleted');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [Settings] Error deleting profile: $e');
          }
        }
      }

      // 5️⃣ 🔥 DELETE AUTH VIA CLOUD FUNCTION
      await deleteAccountFromServer();

      if (kDebugMode) {
        print('✅ [Settings] Firebase Auth deleted via Cloud Function');
      }

      // 6️⃣ Clear local storage
      await _storageService.clearAll();

      if (kDebugMode) {
        print('✅ [Settings] Local storage cleared');
      }

      // 7️⃣ Navigate to login
      await _navigationService.navigateToLogin();

      if (kDebugMode) {
        print('✅ [Settings] Account deletion completed');
      }
    }, errorMessage: 'Failed to delete account. Please try again.');
  }

  void goBack() {
    _navigationService.pop();
  }

  // Preference methods
  void setLanguage(String? language) {
    if (language != null) {
      selectedLanguage = language;
      notifyListeners();
    }
  }

  void setTimezone(String? timezone) {
    if (timezone != null) {
      selectedTimezone = timezone;
      notifyListeners();
    }
  }

  void setEmailNotifications(bool value) {
    emailNotifications = value;
    notifyListeners();
  }

  void setPushNotifications(bool value) {
    pushNotifications = value;
    notifyListeners();
  }
}
