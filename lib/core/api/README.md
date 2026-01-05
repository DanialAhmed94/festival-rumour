# API Layer Documentation

This API layer provides a clean, type-safe way to make HTTP requests using Dio, with integrated error handling and retry logic.

## Architecture

- **`ApiConfig`**: Contains API configuration (base URL, endpoints, headers)
- **`ApiResponse<T>`**: Generic response wrapper for API responses
- **`PaginatedResponse<T>`**: Response wrapper for paginated data
- **`BaseApiService`**: Abstract base class for all API services
- **`ExampleApiService`**: Example implementation showing how to use the base service

## Features

✅ **Integrated Error Handling**: Uses the global `ErrorHandlerService` and `ExceptionMapper`  
✅ **Automatic Retry Logic**: Built-in retry with exponential backoff  
✅ **Type Safety**: Generic response types  
✅ **Authorization**: Automatic token injection  
✅ **Pagination Support**: Built-in pagination helpers  
✅ **Network Connectivity Check**: Validates internet connection before requests  

## Usage

### 1. Create Your API Service

Extend `BaseApiService` and implement your API methods:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import '../di/locator.dart';
import 'base_api_service.dart';
import 'api_config.dart';
import 'api_response.dart';

class FestivalApiService extends BaseApiService {
  FestivalApiService() : super(
    networkService: locator<NetworkService>(),
    errorHandler: locator<ErrorHandlerService>(),
  );

  @override
  String? getAuthToken() {
    // Return your auth token here
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? null; // Replace with actual token retrieval
  }

  // GET request example
  Future<ApiResponse<List<Festival>>> getFestivals() async {
    return get<List<Festival>>(
      ApiConfig.festivals,                       
      fromJson: (json) => (json as List)
          .map((item) => Festival.fromJson(item))
          .toList(),
    );
  }

  // POST request example
  Future<ApiResponse<Festival>> createFestival(Festival festival) async {
    return post<Festival>(
      ApiConfig.festivals,
      data: festival.toJson(),
      fromJson: (json) => Festival.fromJson(json),
    );
  }

  // Paginated request example
  Future<PaginatedResponse<Festival>> getFestivalsPaginated({
    int page = 1,
    int limit = 10,
  }) async {
    return getPaginated<Festival>(
      ApiConfig.festivals,
      page: page,
      limit: limit,
      fromJson: (json) => Festival.fromJson(json),
    );
  }
}
```

### 2. Register in Dependency Injection

Add your service to `lib/core/di/locator.dart`:

```dart
locator.registerLazySingleton<FestivalApiService>(() => FestivalApiService());
```

### 3. Use in ViewModel

```dart
import '../di/locator.dart';
import '../api/festival_api_service.dart';
import '../viewmodels/base_view_model.dart';

class FestivalViewModel extends BaseViewModel {
  final FestivalApiService _apiService = locator<FestivalApiService>();

  Future<void> loadFestivals() async {
    await handleAsync(() async {
      final response = await _apiService.getFestivals();
      
      if (response.success && response.data != null) {
        // Handle success
        festivals = response.data!;
      } else {
        // Error is automatically handled by handleAsync
        throw Exception(response.message ?? 'Failed to load festivals');
      }
    }, errorMessage: 'Failed to load festivals');
  }
}
```

## API Configuration

Update `ApiConfig` with your actual API details:

```dart
class ApiConfig {
  static const String baseUrl = 'https://your-api.com/v1';
  
  // Add your endpoints
  static const String festivals = '/festivals';
  static const String users = '/users';
  // ...
}
```

## Error Handling

All errors are automatically:
- Mapped to `AppException` via `ExceptionMapper`
- Logged via `ErrorHandlerService`
- Retried if retryable (network errors, timeouts)
- Displayed to users via `BaseViewModel.handleAsync`

## Response Format

The API layer expects responses in this format:

```json
{
  "success": true,
  "data": { ... },
  "message": "Success message",
  "statusCode": 200
}
```

Or for errors:

```json
{
  "success": false,
  "message": "Error message",
  "statusCode": 400,
  "errors": { ... }
}
```

If your API uses a different format, you can customize the parsing in `BaseApiService._parseResponse()`.

