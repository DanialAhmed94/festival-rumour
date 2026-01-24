import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import 'SplashViewModel.dart';
import 'package:festival_rumour/ui/views/welcome/welcome_view.dart';

class SplashView extends BaseView<SplashViewModel> {
  const SplashView({super.key});

  @override
  SplashViewModel createViewModel() => SplashViewModel();

  @override
  Widget buildView(BuildContext context, SplashViewModel viewModel) {
    if (viewModel.isLoading) {
      // Splash screen with logo + black background
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          // 🔹 Logo
          Image.asset(
            AppAssets.logoPng,
            height: MediaQuery.of(context).size.height * 0.12,
            fit: BoxFit.contain,
          ),
             // FlutterLogo(size: 120, style: FlutterLogoStyle.markOnly),
            ],
          ),
        ),
      );
    } else {
      // Navigate to WelcomeView after loading
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const WelcomeView(),
          ),
        );
      });
      return const SizedBox.shrink();
    }
  }
}
