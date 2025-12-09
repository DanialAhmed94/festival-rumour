import 'package:flutter/foundation.dart';
import '../exceptions/app_exception.dart';
import '../services/error_handler_service.dart';

/// Base ViewModel class that provides common functionality for all ViewModels
/// Implements ChangeNotifier for state management
abstract class BaseViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool _isDisposed = false;
  String? _errorMessage;
  AppException? _appException;
  bool _busy = false;
  bool get busy => _busy;

  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  /// Current loading state
  bool get isLoading => _isLoading;

  /// Current error message (user-friendly)
  String? get errorMessage => _errorMessage;

  /// Current app exception (for detailed error handling)
  AppException? get appException => _appException;

  /// Check if the ViewModel has been disposed
  bool get isDisposed => _isDisposed;

  /// Set loading state and notify listeners
  void setLoading(bool loading) {
    if (_isDisposed) return;
    
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message and notify listeners
  void setError(String? error) {
    if (_isDisposed) return;
    
    _errorMessage = error;
    _appException = null;
    notifyListeners();
  }

  /// Set error from AppException
  void setErrorFromException(AppException exception) {
    if (_isDisposed) return;
    
    _appException = exception;
    _errorMessage = exception.message;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    if (_isDisposed) return;
    
    _errorMessage = null;
    _appException = null;
    notifyListeners();
  }

  /// Clear error message silently without notifying listeners
  /// Use this to prevent infinite loops when clearing errors from listeners
  void clearErrorSilently() {
    if (_isDisposed) return;
    
    _errorMessage = null;
    _appException = null;
    // Don't call notifyListeners() to prevent recursion
  }

  /// Set both loading and error states
  void setState({bool? loading, String? error}) {
    if (_isDisposed) return;
    
    if (loading != null) {
      _isLoading = loading;
    }
    if (error != null) {
      _errorMessage = error;
    }
    notifyListeners();
  }

  /// Handle async operations with automatic loading state management and error handling
  Future<T?> handleAsync<T>(
    Future<T> Function() operation, {
    bool showLoading = true,
    String? errorMessage,
    void Function(String error)? onError,
    void Function(AppException exception)? onException,
    Duration? minimumLoadingDuration,
    bool useGlobalErrorHandler = true,
  }) async {
    // Check if ViewModel is disposed before proceeding
    if (_isDisposed) return null;
    
    // Record start time for minimum loading duration
    final startTime = DateTime.now();
    
    try {
      if (showLoading) setLoading(true);
      clearError();
      
      final result = await operation();
      
      // Check if disposed after operation
      if (_isDisposed) return null;
      
      // Ensure minimum loading duration if specified
      if (minimumLoadingDuration != null) {
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < minimumLoadingDuration) {
          await Future.delayed(minimumLoadingDuration - elapsed);
        }
      }
      
      if (showLoading && !_isDisposed) setLoading(false);
      return result;
    } catch (e, stackTrace) {
      // Check if disposed before error handling
      if (_isDisposed) return null;
      
      // Ensure minimum loading duration even on error
      if (minimumLoadingDuration != null) {
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < minimumLoadingDuration) {
          await Future.delayed(minimumLoadingDuration - elapsed);
        }
      }
      
      if (showLoading && !_isDisposed) setLoading(false);
      
      // Handle error using global error handler
      AppException appException;
      if (useGlobalErrorHandler) {
        appException = _errorHandler.handleError(
          e,
          stackTrace,
          runtimeType.toString(),
        );
      } else {
        // Use custom error message if provided
        appException = UnknownException(
          message: errorMessage ?? e.toString(),
          originalError: e,
          stackTrace: stackTrace,
        );
      }
      
      if (!_isDisposed) {
        setErrorFromException(appException);
        
        // Call custom error handlers
        if (onException != null) {
          onException(appException);
        }
        
        if (onError != null) {
          onError(appException.message);
        }
      }
      
      return null;
    }
  }

  /// Initialize the ViewModel
  /// Override this method to perform initialization logic
  void init() {
    // Override in subclasses
  }

  /// Called when the ViewModel is being disposed
  /// Override this method to perform cleanup
  void onDispose() {
    // Override in subclasses
  }



  @override
  void dispose() {
    _isDisposed = true;
    onDispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void setBusy(bool val) {
    _busy = val;
    notifyListeners();
  }
}





