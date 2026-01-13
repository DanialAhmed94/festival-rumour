import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'opt_view_model.dart';

class OtpView extends BaseView<OtpViewModel> {
  OtpView({super.key});

  @override
  OtpViewModel createViewModel() => OtpViewModel();

  @override
  void onError(BuildContext context, String error) {
    if (context.mounted) {
      try {
        final viewModel = Provider.of<OtpViewModel>(context, listen: false);
        viewModel.clearError();
      } catch (e) {
        // Provider might not be available yet, ignore
      }
    }
  }

  bool _isShowingSnackbar = false;
  String? _lastShownError;

  @override
  Widget buildView(BuildContext context, OtpViewModel viewModel) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
            children: [
              // Main content
              Positioned.fill(
                child: ResponsiveContainer(
                  mobileMaxWidth: double.infinity,
                  tabletMaxWidth: double.infinity,
                  desktopMaxWidth: double.infinity,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.isSmallScreen 
                          ? AppDimensions.paddingM
                          : context.isMediumScreen 
                              ? AppDimensions.paddingL
                              : AppDimensions.paddingXL,
                      vertical: context.isSmallScreen 
                          ? AppDimensions.paddingM
                          : context.isMediumScreen 
                              ? AppDimensions.paddingL
                              : AppDimensions.paddingXL
                    ),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(AppAssets.bottomsheet),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Selector<OtpViewModel, String?>(
                      selector: (_, vm) => vm.errorText,
                      builder: (context, errorText, child) {
                        final viewModel = Provider.of<OtpViewModel>(context, listen: false);
                        
                        // Show snackbar when errorText changes
                        if (errorText != null && 
                            errorText.isNotEmpty && 
                            errorText != _lastShownError &&
                            !_isShowingSnackbar) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted && errorText == viewModel.errorText) {
                              _showErrorSnackbarIfNeeded(context, viewModel);
                            }
                          });
                        }
                        
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AppDimensions.spaceXXL),
                              const ResponsiveTextWidget(
                                AppStrings.enterCode,
                                textType: TextType.body, 
                                fontSize: AppDimensions.textXL,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: AppDimensions.spaceS),
                              ResponsiveTextWidget(
                                viewModel.phoneNumber != null 
                                  ? "${AppStrings.enterOtpDescription}\n${viewModel.displayPhoneNumber}"
                                  : "${AppStrings.enterOtpDescription}\nPlease check your phone for the verification code.",
                                textType: TextType.body, 
                                color: AppColors.primary, 
                                fontSize: AppDimensions.textM,
                              ),

                              const SizedBox(height: AppDimensions.paddingL),
                              _buildOtpInput(context, viewModel),

                              // Enhanced error display
                              if (viewModel.errorInfo != null) ...[
                                const SizedBox(height: AppDimensions.paddingM),
                                _buildErrorCard(context, viewModel),
                              ],

                              // Attempts remaining indicator
                              if (viewModel.remainingAttempts < 5 && viewModel.remainingAttempts > 0) ...[
                                const SizedBox(height: AppDimensions.paddingS),
                                _buildAttemptsIndicator(context, viewModel),
                              ],

                              const SizedBox(height: AppDimensions.paddingXL),
                              _buildSignupButton(context, viewModel),
                              const SizedBox(height: AppDimensions.spaceM),
                              _buildResendButton(context, viewModel),
                            ],
                          ),
                        );
                      },
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              // Back button
              Positioned(
                left: AppDimensions.paddingM,
                top: AppDimensions.spaceXL,
                child: CustomBackButton(
                  onTap: () {
                    context.pop();
                  },
                ),
              ),
              // Loading overlay
              if (viewModel.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    
  }

  Widget _buildOtpInput(BuildContext context, OtpViewModel viewModel) {
    final isDisabled = viewModel.isLoading || !viewModel.hasRemainingAttempts;
    
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: IgnorePointer(
        ignoring: isDisabled,
        child: PinCodeTextField(
          appContext: context,
          length: 6,
          focusNode: viewModel.otpFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          animationType: AnimationType.fade,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.circle,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            fieldHeight: context.isSmallScreen 
                ? AppDimensions.buttonHeightL
                : context.isMediumScreen 
                    ? AppDimensions.buttonHeightXL
                    : AppDimensions.buttonHeightXL * 1.2,
            fieldWidth: context.isSmallScreen 
                ? AppDimensions.buttonHeightL
                : context.isMediumScreen 
                    ? AppDimensions.buttonHeightXL
                    : AppDimensions.buttonHeightXL * 1.2,
            inactiveFillColor: AppColors.onPrimary,
            activeFillColor: AppColors.onPrimary,
            selectedFillColor: AppColors.onPrimary,
            inactiveColor: AppColors.white,
            selectedColor: viewModel.errorInfo?.type == OtpErrorType.invalidCode 
                ? AppColors.accent 
                : AppColors.primary,
            activeColor: viewModel.errorInfo?.type == OtpErrorType.invalidCode 
                ? AppColors.accent 
                : AppColors.primary,
          ),
          textStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: AppDimensions.textXXL,
            fontWeight: FontWeight.bold,
          ),
          cursorColor: AppColors.primary,
          animationDuration: AppDurations.otpAnimationDuration,
          enableActiveFill: true,
          onChanged: viewModel.onCodeChanged,
          onCompleted: (_) {
            // Only unfocus the field when OTP is completed
            // Do NOT auto-verify - user must tap Continue button
            viewModel.unfocusOtpField();
          },
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, OtpViewModel viewModel) {
    final errorInfo = viewModel.errorInfo!;
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getErrorIcon(errorInfo.type),
                color: AppColors.accent,
                size: AppDimensions.iconM,
              ),
              const SizedBox(width: AppDimensions.spaceS),
              Expanded(
                child: ResponsiveTextWidget(
                  errorInfo.message,
                  textType: TextType.body,
                  color: AppColors.accent,
                  fontSize: AppDimensions.textM,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (errorInfo.recoverySuggestion != null) ...[
            const SizedBox(height: AppDimensions.spaceS),
            Padding(
              padding: const EdgeInsets.only(left: AppDimensions.iconM + AppDimensions.spaceS),
              child: ResponsiveTextWidget(
                errorInfo.recoverySuggestion!,
                textType: TextType.body,
                color: AppColors.primary.withOpacity(0.8),
                fontSize: AppDimensions.textS,
              ),
            ),
          ],
          if (errorInfo.canRetry && viewModel.hasRemainingAttempts) ...[
            const SizedBox(height: AppDimensions.spaceM),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: viewModel.isLoading ? null : viewModel.verifyCode,
                icon: const Icon(Icons.refresh, size: AppDimensions.iconS),
                label: const ResponsiveTextWidget(
                  'Try Again',
                  textType: TextType.body,
                  color: AppColors.accent,
                  fontSize: AppDimensions.textM,
                  fontWeight: FontWeight.w600,
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttemptsIndicator(BuildContext context, OtpViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: AppDimensions.iconS,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.spaceS),
          ResponsiveTextWidget(
            '${viewModel.remainingAttempts} attempt${viewModel.remainingAttempts > 1 ? 's' : ''} remaining',
            textType: TextType.body,
            color: AppColors.primary,
            fontSize: AppDimensions.textS,
          ),
        ],
      ),
    );
  }

  Widget _buildSignupButton(BuildContext context, OtpViewModel viewModel) {
    final isEnabled = viewModel.canVerify && !viewModel.isLoading;
    
    return SizedBox(
      width: double.infinity,
      height: context.isSmallScreen 
          ? AppDimensions.buttonHeightL
          : context.isMediumScreen 
              ? AppDimensions.buttonHeightXL
              : AppDimensions.buttonHeightXL * 1.1,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.accent : AppColors.accent.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
          elevation: isEnabled ? 4 : 0,
        ),
        onPressed: isEnabled
            ? () {
                viewModel.unfocusOtpField();
                viewModel.verifyCode();
              }
            : null,
        child: viewModel.isLoading
            ? const SizedBox(
                width: AppDimensions.iconS,
                height: AppDimensions.iconS,
                child: CircularProgressIndicator(
                  color: AppColors.onPrimary,
                  strokeWidth: AppDimensions.borderWidthS,
                ),
              )
            : const ResponsiveTextWidget(
                AppStrings.signUp,
                textType: TextType.body, 
                color: AppColors.onPrimary,
                fontSize: AppDimensions.textXL,
              ),
      ),
    );
  }

  Widget _buildResendButton(BuildContext context, OtpViewModel viewModel) {
    final canResend = viewModel.canResend && !viewModel.isLoading;
    
    return Center(
      child: Column(
        children: [
          TextButton.icon(
            onPressed: canResend ? viewModel.resendCode : null,
            icon: viewModel.isResending
                ? const SizedBox(
                    width: AppDimensions.iconS,
                    height: AppDimensions.iconS,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                    size: AppDimensions.iconS,
                    color: AppColors.primary,
                  ),
            label: ResponsiveTextWidget(
              viewModel.isResending 
                  ? 'Sending...'
                  : viewModel.canResend
                      ? AppStrings.resendCode
                      : 'Resend Code',
              textType: TextType.body, 
              color: canResend ? AppColors.primary : AppColors.primary.withOpacity(0.5),
              fontSize: AppDimensions.textM,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!viewModel.canResend && viewModel.errorInfo?.requiresResend == true) ...[
            const SizedBox(height: AppDimensions.spaceXS),
            ResponsiveTextWidget(
              'Please request a new code to continue.',
              textType: TextType.body,
              color: AppColors.primary.withOpacity(0.7),
              fontSize: AppDimensions.textS,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getErrorIcon(OtpErrorType type) {
    switch (type) {
      case OtpErrorType.invalidCode:
        return Icons.error_outline;
      case OtpErrorType.expiredSession:
        return Icons.access_time;
      case OtpErrorType.networkError:
        return Icons.wifi_off;
      case OtpErrorType.tooManyAttempts:
        return Icons.block;
      case OtpErrorType.missingData:
        return Icons.info_outline;
      default:
        return Icons.error_outline;
    }
  }

  void _showErrorSnackbarIfNeeded(BuildContext context, OtpViewModel viewModel) {
    final errorText = viewModel.errorText;
    
    if (errorText == null || 
        errorText.isEmpty || 
        !context.mounted ||
        _isShowingSnackbar ||
        errorText == _lastShownError) {
      return;
    }

    _isShowingSnackbar = true;
    _lastShownError = errorText;
    
    viewModel.clearErrorText();
    viewModel.clearError();
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(viewModel.errorInfo?.type ?? OtpErrorType.unknown),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorText,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _isShowingSnackbar = false;
          },
        ),
      ),
    ).closed.then((_) {
      _isShowingSnackbar = false;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_lastShownError == errorText) {
          _lastShownError = null;
        }
      });
    });
  }

}
