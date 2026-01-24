import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/responsive_widget.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'forgot_password_view_model.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordViewModel(),
      child: Consumer<ForgotPasswordViewModel>(
        builder: (context, viewModel, _) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
              fit: StackFit.expand,
              children: [
                /// 🔹 Background
                Image.asset(AppAssets.usernameback, fit: BoxFit.cover),

                /// 🔹 Overlay
                Container(color: AppColors.overlayBlack45),

                /// 🔹 Content
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableHeight = constraints.maxHeight;
                      final isKeyboardVisible = keyboardHeight > 0;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: availableHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              mainAxisAlignment: isKeyboardVisible
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    height: isKeyboardVisible
                                        ? screenHeight * 0.05
                                        : screenHeight * 0.1),

                                /// Animated Content
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ResponsiveContainer(
                                      mobileMaxWidth: double.infinity,
                                      tabletMaxWidth: AppDimensions.tabletWidth,
                                      desktopMaxWidth: AppDimensions.desktopWidth,
                                      child: ResponsivePadding(
                                        mobilePadding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.05,
                                          vertical: screenHeight * 0.05,
                                        ),
                                        tabletPadding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.2,
                                          vertical: screenHeight * 0.02,
                                        ),
                                        desktopPadding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.25,
                                          vertical: screenHeight * 0.02,
                                        ),
                                        child: _buildContent(context, viewModel),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(
                                    height: isKeyboardVisible
                                        ? screenHeight * 0.02
                                        : screenHeight * 0.1),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ForgotPasswordViewModel viewModel) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        /// Logo
        Image.asset(
          AppAssets.logoPng,
          height: screenHeight * 0.12,
          fit: BoxFit.contain,
        ),
        SizedBox(height: context.getConditionalSpacing() * 1.5),

        /// Main Card (white background)
        Container(
          padding: context.responsivePadding,
          margin: context.responsiveMargin,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: viewModel.isEmailSent
              ? _buildEmailSentContent(context, viewModel)
              : _buildForgotPasswordForm(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm(
      BuildContext context, ForgotPasswordViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.getConditionalSpacing()),

        /// Title
        ResponsiveTextWidget(
          AppStrings.forgotPasswordTitle,
          color: Colors.black,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.getConditionalSpacing() * 0.5),

        /// Subtitle
        ResponsiveTextWidget(
          AppStrings.forgotPasswordSubtitle,
          textType: TextType.body,
          color: Colors.black.withOpacity(0.8),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.getConditionalSpacing() * 1.5),

        /// Email Field
        _buildEmailField(context, viewModel),
        SizedBox(height: context.getConditionalSpacing() * 1.5),

        /// Send Reset Link Button
        _buildSendButton(context, viewModel),
        SizedBox(height: context.getConditionalSpacing()),

        /// Back to Login
        _buildBackToLogin(context, viewModel),
        SizedBox(height: context.getConditionalSpacing()),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context, ForgotPasswordViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Email Label
        ResponsiveTextWidget(
          AppStrings.email,
          textType: TextType.body,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        SizedBox(height: context.getConditionalSpacing() * 0.5),

        /// Email Input
        Focus(
          onFocusChange: viewModel.onEmailFocusChange,
          child: TextField(
            controller: viewModel.emailController,
            focusNode: viewModel.emailFocus,
            cursorColor: Colors.black,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            textAlignVertical: TextAlignVertical.center,
            onChanged: viewModel.onEmailChanged,
            onSubmitted: (_) {
              if (viewModel.canSendResetEmail) {
                viewModel.sendPasswordResetEmail();
              }
            },
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              height: 1.2,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              hintText: AppStrings.emailAddressHint,
              hintStyle: TextStyle(color: Colors.black54),
              errorText: viewModel.emailError,
              errorStyle: TextStyle(
                color: AppColors.error,
                fontSize: context.responsiveTextS,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: Colors.black,
                size: context.responsiveIconS,
              ),
              suffixIcon: viewModel.isEmailValid
                  ? Icon(
                Icons.check_circle,
                color: Colors.black,
                size: context.responsiveIconS,
              )
                  : null,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: Colors.black,
                  width: AppDimensions.borderWidthS,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: Colors.black54,
                  width: AppDimensions.dividerThickness,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: AppDimensions.borderWidthS,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context, ForgotPasswordViewModel viewModel) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: viewModel.canSendResetEmail
            ? Colors.black
            : Colors.grey,
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        elevation: viewModel.canSendResetEmail ? 4 : 0,
      ),
      onPressed: viewModel.canSendResetEmail
          ? () => viewModel.sendPasswordResetEmail()
          : null,
      child: viewModel.isLoading
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: AppDimensions.iconS,
            height: AppDimensions.iconS,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: context.responsiveSpaceS),
          ResponsiveTextWidget(
            AppStrings.sendingResetLink,
            textType: TextType.body,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.send,
            color: Colors.white,
            size: context.responsiveIconS,
          ),
          SizedBox(width: context.responsiveSpaceS),
          ResponsiveTextWidget(
            AppStrings.sendResetLink,
            textType: TextType.body,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildBackToLogin(BuildContext context, ForgotPasswordViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ResponsiveTextWidget(
          AppStrings.alreadyHaveAccount,
          textType: TextType.body,
          color: Colors.black,
        ),
        SizedBox(width: AppDimensions.spaceXS),
        GestureDetector(
          onTap: viewModel.goBackToLogin,
          child: ResponsiveTextWidget(
            AppStrings.signIn,
            fontSize: context.getConditionalFont(),
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSentContent(
      BuildContext context, ForgotPasswordViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.getConditionalSpacing()),

        /// Success Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: Colors.black,
            size: 40,
          ),
        ),
        SizedBox(height: context.getConditionalSpacing()),

        /// Success Title
        ResponsiveTextWidget(
          AppStrings.resetEmailSent,
          color: Colors.black,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.getConditionalSpacing() * 0.5),

        /// Success Message
        ResponsiveTextWidget(
          AppStrings.resetEmailSentMessage,
          textType: TextType.body,
          color: Colors.black.withOpacity(0.8),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.getConditionalSpacing() * 1.5),

        /// Didn't receive email section
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Column(
            children: [
              ResponsiveTextWidget(
                AppStrings.didntReceiveEmail,
                textType: TextType.body,
                color: Colors.black,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.getConditionalSpacing() * 0.5),
              ResponsiveTextWidget(
                AppStrings.checkSpamFolder,
                textType: TextType.caption,
                color: Colors.black54,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(height: context.getConditionalSpacing()),

        /// Resend Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: viewModel.canResendEmail
                ? Colors.black
                : Colors.grey,
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            elevation: viewModel.canResendEmail ? 4 : 0,
          ),
          onPressed: viewModel.canResendEmail
              ? () => viewModel.resendPasswordResetEmail()
              : null,
          child: viewModel.isLoading
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: AppDimensions.iconS,
                height: AppDimensions.iconS,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: context.responsiveSpaceS),
              ResponsiveTextWidget(
                AppStrings.resendingEmail,
                textType: TextType.body,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.refresh,
                color: Colors.white,
                size: context.responsiveIconS,
              ),
              SizedBox(width: context.responsiveSpaceS),
              ResponsiveTextWidget(
                viewModel.resendButtonText,
                textType: TextType.body,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
        ),
        SizedBox(height: context.getConditionalSpacing()),

        /// Back to Login
        _buildBackToLogin(context, viewModel),
        SizedBox(height: context.getConditionalSpacing()),
      ],
    );
  }
}
