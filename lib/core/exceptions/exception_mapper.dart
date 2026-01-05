import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'app_exception.dart';

/// Maps various error types to AppException
class ExceptionMapper {
  /// Map any error to AppException
  static AppException mapToAppException(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return _mapFirebaseAuthException(error);
    }

    if (error is DioException) {
      return _mapDioException(error);
    }

    if (error is FormatException) {
      return ValidationException(
        message: 'Invalid data format. Please try again.',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Check for common error patterns
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socket') || errorString.contains('network')) {
      return NetworkException.noInternet();
    }

    if (errorString.contains('timeout')) {
      return NetworkException.timeout();
    }

    // If it's a plain Exception with a user-friendly message, preserve it
    if (error is Exception) {
      final message = error.toString();
      // Check if it's a user-friendly message (not just "Exception: ...")
      if (message.contains(':') && !message.startsWith('Exception:')) {
        // Extract the message part after the colon
        final parts = message.split(':');
        if (parts.length > 1) {
          final userMessage = parts.sublist(1).join(':').trim();
          if (userMessage.isNotEmpty && userMessage.length > 10) {
            // Likely a user-friendly message, preserve it
            return UnknownException(
              message: userMessage,
              originalError: error,
              stackTrace: stackTrace,
            );
          }
        }
      }
      // If message starts with "Exception: ", extract the actual message
      if (message.startsWith('Exception: ')) {
        final userMessage = message.substring(11).trim();
        if (userMessage.isNotEmpty) {
          return UnknownException(
            message: userMessage,
            originalError: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    // Default to unknown exception
    return UnknownException.fromError(error, stackTrace);
  }

  /// Map Firebase Auth Exception to AppException
  static AppException _mapFirebaseAuthException(FirebaseAuthException e) {
    // Check error message for specific patterns that might not have standard codes
    final errorMessage = (e.message ?? '').toLowerCase();
    
    // Check for "blocked" or "unusual activity" messages
    if (errorMessage.contains('blocked') || 
        errorMessage.contains('unusual activity') ||
        errorMessage.contains('too many requests')) {
      return AuthException.tooManyRequests();
    }
    
    switch (e.code) {
      case 'user-not-found':
        return AuthException.userNotFound();
      case 'wrong-password':
        return AuthException.wrongPassword();
      case 'invalid-credential':
        return AuthException.invalidCredential();
      case 'email-already-in-use':
        return AuthException.emailAlreadyInUse();
      case 'weak-password':
        return AuthException.weakPassword();
      case 'invalid-email':
        return AuthException.invalidEmail();
      case 'user-disabled':
        return AuthException.userDisabled();
      case 'too-many-requests':
        return AuthException.tooManyRequests();
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return AuthException.invalidVerificationCode();
      case 'requires-recent-login':
        return AuthException.requiresRecentLogin();
      case 'operation-not-allowed':
        return AuthException(
          message: 'This sign-in method is not enabled. Please contact support.',
          code: e.code,
        );
      case 'credential-already-in-use':
        return AuthException(
          message:
              'This credential is already associated with a different account.',
          code: e.code,
        );
      default:
        return AuthException(
          message: e.message ?? 'An authentication error occurred. Please try again.',
          code: e.code,
          originalError: e,
        );
    }
  }

  /// Map Dio Exception to AppException
  static AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException.timeout();

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        switch (statusCode) {
          case 400:
            return NetworkException.badRequest(
              e.response?.data?.toString() ?? 'Bad request',
            );
          case 401:
            return NetworkException.unauthorized();
          case 403:
            return NetworkException.forbidden();
          case 404:
            return NetworkException.notFound();
          case 500:
          case 502:
          case 503:
            return NetworkException.serverError();
          default:
            return NetworkException.serverError(
              'Server error (${statusCode ?? 'unknown'})',
            );
        }

      case DioExceptionType.cancel:
        return NetworkException(
          message: 'Request was cancelled.',
          code: 'CANCELLED',
        );

      case DioExceptionType.connectionError:
        return NetworkException.noInternet();

      case DioExceptionType.badCertificate:
        return NetworkException(
          message: 'SSL certificate error. Please check your connection.',
          code: 'BAD_CERTIFICATE',
        );

      case DioExceptionType.unknown:
      default:
        return NetworkException.fromDioError(e);
    }
  }

  /// Get user-friendly error message from AppException
  static String getUserFriendlyMessage(AppException exception) {
    return exception.message;
  }
}

