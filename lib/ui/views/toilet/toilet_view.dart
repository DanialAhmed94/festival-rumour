import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/models/toilet_model.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import 'toilet_view_model.dart';
import 'toilet_location_map.dart';

class ToiletView extends BaseView<ToiletViewModel> {
  final VoidCallback? onBack;
  final int? festivalId;
  const ToiletView({super.key, this.onBack, this.festivalId});

  @override
  ToiletViewModel createViewModel() => ToiletViewModel();

  @override
  Widget buildView(BuildContext context, ToiletViewModel viewModel) {
    final effectiveFestivalId = festivalId ?? Provider.of<FestivalProvider>(context, listen: false).selectedFestival?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadToiletsIfNeeded(effectiveFestivalId);
    });

    if (viewModel.showToiletDetail) {
      return _buildToiletDetail(context, viewModel);
    }

    return WillPopScope(
      onWillPop: () async {
        if (onBack != null) {
          onBack!();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: Container(
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, viewModel),
                const SizedBox(height: AppDimensions.spaceS),
                _buildToiletsCard(context),
                const SizedBox(height: AppDimensions.spaceM),
                _buildToiletsSectionHeader(context, effectiveFestivalId),
                const SizedBox(height: AppDimensions.spaceS),
                Expanded(child: _buildToiletList(context, viewModel)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ToiletViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (onBack != null) {
                onBack!();
              } else {
                Navigator.pop(context);
              }
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
          const ResponsiveTextWidget(
            AppStrings.toilets,
            textType: TextType.title,
            color: AppColors.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
  Widget _buildToiletsSectionHeader(BuildContext context, int? effectiveFestivalId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ResponsiveTextWidget(
            AppStrings.toilets,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.viewAll,
                arguments: {'tab': 3, 'festivalId': effectiveFestivalId},
              );
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

  Widget _buildToiletsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      width: double.infinity,
      height: context.screenHeight * 0.25,

      decoration: BoxDecoration(
        color: AppColors.eventGreen,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ResponsiveTextWidget(
              AppStrings.toilets,
              textType: TextType.heading,
              color: AppColors.white,
              //fontSize: AppDimensions.textXXL,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: AppDimensions.spaceM),
            // Clipboard with checklist icon
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingS),

              child: Image.asset(
                AppAssets.assignmentIcon, // 👈 your image path constant
                width: AppDimensions.iconXXL,
                height: AppDimensions.iconXXL,
                fit: BoxFit.contain,
              ),
            ),
            // Yellow pencil icon
          ]
      ),
    );
  }
  Widget _buildToiletList(BuildContext context, ToiletViewModel viewModel) {
    if (viewModel.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.black),
      );
    }
    if (viewModel.toilets.isEmpty) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noData,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }
    final displayCount = viewModel.toilets.length > 4 ? 4 : viewModel.toilets.length;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        final toilet = viewModel.toilets[index];
        return _buildToiletCard(context, toilet, viewModel);
      },
    );
  }

  Widget _buildToiletCard(
      BuildContext context,
      ToiletModel toilet,
      ToiletViewModel viewModel,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.marginS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.transparent,
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
          _buildToiletCardThumbnail(toilet),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: ResponsiveTextWidget(
              toilet.toiletTypeName,
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: () {
              viewModel.navigateToDetail(toilet);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.newsGreen,
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

  /// Card thumbnail uses toilet type image (same as resource_module allToilets).
  Widget _buildToiletCardThumbnail(ToiletModel toilet) {
    final imageUrl = toilet.toiletTypeImageUrl;
    const size = 56.0;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: imageUrl.isEmpty
            ? Image.asset(AppAssets.toiletdetail, width: size, height: size, fit: BoxFit.cover)
            : Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.eventGreen,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: size * 0.5,
                      height: size * 0.5,
                      child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.toiletdetail,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }

  Widget _buildToiletDetail(BuildContext context, ToiletViewModel viewModel) {
    final toilet = viewModel.selectedToilet!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) viewModel.navigateBackToList();
      },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: Container(
          child: SafeArea(
            child: Column(
              children: [
                _buildDetailAppBar(context, viewModel),
                Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    //  _buildFestivalInformationSection1(context, toilet),
                      const SizedBox(height: AppDimensions.spaceXS),
                      _buildFestivalInformationSection2(context, toilet),
                      //const SizedBox(height: AppDimensions.spaceL),
                      _buildFestivalInformationSection3(context, toilet),
                      // const SizedBox(height: AppDimensions.spaceL),
                      _buildImageSection(context, toilet),
                      // const SizedBox(height: AppDimensions.spaceL),
                      _buildLocationSection(context, toilet),
                      const SizedBox(height: AppDimensions.spaceXS),
                      _buildLocationSection2(context, toilet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),)
    );
  }

  Widget _buildDetailAppBar(BuildContext context, ToiletViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => viewModel.navigateBackToList(),
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
          ResponsiveTextWidget(
            viewModel.selectedToilet?.toiletTypeName ?? AppStrings.toiletDetail,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: AppDimensions.textL,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFestivalInformationSection2(
    BuildContext context,
    ToiletModel toilet,
  ) {
    return _buildWhiteCard(
      context,
      '',
      Column(
        children: [
          _buildInfoRow(context, Icons.people, AppStrings.festivalName, toilet.festivalName ?? '—'),
        ],
      ),
    );
  }

  Widget _buildFestivalInformationSection3(
    BuildContext context,
    ToiletModel toilet,
  ) {
    return _buildWhiteCard(
      context,
      '',
      Column(
        children: [
          _buildInfoRow(context, Icons.wc, AppStrings.toiletCategory, toilet.toiletTypeName),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, ToiletModel toilet) {
    final imageUrl = toilet.imageUrl.isNotEmpty ? toilet.imageUrl : toilet.toiletTypeImageUrl;
    return _buildWhiteCard(
      context,
      AppStrings.image,
      Container(
        height: AppDimensions.imageXXL,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        child,
                        Center(
                          child: CircularProgressIndicator(
                            color: AppColors.black,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Image.asset(AppAssets.toiletdetail, fit: BoxFit.contain),
                  ),
                )
              : Center(
                  child: Image.asset(AppAssets.toiletdetail, fit: BoxFit.contain),
                ),
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, ToiletModel toilet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      child: Row(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ResponsiveTextWidget(
                AppStrings.location,
                textType: TextType.body,
                color: AppColors.onPrimary,
                fontSize: AppDimensions.textL,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                // Handle open map action
              },
              child: Row(
                children: [
                  const ResponsiveTextWidget(
                    AppStrings.openMap,
                    textType: TextType.body,
                    color: AppColors.onPrimary,
                    fontSize: AppDimensions.textS,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(width: AppDimensions.spaceS),
                  const Icon(
                    Icons.map,
                    color: AppColors.onPrimary,
                    size: AppDimensions.iconS,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSection2(BuildContext context, ToiletModel toilet) {
    return _buildWhiteCard(
      context,
      '',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToiletLocationMap(
            latitude: toilet.latitude,
            longitude: toilet.longitude,
            height: 180,
          ),
          const SizedBox(height: AppDimensions.spaceM),
          _buildInfoRow(context, Icons.location_on, AppStrings.latitude, toilet.latitude ?? '—'),
          const SizedBox(height: AppDimensions.spaceM),
          _buildInfoRow(context, Icons.location_on, AppStrings.longitude, toilet.longitude ?? '—'),
          const SizedBox(height: AppDimensions.spaceM),
          _buildInfoRow(context, Icons.location_on, AppStrings.what3word, toilet.what3Words ?? '—'),
        ],
      ),
    );
  }

  Widget _buildWhiteCard(BuildContext context, String title, Widget content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.marginS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.eventLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.onPrimary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show title if not empty
          if (title.isNotEmpty) ...[
            ResponsiveTextWidget(
              title,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: AppDimensions.textL,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceM),
          ],
          content,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          decoration: BoxDecoration(
            // color: AppColors.grey600,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Icon(
            icon,
            color: AppColors.onPrimary,
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
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: AppDimensions.textS,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXS),
              ResponsiveTextWidget(
                value,
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: AppDimensions.textM,
                  //fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
