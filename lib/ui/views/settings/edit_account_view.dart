import 'dart:io';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import 'edit_account_view_model.dart';

class EditAccountView extends BaseView<EditAccountViewModel> {
  const EditAccountView({super.key});

  @override
  EditAccountViewModel createViewModel() => EditAccountViewModel();

  @override
  void onError(BuildContext context, String error) {
    // Show error snackbar with black text color
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget buildView(BuildContext context, EditAccountViewModel viewModel) {
    return Consumer<EditAccountViewModel>(
      builder: (context, vm, child) {
        // Listen for success message and show snackbar
        if (vm.successMessage != null && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  vm.successMessage!,
                  style: const TextStyle(color: Colors.black),
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        }
        
        return Scaffold(
          backgroundColor: AppColors.grey50,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: AppColors.onPrimary),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary),
              onPressed: vm.goBack,
            ),
            title: const ResponsiveTextWidget(
              AppStrings.editAccountDetails,
              textType: TextType.title,
              fontWeight: FontWeight.bold,
              color: AppColors.onPrimary,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppDimensions.paddingM),
                child: IntrinsicWidth(
                  child: ElevatedButton.icon(
                    onPressed: vm.isLoading ? null : vm.saveChanges,
                    icon: vm.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Icon(Icons.save, size: 18, color: Colors.black),
                    label: ResponsiveTextWidget(
                      vm.isLoading ? 'Saving...' : AppStrings.save,
                      textType: TextType.caption,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                        vertical: AppDimensions.paddingS,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Form(
                  key: vm.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileSection(context, vm),
                      const SizedBox(height: AppDimensions.paddingL),
                      
                      _buildPersonalInfoSection(context, vm),
                      const SizedBox(height: AppDimensions.paddingL),
                      
                      _buildContactInfoSection(context, vm),
                      const SizedBox(height: AppDimensions.paddingL),
                      
                      _buildPasswordSection(context, vm),
                      const SizedBox(height: AppDimensions.paddingL),
                      
                      _buildDangerZoneSection(context, vm),
                      const SizedBox(height: AppDimensions.paddingXL),
                    ],
                  ),
                ),
              ),
              // Loading overlay
              if (vm.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                          const SizedBox(height: AppDimensions.paddingM),
                          ResponsiveTextWidget(
                            'Updating Information...',
                            textType: TextType.body,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSection(BuildContext context, EditAccountViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              const Expanded(
                child: ResponsiveTextWidget(
                  "Profile Information",
                  textType: TextType.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          
          // Profile Image with professional styling
          Stack(
            children: [
              GestureDetector(
                onTap: () => _showImageSourceDialog(context, viewModel),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.grey100,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildProfileImage(viewModel),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showImageSourceDialog(context, viewModel),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          const ResponsiveTextWidget(
            AppStrings.tapToUploadImage,
            textType: TextType.caption,
            color: AppColors.grey600,
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          
          const ResponsiveTextWidget(
            "Recommended: 400x400px, Max 5MB",
            textType: TextType.caption,
            color: AppColors.grey500,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context, EditAccountViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              const Expanded(
                child: ResponsiveTextWidget(
                  "Personal Information",
                  textType: TextType.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          
          // Name Field
          _buildTextField(
            controller: viewModel.nameController,
            label: "Full Name",
            hint: "Enter your full name",
            validator: viewModel.validateName,
            icon: Icons.person_outline,
            onChanged: viewModel.onNameChanged,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          // Bio Field
          _buildTextField(
            controller: viewModel.bioController,
            label: "Bio",
            hint: "Tell us about yourself",
            validator: viewModel.validateBio,
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoSection(BuildContext context, EditAccountViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                child: const Icon(
                  Icons.contact_mail_outlined,
                  color: AppColors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              const Expanded(
                child: ResponsiveTextWidget(
                  "Contact Information",
                  textType: TextType.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          
          // Email Field (Read-only)
          _buildTextField(
            controller: viewModel.emailController,
            label: AppStrings.emailLabel,
            hint: AppStrings.emailHint,
            validator: viewModel.validateEmail,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
            helperText: "Email cannot be changed",
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          // Phone Field (Read-only)
          _buildTextField(
            controller: viewModel.phoneController,
            label: AppStrings.phoneNumber,
            hint: AppStrings.phoneHint,
            validator: viewModel.validatePhone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            readOnly: true,
            helperText: "Phone number cannot be changed",
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection(BuildContext context, EditAccountViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResponsiveTextWidget(
            AppStrings.changePassword,
            textType: TextType.title,
            fontWeight: FontWeight.bold,
            color: AppColors.onPrimary,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          // Current Password
          _buildPasswordField(
            controller: viewModel.currentPasswordController,
            focusNode: viewModel.currentPasswordFocus,
            label: 'Current Password',
            hint: AppStrings.passwordHint,
            validator: viewModel.validateCurrentPassword,
            isVisible: viewModel.isPasswordVisible,
            onToggleVisibility: viewModel.togglePasswordVisibility,
            onSubmitted: (_) => viewModel.handleCurrentPasswordSubmitted(),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          // New Password
          _buildPasswordField(
            controller: viewModel.newPasswordController,
            focusNode: viewModel.newPasswordFocus,
            label: 'New Password',
            hint: AppStrings.passwordHint,
            validator: viewModel.validateNewPassword,
            isVisible: viewModel.isNewPasswordVisible,
            onToggleVisibility: viewModel.toggleNewPasswordVisibility,
            onSubmitted: (_) => viewModel.handleNewPasswordSubmitted(),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          // Confirm Password
          _buildPasswordField(
            controller: viewModel.confirmPasswordController,
            focusNode: viewModel.confirmPasswordFocus,
            label: AppStrings.confirmPasswordLabel,
            hint: AppStrings.confirmPasswordHint,
            validator: viewModel.validateConfirmPassword,
            isVisible: viewModel.isConfirmPasswordVisible,
            onToggleVisibility: viewModel.toggleConfirmPasswordVisibility,
            onSubmitted: (_) => viewModel.handleConfirmPasswordSubmitted(),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          // Change Password Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: viewModel.changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
              ),
              child: const ResponsiveTextWidget(
                AppStrings.changePassword,
                textType: TextType.body,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection(BuildContext context, EditAccountViewModel viewModel) {
    return Container(
      padding: EdgeInsets.all(
        context.isSmallScreen 
            ? AppDimensions.paddingM
            : context.isMediumScreen 
                ? AppDimensions.paddingL
                : AppDimensions.paddingXL
      ),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResponsiveTextWidget(
            AppStrings.dangerZone,
            textType: TextType.title,
            fontWeight: FontWeight.bold,
            color: AppColors.red,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          
          const ResponsiveTextWidget(
            AppStrings.deleteAccountWarning,
            textType: TextType.caption,
            color: AppColors.red,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showDeleteAccountDialog(context, viewModel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
              ),
              child: const ResponsiveTextWidget(
                AppStrings.delete,
                textType: TextType.body,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    String? helperText,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: readOnly ? AppColors.grey500 : AppColors.primary),
        helperText: helperText,
        helperStyle: TextStyle(
          color: AppColors.grey600,
          fontSize: AppDimensions.textS,
        ),
        filled: readOnly,
        fillColor: readOnly ? AppColors.grey100 : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: readOnly ? AppColors.grey300 : AppColors.grey300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: readOnly ? AppColors.grey400 : AppColors.accent,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required void Function(String) onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: !isVisible,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off : Icons.visibility,
            color: AppColors.grey600,
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(
            color: AppColors.accent,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, EditAccountViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const ResponsiveTextWidget(
            "Delete Account",
            textType: TextType.title,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
          content: const ResponsiveTextWidget(
            "Are you sure you want to delete your account? This action cannot be undone.",
            textType: TextType.body,
            color: AppColors.onPrimary,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const ResponsiveTextWidget(
                AppStrings.cancel,
                textType: TextType.body,
                color: AppColors.grey600,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                viewModel.deleteAccount();
              },
              child: const ResponsiveTextWidget(
                AppStrings.confirm,
                textType: TextType.body,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveTextWidget(
          label,
          textType: TextType.body,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimary,
        ),
        const SizedBox(height: AppDimensions.paddingS),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              borderSide: const BorderSide(color: AppColors.grey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      child: Row(
        children: [
          Icon(icon, color: AppColors.grey600, size: 20),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  title,
                  textType: TextType.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimary,
                ),
                ResponsiveTextWidget(
                  subtitle,
                  textType: TextType.caption,
                  color: AppColors.grey600,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// Build profile image widget
  Widget _buildProfileImage(EditAccountViewModel viewModel) {
    // Show local file if available (newly picked image)
    if (viewModel.profileImageFile != null) {
      return ClipOval(
        child: Image.file(
          viewModel.profileImageFile!,
          fit: BoxFit.cover,
          width: 140,
          height: 140,
        ),
      );
    }
    
    // Show Firebase URL if available
    if (viewModel.profileImageUrl != null && viewModel.profileImageUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: viewModel.profileImageUrl!,
          fit: BoxFit.cover,
          width: 140,
          height: 140,
          placeholder: (context, url) => Container(
            color: AppColors.grey100,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.person,
            size: 70,
            color: AppColors.grey500,
          ),
        ),
      );
    }
    
    // Default placeholder
    return const Icon(
      Icons.person,
      size: 70,
      color: AppColors.grey500,
    );
  }

  /// Show beautiful dialog for image source selection
  void _showImageSourceDialog(BuildContext context, EditAccountViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
          backgroundColor: AppColors.primary,
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ResponsiveTextWidget(
                  'Select Image Source',
                  textType: TextType.heading,
                  fontWeight: FontWeight.bold,
                  fontSize: AppDimensions.textL,
                  color: AppColors.onPrimary,
                ),
                const SizedBox(height: AppDimensions.paddingXL),
                
                // Camera Option
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await viewModel.pickProfileImageFromCamera();
                    // Don't upload immediately - wait for save button
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.paddingL),
                        const Expanded(
                          child: ResponsiveTextWidget(
                            AppStrings.camera,
                            textType: TextType.body,
                            fontSize: AppDimensions.textL,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.onPrimary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppDimensions.paddingL),
                
                // Gallery Option
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await viewModel.pickProfileImageFromGallery();
                    // Don't upload immediately - wait for save button
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.paddingL),
                        const Expanded(
                          child: ResponsiveTextWidget(
                            AppStrings.gallery,
                            textType: TextType.body,
                            fontSize: AppDimensions.textL,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.onPrimary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppDimensions.paddingL),
                
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const ResponsiveTextWidget(
                    AppStrings.cancel,
                    textType: TextType.body,
                    fontSize: AppDimensions.textM,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
 