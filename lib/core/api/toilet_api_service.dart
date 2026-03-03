import 'package:flutter/foundation.dart';
import '../di/locator.dart';
import '../services/network_service.dart';
import '../services/error_handler_service.dart';
import '../exceptions/app_exception.dart';
import 'api_config.dart';
import 'api_response.dart';

/// API service for toilet-related operations.
/// Does not use authentication (no token in headers).
class ToiletApiService {
  final NetworkService _networkService;
  final ErrorHandlerService _errorHandler;

  ToiletApiService({
    NetworkService? networkService,
    ErrorHandlerService? errorHandler,
  })  : _networkService = networkService ?? locator<NetworkService>(),
        _errorHandler = errorHandler ?? locator<ErrorHandlerService>();

  Map<String, dynamic> _getHeaders(Map<String, dynamic>? additionalHeaders) {
    final headers = Map<String, dynamic>.from(ApiConfig.defaultHeaders);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  /// Get toilets for a festival. No auth token in headers.
  /// GET /toilets-all?festival_id=<festivalId>
  Future<ApiResponse<List<Map<String, dynamic>>>> getToilets(int festivalId) async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        ApiConfig.getToilets,
        queryParameters: {'festival_id': festivalId},
        headers: _getHeaders(null),
        maxRetries: 3,
      );

      if (response == null) {
        return ApiResponse.error(
          message: 'Empty response received',
          statusCode: 200,
        );
      }

      final message = response['message']?.toString();
      final data = response['data'];

      if (data == null) {
        return ApiResponse.error(
          message: message ?? 'No toilet data found',
          statusCode: 200,
        );
      }

      List<Map<String, dynamic>> toilets = [];
      if (data is List) {
        toilets = data
            .map((item) {
              try {
                return Map<String, dynamic>.from(item as Map);
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing toilet item: $e');
                }
                return <String, dynamic>{};
              }
            })
            .where((item) => item.isNotEmpty)
            .toList();
      }

      return ApiResponse.success(
        data: toilets,
        message: message,
        statusCode: 200,
      );
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        stackTrace,
        'ToiletApiService.getToilets',
      );

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
