import 'package:festival_rumour/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/locator.dart';
import 'core/services/navigation_service.dart';
import 'core/services/error_handler_service.dart';
import 'core/providers/festival_provider.dart';

/// Main entry point of the Festival Rumour application
void main() async {
  try {
    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase first
    await Firebase.initializeApp();

    // Initialize dependency injection
    await setupLocator();

    // Set preferred orientations (portrait only for mobile experience)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    runApp(const FestivalRumourApp());
  } catch (e, stackTrace) {
    // Handle Firebase initialization errors
    final errorHandler = ErrorHandlerService();
    final exception = errorHandler.handleError(e, stackTrace, 'main');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Firebase initialization failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Error: ${exception.message}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main application widget with MVVM architecture
class FestivalRumourApp extends StatelessWidget {
  const FestivalRumourApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

            // Routing
            initialRoute: AppRoutes.splash,
            onGenerateRoute: onGenerateRoute,

            // Navigation
            navigatorKey: locator<NavigationService>().navigatorKey,

            // TextScale limit
            builder: (context, widget) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: MediaQuery.of(
                    context,
                  ).textScaleFactor.clamp(0.8, 1.2),
                ),
                child: widget ?? const SizedBox.shrink(),
              );
            },

            theme: AppTheme.lightTheme,
          ),
        );
      },

      child: const SizedBox.shrink(), // required by ScreenUtilInit
    );
  }
}
