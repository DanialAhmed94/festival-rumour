import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import '../../../core/services/user_photo_cache_service.dart';
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
      // 1️⃣ Get Google credentials WITHOUT signing in
      final credentialsData = await _authService.getGoogleCredentials();

      if (credentialsData == null) {
        if (kDebugMode) print("ℹ️ [LOGIN] Google Sign-In cancelled by user");
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

      final userEmail = email;

      if (kDebugMode) {
        print("🔍 Checking Firestore for Google user: $userEmail");
      }

      // 2️⃣ Check if Firestore user exists
      final exists = await _firestoreService.checkUserExistsByEmail(userEmail);

      // 3️⃣ Sign in with Google → FirebaseAuth
      final userCredential = await _authService.signInWithCredential(
        credential,
      );
      User? user = userCredential.user;

      if (user == null) {
        setError("Google sign-in failed.");
        setLoading(false);
        return;
      }

      final uid = user.uid;
      print("🔵 Google Logged In → UID = $uid");

      // ---------------------------------------------------------
      // ⭐ 4️⃣ NEW user → update Auth with Google data & start signup
      // ---------------------------------------------------------
      if (!exists) {
        print("🆕 New Google user → starting signup flow");

        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
        if (photoURL != null && photoURL.isNotEmpty) {
          await user.updatePhotoURL(photoURL);
        }
        await user.reload();

        _signupDataService.setGoogleCredential(
          credential: credential,
          email: userEmail,
          displayName: displayName,
          photoURL: photoURL,
        );
        _signupDataService.setEmail(userEmail);
        _signupDataService.setDisplayName(displayName ?? "");
        _signupDataService.setProfileImage(photoURL);

        _navigationService.navigateTo(AppRoutes.photoUpload);
        setLoading(false);
        return;
      }

      // ---------------------------------------------------------
      // ⭐ 5️⃣ Existing user → use Firestore photo (single source of truth),
      //        DON'T overwrite Auth photoURL with the Google provider photo
      // ---------------------------------------------------------
      String? firestorePhotoUrl;
      String? firestoreDisplayName;
      try {
        final userData = await _firestoreService.getUserData(uid);
        if (userData != null) {
          firestorePhotoUrl = userData['photoUrl'] as String?;
          firestoreDisplayName = userData['displayName'] as String?;
        }
      } catch (_) {}

      final photoForStorage = firestorePhotoUrl ?? user.photoURL;
      final nameForStorage = firestoreDisplayName ?? user.displayName;

      // Update the profile cache so every screen sees correct data immediately
      locator<UserPhotoCacheService>().setUserProfile(
        uid,
        photoUrl: photoForStorage,
        displayName: nameForStorage,
      );

      await _storageService.setLoggedIn(
        true,
        userId: uid,
        displayName: nameForStorage,
        photoUrl: photoForStorage,
      );
      await updateFcmTokenForUser();

      print("✅ Returning Google user → navigating to festivals");
      _navigationService.navigateTo(AppRoutes.festivals);
    } catch (error) {
      print("❌ Google Login Error: $error");
      _signupDataService.clearCredentials();
      setError('Failed to sign in with Google. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  static Future<void> updateFcmTokenForUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print("✅ FCM token updated in Firestore");
  }

  Future<void> loginWithEmail() async {
    _navigationService.navigateTo(AppRoutes.username);
  }

  Future<void> loginWithApple() async {
    setLoading(true);

    try {
      // 1️⃣ Get Apple credentials (non-Firebase sign in)
      final credentialsData = await _authService.getAppleCredentials();
      if (credentialsData == null) {
        print("ℹ️ Apple Sign-In cancelled");
        setLoading(false);
        return;
      }

      final credential = credentialsData['credential'] as AuthCredential;
      final displayName = credentialsData['displayName'] as String?;
      final photoURL = credentialsData['photoURL'] as String?;

      // 2️⃣ Sign in to Firebase using Apple credential
      final userCredential = await _authService.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user == null) {
        setError("Apple sign-in failed");
        setLoading(false);
        return;
      }

      final uid = user.uid;
      print("🍎 Apple User UID: $uid");

      // 3️⃣ Check if the UID exists in Firestore
      final exists = await _firestoreService.checkUserExistsByUid(uid);

      if (exists) {
        // Returning user → use Firestore photo (single source of truth),
        // DON'T overwrite Auth photoURL with the Apple provider photo
        String? firestorePhotoUrl;
        String? firestoreDisplayName;
        try {
          final userData = await _firestoreService.getUserData(uid);
          if (userData != null) {
            firestorePhotoUrl = userData['photoUrl'] as String?;
            firestoreDisplayName = userData['displayName'] as String?;
          }
        } catch (_) {}

        final photoForStorage = firestorePhotoUrl ?? user.photoURL;
        final nameForStorage = firestoreDisplayName ?? user.displayName;

        locator<UserPhotoCacheService>().setUserProfile(
          uid,
          photoUrl: photoForStorage,
          displayName: nameForStorage,
        );

        await _storageService.setLoggedIn(
          true,
          userId: uid,
          displayName: nameForStorage,
          photoUrl: photoForStorage,
        );
        await updateFcmTokenForUser();

        print("✅ Existing Apple user → navigating to festivals");
        _navigationService.navigateTo(AppRoutes.festivals);
      } else {
        // NEW user → update Auth with Apple data & start signup
        print("🆕 New Apple user → starting signup");

        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        await user.reload();

        _signupDataService.setAppleCredential(
          credential: credential,
          email: user.email ?? '',
          displayName: displayName,
          photoURL: photoURL,
        );

        _signupDataService.setProfileImage(photoURL);

        _navigationService.navigateTo(AppRoutes.photoUpload);
      }
    } catch (e) {
      print("❌ Apple Login Error: $e");
      _signupDataService.clearCredentials();
      setError("Apple login failed. Try again.");
    } finally {
      setLoading(false);
    }
  }

  // Future<void> loginWithApple() async {
  //   setLoading(true);

  //   try {
  //     // 1️⃣ Ask Apple for credential info (email may be null next time)
  //     final data = await _authService.getAppleCredentials();
  //     if (data == null) {
  //       setLoading(false);
  //       return;
  //     }

  //     final credential = data['credential'] as AuthCredential;
  //     final email = data['email'] as String?;
  //     final displayName = data['displayName'] as String?;
  //     final photoURL = data['photoURL'] as String?; // usually null

  //     // 2️⃣ Sign in to Firebase using Apple credential
  //     final userCredential = await _authService.signInWithCredential(
  //       credential,
  //     );
  //     User? user = userCredential.user;

  //     if (user == null) {
  //       setError("Apple sign-in failed.");
  //       setLoading(false);
  //       return;
  //     }

  //     final uid = user.uid;
  //     print("🍎 Apple Logged In → UID = $uid");

  //     // ----------------------------------------------------
  //     // ⭐ 3️⃣ LOAD & UPDATE FIREBASEAUTH CURRENT USER DATA
  //     // ----------------------------------------------------

  //     // If Apple gave name → update Firebase user
  //     if (displayName != null && displayName.isNotEmpty) {
  //       await user.updateDisplayName(displayName);
  //     }

  //     // If Apple gave email (first login only)
  //     if (email != null && email.isNotEmpty) {
  //       // FirebaseAuth auto-stores Apple email on first login,
  //       // but calling reload ensures _authService.currentUser updates.
  //       print("📩 Updating email: $email");
  //     }

  //     // Apple photoURL is usually null, but update if provided
  //     if (photoURL != null) {
  //       await user.updatePhotoURL(photoURL);
  //     }

  //     // 🔄 Reload user to refresh _authService.currentUser
  //     await user.reload();
  //     user = _authService.currentUser; // Refresh local reference

  //     print("🔥 Updated FirebaseAuth User:");
  //     print("UID: ${user?.uid}");
  //     print("Name: ${user?.displayName}");
  //     print("Email: ${user?.email}");
  //     print("Photo: ${user?.photoURL}");

  //     // ----------------------------------------------------
  //     // ⭐ 4️⃣ CHECK IF USER EXISTS IN FIRESTORE BY UID
  //     // ----------------------------------------------------
  //     final exists = await _firestoreService.checkUserExistsByUid(uid);

  //     if (!exists) {
  //       print("🆕 Creating new Apple user record in Firestore");

  //       await _firestoreService.saveUserData(
  //         userId: uid,
  //         email: email ?? user?.email ?? "",
  //         password: "",
  //         displayName: displayName ?? user?.displayName,
  //         phoneNumber: null,
  //         interests: [],
  //         photoUrl: user?.photoURL,
  //       );
  //     } else {
  //       print("📄 User already exists → No need to create new record");
  //     }

  //     // ----------------------------------------------------
  //     // ⭐ 5️⃣ SAVE LOGIN STATE LOCALLY
  //     // ----------------------------------------------------
  //     await _storageService.setLoggedIn(true, userId: uid);

  //     // ----------------------------------------------------
  //     // ⭐ 6️⃣ NAVIGATE TO FESTIVALS
  //     // ----------------------------------------------------
  //     _navigationService.navigateTo(AppRoutes.festivals);
  //   } catch (e) {
  //     print("❌ Apple login error: $e");
  //     setError("Apple sign-in failed. Please try again.");
  //   } finally {
  //     setLoading(false);
  //   }
  // }

  void goToSignup() {
    _navigationService.navigateTo(AppRoutes.signupEmail);
  }
}
