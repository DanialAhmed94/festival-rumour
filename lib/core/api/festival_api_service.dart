import 'package:flutter/foundation.dart';
import '../di/locator.dart';
import '../services/network_service.dart';
import '../services/error_handler_service.dart';
import '../exceptions/app_exception.dart';
import 'api_config.dart';
import 'api_response.dart';

/// API service for festival-related operations
class FestivalApiService {
  final NetworkService _networkService;
  final ErrorHandlerService _errorHandler;

  FestivalApiService({
    NetworkService? networkService,
    ErrorHandlerService? errorHandler,
  })  : _networkService = networkService ?? locator<NetworkService>(),
        _errorHandler = errorHandler ?? locator<ErrorHandlerService>();

  /// Get authorization token (if needed)
  String? getAuthToken() {
    // Return auth token if needed
    // For now, this endpoint doesn't require authentication
    return null;
  }

  /// Get default headers with authorization
  Map<String, dynamic> _getHeaders(Map<String, dynamic>? additionalHeaders) {
    final token = getAuthToken();
    final headers = ApiConfig.getAuthHeaders(token);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  /// Get all festivals from API
  /// The API returns: {"message": "...", "data": [...]}
  Future<ApiResponse<List<Map<String, dynamic>>>> getFestivals() async {
    try {
      // Call network service to get raw response
      final response = await _networkService.get<Map<String, dynamic>>(
        ApiConfig.getFestivals,
        headers: _getHeaders(null),
        maxRetries: 3,
      );

      if (response == null) {
        return ApiResponse.error(
          message: 'Empty response received',
          statusCode: 200,
        );
      }

      // Extract data from response format: {"message": "...", "data": [...]}
      final message = response['message']?.toString();
      final data = response['data'];

      if (data == null) {
        return ApiResponse.error(
          message: message ?? 'No festival data found',
          statusCode: 200,
        );
      }

      // Parse data array
      List<Map<String, dynamic>> festivals = [];
      if (data is List) {
        festivals = data
            .map((item) {
              try {
                return Map<String, dynamic>.from(item as Map);
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing festival item: $e');
                }
                return <String, dynamic>{};
              }
            })
            .where((item) => item.isNotEmpty)
            .toList();
      }

      return ApiResponse.success(
        data: festivals,
        message: message,
        statusCode: 200,
      );
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(e, stackTrace, 'FestivalApiService.getFestivals');
      
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
  }
}

