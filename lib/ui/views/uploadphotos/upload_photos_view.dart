import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'upload_photos_view_model.dart';


class UploadPhotosViews extends BaseView<UploadPhotosViewModel> {
  const UploadPhotosViews({super.key});

  @override
  UploadPhotosViewModel createViewModel() => UploadPhotosViewModel();

  @override
  Widget buildView(BuildContext context, UploadPhotosViewModel viewModel) {
    // Set status bar style for dark background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return SafeArea(
        child: Scaffold(
          body: Stack(
            children: [
          ResponsiveContainer(
          mobileMaxWidth: double.infinity,
          tabletMaxWidth: double.infinity,
          desktopMaxWidth: double.infinity,
            child: Container(
              padding: context.isLargeScreen
                  ? const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
                vertical: AppDimensions.paddingL,
              )
                  : context.isMediumScreen
                  ? const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingM,
              )
                  : const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingM
              ),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppAssets.addpic),
                fit: BoxFit.cover,
              ),
             // borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button
                _buildHeader(context, viewModel),
                const SizedBox(height: AppDimensions.spaceM),

                // Title and subtitle
                _buildTitleSection(context),
                const SizedBox(height: AppDimensions.spaceM),

                // Image container
                Expanded(child: _buildImageContainer(context, viewModel)),

                const SizedBox(height: AppDimensions.spaceM),

                // Action buttons
                _buildActionButtons(context, viewModel),
                //const SizedBox(height: AppDimensions.space),
              ],
            ),
          ),
        ),
      ]
          ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context, UploadPhotosViewModel viewModel) {
    return Row(
      children: [
        CustomBackButton(onTap: () {
          // Clear signup data if user goes back (cancellation)
          viewModel.clearSignupData();
          context.pop();
        }),
        const SizedBox(width: AppDimensions.spaceS),
        ResponsiveText(
          AppStrings.uploadphoto,
          style: const TextStyle(
            fontSize: AppDimensions.textL,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          AppStrings.picupload,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: AppDimensions.textXL,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceS),

        ResponsiveText(
          AppStrings.uploadSubtitle,
          style: TextStyle(
            fontSize: AppDimensions.textM,
            color: AppColors.primary,
            height: AppDimensions.aspectRatio,
          ),
        ),
      ],
    );
  }

  Widget _buildImageContainer(
    BuildContext context,
    UploadPhotosViewModel viewModel,
  ) {
    return GestureDetector(
      onTap: () => _showImageSourceFullScreen(context, viewModel),
      child: Stack(
        clipBehavior: Clip.none, // allow circle to be outside
        children: [
          Card(
            color: AppColors.onPrimary.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            elevation: AppDimensions.elevationS,
            child: DottedBorder(
              color: AppColors.accent,
              strokeWidth: AppDimensions.borderWidthL,
              borderType: BorderType.RRect,
              radius: Radius.circular(AppDimensions.radiusL),
              dashPattern: const [12, 3],
              child: Container(
               // color: AppColors.onPrimary.withOpacity(0.3),
                width: double.infinity,
                height:
                    AppDimensions.imageXXL * 2.4, // ✅ fixed height (same whether empty or with image)
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                  color: viewModel.isUsingProviderPhoto 
                      ? Colors.transparent // No background blur for provider photos
                      : AppColors.onPrimary.withOpacity(0.4),
                  // 🔥 light layer background
                  //color: AppColors.black.withOpacity(0.9),
                ),
                child:
                    viewModel.hasImage
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusL,
                          ),
                          child: viewModel.isUsingProviderPhoto
                              ? Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.transparent, // No background blur for provider photos
                                  child: Image.network(
                                    viewModel.providerPhotoURL!,
                                    fit: BoxFit.contain, // Better fit for provider photos
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      // If network image fails, show placeholder
                                      return Container(
                                        color: AppColors.onPrimary.withOpacity(0.3),
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: AppColors.primary,
                                          size: AppDimensions.iconXXL,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: AppColors.accent,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : kIsWeb
                                  ? Image.network(
                                      viewModel.selectedImage!.path,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : Image.file(
                                      File(viewModel.selectedImage!.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                        )
                        : null, // no shrink, just background stays
              ),
            ),
          ),
          // Plus circle outside (bottom right)
          Positioned(
            top: AppDimensions.imageXXL * 2.25,
            //bottom: -AppDimensions.paddingXS,
            right: -AppDimensions.paddingM,
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.borderWidthS), // border thickness
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary, // white border
                  width: AppDimensions.borderWidthM, // thickness
                ),
                color: AppColors.onPrimary,
              ),
              child: Icon(Icons.add, color: AppColors.primary, size: AppDimensions.iconXXL),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    UploadPhotosViewModel viewModel,
  ) {
    return Column(
      children: [
        // Next button
        SizedBox(
          width: double.infinity,
          height: context.getConditionalButtonSize(),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  viewModel.hasImage ? AppColors.accent : AppColors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
              ),
            ),
            onPressed:
                viewModel.hasImage && !viewModel.isLoading
                    ? viewModel.continueToNext
                    : null,
            child:
                viewModel.isLoading
                    ?  SizedBox(
                      width: context.getConditionalIconSize(),
                      height: context.getConditionalIconSize(),
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: AppDimensions.borderWidthS,
                      ),
                    )
                    :  ResponsiveTextWidget(
                      AppStrings.next,
                        fontSize: context.getConditionalButtonfont(),
                        color: viewModel.hasImage ? AppColors.onPrimary : AppColors.transparent,
                      ),
                    ),
          ),

        const SizedBox(height: AppDimensions.spaceM),

        // Skip button
      ],
    );
  }

  void _showImageSourceFullScreen(
    BuildContext context,
    UploadPhotosViewModel viewModel,
  ) {
    // Set status bar style for dark background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                // ✅ Background image (PNG/JPG)
                Positioned.fill(
                  child: Image.asset(
                    AppAssets.uploadphoto, // must be PNG/JPG
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  color: AppColors.black.withOpacity(0.5),
                  width: double.infinity,
                  height: context.screenHeight * 0.4,
                ),

                // ✅ Custom AppBar inside Stack
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingS,
                      vertical: AppDimensions.paddingXS,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        CustomBackButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),

                        const ResponsiveTextWidget(
                          AppStrings.selectsourse,
                          textType: TextType.body, 
                            fontSize: AppDimensions.textL,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onPrimary,
                          ),

                        const SizedBox(
                          width: AppDimensions.iconXL,
                        ), // spacer to balance the back button
                      ],
                    ),
                  ),
                ),

                // ✅ Foreground content
                LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: width < AppDimensions.tabletWidth ? AppDimensions.paddingL : AppDimensions.paddingXL,
                        vertical:
                        width < AppDimensions.tabletWidth
                            ? AppDimensions.paddingXXL
                            : AppDimensions.paddingXXL + AppDimensions.paddingL, // ⬅ leave space for custom appbar
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: AppDimensions.paddingXL),

                          // 📸 Camera Option
                          GestureDetector(
                            onTap: () async {
                              await viewModel.pickImageFromCamera();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: SvgPicture.asset(
                                    AppAssets.camera,
                                    width: AppDimensions.iconXXL,
                                    height: AppDimensions.iconXXL,
                                    // color: AppColors.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.paddingM),
                                const ResponsiveTextWidget(
                                  AppStrings.camera,
                                  textType: TextType.body,
                                  fontSize: AppDimensions.textXXL,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppDimensions.paddingL),
                          const Divider(
                            color: AppColors.accent,
                            thickness: AppDimensions.borderWidthS,
                          ),
                          const SizedBox(height: AppDimensions.paddingL),

                          // 🖼️ Gallery Option
                          GestureDetector(
                            onTap: () async {
                              await viewModel.pickImageFromGallery();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: SvgPicture.asset(
                                    AppAssets.gallary,
                                    width: AppDimensions.iconXXL,
                                    height: AppDimensions.iconXXL,
                                    // color: AppColors.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.paddingM),
                                const ResponsiveTextWidget(
                                  AppStrings.gallery,
                                  textType: TextType.body,
                                    fontSize: AppDimensions.textXXL,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}