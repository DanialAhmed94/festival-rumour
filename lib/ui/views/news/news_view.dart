import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/bulletin_model.dart';
import 'news_view_model.dart';

class NewsView extends BaseView<NewsViewModel> {
  final VoidCallback? onBack;

  const NewsView({super.key, this.onBack});

  @override
  NewsViewModel createViewModel() => NewsViewModel();

  @override
  Widget buildView(BuildContext context, NewsViewModel viewModel) {
    if (viewModel.showBulletinPreview) {
      return _buildBulletinPreview(context, viewModel);
    }

    if (viewModel.showPerformancePreview) {
      return _buildPerformancePreview(context, viewModel);
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightGreen, // Light green
              AppColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, viewModel),
              const SizedBox(height: AppDimensions.spaceL),
              _buildBulletinCard(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildToiletsSection(context),
              const SizedBox(height: AppDimensions.spaceM),
              Expanded(child: _buildBulletinList(context, viewModel)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, NewsViewModel viewModel) {
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
                color: AppColors.primary,
                size: AppDimensions.iconM,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          ResponsiveTextWidget(
            AppStrings.bulletinManagement,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletinCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      height: context.screenHeight * 0.25,
      decoration: BoxDecoration(
        color: AppColors.newsGreen, // Green background
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
          ResponsiveTextWidget(
            AppStrings.bulletin,
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
                  AppAssets.news1, // 👈 your image path constant
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

  Widget _buildToiletsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ResponsiveTextWidget(
            AppStrings.news,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.viewAll, arguments: 1);
            },
            child: ResponsiveTextWidget(
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

  Widget _buildBulletinList(BuildContext context, NewsViewModel viewModel) {
    if (viewModel.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.black),
      );
    }
    if (viewModel.bulletins.isEmpty) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noNews,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }
    final displayCount = viewModel.bulletins.length > 4 ? 4 : viewModel.bulletins.length;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        final bulletin = viewModel.bulletins[index];
        return _buildBulletinListItem(context, bulletin, viewModel);
      },
    );
  }

  Widget _buildBulletinListItem(BuildContext context, BulletinModel bulletin, NewsViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.marginS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
            color: AppColors.newsLightGreen, width: AppDimensions.borderWidthS),
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
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              AppAssets.news1,
              width: AppDimensions.iconL,
              height: AppDimensions.iconL,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  bulletin.title ?? AppStrings.news,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
                if (bulletin.content != null && bulletin.content!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    bulletin.content!,
                    textType: TextType.caption,
                    color: AppColors.grey600,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => viewModel.openBulletinDetail(bulletin),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.newsGreen,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: ResponsiveTextWidget(
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

  Widget _buildBulletinPreview(BuildContext context, NewsViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildBulletinPreviewAppBar(context, viewModel),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBulletinInformationSection(context),
                    const SizedBox(height: AppDimensions.spaceL),
                    _buildScheduleOptionsCard(context),
                    const SizedBox(height: AppDimensions.spaceL),
                    _buildScheduleForLaterSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletinPreviewAppBar(BuildContext context,
      NewsViewModel viewModel,) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: const BoxDecoration(
        color: AppColors.black, // Light green background
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              viewModel.showBulletinPreview = false;
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
                color: AppColors.primary,
                size: AppDimensions.iconM,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          ResponsiveTextWidget(
            AppStrings.bulletinPreview,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletinInformationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Title Name Card
        _buildInfoCard(context, AppStrings.titleName, AppStrings.magicShow,
            Icons.description),
        const SizedBox(height: AppDimensions.spaceM),

        // Content Card
        _buildContentCard(context),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context,
      String label,
      String value,
      IconData icon,) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.newsLightGreen, // Light blue-green
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(
                icon, color: AppColors.white, size: AppDimensions.iconM),
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

  Widget _buildContentCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.newsLightGreen, // Light blue-green
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ResponsiveTextWidget(
                AppStrings.content,
                textType: TextType.caption,
                color: AppColors.grey600,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceM),
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: AppColors.newsGreen,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: const Icon(
                Icons.edit_document,
                color: AppColors.white,
                size: AppDimensions.iconXXL,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleOptionsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.newsLightGreen, // Light blue-green
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: const Icon(
              Icons.check,
              color: AppColors.white,
              size: AppDimensions.iconL,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  AppStrings.scheduleOptions,
                  textType: TextType.caption,
                  color: AppColors.grey600,
                ),
                const SizedBox(height: AppDimensions.spaceXS),
                ResponsiveTextWidget(
                  AppStrings.publishNow,
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

  Widget _buildScheduleForLaterSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveTextWidget(
          AppStrings.scheduleForLater,
          textType: TextType.title,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
        const SizedBox(height: AppDimensions.spaceM),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                context,
                AppStrings.time,
                '2.00 PM',
                Icons.access_time,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Expanded(
              child: _buildInfoCard(
                context,
                AppStrings.date,
                '07.12.2024',
                Icons.calendar_today,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformancePreview(BuildContext context,
      NewsViewModel viewModel) {
    final bulletin = viewModel.selectedBulletin;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) viewModel.navigateBackFromPerformancePreview();
      },
      child: Scaffold(
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
                      _buildPerformanceInformationSection(context, bulletin),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewAppBar(BuildContext context, NewsViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // Navigate back from performance preview using ViewModel
              viewModel.navigateBackFromPerformancePreview();
            },
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              decoration: BoxDecoration(
                color: AppColors.eventGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: AppDimensions.iconM,
              ),
            ),
          ),

          const SizedBox(width: AppDimensions.spaceM),
          ResponsiveTextWidget(
            AppStrings.bulletinPreview,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceInformationSection(BuildContext context, BulletinModel? bulletin) {
    final title = bulletin?.title ?? AppStrings.news;
    final content = bulletin?.content ?? '';
    final timeStr = bulletin?.time ?? '—';
    final dateStr = bulletin?.date ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPerformanceInfoCard(
          context,
          AppStrings.titleName,
          title,
          Icons.auto_fix_high,
        ),
        const SizedBox(height: AppDimensions.spaceM),
        _buildPerformanceInfoCard(
          context,
          AppStrings.content,
          content,
          Icons.content_paste,
        ),
        const SizedBox(height: AppDimensions.spaceM),
        Row(
          children: [
            Expanded(
              child: _buildPerformanceInfoCard2(
                context,
                AppStrings.time,
                timeStr,
                Icons.access_time,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Expanded(
              child: _buildPerformanceInfoCard2(
                context,
                AppStrings.date,
                dateStr,
                Icons.calendar_today,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceInfoCard(BuildContext context, String label,
      String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.newsLightBlue, // Light blue
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
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

  Widget _buildPerformanceInfoCard2(BuildContext context, String label,
      String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.newsLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
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

//   Widget _buildviewall(BuildContext context)  {
//
//
// }
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
