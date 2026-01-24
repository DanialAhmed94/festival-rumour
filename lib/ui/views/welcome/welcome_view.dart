import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/auth_background.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import 'welcome_view_model.dart';

class WelcomeView extends BaseView<WelcomeViewModel> {
  const WelcomeView({super.key});

  @override
  WelcomeViewModel createViewModel() => WelcomeViewModel();

  @override
  Widget buildView(BuildContext context, WelcomeViewModel viewModel) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const AuthBackground(),

          /// Login Section
          Align(
            alignment: Alignment.bottomCenter,
            child: ResponsiveContainer(
              mobileMaxWidth: double.infinity,
              tabletMaxWidth: AppDimensions.tabletWidth,
              desktopMaxWidth: AppDimensions.desktopWidth,
              child: Container(
                width: double.infinity,
                padding: context.responsivePadding,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusXL),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: context.getConditionalSpacing()),
                      SizedBox(height: context.getConditionalSpacing()),
                      _LoginButton(
                        color: AppColors.googleRed,
                        icon: AppAssets.googleIcon,
                        label: AppStrings.loginWithGoogle,
                        onPressed: viewModel.loginWithGoogle,
                      ),
                      SizedBox(height: context.getConditionalSpacing()),
                      _LoginButton(
                        color: AppColors.emailBlue,
                        icon: AppAssets.phoneIcon,
                        label: AppStrings.loginWithEmailPhone,
                        onPressed: viewModel.loginWithEmail,
                      ),
                      SizedBox(height: context.getConditionalSpacing()),
                      _LoginButton(
                        color: AppColors.grey800,
                        icon: AppAssets.appleIcon,
                        label: AppStrings.loginWithApple,
                        onPressed: viewModel.loginWithApple,
                      ),
                      SizedBox(height: context.getConditionalSpacing()),
                      _SignupText(onTap: viewModel.goToSignup),
                      SizedBox(height: context.getConditionalSpacing()),
                      SizedBox(height: context.getConditionalSpacing()),
                      SizedBox(height: context.getConditionalSpacing()),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// Loader Overlay
          if (viewModel.isLoading)
            Container(
              color: AppColors.black.withOpacity(0.45),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}


class _LoginButton extends StatelessWidget {
  final Color color;
  final String icon;
  final String label;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightXL,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleIcon(icon),
            const Spacer(),
            ResponsiveTextWidget(
              label,
              style: const TextStyle(color: AppColors.white),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}





class _CircleIcon extends StatelessWidget {
  final String asset;
  const _CircleIcon(this.asset);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
      child: Center(
      child: SvgPicture.asset(
        asset,
        height: AppDimensions.iconL,
        width: AppDimensions.iconL,
      ),
    ),
    );
  }
}



class _SignupText extends StatelessWidget {
  final VoidCallback onTap;
  const _SignupText({required this.onTap});

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          text: AppStrings.dontHaveAccount,
          style: TextStyle(color: AppColors.black, fontSize: context.responsiveTextM),
          children: [
            TextSpan(
              text: AppStrings.signupNow,
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: context.responsiveTextL,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
