import 'dart:async';
import 'dart:convert';
import 'package:festival_rumour/util/firebase_notification_service.dart';
import 'package:festival_rumour/util/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_assets.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/locator.dart';
import 'core/services/navigation_service.dart';
import 'core/services/notification_storage_service.dart';
import 'core/services/storage_service.dart';
import 'core/providers/festival_provider.dart';

const String _kChatBadgeStorageKey = 'chat_room_badge_counts';
const String _kNotificationsEnabledKey = 'notifications_enabled';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[NOTIF] Device: background FCM received, messageId=${message.messageId}, data=${message.data}');

  final prefs = await SharedPreferences.getInstance();
  var notificationsEnabled = prefs.getBool(_kNotificationsEnabledKey);
  if (notificationsEnabled == null) {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    notificationsEnabled = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
  if (!notificationsEnabled) {
    print('[NOTIF] Device: skip background update - notifications disabled or not granted');
    return;
  }

  final chatRoomId = message.data['chatRoomId'] as String?;
  if (chatRoomId != null && chatRoomId.isNotEmpty) {
    try {
      final json = prefs.getString(_kChatBadgeStorageKey) ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
      map[chatRoomId] = ((map[chatRoomId] as int?) ?? 0) + 1;
      await prefs.setString(_kChatBadgeStorageKey, jsonEncode(map));
    } catch (e) {
      print('[NOTIF] Device: background badge update error: $e');
    }
  }

  try {
    await NotificationStorageService.persistFromRemoteMessage(message);
  } catch (e) {
    print('[NOTIF] Device: background notification list error: $e');
  }
}

const String _kLogTag = '[APP]';

/// Debug-only: avoids string work and I/O on every frame in release builds.
void _log(String where, [String? detail]) {
  if (!kDebugMode) return;
  if (detail != null) {
    debugPrint('$_kLogTag $where $detail');
  } else {
    debugPrint('$_kLogTag $where');
  }
}

/// Set once at startup. Do not assign from [MaterialApp.builder] (rebuild churn).
void _configureGlobalErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final message = details.exception.toString();
    if (message.contains('404') ||
        message.contains('HttpException') ||
        message.contains('Invalid statusCode: 404')) {
      return const SizedBox.shrink();
    }
    return ErrorWidget(details.exception);
  };
}

/// Shared by bootstrap shell + splash [MaterialApp]s (same look, one allocation).
final ThemeData _kShellMaterialTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  useMaterial3: true,
);

/// Main entry point of the Festival Rumour application
void main() {
  // runZonedGuarded catches any uncaught async error that escapes Flutter's
  // framework error handler (FlutterError.onError).  Without this wrapper,
  // an unhandled Future/Stream error kills the root isolate and the OS
  // restarts the app from the splash screen.
  runZonedGuarded(_appMain, (error, stack) {
    // Always log fatal async escapes; keep release signal (Crashlytics can hook here later).
    debugPrint('[CRASH] Uncaught zone error: $error\n$stack');
    // Log but do NOT rethrow — prevents cascade crash-to-splash.
  });
}

Future<void> _appMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGlobalErrorWidget();

  // Catch synchronous Flutter framework errors (layout overflows, etc.)
  // and log them instead of crashing in release builds.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    // In debug mode Flutter already prints; in release, just log and continue.
  };

  await Firebase.initializeApp();

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.init();
  await FirebaseNotificationService.init();
  await setupLocator();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  String? notificationLaunchRoute;
  final pendingLaunch =
      FirebaseNotificationService.peekPendingNotificationData();
  if (pendingLaunch != null) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = await locator<StorageService>().isLoggedIn();
    if (isLoggedIn && user != null) {
      final target = FirebaseNotificationService.parseLaunchTargetFromData(
        pendingLaunch,
      );
      if (target != null) {
        notificationLaunchRoute = AppRoutes.notificationLaunch;
        AppLaunchInitialRouteArgs.value = target;
      }
      FirebaseNotificationService.consumePendingNotificationData();
    }
  }

  runApp(_AppRoot(notificationLaunchRoute: notificationLaunchRoute));
}

/// Root widget: optional video splash, then the main app.
/// Cold start from a notification + logged-in user: branded launch screen then chat deep link.
class _AppRoot extends StatefulWidget {
  const _AppRoot({this.notificationLaunchRoute});

  final String? notificationLaunchRoute;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  /// False until we know whether to show video splash (skipped for notification cold start).
  bool _bootstrapComplete = false;
  bool _showSplash = true;
  String _initialRoute = AppRoutes.welcome;

