import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/models/toilet_model.dart';
import 'toilet_location_map.dart';

/// Full-screen toilet detail (same content as ToiletView detail).
/// Used when opening "View Detail" from View All toilets list.
class ToiletDetailView extends StatelessWidget {
  final ToiletModel toilet;

  const ToiletDetailView({super.key, required this.toilet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWhiteCard(context, '', _buildInfoRow(context, Icons.people, AppStrings.festivalName, toilet.festivalName ?? '—')),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, '', _buildInfoRow(context, Icons.wc, AppStrings.toiletCategory, toilet.toiletTypeName)),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildImageSection(context),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildLocationHeader(context),
                    const SizedBox(height: AppDimensions.spaceXS),
                    _buildWhiteCard(
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              decoration: BoxDecoration(color: AppColors.eventGreen, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: AppColors.primary, size: AppDimensions.iconM),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          ResponsiveTextWidget(
            toilet.toiletTypeName,
            style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textL, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final imageUrl = toilet.imageUrl.isNotEmpty ? toilet.imageUrl : toilet.toiletTypeImageUrl;
    return _buildWhiteCard(
      context,
      AppStrings.image,
      Container(
        height: AppDimensions.imageXXL,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppDimensions.radiusM)),
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
                  errorBuilder: (_, __, ___) =>
                      Center(child: Image.asset(AppAssets.toiletdetail, fit: BoxFit.contain)),
                )
              : Center(child: Image.asset(AppAssets.toiletdetail, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  Widget _buildLocationHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      child: Row(
        children: [
          const ResponsiveTextWidget(AppStrings.location, textType: TextType.body, color: AppColors.onPrimary, fontSize: AppDimensions.textL, fontWeight: FontWeight.bold),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: const Row(
              children: [
                ResponsiveTextWidget(AppStrings.openMap, textType: TextType.body, color: AppColors.onPrimary, fontSize: AppDimensions.textS, fontWeight: FontWeight.w600),
                SizedBox(width: AppDimensions.spaceS),
                Icon(Icons.map, color: AppColors.onPrimary, size: AppDimensions.iconS),
              ],
            ),
          ),
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
        boxShadow: [BoxShadow(color: AppColors.onPrimary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title.isNotEmpty) ...[
          ResponsiveTextWidget(title, style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textL, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimensions.spaceM),
        ],
        content,
      ]),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
          child: Icon(icon, color: AppColors.onPrimary, size: AppDimensions.iconM),
        ),
        const SizedBox(width: AppDimensions.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveTextWidget(label, style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textS, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppDimensions.spaceXS),
              ResponsiveTextWidget(value, style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textM)),
            ],
          ),
        ),
      ],
    );
  }
}
