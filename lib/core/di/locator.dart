import 'package:get_it/get_it.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_with_apple.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../services/auth_service.dart';
import '../services/navigation_service.dart';
import '../services/error_handler_service.dart';
import '../services/network_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/geocoding_service.dart';
import '../api/api_config.dart';
import '../api/festival_api_service.dart';

final GetIt locator = GetIt.instance;

/// Initialize dependency injection
Future<void> setupLocator() async {
  // Core Services
  locator.registerLazySingleton<ErrorHandlerService>(() => ErrorHandlerService());
  locator.registerLazySingleton<NetworkService>(() => NetworkService());
  
  // Services
  locator.registerLazySingleton<NavigationService>(() => NavigationService());
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<FirestoreService>(() => FirestoreService());
  locator.registerLazySingleton<StorageService>(() => StorageService());
  locator.registerLazySingleton<GeocodingService>(() => GeocodingService());
  
  // Initialize NetworkService with API base URL
  locator<NetworkService>().initialize(
    baseUrl: ApiConfig.baseUrl,
    headers: ApiConfig.defaultHeaders,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    sendTimeout: ApiConfig.sendTimeout,
  );
  
  // API Services
  locator.registerLazySingleton<FestivalApiService>(() => FestivalApiService());
  
  // Repositories
  locator.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(locator<AuthService>()));
  
  // Use cases
  locator.registerFactory<SignInWithGoogle>(() => SignInWithGoogle(locator<AuthRepository>()));
  locator.registerFactory<SignInWithApple>(() => SignInWithApple(locator<AuthRepository>()));
}


