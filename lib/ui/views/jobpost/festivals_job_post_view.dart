import 'package:festival_rumour/core/constants/app_colors.dart';
import 'package:festival_rumour/core/constants/app_sizes.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'festivals_job_post_view_model.dart';
import 'job_location_map_picker_screen.dart';

class FestivalsJobPostView extends BaseView<FestivalsJobPostViewModel> {
  final String? category;
  final Map<String, dynamic>? jobData;

  const FestivalsJobPostView({super.key, this.category, this.jobData});

  @override
  bool get useWideProviderListen => false;

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
                    child: Selector<FestivalsJobPostViewModel, bool>(
                      selector: (_, m) => m.isEditing,
                      builder: (context, editing, _) {
                        return ResponsiveTextWidget(
                          editing ? 'Edit Job' : 'Post Job',
                          textType: TextType.title,
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListenableBuilder(
                            listenable: viewModel.jobTitleController,
                            builder: (context, _) {
                              return ResponsiveTextWidget(
                                viewModel.jobTitleController.text.isEmpty
                                    ? ' Add job detail'
                                    : viewModel.jobTitleController.text,
                                textType: TextType.heading,
                                fontSize: context.isSmallScreen
                                    ? AppDimensions.textL
                                    : AppDimensions.textXL,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              );
                            },
                          ),
                          SizedBox(
                            height: context.isSmallScreen
                                ? AppDimensions.spaceS
                                : AppDimensions.spaceM,
                          ),
                          ListenableBuilder(
                            listenable: viewModel.companyController,
                            builder: (context, _) {
                              return ResponsiveTextWidget(
                                viewModel.companyController.text,
                                textType: TextType.body,
                                fontSize: context.isSmallScreen
                                    ? AppDimensions.textM
                                    : AppDimensions.textL,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Selector<FestivalsJobPostViewModel, String?>(
                      selector: (_, m) => m.selectedCategory,
                      builder: (context, selectedCategory, _) {
                        if (selectedCategory == null) return const SizedBox.shrink();
                        return Container(
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
                            selectedCategory,
                            textType: TextType.body,
                            fontSize: context.isSmallScreen
                                ? AppDimensions.textS
                                : AppDimensions.textM,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(
                  height: context.isSmallScreen
                      ? AppDimensions.paddingM
                      : AppDimensions.paddingL,
                ),

                Divider(color: AppColors.black.withOpacity(0.1), thickness: 2),
                SizedBox(
                  height: context.isSmallScreen
                      ? AppDimensions.paddingM
                      : AppDimensions.paddingL,
                ),

                _buildTextField(
                  context,
                  'Job Title',
                  viewModel.jobTitleController,
                  viewModel.jobTitleFocusNode,
                  viewModel.companyFocusNode,
                  Icons.work,
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(
                  context,
                  'Company',
                  viewModel.companyController,
                  viewModel.companyFocusNode,
                  viewModel.locationFocusNode,
                  Icons.business,
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildLocationField(context, viewModel),
                SizedBox(height: AppDimensions.paddingM),
                Selector<FestivalsJobPostViewModel, String>(
                  selector: (_, m) => m.selectedJobType,
                  builder: (context, selectedJobType, _) {
                    return _buildDropdown(
                      context,
                      'Job Type',
                      selectedJobType,
                      viewModel.jobTypes,
                      viewModel.setJobType,
                    );
                  },
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(
                  context,
                  'Salary',
                  viewModel.salaryController,
                  viewModel.salaryFocusNode,
                  viewModel.descriptionFocusNode,
                  Icons.attach_money,
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextArea(
                  context,
                  'Description',
                  viewModel.descriptionController,
                  viewModel.descriptionFocusNode,
                  Icons.description,
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextArea(
                  context,
                  'Requirements',
                  viewModel.requirementsController,
                  viewModel.requirementsFocusNode,
                  Icons.checklist,
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(
                  context,
                  'Contact Info',
                  viewModel.contactController,
                  viewModel.contactFocusNode,
                  viewModel.jobUrlFocusNode,
                  Icons.contact_mail,
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildTextField(
                  context,
                  'Job URL (optional)',
                  viewModel.jobUrlController,
                  viewModel.jobUrlFocusNode,
                  viewModel.festivalDateFocusNode,
                  Icons.link,
                  hintText: 'https://example.com/job or leave blank',
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                ),
                SizedBox(height: AppDimensions.paddingM),
                _buildDateField(
                  context,
                  'Festival Date',
                  viewModel.festivalDateController,
                  viewModel.festivalDateFocusNode,
                  viewModel.festivalDateDummyNextFocusNode,
                  Icons.calendar_today,
                  () => viewModel.selectFestivalDate(context),
                ),
                SizedBox(height: AppDimensions.paddingL),

                Selector<FestivalsJobPostViewModel, (bool, bool)>(
                  selector: (_, m) => (m.isLoading, m.isEditing),
                  builder: (context, tuple, _) {
                    final (isLoading, isEditing) = tuple;
                    return _buildPostButton(context, viewModel, isLoading, isEditing);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickLocationOnMap(
    BuildContext context,
    FestivalsJobPostViewModel viewModel,
  ) async {
    final address = await JobLocationMapPickerScreen.open(context);
    if (!context.mounted) return;
    if (address != null && address.isNotEmpty) {
      viewModel.locationController.text = address;
    }
  }

  Widget _buildLocationField(
    BuildContext context,
    FestivalsJobPostViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: AppColors.black.withOpacity(0.7)),
            SizedBox(width: AppDimensions.spaceS),
            Expanded(
              child: ResponsiveTextWidget(
                'Location',
                textType: TextType.body,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickLocationOnMap(context, viewModel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.black,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: context.isSmallScreen
                      ? AppDimensions.paddingS
                      : AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
              ),
              icon: Icon(
                Icons.map_outlined,
                size: context.isSmallScreen ? 20 : 22,
                color: AppColors.black.withOpacity(0.85),
              ),
              label: ResponsiveTextWidget(
                'Map',
                textType: TextType.body,
                fontWeight: FontWeight.w600,
                color: AppColors.black.withOpacity(0.85),
                fontSize: context.isSmallScreen
                    ? AppDimensions.textS
                    : AppDimensions.textM,
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spaceS),
        TextField(
          controller: viewModel.locationController,
          focusNode: viewModel.locationFocusNode,
          textInputAction: TextInputAction.next,
          cursorColor: AppColors.black,
          style: const TextStyle(color: AppColors.black),
          onSubmitted: (_) => viewModel.salaryFocusNode.requestFocus(),
          decoration: InputDecoration(
            hintText: 'Enter location or pick on map',
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

  Widget _buildTextField(
    BuildContext context,
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    FocusNode nextFocusNode,
    IconData icon, {
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    bool autocorrect = true,
    bool enableSuggestions = true,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
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
          keyboardType: keyboardType,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          textCapitalization: textCapitalization,
          textInputAction: TextInputAction.next,
          cursorColor: AppColors.black,
          style: const TextStyle(color: AppColors.black),
          onSubmitted: (_) => nextFocusNode.requestFocus(),
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter $label',
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

  Widget _buildTextArea(
    BuildContext context,
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    IconData icon,
  ) {
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
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 6,
          maxLines: null,
          cursorColor: AppColors.black,
          style: const TextStyle(color: AppColors.black),
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

  Widget _buildDropdown(
    BuildContext context,
    String label,
    String? value,
    List<String> items,
    Function(String) onChanged,
  ) {
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

  Widget _buildDateField(
    BuildContext context,
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    FocusNode dummyNextSubmitTarget,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: _buildTextField(
          context,
          label,
          controller,
          focusNode,
          dummyNextSubmitTarget,
          icon,
        ),
      ),
    );
  }

  Widget _buildPostButton(
    BuildContext context,
    FestivalsJobPostViewModel viewModel,
    bool isLoading,
    bool isEditing,
  ) {
    return ElevatedButton(
      onPressed: isLoading ? null : () => viewModel.postJob(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFC2E95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusL)),
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: AppColors.black)
          : ResponsiveTextWidget(
              isEditing ? 'Update Job' : 'Post Job',
              textType: TextType.body,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
    );
  }
}
