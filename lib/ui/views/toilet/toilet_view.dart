import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_assets.dart';
import 'toilet_view_model.dart';

class ToiletView extends BaseView<ToiletViewModel> {
  final VoidCallback? onBack;
  const ToiletView({super.key, this.onBack});

  @override
  ToiletViewModel createViewModel() => ToiletViewModel();

  @override
  Widget buildView(BuildContext context, ToiletViewModel viewModel) {
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: viewModel.toilets.length,
      itemBuilder: (context, index) {
        final toilet = viewModel.toilets[index];
        return _buildToiletCard(context, toilet, viewModel);
      },
    );
  }

  Widget _buildToiletCard(
      BuildContext context,
      ToiletItem toilet,
      ToiletViewModel viewModel,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.marginS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white, // same as festival card
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.transparent,// same green border tone
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
          // 🔹 Toilet Icon (same circular design)
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: const BoxDecoration(
              color: AppColors.eventGreen,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              AppAssets.assignmentIcon,
              width: AppDimensions.iconL,
              height: AppDimensions.iconL,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: AppDimensions.spaceM),

          // 🔹 Toilet Name
          Expanded(
            child: ResponsiveTextWidget(
              toilet.name,
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),

          // 🔹 View Detail button (same design & alignment)
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

  Widget _buildToiletDetail(BuildContext context, ToiletViewModel viewModel) {
    final toilet = viewModel.selectedToilet!;

    return Scaffold(
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
      ),
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
            viewModel.selectedToilet?.name ?? AppStrings.toiletDetail,
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
    ToiletItem toilet,
  ) {
    return _buildWhiteCard(
      context,
      '',
      Column(
        children: [
          _buildInfoRow(context, Icons.people, AppStrings.festivalName, 'Magic show'),
        ],
      ),
    );
  }

  Widget _buildFestivalInformationSection3(
    BuildContext context,
    ToiletItem toilet,
  ) {
    return _buildWhiteCard(
      context,
      '',
      Column(
        children: [
          _buildInfoRow(context, Icons.wc, AppStrings.toiletCategory, 'Magic show'),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, ToiletItem toilet) {
    return _buildWhiteCard(
      context,
      AppStrings.image,
      Container(
        height: AppDimensions.imageXXL,
        decoration: BoxDecoration(
          //color: toilet.color,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: Container(
            child: Center(
              child: Image.asset(
                AppAssets.toiletdetail, // 👈 your custom icon path
                // color: Colors.white, // optional if you want to tint the image
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, ToiletItem toilet) {
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

  Widget _buildLocationSection2(BuildContext context, ToiletItem toilet) {
    return _buildWhiteCard(
      context,
      '',
      Column(
        children: [
          _buildInfoRow(context, Icons.location_on, AppStrings.latitude, 'Lorem Ipsum'),
          const SizedBox(height: AppDimensions.spaceM),
          _buildInfoRow(context, Icons.location_on, AppStrings.longitude, 'Lorem Ipsum'),
          const SizedBox(height: AppDimensions.spaceM),
          _buildInfoRow(context, Icons.location_on, AppStrings.what3word, 'Lorem Ipsum'),
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

class ToiletItem {
  final String name;
  final String description;
  final Color color;

  ToiletItem({
    required this.name,
    required this.description,
    required this.color,
  });
}
