import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'all_jobs_view_model.dart';

class AllJobsView extends BaseView<AllJobsViewModel> {
  const AllJobsView({super.key});

  @override
  AllJobsViewModel createViewModel() => AllJobsViewModel();

  @override
  void onViewModelReady(AllJobsViewModel viewModel) {
    super.onViewModelReady(viewModel);
    viewModel.loadAllJobs();
  }

  @override
  Widget buildView(BuildContext context, AllJobsViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          bottom: false,
          child: Container(
            color: const Color(0xFFFC2E95),
            padding: EdgeInsets.symmetric(
              horizontal:
                  context.isSmallScreen ? AppDimensions.paddingS : AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            child: Row(
              children: [
                // Back button (same as Home screen)
                CustomBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: AppDimensions.spaceS),
                Expanded(
                  child: ResponsiveTextWidget(
                    'Browse Jobs',
                    textType: TextType.title,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<AllJobsViewModel>(
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
                    'No jobs available yet',
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
                SizedBox(height: AppDimensions.spaceS),
                // Category tabs
                Container(
                  height: AppDimensions.buttonHeightXL,
                  color: const Color(0xFF3A2D46),
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

  Widget _buildJobsList(BuildContext context, AllJobsViewModel viewModel, String category) {
    final jobs = viewModel.jobsByCategory[category] ?? [];
    final hasMore = viewModel.hasMoreForCategory(category);

    if (jobs.isEmpty && !viewModel.isLoading) {
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
      itemCount: jobs.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show load more button at the end
        if (index == jobs.length) {
          return _buildLoadMoreButton(context, viewModel);
        }
        
        final job = jobs[index];
        return _buildJobCard(context, job);
      },
    );
  }

  Widget _buildLoadMoreButton(BuildContext context, AllJobsViewModel viewModel) {
    final category = viewModel.categories[viewModel.selectedCategoryIndex];
    final hasMore = viewModel.hasMoreForCategory(category);

    if (!hasMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
        vertical: context.isSmallScreen 
            ? AppDimensions.paddingL 
            : AppDimensions.paddingXL,
      ),
      child: Center(
        child: viewModel.isLoadingMore
            ? const CircularProgressIndicator(
                color: AppColors.yellow,
              )
            : ElevatedButton(
                onPressed: viewModel.loadMoreJobs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.black,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isSmallScreen 
                        ? AppDimensions.paddingL 
                        : AppDimensions.paddingXL,
                    vertical: context.isSmallScreen 
                        ? AppDimensions.paddingM 
                        : AppDimensions.paddingL,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  ),
                  elevation: 4,
                ),
                child: ResponsiveTextWidget(
                  'Load More',
                  textType: TextType.body,
                  fontWeight: FontWeight.bold,
                  fontSize: context.isSmallScreen 
                      ? AppDimensions.textM 
                      : AppDimensions.textL,
                  color: AppColors.black,
                ),
              ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    return Container(
      margin: EdgeInsets.only(
        bottom: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
      ),
      padding: EdgeInsets.all(
        context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A2D46),
            Color(0xFF4A3A5A),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.yellow.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and company
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
                      color: AppColors.yellow,
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
                      color: AppColors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
              // Category badge and forward icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.isSmallScreen 
                          ? AppDimensions.paddingXS 
                          : AppDimensions.paddingS,
                      vertical: AppDimensions.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      border: Border.all(
                        color: AppColors.yellow.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: ResponsiveTextWidget(
                      job['category'] ?? '',
                      textType: TextType.caption,
                      fontSize: context.isSmallScreen 
                          ? AppDimensions.textXS 
                          : AppDimensions.textS,
                      color: AppColors.yellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.isSmallScreen 
                      ? AppDimensions.spaceXS 
                      : AppDimensions.spaceS),
                  // Forward icon
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.jobDetail,
                        arguments: job,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(context.isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                        border: Border.all(
                          color: AppColors.yellow.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.yellow,
                        size: context.isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.isSmallScreen 
              ? AppDimensions.paddingXS 
              : AppDimensions.paddingS),
          // Divider
          Divider(
            color: AppColors.yellow.withOpacity(0.3),
            thickness: 1,
            height: 1,
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.yellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon, 
              size: context.isSmallScreen ? 14 : 16, 
              color: AppColors.yellow,
            ),
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
}
