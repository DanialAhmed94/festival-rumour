import 'package:flutter/foundation.dart';
import '../services/network_service.dart';
import '../services/error_handler_service.dart';
import '../exceptions/app_exception.dart';
import '../exceptions/exception_mapper.dart';
import 'api_response.dart';
import 'api_config.dart';

/// Base API service that provides common functionality for all API services
abstract class BaseApiService {
  final NetworkService _networkService;
  final ErrorHandlerService _errorHandler;

  BaseApiService({
    NetworkService? networkService,
    ErrorHandlerService? errorHandler,
  })  : _networkService = networkService ?? NetworkService(),
        _errorHandler = errorHandler ?? ErrorHandlerService();

  /// Get authorization token (override in child classes if needed)
  String? getAuthToken() => null;

  /// Get default headers with authorization
  Map<String, dynamic> _getHeaders(Map<String, dynamic>? additionalHeaders) {
    final token = getAuthToken();
    final headers = ApiConfig.getAuthHeaders(token);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  /// Execute GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: queryParameters,
        headers: _getHeaders(headers),
        maxRetries: maxRetries,
      );

      return _parseResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'GET $endpoint');
    }
  }

  /// Execute POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        headers: _getHeaders(headers),
        maxRetries: maxRetries,
      );

      return _parseResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'POST $endpoint');
    }
  }

  /// Execute PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _networkService.put<Map<String, dynamic>>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        headers: _getHeaders(headers),
        maxRetries: maxRetries,
      );

      return _parseResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'PUT $endpoint');
    }
  }

  /// Execute PATCH request
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _networkService.patch<Map<String, dynamic>>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        headers: _getHeaders(headers),
        maxRetries: maxRetries,
      );

      return _parseResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'PATCH $endpoint');
    }
  }

  /// Execute DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _networkService.delete<Map<String, dynamic>>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        headers: _getHeaders(headers),
        maxRetries: maxRetries,
      );

      return _parseResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'DELETE $endpoint');
    }
  }

  /// Parse response data
  ApiResponse<T> _parseResponse<T>(
    Map<String, dynamic>? response,
    T Function(dynamic)? fromJson,
  ) {
    if (response == null) {
      return ApiResponse.error(
        message: 'Empty response received',
        statusCode: 200,
      );
    }

    // Try to parse as ApiResponse format
    try {
      return ApiResponse.fromJson(response, fromJson);
    } catch (e) {
      // If parsing fails, assume the response itself is the data
      if (fromJson != null) {
        try {
          final data = fromJson(response);
          return ApiResponse.success(data: data);
        } catch (e) {
          if (kDebugMode) {
            print('Failed to parse response: $e');
          }
        }
      }
      return ApiResponse.success(data: response as T?);
    }
  }

  /// Handle errors and convert to ApiResponse
  ApiResponse<T> _handleError<T>(
    dynamic error,
    StackTrace? stackTrace,
    String context,
  ) {
    final exception = _errorHandler.handleError(error, stackTrace, context);

    // Extract status code if available
    int? statusCode;
    if (exception is NetworkException && exception.code != null) {
      switch (exception.code) {
        case 'UNAUTHORIZED':
          statusCode = 401;
          break;
        case 'FORBIDDEN':
          statusCode = 403;
          break;
        case 'NOT_FOUND':
          statusCode = 404;
          break;
        case 'BAD_REQUEST':
          statusCode = 400;
          break;
        case 'SERVER_ERROR':
          statusCode = 500;
          break;
      }
    }

    return ApiResponse.error(
      message: exception.message,
      statusCode: statusCode,
    );
  }

  /// Get paginated data
  Future<PaginatedResponse<T>> getPaginated<T>(
    String endpoint, {
    int page = 1,
    int limit = 10,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    int maxRetries = 3,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final params = {
        'page': page,
        'limit': limit,
        ...?queryParameters,
      };

      final response = await _networkService.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: params,
        headers: _getHeaders(headers),
        maxRetries: maxRetries,
      );

      if (response == null) {
        throw NetworkException(
          message: 'Empty response received',
          code: 'EMPTY_RESPONSE',
        );
      }

      return PaginatedResponse.fromJson(response, fromJson);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(e, stackTrace, 'GET $endpoint');
      throw exception;
    }
  }
}

