import 'dart:convert';
import 'package:festival_rumour/firebase_options.dart';
import 'package:festival_rumour/services/notification_service.dart';
import 'package:festival_rumour/util/firebase_notification_service.dart';
import 'package:festival_rumour/util/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'core/services/error_handler_service.dart';
import 'core/services/storage_service.dart';
import 'core/providers/festival_provider.dart';

const String _kChatBadgeStorageKey = 'chat_room_badge_counts';
const String _kNotificationListKey = 'notification_list';
const String _kNotificationsEnabledKey = 'notifications_enabled';
const int _kMaxNotifications = 30;

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
    final listJson = prefs.getString(_kNotificationListKey) ?? '[]';
    final list = (jsonDecode(listJson) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final id = message.messageId ?? '${DateTime.now().millisecondsSinceEpoch}';
    if (list.any((e) => e['id'] == id)) return;
    final notif = message.notification;
    list.insert(0, {
      'id': id,
      'title': notif?.title ?? 'Notification',
      'message': notif?.body ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'chatRoomId': chatRoomId,
      'type': chatRoomId != null ? 'chat' : 'general',
    });
    if (list.length > _kMaxNotifications) {
      list.removeRange(_kMaxNotifications, list.length);
    }
    await prefs.setString(_kNotificationListKey, jsonEncode(list));
  } catch (e) {
    print('[NOTIF] Device: background notification list error: $e');
  }
}

const String _kLogTag = '[APP]';

void _log(String where, [String? detail]) {
  if (detail != null) {
    debugPrint('$_kLogTag $where $detail');
  } else {
    debugPrint('$_kLogTag $where');
  }
}

/// Main entry point of the Festival Rumour application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const _AppRoot());
}

/// Root widget: shows a simple splash (no theme, no router) for 3s, then the main app.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _showSplash = true;
  String _initialRoute = AppRoutes.welcome;

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
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      _log('_AppRoot.build()', 'showing splash');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
        ),
        home: _SimpleSplashScreen(onDone: _onSplashDone),
      );
    }
    _log(
      '_AppRoot.build()',
      'showing FestivalRumourApp(initialRoute=$_initialRoute)',
    );
    return FestivalRumourApp(initialRoute: _initialRoute);
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
      alignment: Alignment.center,
      child: Image.asset(
        AppAssets.splashLogo,
        width: 160,
        height: 160,
        fit: BoxFit.contain,
      ),
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
            ChangeNotifierProvider(create: (_) => FestivalProvider()),
          ],
          child: MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            initialRoute: initialRoute,
            onGenerateInitialRoutes: onGenerateInitialRoutes,
            onGenerateRoute: onGenerateRoute,
            navigatorKey: locator<NavigationService>().navigatorKey,
            builder: (context, widget) {
              _log(
                'FestivalRumourApp.MaterialApp.builder()',
                'widget=${widget?.runtimeType ?? "null"}',
              );
              ErrorWidget.builder = (FlutterErrorDetails details) {
                if (details.exception.toString().contains('404') ||
                    details.exception.toString().contains('HttpException') ||
                    details.exception.toString().contains(
                      'Invalid statusCode: 404',
                    )) {
                  return const SizedBox.shrink();
                }
                return ErrorWidget(details.exception);
              };
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
