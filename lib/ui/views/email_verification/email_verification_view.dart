import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/auth_background.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import 'email_verification_view_model.dart';

class EmailVerificationView extends BaseView<EmailVerificationViewModel> {
  const EmailVerificationView({super.key});

  @override
  EmailVerificationViewModel createViewModel() => EmailVerificationViewModel();

  @override
  Widget buildView(BuildContext context, EmailVerificationViewModel viewModel) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const AuthBackground(),

          /// Main Content
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
                  image: DecorationImage(
                    image: AssetImage(AppAssets.bottomsheet),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusXL),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildHeader(context),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildEmailIcon(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildTitle(),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildDescription(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildEmailAddress(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildResendButton(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildContinueButton(context, viewModel),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        CustomBackButton(onTap: () => context.pop()),
        SizedBox(width: context.getConditionalSpacing()),
        Text(
          'Email Verification',
          style: TextStyle(
            fontSize: context.responsiveTextXL,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailIcon(BuildContext context, EmailVerificationViewModel viewModel) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: viewModel.isEmailVerified
            ? Colors.green.withOpacity(0.1)
            : AppColors.primary.withOpacity(0.1),
        border: Border.all(
          color: viewModel.isEmailVerified
              ? Colors.green.withOpacity(0.5)
              : AppColors.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        viewModel.isEmailVerified ? Icons.check_circle : Icons.email_outlined,
        size: 50,
        color: viewModel.isEmailVerified ? Colors.green : AppColors.primary,
      ),
    );
  }

  Widget _buildTitle() {
    return const ResponsiveTextWidget(
      'Check Your Email',
      textType: TextType.title,
      fontSize: AppDimensions.textXXL,
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription(BuildContext context, EmailVerificationViewModel viewModel) {
    return ResponsiveTextWidget(
      viewModel.isEmailVerified
          ? 'Email verified successfully! You can now continue to the next step.'
          : 'We\'ve sent a verification link to your email address. Please check your inbox and click the link to verify your email.',
      textType: TextType.body,
      fontSize: context.getConditionalFont(),
      color: viewModel.isEmailVerified ? Colors.green : AppColors.primary,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildEmailAddress(BuildContext context, EmailVerificationViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.email,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: ResponsiveTextWidget(
              viewModel.userEmail ?? 'user@example.com',
              textType: TextType.body,
              fontSize: context.getConditionalFont(),
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton(BuildContext context, EmailVerificationViewModel viewModel) {
    return TextButton(
      onPressed: viewModel.isLoading || !viewModel.canResend
          ? null
          : () => viewModel.resendVerificationEmail(),
      child: ResponsiveTextWidget(
        viewModel.resendButtonText,
        textType: TextType.body,
        fontSize: context.getConditionalFont(),
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
      ),
    );
  }


  Widget _buildContinueButton(BuildContext context, EmailVerificationViewModel viewModel) {
    final isEnabled = !viewModel.isLoading && viewModel.isEmailVerified;
    
    return SizedBox(
      width: double.infinity,
      height: context.getConditionalButtonSize(),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.accent : AppColors.accent.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
        onPressed: isEnabled
            ? () => viewModel.checkEmailVerification()
            : null,
        child: viewModel.isLoading
            ? const CircularProgressIndicator(color: AppColors.onPrimary)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ResponsiveTextWidget(
                    viewModel.isEmailVerified ? 'Continue' : 'Verify Email to Continue',
                    textType: TextType.body,
                    fontSize: context.getConditionalMainFont(),
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  if (viewModel.isEmailVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.onPrimary,
                      size: 20,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
