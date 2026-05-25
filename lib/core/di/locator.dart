import 'package:festival_rumour/core/services/signup_data_service.dart';
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
import '../services/post_data_service.dart';
import '../services/current_chat_room_service.dart';
import '../services/current_chat_list_service.dart';
import '../services/chat_badge_service.dart';
import '../services/notification_storage_service.dart';
import '../services/user_photo_cache_service.dart';
import '../services/profile_readiness_service.dart';
import '../api/api_config.dart';
import '../api/festival_api_service.dart';
import '../api/news_api_service.dart';
import '../api/toilet_api_service.dart';
import '../api/event_api_service.dart';
import '../api/performance_api_service.dart';
import '../providers/festival_provider.dart';

final GetIt locator = GetIt.instance;

/// Initialize dependency injection
Future<void> setupLocator() async {
  // Core Services
  locator.registerLazySingleton<ErrorHandlerService>(
    () => ErrorHandlerService(),
  );
  locator.registerLazySingleton<NetworkService>(() => NetworkService());

  // Services
  locator.registerLazySingleton<NavigationService>(() => NavigationService());
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<FirestoreService>(() => FirestoreService());
  locator.registerLazySingleton<StorageService>(() => StorageService());
  locator.registerLazySingleton<ProfileReadinessService>(
    () => ProfileReadinessService(),
  );
  locator.registerLazySingleton<GeocodingService>(() => GeocodingService());
  locator.registerLazySingleton<PostDataService>(() => PostDataService());
  locator.registerLazySingleton<CurrentChatRoomService>(() => CurrentChatRoomService());
  locator.registerLazySingleton<CurrentChatListService>(() => CurrentChatListService());
  locator.registerLazySingleton<ChatBadgeService>(() => ChatBadgeService());
  locator.registerLazySingleton<NotificationStorageService>(() => NotificationStorageService());
  locator.registerLazySingleton<UserPhotoCacheService>(() => UserPhotoCacheService());

  locator.registerLazySingleton<SignupDataService>(() => SignupDataService());

  // FestivalProvider is a ChangeNotifier registered here as a singleton so that
  // FestivalViewModel can update it from loadFestivals() without needing a BuildContext.
  // main.dart uses ChangeNotifierProvider.value(locator<FestivalProvider>()) to share
  // the same instance with the widget tree.
  locator.registerLazySingleton<FestivalProvider>(() => FestivalProvider());

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
  locator.registerLazySingleton<NewsApiService>(() => NewsApiService());
  locator.registerLazySingleton<ToiletApiService>(() => ToiletApiService());
  locator.registerLazySingleton<EventApiService>(() => EventApiService());
  locator.registerLazySingleton<PerformanceApiService>(() => PerformanceApiService());

  // Repositories
  locator.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(locator<AuthService>()),
  );

  // Use cases
  locator.registerFactory<SignInWithGoogle>(
    () => SignInWithGoogle(locator<AuthRepository>()),
  );
  locator.registerFactory<SignInWithApple>(
    () => SignInWithApple(locator<AuthRepository>()),
  );
}
