 import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import 'performance_view_model.dart';

class PerformanceView extends BaseView<PerformanceViewModel> {
  const PerformanceView({super.key});

  @override
  PerformanceViewModel createViewModel() => PerformanceViewModel();

  @override
  Widget buildView(BuildContext context, PerformanceViewModel viewModel) {
    if (viewModel.showPerformancePreview) {
      return _buildPerformancePreview(context, viewModel);
    }
    
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Container(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildPerformanceCard(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildPerformanceSection(context),
              const SizedBox(height: AppDimensions.spaceM),
              Expanded(
                child: _buildPerformanceCategories(context, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              decoration: BoxDecoration(
                color: AppColors.eventGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.white,
                size: AppDimensions.iconM,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          const ResponsiveTextWidget(
            AppStrings.stageRunningOrder,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      padding: const EdgeInsets.all( AppDimensions.paddingL),
      height: context.screenHeight * 0.25,
      decoration: BoxDecoration(
        color: AppColors.performanceGreen,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const ResponsiveTextWidget(
            AppStrings.performance,
            textType: TextType.heading,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: AppDimensions.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Image.asset(
                  AppAssets.performance,
                  width: AppDimensions.iconXXL,
                  height: AppDimensions.iconXXL,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const ResponsiveTextWidget(
            AppStrings.performance,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.viewAll, arguments: 2);
            },
            child: const ResponsiveTextWidget(
              AppStrings.viewAll,
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCategories(BuildContext context, PerformanceViewModel viewModel) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: viewModel.performanceCategories.length,
      itemBuilder: (context, index) {
        final category = viewModel.performanceCategories[index];
        return _buildPerformanceCategoryCard(context, category, viewModel);
      },
    );
  }

  Widget _buildPerformanceCategoryCard(BuildContext context, PerformanceCategory category, PerformanceViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.performanceLightBlue,
          width: AppDimensions.borderWidthS,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.performanceGreen,
              shape: BoxShape.circle,
              // Brown color
            ),
            child: Center(
              child: Image.asset(
                AppAssets.performance,
                width: AppDimensions.iconL,
                height: AppDimensions.iconL,
                fit: BoxFit.contain,
              )
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          
          // Category name
          Expanded(
            child: ResponsiveTextWidget(
              category.name,
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          // View Detail button
          GestureDetector(
            onTap: () {
              viewModel.showPerformancePreview = true;
              viewModel.notifyListeners();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.performanceGreen,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: const ResponsiveTextWidget(
                AppStrings.viewDetail,
                textType: TextType.caption,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformancePreview(BuildContext context, PerformanceViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildPreviewAppBar(context, viewModel),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPerformanceInformationSection(context),
                    const SizedBox(height: AppDimensions.spaceL),
                    _buildNotesSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewAppBar(BuildContext context, PerformanceViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
       GestureDetector(
            onTap: () {
              viewModel.showPerformancePreview = false;
              viewModel.notifyListeners();
            },
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingS),
        decoration: BoxDecoration(
          color: AppColors.eventGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back,
          color: AppColors.white,
          size: AppDimensions.iconM,
        ),
      ),
    ),
          const SizedBox(width: AppDimensions.spaceM),
          const ResponsiveTextWidget(
            AppStrings.performancePreview,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceInformationSection(BuildContext context) {
    final screenWidth = context.screenWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Festival Name
        _buildInfoCard(
          context,
          AppStrings.festivalName,
          AppStrings.magicShow,
          Icons.auto_fix_high,
        ),
        const SizedBox(height: AppDimensions.spaceM),

        // Select Event
        _buildInfoCard(
          context,
          AppStrings.selectEvent,
          AppStrings.magicShow,
          Icons.confirmation_number,
        ),
        const SizedBox(height: AppDimensions.spaceM),

        // Start/End Date
        Row(
          children: [
            Expanded(
              child: _buildInfoCard2(
                context,
                AppStrings.startDate,
                '07.12.2024',
                Icons.calendar_today,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Expanded(
              child: _buildInfoCard2(
                context,
                AppStrings.endDate,
                '09.12.2024',
                Icons.calendar_today,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceM),

        // Performance Title
        _buildInfoCard(
          context,
          AppStrings.performanceTitle,
          AppStrings.performancetitle,
          Icons.flag,
        ),
        const SizedBox(height: AppDimensions.spaceM),

        // Band
        _buildInfoCard(
          context,
          AppStrings.band,
          AppStrings.brand,
          Icons.music_note,
        ),
        const SizedBox(height: AppDimensions.spaceM),

        // Artist
        _buildInfoCard(
          context,
          AppStrings.artist,
          AppStrings.Atrist,
          Icons.mic,
        ),
        const SizedBox(height: AppDimensions.spaceM),

        // Participant Name
        _buildParticipantCard(context),
        const SizedBox(height: AppDimensions.spaceM),

        // Special Guests
        _buildInfoCard(
          context,
          AppStrings.specialGuests,
          AppStrings.duaLipa,
          Icons.star,
        ),
        const SizedBox(height: AppDimensions.spaceM),

        // Start/End Time in Row
        Row(
          children: [
            Expanded(
              child: _buildInfoCard2(
                context,
                AppStrings.startTime,
                '10:00 AM',
                Icons.access_time,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Expanded(
              child: _buildInfoCard2(
                context,
                AppStrings.endTime,
                '12:00 AM',
                Icons.access_time,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildInfoCard(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.performanceLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.performanceGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: AppDimensions.iconM,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  label,
                  textType: TextType.caption,
                  color: AppColors.grey600,
                ),
                const SizedBox(height: AppDimensions.spaceXS),
                ResponsiveTextWidget(
                  value,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoCard2(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.performanceLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.performanceGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: AppDimensions.iconS,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  label,
                  textType: TextType.caption,
                  color: AppColors.grey600,
                ),
                const SizedBox(height: AppDimensions.spaceXS),
                ResponsiveTextWidget(
                  value,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildParticipantCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.performanceLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.performanceGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: const Icon(
              Icons.people,
              color: AppColors.white,
              size: AppDimensions.iconM,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          const Expanded(
            child: ResponsiveTextWidget(
              AppStrings.participantName,
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ResponsiveTextWidget(
          AppStrings.notes,
          textType: TextType.title,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
        const SizedBox(height: AppDimensions.spaceM),
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: AppColors.performanceLightBlue,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border(
              left: BorderSide(
                color: AppColors.grey600,
                width: AppDimensions.borderWidthM,
              ),
            ),
          ),
          child: const ResponsiveTextWidget(
            AppStrings.festivalPerformanceNote,
            textType: TextType.body,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

class PerformanceCategory {
  final String name;
  final String description;
  final IconData icon;

  PerformanceCategory({
    required this.name,
    required this.description,
    required this.icon,
  });
}