  @override
  void initState() {
    super.initState();
    if (widget.notificationLaunchRoute != null) {
      _log(
        '_AppRoot.initState',
        'notification cold start → initialRoute=${widget.notificationLaunchRoute}',
      );
      _bootstrapComplete = true;
      _showSplash = false;
      _initialRoute = widget.notificationLaunchRoute!;
      return;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Intro splash video plays ONLY on the very first launch. Returning users
    // skip it and go straight to their initial route.
    final storage = locator<StorageService>();
    final introShown = await storage.hasShownIntroVideo();
    if (!mounted) return;

    if (introShown) {
      _log('_AppRoot._bootstrap()', 'intro already shown → skip splash video');
      final isLoggedIn = await storage.isLoggedIn();
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      setState(() {
        _showSplash = false;
        _bootstrapComplete = true;
        _initialRoute = (isLoggedIn && user != null)
            ? AppRoutes.festivals
            : AppRoutes.welcome;
      });
      _handlePendingNotification(isLoggedIn && user != null);
      return;
    }

    // First launch — mark as shown so the video never plays again, then show it.
    _log('_AppRoot._bootstrap()', 'first launch → play intro splash video');
    await storage.setIntroVideoShown();
    if (mounted) setState(() => _bootstrapComplete = true);
  }

  void _onSplashDone() async {
    _log('_AppRoot._onSplashDone()', 'start');
    final isLoggedIn = await locator<StorageService>().isLoggedIn();
    final user = FirebaseAuth.instance.currentUser;
    _log(
      '_AppRoot._onSplashDone()',
      'isLoggedIn=$isLoggedIn user=${user != null}',
    );
    if (!mounted) {
      _log('_AppRoot._onSplashDone()', '!mounted, abort');
      return;
    }
    setState(() {
      _showSplash = false;
      _initialRoute =
          (isLoggedIn && user != null)
              ? AppRoutes.festivals
              : AppRoutes.welcome;
    });
    _log(
      '_AppRoot._onSplashDone()',
      'setState done, initialRoute=$_initialRoute',
    );
    _handlePendingNotification(isLoggedIn && user != null);
  }

  /// If the app was launched by tapping a notification (terminated state),
  /// process the pending deep link after the navigator is ready.
  void _handlePendingNotification(bool loggedInUser) {
    if (!loggedInUser) return;
    final pendingData =
        FirebaseNotificationService.consumePendingNotificationData();
    if (pendingData != null) {
      _log('_AppRoot', 'pending notification data found: $pendingData');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseNotificationService.navigateFromNotificationData(pendingData);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (!_bootstrapComplete) {
      child = KeyedSubtree(
        key: const ValueKey('boot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _kShellMaterialTheme,
          home: const _BrandedLoading(),
        ),
      );
    } else if (_showSplash) {
      _log('_AppRoot.build()', 'showing splash');
      child = KeyedSubtree(
        key: const ValueKey('splash'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _kShellMaterialTheme,
          home: _SimpleSplashScreen(onDone: _onSplashDone),
        ),
      );
    } else {
      _log(
        '_AppRoot.build()',
        'showing FestivalRumourApp(initialRoute=$_initialRoute)',
      );
      child = KeyedSubtree(
        key: const ValueKey('app'),
        child: FestivalRumourApp(initialRoute: _initialRoute),
      );
    }

    // Cross-fade between boot → (splash) → app so there's no hard white cut,
    // especially for returning users who skip the splash video.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: child,
      ),
    );
  }
}

/// Branded loading placeholder (cream background + logo) shown for the brief
/// moment before we know whether to play the splash video. Avoids a white flash.
class _BrandedLoading extends StatelessWidget {
  const _BrandedLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFFD2),
      body: Center(
        child: Image.asset(
          AppAssets.splashLogo,
          width: 160,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Splash screen: logo on white placeholder until video is ready, then full-screen video. Waits until video completes.
class _SimpleSplashScreen extends StatefulWidget {
  final VoidCallback onDone;

  const _SimpleSplashScreen({required this.onDone});

  @override
  State<_SimpleSplashScreen> createState() => _SimpleSplashScreenState();
}

class _SimpleSplashScreenState extends State<_SimpleSplashScreen> {
  VideoPlayerController? _controller;
  bool _hasCompleted = false;

  void _complete() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _controller?.removeListener(_onVideoUpdate);
    widget.onDone();
  }

  void _onVideoUpdate() {
    if (!mounted || _controller == null) return;
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    final posMs = pos.inMilliseconds;
    final durMs = dur.inMilliseconds;
    if (durMs > 0 && posMs >= durMs - 100) {
      _complete();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(AppAssets.splashVideo);
    _controller!.setLooping(false);
    _controller!.setVolume(1.0);
    _controller!
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          _controller!.addListener(_onVideoUpdate);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _controller == null) return;
            _controller!.play();
            _log('_SimpleSplashScreen', 'video playing');
          });
        })
        .catchError((Object e, StackTrace st) {
          _log('_SimpleSplashScreen', 'video init error: $e');
          if (mounted) widget.onDone();
        });
  }

  void _skip() {
    _complete();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoReady = _controller != null && _controller!.value.isInitialized;
    return Scaffold(
      backgroundColor: videoReady ? Colors.black : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (videoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:
                    _controller!.value.size.width > 0
                        ? _controller!.value.size.width
                        : 16,
                height:
                    _controller!.value.size.height > 0
                        ? _controller!.value.size.height
                        : 9,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            _buildPlaceholder(),
          if (videoReady) _buildSkipButton(),
        ],
      ),
    );
  }

  Widget _buildSkipButton() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, right: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _skip,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black87, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main application widget with MVVM architecture
class FestivalRumourApp extends StatelessWidget {
  const FestivalRumourApp({Key? key, required this.initialRoute})
    : super(key: key);

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    _log('FestivalRumourApp.build()', 'initialRoute=$initialRoute');
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            // Use the locator singleton so FestivalViewModel can call
            // setAllFestivals() without a BuildContext (Bug 1 fix).
            ChangeNotifierProvider<FestivalProvider>.value(
              value: locator<FestivalProvider>(),
            ),
          ],
          child: MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            initialRoute: initialRoute,
            onGenerateInitialRoutes: onGenerateInitialRoutes,
            onGenerateRoute: onGenerateRoute,
            navigatorKey: locator<NavigationService>().navigatorKey,
            navigatorObservers: <NavigatorObserver>[
              locator<NavigationService>().routeObserver,
            ],
            scaffoldMessengerKey:
                locator<NavigationService>().scaffoldMessengerKey,
            builder: (context, widget) {
              _log(
                'FestivalRumourApp.MaterialApp.builder()',
                'widget=${widget?.runtimeType ?? "null"}',
              );
              final child = widget ?? const SizedBox.shrink();
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: MediaQuery.of(
                    context,
                  ).textScaleFactor.clamp(0.8, 1.2),
                ),
                child: child,
              );
            },
            theme: AppTheme.lightTheme,
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
