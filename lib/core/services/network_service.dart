import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../exceptions/app_exception.dart';
import '../exceptions/exception_mapper.dart';
import 'error_handler_service.dart';

/// Network service with retry logic and error handling
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  late final Dio _dio;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  final Connectivity _connectivity = Connectivity();

  /// Initialize network service
  void initialize({
    String? baseUrl,
    Map<String, dynamic>? headers,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        headers: headers ?? {},
        connectTimeout: connectTimeout ?? const Duration(seconds: 30),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        sendTimeout: sendTimeout ?? const Duration(seconds: 30),
      ),
    );

    // Add interceptors for logging and error handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Log request in debug mode
          if (kDebugMode) {
            print('🌐 Request: ${options.method} ${options.path}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Log response in debug mode
          if (kDebugMode) {
            print('✅ Response: ${response.statusCode} ${response.requestOptions.path}');
          }
          handler.next(response);
        },
        onError: (error, handler) {
          // Log error in debug mode
          if (kDebugMode) {
            print('❌ Network Error: ${error.message}');
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Check internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Execute network request with retry logic
  Future<T> request<T>({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
    Duration? retryDelay,
    bool Function(DioException)? retryCondition,
  }) async {
    // Check connectivity first
    if (!await hasInternetConnection()) {
      throw NetworkException.noInternet();
    }

    int attempt = 0;
    DioException? lastError;

    while (attempt < maxRetries) {
      try {
        attempt++;
        
        final response = await _dio.request(
          path,
          data: data,
          queryParameters: queryParameters,
          options: Options(
            method: method,
            headers: headers,
          ),
        );

        return response.data as T;
      } on DioException catch (e) {
        lastError = e;
        final exception = ExceptionMapper.mapToAppException(e);

        // Check if we should retry
        if (attempt < maxRetries) {
          final shouldRetry = retryCondition?.call(e) ??
              _errorHandler.isRetryable(exception);

          if (shouldRetry) {
            final delay = retryDelay ??
                _errorHandler.getRetryDelay(attempt);
            
            if (kDebugMode) {
              print('🔄 Retrying request (attempt $attempt/$maxRetries) after ${delay.inSeconds}s');
            }
            
            await Future.delayed(delay);
            continue;
          }
        }

        // If we shouldn't retry or max retries reached, throw the exception
        throw exception;
      } catch (e) {
        // If it's not a DioException, handle it as a general error
        if (e is AppException) {
          rethrow;
        }
        throw _errorHandler.handleError(e, null, 'NetworkService.request');
      }
    }

    // If we exhausted all retries, throw the last error
    throw ExceptionMapper.mapToAppException(lastError!);
  }

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
  }) {
    return request<T>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      maxRetries: maxRetries,
    );
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
  }) {
    return request<T>(
      method: 'POST',
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      maxRetries: maxRetries,
    );
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
  }) {
    return request<T>(
      method: 'PUT',
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      maxRetries: maxRetries,
    );
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
  }) {
    return request<T>(
      method: 'DELETE',
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      maxRetries: maxRetries,
    );
  }

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
  }) {
    return request<T>(
      method: 'PATCH',
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      maxRetries: maxRetries,
    );
  }
}

