import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/signup_data_service.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../shared/extensions/context_extensions.dart';

class WelcomeViewModel extends BaseViewModel {
  bool _isLoading = false;
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final StorageService _storageService = locator<StorageService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final SignupDataService _signupDataService = SignupDataService();

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    setLoading(true);

    try {
      // Get Google credentials WITHOUT signing in
      final credentialsData = await _authService.getGoogleCredentials();
      
      if (credentialsData == null) {
        // User cancelled the sign-in
        if (kDebugMode) {
          print("ℹ️ [LOGIN] Google Sign-In cancelled by user");
        }
        setLoading(false);
        return;
      }

      final credential = credentialsData['credential'] as AuthCredential;
      final email = credentialsData['email'] as String?;
      final displayName = credentialsData['displayName'] as String?;
      final photoURL = credentialsData['photoURL'] as String?;

      if (email == null || email.isEmpty) {
        setError('Unable to get email from Google account. Please try again.');
        setLoading(false);
        return;
      }

      // At this point, email is guaranteed to be non-null
      final userEmail = email;
      
      if (kDebugMode) {
        print("🔍 [LOGIN] Checking if user exists with email: $userEmail");
      }

      // Check if user already exists in Firestore
      final userExists = await _firestoreService.checkUserExistsByEmail(userEmail);

      if (userExists) {
        // Returning user - sign in and navigate to Festivals
        if (kDebugMode) {
          print("✅ [LOGIN] Returning user found, signing in...");
        }
        
        final userCredential = await _authService.signInWithCredential(credential);
        final user = userCredential.user;
        
        if (user != null) {
          // Save login state to storage
          await _storageService.setLoggedIn(true, userId: user.uid);
          if (kDebugMode) {
            print('✅ [LOGIN] Google Sign-In successful (returning user)');
            print('   User ID: ${user.uid}');
            print('   Email: ${user.email}');
            print('   Navigating to: ${AppRoutes.festivals}');
          }
          
          // Navigate to festival screen
          _navigationService.navigateTo(AppRoutes.festivals);
        }
      } else {
        // First-time user - store credentials and navigate to Photo Upload
        if (kDebugMode) {
          print("🆕 [LOGIN] New user detected, starting signup flow...");
          print("   Email: $userEmail");
          print("   Display Name: $displayName");
          print("   Photo URL: $photoURL");
          print("   Navigating to: ${AppRoutes.photoUpload}");
        }

        // Store Google credential and user data in SignupDataService
        _signupDataService.setGoogleCredential(
          credential: credential,
          email: userEmail,
          displayName: displayName,
          photoURL: photoURL,
        );

        // Navigate to Photo Upload screen (first step of signup flow)
        _navigationService.navigateTo(AppRoutes.photoUpload);
      }
    } catch (error) {
      if (kDebugMode) {
        print("❌ [LOGIN] Google Sign-In Error: $error");
      }
      // Clear any stored data on error
      _signupDataService.clearCredentials();
      // Error handling is done by the global error handler
      setError('Failed to sign in with Google. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  Future<void> loginWithEmail() async {
    _navigationService.navigateTo(AppRoutes.username);
  }

  Future<void> loginWithApple() async {
    setLoading(true);

    try {
      // Get Apple credentials WITHOUT signing in
      final credentialsData = await _authService.getAppleCredentials();
      
      if (credentialsData == null) {
        // User cancelled the sign-in
        if (kDebugMode) {
          print("ℹ️ [LOGIN] Apple Sign-In cancelled by user");
        }
        setLoading(false);
        return;
      }

      final credential = credentialsData['credential'] as AuthCredential;
      final email = credentialsData['email'] as String?;
      final displayName = credentialsData['displayName'] as String?;
      final photoURL = credentialsData['photoURL'] as String?;

      // Note: Apple may not provide email on subsequent sign-ins
      // If email is null, we need to handle it differently
      if (email == null || email.isEmpty) {
        // Try to sign in to get email from Firebase Auth
        // This happens when user has already signed in with Apple before
        try {
          final userCredential = await _authService.signInWithCredential(credential);
          final user = userCredential.user;
          
          if (user != null && user.email != null) {
            // Check if user exists in Firestore
            final userExists = await _firestoreService.checkUserExistsByEmail(user.email!);
            
            if (userExists) {
              // Returning user
              await _storageService.setLoggedIn(true, userId: user.uid);
              if (kDebugMode) {
                print('✅ [LOGIN] Apple Sign-In successful (returning user)');
                print('   User ID: ${user.uid}');
                print('   Email: ${user.email}');
              }
              _navigationService.navigateTo(AppRoutes.festivals);
              setLoading(false);
              return;
            } else {
              // New user but email not provided by Apple
              // Sign out and show error
              await _authService.signOut();
              setError('Unable to get email from Apple account. Please try again or use email signup.');
              setLoading(false);
              return;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print("⚠️ [LOGIN] Error during Apple credential check: $e");
          }
          setError('Unable to verify Apple account. Please try again.');
          setLoading(false);
          return;
        }
      }

      // At this point, email is guaranteed to be non-null
      // (we would have returned earlier if it was null)
      final userEmail = email!;
      
      if (kDebugMode) {
        print("🔍 [LOGIN] Checking if user exists with email: $userEmail");
      }

      // Check if user already exists in Firestore
      final userExists = await _firestoreService.checkUserExistsByEmail(userEmail);

      if (userExists) {
        // Returning user - sign in and navigate to Festivals
        if (kDebugMode) {
          print("✅ [LOGIN] Returning user found, signing in...");
        }
        
        final userCredential = await _authService.signInWithCredential(credential);
        final user = userCredential.user;
        
        if (user != null) {
          // Save login state to storage
          await _storageService.setLoggedIn(true, userId: user.uid);
          if (kDebugMode) {
            print('✅ [LOGIN] Apple Sign-In successful (returning user)');
            print('   User ID: ${user.uid}');
            print('   Email: ${user.email}');
            print('   Navigating to: ${AppRoutes.festivals}');
          }
          
          // Navigate to festival screen
          _navigationService.navigateTo(AppRoutes.festivals);
        }
      } else {
        // First-time user - store credentials and navigate to Photo Upload
        if (kDebugMode) {
          print("🆕 [LOGIN] New user detected, starting signup flow...");
          print("   Email: $userEmail");
          print("   Display Name: $displayName");
          print("   Photo URL: $photoURL");
          print("   Navigating to: ${AppRoutes.photoUpload}");
        }

        // Store Apple credential and user data in SignupDataService
        _signupDataService.setAppleCredential(
          credential: credential,
          email: userEmail,
          displayName: displayName,
          photoURL: photoURL,
        );

        // Navigate to Photo Upload screen (first step of signup flow)
        _navigationService.navigateTo(AppRoutes.photoUpload);
      }
    } catch (error) {
      if (kDebugMode) {
        print("❌ [LOGIN] Apple Sign-In Error: $error");
      }
      // Clear any stored data on error
      _signupDataService.clearCredentials();
      // Error handling is done by the global error handler
      setError('Failed to sign in with Apple. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  void goToSignup() {
    _navigationService.navigateTo(AppRoutes.signupEmail);
  }
}
