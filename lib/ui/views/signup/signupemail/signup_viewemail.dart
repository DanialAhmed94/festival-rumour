import 'package:festival_rumour/shared/widgets/responsive_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:festival_rumour/ui/views/signup/signupemail/signup_viewemail_model.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/auth_background.dart';
import '../../../../core/utils/backbutton.dart';
import '../../../../core/utils/base_view.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/responsive_widget.dart';

class SignupViewEmail extends BaseView<SignupViewEmailModel> {
  const SignupViewEmail({super.key});

  @override
  SignupViewEmailModel createViewModel() => SignupViewEmailModel();

  /// Override onError to prevent automatic snackbar (we handle errors manually)
  @override
  void onError(BuildContext context, String error) {
    // Don't show automatic snackbar - we handle errors manually in buildView
    // This prevents duplicate snackbars
  }

  @override
  Widget buildView(BuildContext context, SignupViewEmailModel viewModel) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AuthBackground(),

          Align(
            alignment: Alignment.bottomCenter,
            child: ResponsiveContainer(
              mobileMaxWidth: double.infinity,
              tabletMaxWidth: double.infinity,
              desktopMaxWidth: double.infinity,
              child: Container(
                width: double.infinity,
               // margin: EdgeInsets.zero,
                padding:context.responsivePadding,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusXXL),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildHeader(context),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildEmailField(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildPasswordField(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildConfirmPasswordField(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                      _buildContinueButton(context, viewModel),
                      SizedBox(height: context.getConditionalSpacing()),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// 🔹 Error snackbar handler
          _ErrorSnackbarHandler(viewModel: viewModel),
        ],
      ),
    );
  }

  /// 🔹 Header
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        CustomBackButton(onTap: () => context.pop()),
        SizedBox(width: context.getConditionalSpacing()),
        Text(
          AppStrings.signUp,
          style: TextStyle(
            fontSize: context.responsiveTextXL,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }

  /// 🔹 Email Field
  Widget _buildEmailField(BuildContext context, SignupViewEmailModel viewModel) {
    return TextField(
      controller: viewModel.emailController,
      focusNode: viewModel.emailFocus,
      autofocus: true,
      style: const TextStyle(color: AppColors.black),
      decoration: InputDecoration(
        labelText: AppStrings.emailLabel,
        hintText: AppStrings.emailHint,
        labelStyle: const TextStyle(color: AppColors.black),
        hintStyle: const TextStyle(color: AppColors.black),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black, width: 2),
        ),
        errorText: viewModel.emailError,
        errorStyle: TextStyle(
          color: Colors.red,
          fontSize: context.getConditionalFont(),
          fontWeight: FontWeight.w500,
        ),
      ),
      keyboardType: TextInputType.emailAddress,
      cursorColor: AppColors.black,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => viewModel.handleEmailSubmitted(),
      onChanged: (value) {
        if (viewModel.emailError != null) {
          viewModel.emailError = null;
          viewModel.notifyListeners();
        }
      },
    );
  }

  /// 🔹 Password Field
  Widget _buildPasswordField(BuildContext context, SignupViewEmailModel viewModel) {
    return TextField(
      controller: viewModel.passwordController,
      focusNode: viewModel.passwordFocus,
      obscureText: !viewModel.isPasswordVisible,
      style: const TextStyle(color: AppColors.black),
      decoration: InputDecoration(
        labelText: AppStrings.passwordLabel,
        hintText: AppStrings.passwordHint,
        labelStyle: const TextStyle(color: AppColors.black),
        hintStyle: const TextStyle(color: AppColors.black),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black, width: 2),
        ),
        errorText: viewModel.passwordError,
        errorStyle: TextStyle(
          color: Colors.red,
          fontSize: context.getConditionalFont(),
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            viewModel.isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: AppColors.black,
            size: context.getConditionalIconSize(),
          ),
          onPressed: viewModel.togglePasswordVisibility,
        ),
      ),
      keyboardType: TextInputType.visiblePassword,
      cursorColor: AppColors.black,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => viewModel.handlePasswordSubmitted(),
      onChanged: (value) {
        if (viewModel.passwordError != null) {
          viewModel.passwordError = null;
          viewModel.notifyListeners();
        }
      },
    );
  }

  /// 🔹 Confirm Password Field
  Widget _buildConfirmPasswordField(BuildContext context, SignupViewEmailModel viewModel) {
    return TextField(
      controller: viewModel.confirmPasswordController,
      focusNode: viewModel.confirmPasswordFocus,
      obscureText: !viewModel.isConfirmPasswordVisible,
      style: const TextStyle(color: AppColors.black),
      decoration: InputDecoration(
        labelText: AppStrings.confirmPasswordLabel,
        hintText: AppStrings.confirmPasswordHint,
        labelStyle: const TextStyle(color: AppColors.black),
        hintStyle: const TextStyle(color: AppColors.black),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black, width: 2),
        ),
        errorText: viewModel.confirmPasswordError,
        errorStyle: TextStyle(
          color: Colors.red,
          fontSize: context.getConditionalFont(),
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            viewModel.isConfirmPasswordVisible
                ? Icons.visibility
                : Icons.visibility_off,
            color: AppColors.black,
            size: context.getConditionalIconSize(),
          ),
          onPressed: viewModel.toggleConfirmPasswordVisibility,
        ),
      ),
      keyboardType: TextInputType.visiblePassword,
      cursorColor: AppColors.black,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => viewModel.handleConfirmPasswordSubmitted(),
      onChanged: (value) {
        if (viewModel.confirmPasswordError != null) {
          viewModel.confirmPasswordError = null;
          viewModel.notifyListeners();
        }
      },
    );
  }

  /// 🔹 Continue Button
  Widget _buildContinueButton(BuildContext context, SignupViewEmailModel viewModel) {
    return SizedBox(
      width: double.infinity,
      height: context.getConditionalButtonSize(),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
          padding: EdgeInsets.symmetric(),

        ),
        onPressed: viewModel.isLoading
            ? null
            : () {
          viewModel.unfocusAll();
          viewModel.goToOtp();
        },
        child: viewModel.isLoading
            ? SizedBox(
          width: context.getConditionalIconSize(),
          height: context.getConditionalIconSize(),
          child: const CircularProgressIndicator(
            color: AppColors.onPrimary,
            strokeWidth: 2,
          ),
        )
            : ResponsiveTextWidget(
          AppStrings.continueText,
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: context.getConditionalMainFont(),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Error snackbar handler widget - only shows when error changes
class _ErrorSnackbarHandler extends StatelessWidget {
  final SignupViewEmailModel viewModel;
  
  const _ErrorSnackbarHandler({required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return Selector<SignupViewEmailModel, String?>(
      selector: (_, vm) => vm.snackbarError,
      builder: (context, snackbarError, child) {
        if (snackbarError != null && snackbarError.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && snackbarError == viewModel.snackbarError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          snackbarError,
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
                      viewModel.clearSnackbarError();
                    },
                  ),
                ),
              );
              viewModel.clearSnackbarError();
            }
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}
