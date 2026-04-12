import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../di/locator.dart';
import '../services/network_service.dart';
import '../services/error_handler_service.dart';
import '../exceptions/app_exception.dart';
import 'api_config.dart';
import 'api_response.dart';

/// Result of a paginated festivals request (View All with load more).
class FestivalPageResult {
  final List<Map<String, dynamic>> list;
  final int currentPage;
  final int lastPage;
  final bool hasMore;

  const FestivalPageResult({
    required this.list,
    required this.currentPage,
    required this.lastPage,
  }) : hasMore = currentPage < lastPage;
}

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
  /// Optional [search] adds query param "search" for server-side search.
  /// The API returns: {"message": "...", "data": [...]} or paginated {"data": {"current_page", "data": [...], "last_page", ...}}
  Future<ApiResponse<List<Map<String, dynamic>>>> getFestivals({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      final response = await _networkService.get<Map<String, dynamic>>(
        ApiConfig.getFestivals,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        headers: _getHeaders(null),
        maxRetries: 3,
      );

      if (response == null) {
        return ApiResponse.error(
          message: 'Empty response received',
          statusCode: 200,
        );
      }

      // Log raw JSON response in chunks (logcat truncates long single messages)
      if (kDebugMode) {
        try {
          final pretty = const JsonEncoder.withIndent('  ').convert(response);
          const int chunkSize = 800;
          print('FestivalApiService.getFestivals — raw JSON response (start):');
          for (int i = 0; i < pretty.length; i += chunkSize) {
            final end = (i + chunkSize < pretty.length) ? i + chunkSize : pretty.length;
            print(pretty.substring(i, end));
          }
          print('FestivalApiService.getFestivals — raw JSON response (end)');
        } catch (_) {
          print('FestivalApiService.getFestivals — raw response: $response');
        }
      }

      // Extract data from response.
      // API can return either:
      // - {"message": "...", "data": [...]}  (plain list)
      // - {"message": "...", "data": {"current_page": 1, "data": [...], ...}}  (paginated)
      final message = response['message']?.toString();
      final rawData = response['data'];

      if (rawData == null) {
        return ApiResponse.error(
          message: message ?? 'No festival data found',
          statusCode: 200,
        );
      }

      // Get the list: either rawData is the list, or it's a pagination wrapper with inner "data"
      List<dynamic>? list;
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map && rawData['data'] is List) {
        list = rawData['data'] as List;
      }

      List<Map<String, dynamic>> festivals = [];
      if (list != null) {
        festivals = list
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

  /// Get festivals for a given page (for View All with load more).
  Future<ApiResponse<FestivalPageResult>> getFestivalsPage(int page) async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        ApiConfig.getFestivals,
        queryParameters: <String, dynamic>{'page': page},
        headers: _getHeaders(null),
        maxRetries: 3,
      );

      if (response == null) {
        return ApiResponse.error(
          message: 'Empty response received',
          statusCode: 200,
        );
      }

      if (kDebugMode) {
        try {
          final pretty = const JsonEncoder.withIndent('  ').convert(response);
          const int chunkSize = 800;
          print('FestivalApiService.getFestivalsPage($page) — raw JSON response (start):');
          for (int i = 0; i < pretty.length; i += chunkSize) {
            final end = (i + chunkSize < pretty.length) ? i + chunkSize : pretty.length;
            print(pretty.substring(i, end));
          }
          print('FestivalApiService.getFestivalsPage($page) — raw JSON response (end)');
        } catch (_) {
          print('FestivalApiService.getFestivalsPage($page) — raw response: $response');
        }
      }

      final message = response['message']?.toString();
      final rawData = response['data'];

      if (rawData == null) {
        return ApiResponse.error(
          message: message ?? 'No festival data found',
          statusCode: 200,
        );
      }

      List<dynamic>? list;
      int currentPage = page;
      int lastPage = page;

      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map) {
        list = rawData['data'] is List ? rawData['data'] as List : null;
        currentPage = rawData['current_page'] is num
            ? (rawData['current_page'] as num).toInt()
            : page;
        lastPage = rawData['last_page'] is num
            ? (rawData['last_page'] as num).toInt()
            : page;
      }

      List<Map<String, dynamic>> festivals = [];
      if (list != null) {
        festivals = list
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

      final result = FestivalPageResult(
        list: festivals,
        currentPage: currentPage,
        lastPage: lastPage,
      );

      return ApiResponse.success(
        data: result,
        message: message,
        statusCode: 200,
      );
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        stackTrace,
        'FestivalApiService.getFestivalsPage',
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

