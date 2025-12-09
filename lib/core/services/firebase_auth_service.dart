import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../exceptions/app_exception.dart';
import '../exceptions/exception_mapper.dart';
import 'error_handler_service.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  // Check if Firebase is initialized
  bool get isFirebaseInitialized {
    try {
      return _auth.app != null;
    } catch (e) {
      return false;
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  // Sign up with email and password
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      // Check if Firebase is initialized
      if (!isFirebaseInitialized) {
        return AuthResult.failure('Firebase is not initialized. Please restart the app.');
      }

      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
      }

      return AuthResult.success(userCredential.user!);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.signUpWithEmail');
      return AuthResult.failure(exception.message);
    }
  }

  // Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return AuthResult.success(userCredential.user!);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.signInWithEmail');
      return AuthResult.failure(exception.message);
    }
  }

  // Sign in with phone number
  Future<AuthResult> signInWithPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      // Check if Firebase is initialized
      if (!isFirebaseInitialized) {
        return AuthResult.failure('Firebase is not initialized. Please restart the app.');
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );

      return AuthResult.success(null); // Phone verification initiated
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.signInWithPhone');
      return AuthResult.failure(exception.message);
    }
  }

  // Verify phone number with SMS code
  Future<AuthResult> verifyPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return AuthResult.success(userCredential.user!);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.verifyPhoneNumber');
      return AuthResult.failure(exception.message);
    }
  }

  // Send password reset email
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.sendPasswordResetEmail');
      return AuthResult.failure(exception.message);
    }
  }

  // Update user profile
  Future<AuthResult> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in.');
      }

      await user.updateDisplayName(displayName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();

      return AuthResult.success(user);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.updateUserProfile');
      return AuthResult.failure(exception.message);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.signOut');
    }
  }

  // Delete user account
  Future<AuthResult> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in.');
      }

      await user.delete();
      return AuthResult.success(null);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirebaseAuthService.deleteAccount');
      return AuthResult.failure(exception.message);
    }
  }

}

// Auth result class
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
  });

  factory AuthResult.success(User? user) => AuthResult._(
        isSuccess: true,
        user: user,
      );

  factory AuthResult.failure(String errorMessage) => AuthResult._(
        isSuccess: false,
        errorMessage: errorMessage,
      );
}
