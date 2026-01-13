import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/signup_data_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/exceptions/exception_mapper.dart';

class InterestsViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final SignupDataService _signupDataService = SignupDataService();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final StorageService _storageService = locator<StorageService>();

  final List<String> categories = [
    AppStrings.culture,
    AppStrings.food,
    AppStrings.music,
    AppStrings.meetPeople,
    AppStrings.socialsOnWeekends,
    AppStrings.comedy,
    AppStrings.dance,
    AppStrings.art,
  ];

  final Set<String> _selected = {};
  Set<String> get selected => Set.unmodifiable(_selected);

  bool isSelected(String category) => _selected.contains(category);

  void toggle(String category) {
    if (_selected.contains(category)) {
      _selected.remove(category);
    } else {
      _selected.add(category);
    }
    notifyListeners();
  }

  bool get hasSelection => _selected.isNotEmpty;

  /// Save interests and create Firebase user with all collected data
  Future<void> saveInterests() async {
    await handleAsync(
      () async {
        // Store interests
        _signupDataService.setInterests(_selected.toList());

        if (kDebugMode) {
          print('🎯 [SIGNUP] Interest screen - saving interests');
          print('   Current Route: ${AppRoutes.interest}');
          print('   Selected Interests: ${_selected.toList()}');
          print('   Creating Firebase user...');
        }

        // Now create Firebase user with all collected data
        await _createUserWithAllData();

        if (kDebugMode) {
          print('✅ [SIGNUP] User creation completed');
          print('   Navigating to: ${AppRoutes.festivals}');
        }

        // Navigate to next screen
        _navigationService.navigateTo(AppRoutes.festivals);
      },
      onException: (exception) {
        // Handle specific exception types if needed
        _handleUserCreationException(exception);
      },
      onError: (errorMessage) {
        // Error message is already set by handleAsync
        // Additional error handling can be added here if needed
      },
    );
  }

  /// Skip interests but still create Firebase user with collected data
  Future<void> skipInterests() async {
    await handleAsync(
      () async {
        // Store empty interests
        _signupDataService.setInterests([]);

        if (kDebugMode) {
          print('🎯 [SIGNUP] Interest screen - skipping interests');
          print('   Current Route: ${AppRoutes.interest}');
          print('   Creating Firebase user...');
        }

        // Create Firebase user with all collected data (without interests)
        await _createUserWithAllData();

        if (kDebugMode) {
          print('✅ [SIGNUP] User creation completed');
          print('   Navigating to: ${AppRoutes.festivals}');
        }

        // Navigate to next screen
        _navigationService.navigateTo(AppRoutes.festivals);
      },
      onException: (exception) {
        // Handle specific exception types if needed
        _handleUserCreationException(exception);
      },
      onError: (errorMessage) {
        // Error message is already set by handleAsync
        // Additional error handling can be added here if needed
      },
    );
  }

  /// Create Firebase user with all collected signup data
  /// All exceptions are handled by the centralized error handling system
  Future<void> _createUserWithAllData() async {
    // Get all stored signup data
    final email = _signupDataService.email;
    final password = _signupDataService.password;
    final phoneNumber = _signupDataService.phoneNumber;
    final displayName = _signupDataService.displayName;
    final interests = _signupDataService.interests;
    final profileImage = _signupDataService.profileImage;

    // Check if this is Google/Apple OAuth flow
    final isOAuthFlow = _signupDataService.isOAuthFlow;
    final storedCredential = _signupDataService.storedCredential;
    final providerType = _signupDataService.providerType;

    UserCredential? userCredential;
    User? user;

    if (isOAuthFlow && storedCredential != null) {
      // Google/Apple OAuth flow - sign in with stored credential
      if (kDebugMode) {
        print('🔐 [SIGNUP] Creating user via OAuth flow ($providerType)');
        print('   Email: $email');
        print('   Display Name: $displayName');
      }

      if (email == null || email.isEmpty) {
        throw ValidationException(
          message: 'Email is required. Please start signup again.',
          code: 'MISSING_REQUIRED_FIELDS',
        );
      }

      // Sign in to Firebase Auth with stored credential
      userCredential = await _authService.signInWithCredential(
        storedCredential,
      );

      // Validate user creation was successful
      if (userCredential.user == null) {
        throw UnknownException(
          message: 'Failed to create user account. Please try again.',
        );
      }

      user = userCredential.user!;
    } else {
      // Email/Password flow - create new user
      if (kDebugMode) {
        print('🔐 [SIGNUP] Creating user via Email/Password flow');
        print('   Email: $email');
      }

      // Validate required data - use ValidationException for validation errors
      if (email == null || password == null) {
        throw ValidationException(
          message:
              'Email and password are required. Please start signup again.',
          code: 'MISSING_REQUIRED_FIELDS',
        );
      }

      // Create Firebase user account with email/password
      // This will throw AppException (mapped by ExceptionMapper) if there's an error
      // The exception will be handled by handleAsync's centralized error handler
      userCredential = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      // Validate user creation was successful
      if (userCredential?.user == null) {
        throw UnknownException(
          message: 'Failed to create user account. Please try again.',
        );
      }

      user = userCredential!.user!;
    }

    // Update user profile with collected data
    // These operations will throw AppException if they fail
    // All exceptions will be handled by the centralized error handler
    if (displayName != null && displayName.isNotEmpty) {
      await _authService.updateDisplayName(displayName);
    }

    // Upload profile image if available and get photo URL
    String? photoUrl;
    if (profileImage != null) {
      try {
        // Check if profileImage is a URL string (from Google/Apple provider)
        if (profileImage is String &&
            (profileImage.startsWith('http://') ||
                profileImage.startsWith('https://'))) {
          // Provider photo URL - download it first, then upload to Storage
          if (kDebugMode) {
            print(
              '📥 [SIGNUP] Downloading provider photo from URL: $profileImage',
            );
          }

          try {
            // Use dio to download the image (already in dependencies)
            final dio = Dio();
            final response = await dio.get<List<int>>(
              profileImage,
              options: Options(responseType: ResponseType.bytes),
            );

            if (response.data != null) {
              // Get temporary directory
              final tempDir = await getTemporaryDirectory();
              final filePath =
                  '${tempDir.path}/provider_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final file = File(filePath);

              // Write downloaded bytes to file
              await file.writeAsBytes(response.data!);

              if (kDebugMode) {
                print('✅ [SIGNUP] Provider photo downloaded successfully');
              }

              // Now upload to Firebase Storage
              final originalSize = await file.length();
              if (kDebugMode) {
                print(
                  '📸 [SIGNUP] Original image size: ${(originalSize / 1024).toStringAsFixed(2)} KB',
                );
              }

              // Compress image to 70% quality before upload
              final compressedFile = await _compressImage(file, quality: 70);

              if (compressedFile != null) {
                if (kDebugMode) {
                  final compressedSize = await compressedFile.length();
                  print(
                    '📸 [SIGNUP] Compressed image size: ${(compressedSize / 1024).toStringAsFixed(2)} KB',
                  );
                }
                photoUrl = await _authService.uploadProfilePhoto(
                  compressedFile,
                );
              } else {
                // If compression fails, upload original image
                photoUrl = await _authService.uploadProfilePhoto(file);
              }

              if (photoUrl != null) {
                await _authService.updateProfilePhoto(photoUrl);
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                '⚠️ [SIGNUP] Error downloading provider photo, will use URL directly: $e',
              );
            }
            // If download fails, use the URL directly (store it in Firestore)
            photoUrl = profileImage as String;
          }
        } else {
          // Regular file upload (from gallery/camera)
          File? imageFile;
          if (profileImage is File) {
            imageFile = profileImage as File;
          } else if (kIsWeb && profileImage is XFile) {
            // For web, we might need to handle XFile differently
            // For now, skip upload on web or convert XFile to File
            // TODO: Handle web image upload
          }

          if (imageFile != null) {
            if (kDebugMode) {
              final originalSize = await imageFile.length();
              print(
                '📸 [SIGNUP] Original image size: ${(originalSize / 1024).toStringAsFixed(2)} KB',
              );
            }

            // Compress image to 70% quality before upload
            final compressedFile = await _compressImage(imageFile, quality: 70);

            if (compressedFile != null) {
              if (kDebugMode) {
                final compressedSize = await compressedFile.length();
                print(
                  '📸 [SIGNUP] Compressed image size: ${(compressedSize / 1024).toStringAsFixed(2)} KB',
                );
                print(
                  '   Compression ratio: ${((1 - compressedSize / await imageFile.length()) * 100).toStringAsFixed(1)}%',
                );
              }

              // Upload compressed profile photo to Firebase Storage
              photoUrl = await _authService.uploadProfilePhoto(compressedFile);
              if (photoUrl != null) {
                // Update user profile with photo URL
                await _authService.updateProfilePhoto(photoUrl);
              }
            } else {
              // If compression fails, upload original image
              if (kDebugMode) {
                print(
                  '⚠️ [SIGNUP] Image compression failed, uploading original image',
                );
              }
              photoUrl = await _authService.uploadProfilePhoto(imageFile);
              if (photoUrl != null) {
                await _authService.updateProfilePhoto(photoUrl);
              }
            }
          }
        }
      } catch (e, stackTrace) {
        // Profile image upload is optional, log but don't fail the entire signup
        // Map the exception for logging but don't throw
        final exception = ExceptionMapper.mapToAppException(e, stackTrace);
        // Log the error but continue - profile image upload is optional
        // The centralized error handler will log this if needed
        if (kDebugMode) {
          print('❌ [SIGNUP] Error uploading profile image: $e');
        }
      }
    }

    // Link phone number if available
    // Note: Firebase requires phone number to be verified before linking
    // Since we already verified it during OTP, we can link it here
    // Phone linking is optional - if it fails, we continue without it
    if (phoneNumber != null) {
      try {
        // TODO: Link verified phone number to user account
        // This requires the PhoneAuthCredential from OTP verification
        // You may need to store the credential in SignupDataService
        // await user.linkWithCredential(phoneCredential);
      } catch (e, stackTrace) {
        // Phone linking is optional, log but don't fail the entire signup
        // Map the exception for logging but don't throw
        final exception = ExceptionMapper.mapToAppException(e, stackTrace);
        // Log the error but continue - phone linking is optional
        // The centralized error handler will log this if needed
      }
    }

    // Save all user data to Firestore
    // For OAuth flow, password will be null (not applicable)
    // App identifier 'festivalrumor' will be added to differentiate users
    // postCount will be initialized to 0
    await _firestoreService.saveUserData(
      userId: user.uid,
      email: email!,
      password:
          password ??
          '', // Will be hashed in FirestoreService (empty string for OAuth)
      displayName: displayName,
      phoneNumber: phoneNumber,
      interests: interests,
      photoUrl: photoUrl,
    );

    // Add user to all existing public chat rooms
    // This is non-blocking - if it fails, signup still succeeds
    // User will be automatically added to all public chat rooms
    await _firestoreService.addUserToAllPublicChatRooms(user.uid);

    // Save login status after successful user creation and Firestore save
    await _storageService.setLoggedIn(true, userId: user.uid);

    // Clear stored signup data after successful creation and Firestore save
    // Only clear if everything succeeded
    _signupDataService.clearAllData();
  }

  /// Compress image to specified quality percentage (0-100)
  /// For 70% compression, reduces file size to approximately 30% of original
  /// Returns compressed File or null if compression fails
  Future<File?> _compressImage(File imageFile, {int quality = 70}) async {
    try {
      if (kIsWeb) {
        // Web doesn't support File compression the same way
        // Return original file for web
        return imageFile;
      }

      // Read original image bytes
      final Uint8List originalBytes = await imageFile.readAsBytes();
      final originalSize = originalBytes.length;

      if (kDebugMode) {
        print('📸 [COMPRESSION] Starting image compression');
        print(
          '   Original size: ${(originalSize / 1024).toStringAsFixed(2)} KB',
        );
        print(
          '   Target compression: $quality% (reduce to ${100 - quality}% of original)',
        );
      }

      // Decode original image to get dimensions
      final originalCodec = await ui.instantiateImageCodec(originalBytes);
      final originalFrame = await originalCodec.getNextFrame();
      final originalImage = originalFrame.image;

      // Calculate target dimensions to achieve ~70% compression
      // Compression ratio: For 70% compression, we want ~30% of original file size
      // Resizing to ~55% of original dimensions typically achieves this
      final compressionRatio = (100 - quality) / 100; // 0.3 for 70% compression
      final dimensionScale = compressionRatio.clamp(
        0.4,
        0.9,
      ); // Scale between 40% and 90%

      final targetWidth = (originalImage.width * dimensionScale).round().clamp(
        400,
        1200,
      );
      final targetHeight = (originalImage.height * dimensionScale)
          .round()
          .clamp(400, 1200);

      if (kDebugMode) {
        print(
          '   Original dimensions: ${originalImage.width}x${originalImage.height}',
        );
        print('   Target dimensions: ${targetWidth}x${targetHeight}');
      }

      // Decode and resize image
      final codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final resizedImage = frame.image;

      // Get temporary directory for compressed file
      final tempDir = await getTemporaryDirectory();
      final compressedPath =
          '${tempDir.path}/compressed_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(compressedPath);

      // Convert resized image to PNG format (good compression)
      final byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        if (kDebugMode) {
          print('⚠️ Failed to convert image to byte data');
        }
        return null;
      }

      final compressedBytes = byteData.buffer.asUint8List();
      await compressedFile.writeAsBytes(compressedBytes);

      final compressedSize = compressedBytes.length;
      final actualCompression = ((1 - compressedSize / originalSize) * 100);

      if (kDebugMode) {
        print('✅ [COMPRESSION] Image compression completed');
        print(
          '   Compressed size: ${(compressedSize / 1024).toStringAsFixed(2)} KB',
        );
        print(
          '   Actual compression: ${actualCompression.toStringAsFixed(1)}%',
        );
        print(
          '   Size reduction: ${((originalSize - compressedSize) / 1024).toStringAsFixed(2)} KB',
        );
      }

      // Clean up original image resources
      originalImage.dispose();
      resizedImage.dispose();

      return compressedFile;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error compressing image: $e');
        print('   StackTrace: $stackTrace');
      }
      return null;
    }
  }

  /// Handle user creation exceptions with specific error messages
  void _handleUserCreationException(AppException exception) {
    // The centralized error handler has already logged the error
    // Here we can add specific handling if needed (e.g., show specific UI, retry logic, etc.)

    // All exceptions are already handled by handleAsync:
    // - NetworkException -> Shows network error message
    // - AuthException -> Shows auth error message (email-already-in-use, weak-password, etc.)
    // - ValidationException -> Shows validation error message
    // - UnknownException -> Shows generic error message

    // Additional specific handling can be added here if needed
    // For example, you might want to show a different message for specific error codes
    if (exception is AuthException) {
      switch (exception.code) {
        case 'email-already-in-use':
          // Email was taken between check and creation - rare but possible
          // Error message is already set by handleAsync
          break;
        case 'weak-password':
          // Password validation failed
          // Error message is already set by handleAsync
          break;
        default:
          // Other auth errors - already handled
          break;
      }
    } else if (exception is NetworkException) {
      // Network errors - already handled with user-friendly messages
      // Could add retry logic here if needed
    }
  }
}
