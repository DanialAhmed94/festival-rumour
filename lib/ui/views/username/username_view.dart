import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/responsive_widget.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'username_view_model.dart';


class UsernameView extends StatefulWidget {
  const UsernameView({super.key});

  @override
  State<UsernameView> createState() => _UsernameViewState();
}

class _UsernameViewState extends State<UsernameView> {
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus on email field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UsernameViewModel(),
      child: Consumer<UsernameViewModel>(
        builder: (context, viewModel, _) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

          return SafeArea(child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
           //   fit: StackFit.expand,
              children: [
                /// 🔹 Background
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.asset(
                    AppAssets.background,
                    fit: BoxFit.cover,
                  ),
                ),

                /// 🔹 Overlay
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.7),
                ),

                /// 🔹 Content (keyboard-aware positioning)
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
                                SizedBox(height: isKeyboardVisible ? screenHeight * 0.05 : screenHeight * 0.1),
                            ResponsiveContainer(
                              mobileMaxWidth: double.infinity,
                              tabletMaxWidth: AppDimensions.tabletWidth,
                              desktopMaxWidth: AppDimensions.desktopWidth,
                              child: ResponsivePadding(
                                mobilePadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.03,
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
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                          /// Logo
                          Image.asset(
                            AppAssets.logoPng,
                            height: MediaQuery.of(context).size.height * 0.12,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: AppDimensions.spaceXL),
                          SizedBox(height: AppDimensions.spaceL),

                          /// Login Card
                          Container(
                            padding: context.responsivePadding,
                            margin: context.responsiveMargin,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                            ),
                            child: Column(
                            // crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: context.getConditionalSpacing()),
                                /// Username Label
                                Row(
                                  children: [
                                    ResponsiveTextWidget(
                                      AppStrings.username,
                                      textType: TextType.body,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    ResponsiveTextWidget(
                                      AppStrings.asterisk,
                                      textType: TextType.body,
                                      color: AppColors.black,
                                    ),
                                  ],
                                ),
                                SizedBox(height: context.getConditionalSpacing()),

                                /// Username Field
                                Focus(
                                  onFocusChange: viewModel.onUsernameFocusChange,
                                  child: TextField(
                                    controller: viewModel.emailController,
                                    focusNode: _emailFocusNode,
                                    cursorColor: AppColors.primary,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    textAlignVertical: TextAlignVertical.center,
                                    onChanged: viewModel.onUsernameChanged,
                                    onSubmitted: (_) {
                                      // Move focus to password field when user presses next
                                      _passwordFocusNode.requestFocus();
                                    },
                                    style: const TextStyle(
                                      color: AppColors.black,
                                      fontSize: 16,
                                      height: 1.2,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: viewModel.isEmailValid 
                                        ? AppColors.success.withOpacity(0.1)
                                        : AppColors.primary.withOpacity(0.3),
                                      hintText: AppStrings.enterYourEmail,
                                      hintStyle: const TextStyle(color: AppColors.black),
                                      errorText: viewModel.emailError,
                                      errorStyle:  TextStyle(
                                        color: AppColors.error,
                                        fontSize: context.responsiveTextS,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.email,
                                        color: viewModel.isEmailValid
                                          ? AppColors.success
                                          : AppColors.black,
                                        size: context.responsiveIconS,
                                      ),
                                      suffixIcon: viewModel.isEmailValid
                                        ?  Icon(
                                            Icons.check_circle,
                                            color: AppColors.success,
                                            size: context.responsiveIconS,
                                          )
                                        : null,
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                        borderSide: BorderSide(
                                          color: viewModel.isEmailValid
                                            ? AppColors.success
                                            : AppColors.black,
                                          width: AppDimensions.borderWidthS,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                        borderSide: BorderSide(
                                          color: viewModel.isEmailValid
                                            ? AppColors.success
                                            : AppColors.black,
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

                                SizedBox(height: context.getConditionalSpacing()),


                                Row(
                                  children: [
                                    ResponsiveTextWidget(
                                      AppStrings.password,
                                      textType: TextType.body,
                                      color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ResponsiveTextWidget(
                                      AppStrings.asterisk,
                                      textType: TextType.body,
                                      color: AppColors.black
                                    ),
                                ],
                              ),
                                SizedBox(height: context.getConditionalSpacing()),


                                Focus(
                                  onFocusChange: viewModel.onPasswordFocusChange,
                                  child: TextField(
                                    controller: viewModel.passwordController,
                                    focusNode: _passwordFocusNode,
                                    obscureText: !viewModel.isPasswordVisible,
                                    cursorColor: AppColors.primary,
                                    textInputAction: TextInputAction.done,
                                    textAlignVertical: TextAlignVertical.center,
                                    onChanged: viewModel.onPasswordChanged,
                                    onSubmitted: (_) {
                                      // Attempt login when user presses done on password field
                                      if (viewModel.isFormValid && !viewModel.isLoading) {
                                        viewModel.validateAndLogin(context);
                                      }
                                    },
                                    style: const TextStyle(
                                      color: AppColors.black,
                                      fontSize: 16,
                                      height: 1.2,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: viewModel.isPasswordValid
                                        ? AppColors.success.withOpacity(0.1)
                                        : AppColors.primary.withOpacity(0.3),
                                      hintText: AppStrings.passwordPlaceholder,
                                      hintStyle: const TextStyle(color: AppColors.black),
                                      errorText: viewModel.passwordError,
                                      errorStyle:  TextStyle(
                                        color: AppColors.error,
                                        fontSize: context.responsiveTextS,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.lock,
                                        color: viewModel.isPasswordValid
                                          ? AppColors.success
                                          : AppColors.black,
                                        size: context.responsiveIconS,
                                      ),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (viewModel.passwordStrength.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: AppDimensions.paddingXS,
                                                vertical: AppDimensions.paddingXS,
                                              ),
                                              margin: const EdgeInsets.only(right: AppDimensions.spaceXS),
                                              decoration: BoxDecoration(
                                                color: viewModel.passwordStrengthColor.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                                              ),
                                              child: Text(
                                                viewModel.passwordStrength,
                                                style: TextStyle(
                                                  color: viewModel.passwordStrengthColor,
                                                  fontSize: context.responsiveTextXS,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          IconButton(
                                            icon: Icon(
                                              viewModel.isPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: AppColors.black,
                                              size: context.responsiveIconS,
                                            ),
                                            onPressed: viewModel.togglePasswordVisibility,
                                          ),
                                        ],
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                        borderSide: BorderSide(
                                          color: viewModel.isPasswordValid
                                            ? AppColors.success
                                            : AppColors.black,
                                          width: AppDimensions.borderWidthS,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                        borderSide: BorderSide(
                                          color: viewModel.isPasswordValid
                                            ? AppColors.success
                                            : AppColors.black,
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

                                SizedBox(height: context.getConditionalSpacing()),

                                /// Remember + Forgot
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: viewModel.rememberMe,
                                          onChanged: viewModel.toggleRememberMe,
                                          activeColor: AppColors.primary,
                                          checkColor: AppColors.onPrimary,
                                        ),

                                         ResponsiveTextWidget(
                                          AppStrings.rememberMe,
                                          fontSize: context.responsiveTextS,
                                      color: AppColors.black),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(context, AppRoutes.forgotpassword);
                                      },
                                      child: const ResponsiveTextWidget(
                                        AppStrings.forgotPassword,
                                        fontSize: AppDimensions.textS,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),



                                  ],
                                ),

                                SizedBox(height: context.getConditionalSpacing()),

                                /// Login Button
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: viewModel.isLoading
                                      ? null
                                      : () => viewModel.validateAndLogin(context),
                                  child: viewModel.isLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: AppDimensions.iconS,
                                              height: AppDimensions.iconS,
                                              child: CircularProgressIndicator(
                                                color: AppColors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: context.responsiveSpaceS),
                                            const ResponsiveTextWidget(
                                              AppStrings.loggingIn,
                                              textType: TextType.body,
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                             Icon(
                                              Icons.login,
                                              color: AppColors.white,
                                              size: context.responsiveIconS,
                                            ),
                                            SizedBox(width: context.responsiveSpaceS),
                                            const ResponsiveTextWidget(
                                              AppStrings.login,
                                              textType: TextType.body,
                                              color: AppColors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ],
                                        ),
                                ),

                                SizedBox(height: context.getConditionalSpacing()),


                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const ResponsiveTextWidget(
                                      AppStrings.dontHaveAccount,
                                      textType: TextType.body,
                                      color: AppColors.black),
                                    SizedBox(width: AppDimensions.spaceXS),
                                    GestureDetector(
                                      onTap: () => viewModel.goToSignUp(context),
                                      child:  ResponsiveTextWidget(
                                        AppStrings.signUp,
                                        fontSize: context.getConditionalFont(),
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: context.getConditionalSpacing()),
                              ],
                            ),
                          ),
                                  ],
                                ),
                              ),
                            ),
                                SizedBox(height: isKeyboardVisible ? screenHeight * 0.02 : screenHeight * 0.1),
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
          ),
          );
        },
      ),
    );
  }
}
