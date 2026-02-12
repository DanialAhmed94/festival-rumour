import 'package:festival_rumour/core/constants/app_assets.dart';
import 'package:festival_rumour/core/constants/app_colors.dart';
import 'package:festival_rumour/core/constants/app_sizes.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'festivals_job_post_view_model.dart';


class FestivalsJobPostView extends BaseView<FestivalsJobPostViewModel> {
  final String? category;
  final Map<String, dynamic>? jobData;

  const FestivalsJobPostView({super.key, this.category, this.jobData});

  @override
  FestivalsJobPostViewModel createViewModel() => FestivalsJobPostViewModel();

  @override
  void onViewModelReady(FestivalsJobPostViewModel viewModel) {
    super.onViewModelReady(viewModel);
    if (category != null) viewModel.setCategoryFromNavigation(category!);
    if (jobData != null) viewModel.loadJobForEditing(jobData!);
  }

  @override
  Widget buildView(BuildContext context, FestivalsJobPostViewModel viewModel) {
    return GestureDetector(
      onTap: viewModel.unfocusAllFields,
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: SafeArea(
            bottom: false,
            child: Container(
              color: const Color(0xFFFC2E95),
              padding: EdgeInsets.symmetric(
                horizontal: context.isSmallScreen
                    ? AppDimensions.paddingS
                    : AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppDimensions.spaceS),
                  Expanded(
                    child: ResponsiveTextWidget(
                      viewModel.isEditing ? 'Edit Job' : 'Post Job',
                      textType: TextType.title,
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(
            context.isSmallScreen ? AppDimensions.paddingM : AppDimensions.paddingL,
          ),
          child: Container(
            padding: EdgeInsets.all(
              context.isSmallScreen ? AppDimensions.paddingM : AppDimensions.paddingL,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(
                color: AppColors.black.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Job Header (Title + Category Badge)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveTextWidget(
                            viewModel.jobTitleController.text.isEmpty
                                ? ' Add job detail'
                                : viewModel.jobTitleController.text,
                            textType: TextType.heading,
                            fontSize: context.isSmallScreen
                                ? AppDimensions.textL
                                : AppDimensions.textXL,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                          SizedBox(height: context.isSmallScreen
                              ? AppDimensions.spaceS
                              : AppDimensions.spaceM),
                          ResponsiveTextWidget(
                            viewModel.companyController.text,
                            textType: TextType.body,
                            fontSize: context.isSmallScreen
                                ? AppDimensions.textM
                                : AppDimensions.textL,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ],
                      ),
                    ),
                    if (viewModel.selectedCategory != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.isSmallScreen
                              ? AppDimensions.paddingS
                              : AppDimensions.paddingM,
                          vertical: AppDimensions.paddingS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                          border: Border.all(
                            color: AppColors.black.withOpacity(0.18),
                            width: 1.5,
                          ),
                        ),
                        child: ResponsiveTextWidget(
                          viewModel.selectedCategory!,
                          textType: TextType.body,
                          fontSize: context.isSmallScreen
                              ? AppDimensions.textS
                              : AppDimensions.textM,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: context.isSmallScreen
                    ? AppDimensions.paddingM
                    : AppDimensions.paddingL),

                // Divider
                Divider(color: AppColors.black.withOpacity(0.1), thickness: 2),
                SizedBox(height: context.isSmallScreen
                    ? AppDimensions.paddingM
                    : AppDimensions.paddingL),

                // Form Fields
                _buildTextField(context, 'Job Title', viewModel.jobTitleController, viewModel.jobTitleFocusNode, viewModel.companyFocusNode, Icons.work),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(context, 'Company', viewModel.companyController, viewModel.companyFocusNode, viewModel.locationFocusNode, Icons.business),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(context, 'Location', viewModel.locationController, viewModel.locationFocusNode, viewModel.salaryFocusNode, Icons.location_on),
                SizedBox(height: AppDimensions.paddingM),
                _buildDropdown(context, 'Job Type', viewModel.selectedJobType, viewModel.jobTypes, viewModel.setJobType),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(context, 'Salary', viewModel.salaryController, viewModel.salaryFocusNode, viewModel.descriptionFocusNode, Icons.attach_money),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextArea(context, 'Description', viewModel.descriptionController, viewModel.descriptionFocusNode, viewModel.requirementsFocusNode, Icons.description),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextArea(context, 'Requirements', viewModel.requirementsController, viewModel.requirementsFocusNode, viewModel.contactFocusNode, Icons.checklist),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(context, 'Contact Info', viewModel.contactController, viewModel.contactFocusNode, viewModel.festivalDateFocusNode, Icons.contact_mail),
                SizedBox(height: AppDimensions.paddingM),
                _buildDateField(context, 'Festival Date', viewModel.festivalDateController, viewModel.festivalDateFocusNode, Icons.calendar_today, () => viewModel.selectFestivalDate(context)),
                SizedBox(height: AppDimensions.paddingL),

                // Post Button
                _buildPostButton(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller,
      FocusNode focusNode, FocusNode nextFocusNode, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: AppColors.black.withOpacity(0.7)),
          SizedBox(width: AppDimensions.spaceS),
          ResponsiveTextWidget(label, textType: TextType.body, fontWeight: FontWeight.w600),
        ]),
        SizedBox(height: AppDimensions.spaceS),
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => nextFocusNode.requestFocus(),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: AppColors.black.withOpacity(0.3)),
            filled: true,
            fillColor: AppColors.grey100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: BorderSide(color: AppColors.black.withOpacity(0.1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(BuildContext context, String label, TextEditingController controller,
      FocusNode focusNode, FocusNode nextFocusNode, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: AppColors.black.withOpacity(0.7)),
          SizedBox(width: AppDimensions.spaceS),
          ResponsiveTextWidget(label, textType: TextType.body, fontWeight: FontWeight.w600),
        ]),
        SizedBox(height: AppDimensions.spaceS),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: 4,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => nextFocusNode.requestFocus(),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: AppColors.black.withOpacity(0.3)),
            filled: true,
            fillColor: AppColors.grey100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: BorderSide(color: AppColors.black.withOpacity(0.1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(BuildContext context, String label, String? value, List<String> items, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveTextWidget(label, textType: TextType.body, fontWeight: FontWeight.w600),
        SizedBox(height: AppDimensions.spaceS),
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.spaceM),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            border: Border.all(color: AppColors.black.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              dropdownColor: AppColors.white,
              style: const TextStyle(color: AppColors.black),
              icon: const Icon(Icons.arrow_drop_down),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context, String label, TextEditingController controller, FocusNode focusNode,
      IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: _buildTextField(context, label, controller, focusNode, FocusNode(), icon),
      ),
    );
  }

  Widget _buildPostButton(BuildContext context, FestivalsJobPostViewModel viewModel) {
    return ElevatedButton(
      onPressed: viewModel.isLoading ? null : () => viewModel.postJob(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFC2E95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusL)),
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
      ),
      child: viewModel.isLoading
          ? const CircularProgressIndicator(color: AppColors.white)
          : ResponsiveTextWidget(
        viewModel.isEditing ? 'Update Job' : 'Post Job',
        textType: TextType.body,
        fontWeight: FontWeight.bold,
        color: AppColors.white,
      ),
    );
  }
}
