import 'package:country_code_picker/country_code_picker.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/auth_background.dart';
import '../../../../core/utils/backbutton.dart';
import '../../../../core/utils/base_view.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/responsive_text_widget.dart';
import '../../../../shared/widgets/responsive_widget.dart';
import 'signup_view_model.dart';


class SignupView extends BaseView<SignupViewModel> {
  const SignupView({super.key});

  @override
  SignupViewModel createViewModel() => SignupViewModel();

  @override
  Widget buildView(BuildContext context, SignupViewModel viewModel) {
    // Listen for error messages and show snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.errorMessage!),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: AppColors.onPrimary,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          /// 🔹 Background
          const AuthBackground(),

          /// 🔹 Signup container at bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: ResponsiveContainer(
              mobileMaxWidth: double.infinity,
              tabletMaxWidth: AppDimensions.tabletWidth,
              desktopMaxWidth: AppDimensions.desktopWidth,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsivePadding.top,
                  vertical: context.responsivePadding.left,
                ),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppAssets.bottomsheet),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusXXL),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      SizedBox(height: context.responsiveSpaceL),
                      _buildPhoneInput(context, viewModel),
                      SizedBox(height: context.responsiveSpaceL),
                      _buildDescription(context),
                      SizedBox(height: context.responsiveSpaceXL),
                      _buildContinueButton(context, viewModel),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// 🔹 Loader overlay
          if (viewModel.isLoading)
            Container(
              color: AppColors.overlay,
              alignment: Alignment.center,
              child: const LoadingWidget(color: AppColors.onPrimary),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        CustomBackButton(onTap: () => context.pop()),
        SizedBox(width: context.responsiveSpaceM),
        ResponsiveTextWidget(
          AppStrings.signUp,
          style: TextStyle(
            fontSize: context.responsiveTextXXL,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput(BuildContext context, SignupViewModel viewModel) {
    return Row(
      children: [
        SizedBox(
          width: AppDimensions.countryPickerWidth,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
            height: AppDimensions.buttonHeightM,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Localizations.override(
              context: context,
              locale: const Locale(AppStrings.localeEnglish),
              child: CountryCodePicker(
                onChanged: viewModel.onCountryChanged,
                initialSelection: viewModel.selectedCountryCode.code,
                favorite: AppStrings.favoriteCountries,
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: AppDimensions.textM,
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                ),
                showFlag: true,
                showFlagDialog: true,
              ),
            ),
          ),
        ),
        SizedBox(width: context.responsiveSpaceM),
        Expanded(
          child: TextField(
            controller: viewModel.phoneNumberController,
            focusNode: viewModel.phoneFocus,
            autofocus: true, // Auto-focus on first field
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: AppStrings.phoneHint,
              hintStyle: const TextStyle(color: AppColors.white),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.white),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: AppDimensions.borderWidthM),
              ),
              errorText: viewModel.phoneNumberError,
              errorStyle: TextStyle(
                color: AppColors.accent,
                fontSize: context.responsiveTextS,
                fontWeight: FontWeight.w500,
              ),
            ),
            keyboardType: TextInputType.phone,
            cursorColor: AppColors.primary,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              viewModel.validatePhone();
              // Clear error when user starts typing
              // Note: validatePhone() already calls notifyListeners() if needed
              // No need to call notifyListeners() again here
            },
            onSubmitted: (_) => viewModel.goToOtp(),
          ),
        ),
      ],
    );
  }


  Widget _buildDescription(BuildContext context) {
    return ResponsiveTextWidget(
      AppStrings.otpdescription,
      style: TextStyle(
        color: AppColors.white,
        fontSize: context.responsiveTextM,
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context, SignupViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      height: context.responsiveButtonHeightXL,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
          padding: EdgeInsets.symmetric(
            vertical: context.responsivePadding.top,
          ),
        ),
        onPressed: viewModel.isLoading ? null : viewModel.goToOtp,
        child: viewModel.isLoading
            ?  SizedBox(
          width: context.responsiveIconS,
          height: context.responsiveIconS,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        )
            : ResponsiveTextWidget(
          AppStrings.continueText,
          textType: TextType.body,
          fontSize: context.responsiveTextL,
          fontWeight: FontWeight.bold,
          color: AppColors.onPrimary,
        ),
        ),
    );
  }
}
