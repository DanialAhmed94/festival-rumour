/// Base exception class for all app-specific exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory NetworkException.noInternet() => const NetworkException(
        message: 'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      );

  factory NetworkException.timeout() => const NetworkException(
        message: 'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );

  factory NetworkException.serverError([String? message]) => NetworkException(
        message: message ?? 'Server error occurred. Please try again later.',
        code: 'SERVER_ERROR',
      );

  factory NetworkException.badRequest([String? message]) => NetworkException(
        message: message ?? 'Invalid request. Please check your input and try again.',
        code: 'BAD_REQUEST',
      );

  factory NetworkException.unauthorized() => const NetworkException(
        message: 'You are not authorized to perform this action. Please sign in again.',
        code: 'UNAUTHORIZED',
      );

  factory NetworkException.forbidden() => const NetworkException(
        message: 'Access denied. You do not have permission to perform this action.',
        code: 'FORBIDDEN',
      );

  factory NetworkException.notFound() => const NetworkException(
        message: 'The requested resource was not found.',
        code: 'NOT_FOUND',
      );

  factory NetworkException.fromDioError(dynamic error) {
    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException')) {
      return NetworkException.noInternet();
    }
    if (error.toString().contains('TimeoutException') ||
        error.toString().contains('timeout')) {
      return NetworkException.timeout();
    }
    return NetworkException(
      message: 'Network error occurred. Please try again.',
      originalError: error,
    );
  }
}

/// Authentication-related exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory AuthException.userNotFound() => const AuthException(
        message: 'No user found with this email address.',
        code: 'USER_NOT_FOUND',
      );

  factory AuthException.wrongPassword() => const AuthException(
        message: 'Incorrect password. Please try again.',
        code: 'WRONG_PASSWORD',
      );

  factory AuthException.emailAlreadyInUse() => const AuthException(
        message: 'An account already exists with this email address.',
        code: 'EMAIL_ALREADY_IN_USE',
      );

  factory AuthException.weakPassword() => const AuthException(
        message: 'Password is too weak. Please choose a stronger password.',
        code: 'WEAK_PASSWORD',
      );

  factory AuthException.invalidEmail() => const AuthException(
        message: 'Invalid email address. Please enter a valid email.',
        code: 'INVALID_EMAIL',
      );

  factory AuthException.userDisabled() => const AuthException(
        message: 'This account has been disabled. Please contact support.',
        code: 'USER_DISABLED',
      );

  factory AuthException.tooManyRequests() => const AuthException(
        message: 'Too many failed attempts. Please try again later.',
        code: 'TOO_MANY_REQUESTS',
      );

  factory AuthException.invalidVerificationCode() => const AuthException(
        message: 'Invalid verification code. Please try again.',
        code: 'INVALID_VERIFICATION_CODE',
      );

  factory AuthException.requiresRecentLogin() => const AuthException(
        message: 'This operation requires recent authentication. Please sign in again.',
        code: 'REQUIRES_RECENT_LOGIN',
      );

  factory AuthException.invalidCredential() => const AuthException(
        message: 'Invalid email or password. Please check your credentials and try again.',
        code: 'INVALID_CREDENTIAL',
      );

  factory AuthException.notSignedIn() => const AuthException(
        message: 'You are not signed in. Please sign in to continue.',
        code: 'NOT_SIGNED_IN',
      );
}

/// Validation-related exceptions
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationException.emptyField(String fieldName) => ValidationException(
        message: '$fieldName cannot be empty.',
        code: 'EMPTY_FIELD',
      );

  factory ValidationException.invalidFormat(String fieldName) => ValidationException(
        message: 'Invalid $fieldName format. Please check and try again.',
        code: 'INVALID_FORMAT',
      );

  factory ValidationException.tooShort(String fieldName, int minLength) =>
      ValidationException(
        message: '$fieldName must be at least $minLength characters long.',
        code: 'TOO_SHORT',
      );

  factory ValidationException.tooLong(String fieldName, int maxLength) =>
      ValidationException(
        message: '$fieldName must not exceed $maxLength characters.',
        code: 'TOO_LONG',
      );
}

/// Storage-related exceptions
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory StorageException.writeFailed() => const StorageException(
        message: 'Failed to save data. Please try again.',
        code: 'WRITE_FAILED',
      );

  factory StorageException.readFailed() => const StorageException(
        message: 'Failed to read data. Please try again.',
        code: 'READ_FAILED',
      );

  factory StorageException.deleteFailed() => const StorageException(
        message: 'Failed to delete data. Please try again.',
        code: 'DELETE_FAILED',
      );

  factory StorageException.notFound() => const StorageException(
        message: 'Data not found.',
        code: 'NOT_FOUND',
      );
}

/// Permission-related exceptions
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory PermissionException.denied(String permission) => PermissionException(
        message: '$permission permission is required. Please grant permission in settings.',
        code: 'PERMISSION_DENIED',
      );

  factory PermissionException.permanentlyDenied(String permission) =>
      PermissionException(
        message:
            '$permission permission is permanently denied. Please enable it in app settings.',
        code: 'PERMISSION_PERMANENTLY_DENIED',
      );
}

/// Unknown or unexpected exceptions
class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory UnknownException.fromError(dynamic error, [StackTrace? stackTrace]) {
    return UnknownException(
      message: 'An unexpected error occurred. Please try again.',
      code: 'UNKNOWN_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}

