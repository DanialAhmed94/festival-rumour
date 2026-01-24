import 'package:country_code_picker/country_code_picker.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final bool fromFestival;
  const SignupView({super.key, this.fromFestival = false});

  @override
  SignupViewModel createViewModel() => SignupViewModel();

  @override
  Widget buildView(BuildContext context, SignupViewModel viewModel) {
    viewModel.fromFestival = this.fromFestival; // ✔ works correctly
    final bool fromFestival = this.fromFestival; // ✔ works correctly

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
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusXXL),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, fromFestival),
                      SizedBox(height: context.responsiveSpaceL),
                      _buildPhoneInput(context, viewModel),
                      SizedBox(height: context.responsiveSpaceL),
                      _buildDescription(context, fromFestival),
                      SizedBox(height: context.responsiveSpaceXL),
                      _buildContinueButton(context, viewModel),
                      SizedBox(height: AppDimensions.paddingL),
                    ],
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool fromFestival) {
    return Row(
      children: [
        CustomBackButton(onTap: () => context.pop()),
        SizedBox(width: context.responsiveSpaceM),
        ResponsiveTextWidget(
          fromFestival ? "Verify Contact" : AppStrings.signUp,
          style: TextStyle(
            fontSize: context.responsiveTextXL,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput(BuildContext context, SignupViewModel viewModel) {
    return Row(
      children: [
        /// Country Picker with Dropdown Icon
        SizedBox(
          width: AppDimensions.countryPickerWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingS,
            ),
            height: AppDimensions.buttonHeightM,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Row(
              children: [
                /// Country Picker
                Expanded(
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
                        color: AppColors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      showFlag: true,
                      showFlagDialog: true,
                      flagWidth: 32,
                    ),
                  ),
                ),

                /// 🔽 Dropdown Arrow Icon (new)
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.black,
                  size: 22,
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: context.responsiveSpaceM),

        /// Phone Number Field
        Expanded(
          child: TextField(
            controller: viewModel.phoneNumberController,
            focusNode: viewModel.phoneFocus,
            autofocus: true,
            style: const TextStyle(color: AppColors.black),
            decoration: InputDecoration(
              hintText: AppStrings.phoneHint,
              hintStyle: const TextStyle(color: AppColors.black),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.black),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: AppColors.black,
                  width: AppDimensions.borderWidthM,
                ),
              ),
              errorText: viewModel.phoneNumberError,
              errorStyle: TextStyle(
                color: AppColors.accent,
                fontSize: context.responsiveTextS,
                fontWeight: FontWeight.w500,
              ),
            ),
            keyboardType: TextInputType.phone,
            cursorColor: AppColors.black,
            textInputAction: TextInputAction.done,
            onChanged: (value) => viewModel.validatePhone(),
            onSubmitted: (_) => viewModel.goToOtp(),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, bool fromFestival) {
    return ResponsiveTextWidget(
      fromFestival
          ? "Please verify your phone number to continue."
          : AppStrings.otpdescription,
      style: TextStyle(
        color: AppColors.black,
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
            ? SizedBox(
                width: context.responsiveIconS,
                height: context.responsiveIconS,
                child: const CircularProgressIndicator(
                  color: AppColors.white,
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

