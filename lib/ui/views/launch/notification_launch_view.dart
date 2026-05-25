import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../util/firebase_notification_service.dart';

/// Shown only on cold start when the user opens the app by tapping a notification.
/// Plain [AppColors.screenBackground] and centered logo, then navigates to the chat deep link.
class NotificationLaunchView extends StatefulWidget {
  const NotificationLaunchView({super.key});

  @override
  State<NotificationLaunchView> createState() => _NotificationLaunchViewState();
}

class _NotificationLaunchViewState extends State<NotificationLaunchView> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToDeepLink());
  }

  Future<void> _goToDeepLink() async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || _navigated) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final target = args is NotificationLaunchTarget ? args : null;
    _navigated = true;

    if (target == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.festivals);
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      target.routeName,
      arguments: target.arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: Center(
          child: Image.asset(
            AppAssets.splashLogo,
            width: 160,
            height: 160,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Festival Rumour',
          ),
        ),
      ),
    );
  }
}
