import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../exceptions/app_exception.dart';
import '../exceptions/exception_mapper.dart';

/// Global error handler service for handling and reporting errors
class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Handle and log an error
  AppException handleError(
    dynamic error, [
    StackTrace? stackTrace,
    String? context,
  ]) {
    final appException = ExceptionMapper.mapToAppException(error, stackTrace);

    // Log the error
    _logError(appException, context);

    return appException;
  }

  /// Log error with context
  void _logError(AppException exception, String? context) {
    final contextInfo = context != null ? ' in $context' : '';
    
    _logger.e(
      'Error$contextInfo: ${exception.message}',
      error: exception.originalError,
      stackTrace: exception.stackTrace,
    );

    // In debug mode, also print to console for immediate visibility
    if (kDebugMode) {
      debugPrint('❌ Error$contextInfo: ${exception.message}');
      if (exception.originalError != null) {
        debugPrint('Original error: ${exception.originalError}');
      }
      if (exception.stackTrace != null) {
        debugPrint('Stack trace: ${exception.stackTrace}');
      }
    }
  }

  /// Get user-friendly error message
  String getUserFriendlyMessage(dynamic error) {
    final appException = ExceptionMapper.mapToAppException(error);
    return ExceptionMapper.getUserFriendlyMessage(appException);
  }

  /// Handle error and return formatted message for UI
  String handleErrorForUI(
    dynamic error, [
    StackTrace? stackTrace,
    String? context,
  ]) {
    final appException = handleError(error, stackTrace, context);
    return appException.message;
  }

  /// Check if error is retryable
  bool isRetryable(AppException exception) {
    if (exception is NetworkException) {
      return exception.code != 'UNAUTHORIZED' &&
          exception.code != 'FORBIDDEN' &&
          exception.code != 'BAD_REQUEST';
    }
    if (exception is AuthException) {
      return exception.code == 'TOO_MANY_REQUESTS';
    }
    return false;
  }

  /// Get retry delay based on attempt number
  Duration getRetryDelay(int attemptNumber) {
    // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
    final delaySeconds = (1 << (attemptNumber - 1)).clamp(1, 30);
    return Duration(seconds: delaySeconds);
  }
}

