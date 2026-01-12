import 'package:festival_rumour/core/constants/app_assets.dart';
import 'package:festival_rumour/core/constants/app_colors.dart';
import 'package:festival_rumour/core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'festivals_job_post_view_model.dart';


class FestivalsJobPostView extends BaseView<FestivalsJobPostViewModel> {
  final String? category; // Category selected from modal bottom sheet
  final Map<String, dynamic>? jobData; // Job data for editing (null means new job)
  
  const FestivalsJobPostView({super.key, this.category, this.jobData});

  @override
  FestivalsJobPostViewModel createViewModel() => FestivalsJobPostViewModel();
  
  @override
  void onViewModelReady(FestivalsJobPostViewModel viewModel) {
    super.onViewModelReady(viewModel);
    // Set the category from navigation arguments
    if (category != null) {
      viewModel.setCategoryFromNavigation(category!);
    }
    // If jobData is provided, populate form for editing
    if (jobData != null) {
      viewModel.loadJobForEditing(jobData!);
    }
  }

  @override
  void onError(BuildContext context, String error) {
    // Custom error handling with print statement
    if (kDebugMode) {
      print('❌ [JobPostView] Showing error snackbar: $error');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.black),
              const SizedBox(width: AppDimensions.spaceS),
              Expanded(
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget buildView(BuildContext context, FestivalsJobPostViewModel viewModel) {
    // Listen for success message and show snackbar
    if (viewModel.successMessage != null && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppDimensions.spaceS),
                Expanded(
                  child: Text(
                    viewModel.successMessage!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // Clear success message after showing snackbar
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            viewModel.clearSuccessMessage();
          }
        });
      });
    }

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        viewModel.unfocusAllFields();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Consumer<FestivalsJobPostViewModel>(
            builder: (context, vm, child) {
              return ResponsiveTextWidget(
                vm.isEditing ? 'Edit Job' : AppStrings.postJob,
                textType: TextType.body, 
                color: AppColors.white, 
                fontWeight: FontWeight.bold,
              );
            },
          ),
        ),
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                AppAssets.bottomsheet,
                fit: BoxFit.cover,
              ),
            ),
            
            // Main Content
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingM),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppDimensions.paddingL),
                      
                      // Job Post Form
                      _buildJobPostForm(context),
                      
                      const SizedBox(height: AppDimensions.paddingL),
                      
                      // Post/Update Job Button
                      _buildPostButton(context, viewModel),
                      
                      const SizedBox(height: AppDimensions.paddingL),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobPostForm(BuildContext context) {
    return Consumer<FestivalsJobPostViewModel>(
      builder: (context, vm, child) {
        return Container(
          padding: EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: AppColors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.yellow, width: AppDimensions.borderWidthS),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Title
          const ResponsiveTextWidget(
            AppStrings.jobDetails,
            textType: TextType.body, 
              color: AppColors.yellow,
              fontSize: AppDimensions.textL,
              fontWeight: FontWeight.bold,
            ),
          const SizedBox(height: AppDimensions.paddingL),
          
          // Job Title Field
          _buildTextField(
            controller: vm.jobTitleController,
            focusNode: vm.jobTitleFocusNode,
            nextFocusNode: vm.companyFocusNode,
            label: AppStrings.jobTitle,
            hint: AppStrings.jobTitleHint,
            icon: Icons.work,
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Company/Organization Field
          _buildTextField(
            controller: vm.companyController,
            focusNode: vm.companyFocusNode,
            nextFocusNode: vm.locationFocusNode,
            label: AppStrings.company,
            hint: AppStrings.companyHint,
            icon: Icons.business,
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Location Field
          _buildTextField(
            controller: vm.locationController,
            focusNode: vm.locationFocusNode,
            nextFocusNode: vm.salaryFocusNode,
            label: AppStrings.location,
            hint: AppStrings.locationHint,
            icon: Icons.location_on,
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Job Type Dropdown
          _buildDropdownField(
            value: vm.selectedJobType,
            label: AppStrings.jobType,
            icon: Icons.category,
            items: vm.jobTypes,
            onChanged: (value) {
              vm.setJobType(value!);
              // Update salary field label when job type changes
            },
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Salary Field
          _buildTextField(
            controller: vm.salaryController,
            focusNode: vm.salaryFocusNode,
            nextFocusNode: vm.descriptionFocusNode,
            label: AppStrings.salary + (vm.selectedJobType == 'Volunteer' ? ' (Optional)' : ''),
            hint: AppStrings.salaryHint,
            icon: Icons.attach_money,
            keyboardType: TextInputType.text,
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Job Description
          _buildTextAreaField(
            controller: vm.descriptionController,
            focusNode: vm.descriptionFocusNode,
            nextFocusNode: vm.requirementsFocusNode,
            label: AppStrings.jobDescription,
            hint: AppStrings.jobDescriptionHint,
            icon: Icons.description,
            maxLines: 5,
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Requirements
          _buildTextAreaField(
            controller: vm.requirementsController,
            focusNode: vm.requirementsFocusNode,
            nextFocusNode: vm.contactFocusNode,
            label: AppStrings.requirements,
            hint: AppStrings.requirementsHint,
            icon: Icons.checklist,
            maxLines: 3,
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Contact Information
          _buildTextField(
            controller: vm.contactController,
            focusNode: vm.contactFocusNode,
            nextFocusNode: vm.festivalDateFocusNode,
            label: AppStrings.contactInfo,
            hint: AppStrings.contactInfoHint,
            icon: Icons.contact_mail,
            keyboardType: TextInputType.emailAddress,
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Festival Date
          _buildDateField(
            context: context,
            controller: vm.festivalDateController,
            focusNode: vm.festivalDateFocusNode,
            label: AppStrings.festivalDate,
            hint: AppStrings.festivalDateHint,
            icon: Icons.calendar_today,
            onTap: () => vm.selectFestivalDate(context),
          ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? nextFocusNode,
    bool isLastField = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.yellow, size: 20),
            const SizedBox(width: AppDimensions.spaceS),
            ResponsiveTextWidget(
              label,
              textType: TextType.body,
              color: AppColors.yellow,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceS),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: isLastField 
              ? TextInputAction.done 
              : (nextFocusNode != null ? TextInputAction.next : TextInputAction.next),
          onSubmitted: (_) {
            if (isLastField) {
              // Dismiss keyboard on last field
              focusNode.unfocus();
            } else if (nextFocusNode != null) {
              // Move to next field
              nextFocusNode.requestFocus();
            }
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.black.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.yellow.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.yellow.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.yellow, width: AppDimensions.borderWidthS),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.spaceM, vertical: AppDimensions.spaceM),
          ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 3,
    FocusNode? nextFocusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.yellow, size: 20),
            const SizedBox(width: AppDimensions.spaceS),
            ResponsiveTextWidget(
              label,
              textType: TextType.body,
              color: AppColors.yellow,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceS),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.newline,
          onSubmitted: (_) {
            if (nextFocusNode != null) {
              // Move to next field
              nextFocusNode.requestFocus();
            }
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.black.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.yellow.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.yellow.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.yellow, width: AppDimensions.borderWidthS),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.spaceM, vertical: AppDimensions.spaceM),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.yellow, size: 20),
            const SizedBox(width: AppDimensions.spaceS),
            ResponsiveTextWidget(
              label,
              textType: TextType.body,
              color: AppColors.yellow,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceS),
        GestureDetector(
          onTap: () {
            // Unfocus first to prevent any focus-related issues
            focusNode.unfocus();
            // Use a small delay to ensure focus is removed before opening picker
            Future.delayed(const Duration(milliseconds: 50), () {
              onTap();
            });
          },
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                focusNode.unfocus();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.black.withOpacity(0.5),
                suffixIcon: const Icon(Icons.calendar_today, color: AppColors.yellow),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.yellow.withOpacity(0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.yellow.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.yellow, width: AppDimensions.borderWidthS),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.spaceM, vertical: AppDimensions.spaceM),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String) onChanged,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.yellow, size: 20),
            const SizedBox(width: AppDimensions.spaceS),
            ResponsiveTextWidget(
              label + (isRequired ? ' *' : ''),
              textType: TextType.body,
              color: AppColors.yellow,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceS),
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.spaceM),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.yellow.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                'Select $label',
                style: TextStyle(
                  color: AppColors.white.withOpacity(0.6),
                ),
              ),
              dropdownColor: Colors.black.withOpacity(0.9),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.yellow),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: ResponsiveTextWidget(
                    item,
                    textType: TextType.body,
                    color: AppColors.white,
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostButton(BuildContext context, FestivalsJobPostViewModel viewModel) {
    return Consumer<FestivalsJobPostViewModel>(
      builder: (context, vm, child) {
        return Container(
          height: AppDimensions.buttonHeightXL,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.yellow, AppColors.orange],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: vm.isLoading ? null : () => vm.postJob(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: vm.isLoading
                ? const SizedBox(
                    height: AppDimensions.iconS,
                    width: AppDimensions.iconS,
                    child: CircularProgressIndicator(
                      color: AppColors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        vm.isEditing ? Icons.save : Icons.post_add,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppDimensions.spaceS),
                      ResponsiveTextWidget(
                        vm.isEditing ? 'Update Job' : AppStrings.postJob,
                        textType: TextType.body, 
                        color: AppColors.white,
                        fontSize: AppDimensions.textL,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
