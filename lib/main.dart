import 'package:festival_rumour/firebase_options.dart';
import 'package:festival_rumour/services/notification_service.dart';
import 'package:festival_rumour/util/firebase_notification_service.dart';
import 'package:festival_rumour/util/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 Background message: ${message.messageId}');
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

/// Splash screen: full-screen video from assets, skip button top-right. Waits until video completes.
const String _kSplashVideoAsset = 'assets/videos/Festival_Rumour.mp4';

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
    _controller = VideoPlayerController.asset(_kSplashVideoAsset);
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

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
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
            const ColoredBox(color: Colors.black),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _skip,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
