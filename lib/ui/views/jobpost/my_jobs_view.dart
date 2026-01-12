import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'my_jobs_view_model.dart';

class MyJobsView extends BaseView<MyJobsViewModel> {
  const MyJobsView({super.key});

  @override
  MyJobsViewModel createViewModel() => MyJobsViewModel();

  @override
  void onViewModelReady(MyJobsViewModel viewModel) {
    super.onViewModelReady(viewModel);
    // Load jobs when view is ready (only once)
    viewModel.loadUserJobs();
  }

  @override
  Widget buildView(BuildContext context, MyJobsViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const ResponsiveTextWidget(
          'My Jobs',
          textType: TextType.title,
          fontWeight: FontWeight.bold,
          color: AppColors.onPrimary,
        ),
      ),
      body: Consumer<MyJobsViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.onPrimary,
              ),
            );
          }

          if (vm.jobsByCategory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 64,
                    color: AppColors.grey600,
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  ResponsiveTextWidget(
                    'No jobs posted yet',
                    textType: TextType.body,
                    fontSize: AppDimensions.textM,
                    color: AppColors.grey600,
                  ),
                ],
              ),
            );
          }

          // Show category tabs if multiple categories
          if (vm.categories.length > 1) {
            return Column(
              children: [
                // Category tabs
                Container(
                  height: AppDimensions.buttonHeightXL,
                  color: AppColors.black.withOpacity(0.8),
                  child: Row(
                    children: vm.categories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      final isSelected = vm.selectedCategoryIndex == index;
                      return Expanded(
                        child: InkWell(
                          onTap: () => vm.setSelectedCategoryIndex(index),
                          child: Container(
                            height: AppDimensions.buttonHeightXL,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? AppColors.yellow : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: ResponsiveTextWidget(
                              category,
                              color: isSelected ? AppColors.yellow : AppColors.white.withOpacity(0.6),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: context.getConditionalSubFont(),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Jobs list for selected category
                Expanded(
                  child: _buildJobsList(context, vm, vm.categories[vm.selectedCategoryIndex]),
                ),
              ],
            );
          } else {
            // Single category - no tabs needed
            return _buildJobsList(context, vm, vm.categories.first);
          }
        },
      ),
    );
  }

  Widget _buildJobsList(BuildContext context, MyJobsViewModel viewModel, String category) {
    final jobs = viewModel.jobsByCategory[category] ?? [];

    if (jobs.isEmpty) {
      return Center(
        child: ResponsiveTextWidget(
          'No jobs in this category',
          textType: TextType.body,
          fontSize: AppDimensions.textM,
          color: AppColors.grey600,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
        vertical: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _buildJobCard(context, viewModel, job);
      },
    );
  }

  Widget _buildJobCard(BuildContext context, MyJobsViewModel viewModel, Map<String, dynamic> job) {
    return Container(
      margin: EdgeInsets.only(
        bottom: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
        left: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
        right: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
      ),
      padding: EdgeInsets.all(
        context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveTextWidget(
                      job['title'] ?? 'Untitled Job',
                      textType: TextType.body,
                      fontSize: context.isSmallScreen 
                          ? AppDimensions.textM 
                          : AppDimensions.textL,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    SizedBox(height: context.isSmallScreen 
                        ? AppDimensions.spaceXS 
                        : AppDimensions.spaceS),
                    ResponsiveTextWidget(
                      job['company'] ?? '',
                      textType: TextType.body,
                      fontSize: context.isSmallScreen 
                          ? AppDimensions.textS 
                          : AppDimensions.textM,
                      color: AppColors.white.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
              // Edit and Delete buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit, 
                      color: AppColors.yellow,
                      size: context.isSmallScreen ? 20 : 24,
                    ),
                    onPressed: () => viewModel.editJob(context, job),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete, 
                      color: AppColors.red,
                      size: context.isSmallScreen ? 20 : 24,
                    ),
                    onPressed: () => _showDeleteConfirmation(context, viewModel, job),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.isSmallScreen 
              ? AppDimensions.paddingXS 
              : AppDimensions.paddingS),
          // Job details
          if (job['location'] != null && (job['location'] as String).isNotEmpty)
            _buildJobDetailRow(
              context,
              Icons.location_on, 
              job['location'] as String,
            ),
          if (job['jobType'] != null && (job['jobType'] as String).isNotEmpty)
            _buildJobDetailRow(
              context,
              Icons.category, 
              job['jobType'] as String,
            ),
          if (job['salary'] != null && (job['salary'] as String).isNotEmpty)
            _buildJobDetailRow(
              context,
              Icons.attach_money, 
              job['salary'] as String,
            ),
          if (job['festivalDate'] != null && (job['festivalDate'] as String).isNotEmpty)
            _buildJobDetailRow(
              context,
              Icons.calendar_today, 
              job['festivalDate'] as String,
            ),
        ],
      ),
    );
  }

  Widget _buildJobDetailRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: context.isSmallScreen 
            ? AppDimensions.spaceXS 
            : AppDimensions.spaceS,
      ),
      child: Row(
        children: [
          Icon(
            icon, 
            size: context.isSmallScreen ? 14 : 16, 
            color: AppColors.yellow,
          ),
          SizedBox(width: context.isSmallScreen 
              ? AppDimensions.spaceXS 
              : AppDimensions.spaceS),
          Expanded(
            child: ResponsiveTextWidget(
              text,
              textType: TextType.body,
              fontSize: context.isSmallScreen 
                  ? AppDimensions.textXS 
                  : AppDimensions.textS,
              color: AppColors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MyJobsViewModel viewModel, Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.black,
        title: const ResponsiveTextWidget(
          'Delete Job',
          textType: TextType.heading,
          fontWeight: FontWeight.bold,
          fontSize: AppDimensions.textL,
          color: AppColors.red,
        ),
        content: ResponsiveTextWidget(
          'Are you sure you want to delete this job? This action cannot be undone.',
          textType: TextType.body,
          fontSize: AppDimensions.textM,
          color: AppColors.white,
        ),
        actions: [
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
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final category = job['category'] as String?;
              final jobId = job['jobId'] as String?;
              if (category != null && jobId != null) {
                await viewModel.deleteJob(jobId, category);
              }
            },
            child: const ResponsiveTextWidget(
              'Delete',
              textType: TextType.body,
              fontSize: AppDimensions.textM,
              fontWeight: FontWeight.bold,
              color: AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}
