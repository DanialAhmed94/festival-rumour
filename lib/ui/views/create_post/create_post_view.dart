import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'create_post_view_model.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostView extends BaseView<CreatePostViewModel> {
  const CreatePostView({super.key});

  @override
  CreatePostViewModel createViewModel() => CreatePostViewModel();

  @override
  void onViewModelReady(CreatePostViewModel viewModel) {
    super.onViewModelReady(viewModel);
  }

  @override
  Widget buildView(BuildContext context, CreatePostViewModel viewModel) {
    // Get collection name from navigation arguments if provided (from rumors context)
    final route = ModalRoute.of(context);
    final collectionName = route?.settings.arguments as String?;
    if (collectionName != null && viewModel.collectionName == null) {
      viewModel.initialize(collectionName);
    }
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              AppAssets.bottomsheet,
              fit: BoxFit.cover,
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Text Input Card
                        _buildTextInputCard(context, viewModel),
                        const SizedBox(height: 16),

                        // Media Preview Card
                        if (viewModel.hasMedia) ...[
                          _buildMediaPreviewCard(context, viewModel),
                          const SizedBox(height: 16),
                        ],

                        // Media Selection Buttons Card
                        _buildMediaButtonsCard(context, viewModel),
                        const SizedBox(height: 16),

                        // Upload Post Button
                        _buildUploadButton(context, viewModel),
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ResponsivePadding(
      mobilePadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.appBarHorizontalMobile,
        vertical: AppDimensions.appBarVerticalMobile,
      ),
      tabletPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.appBarHorizontalTablet,
        vertical: AppDimensions.appBarVerticalTablet,
      ),
      desktopPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.appBarHorizontalDesktop,
        vertical: AppDimensions.appBarVerticalDesktop,
      ),
      child: Row(
        children: [
          // Back Button
          CustomBackButton(
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: AppDimensions.spaceS),

          // Logo
          SvgPicture.asset(
            AppAssets.logo,
            color: AppColors.primary,
            width: context.getConditionalLogoSize(),
            height: context.getConditionalLogoSize(),
          ),
          const SizedBox(width: AppDimensions.spaceS),

          // Title
          Expanded(
            child: ResponsiveTextWidget(
              AppStrings.createPost,
              fontSize: context.getConditionalMainFont(),
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputCard(BuildContext context, CreatePostViewModel viewModel) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: viewModel.postTextController,
          maxLines: null,
          minLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: AppStrings.whatsOnYourMind,
            hintStyle: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 16,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 16,
            height: 1.5,
          ),
          cursorColor: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildMediaPreviewCard(BuildContext context, CreatePostViewModel viewModel) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_library,
                  color: AppColors.onSurface,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${viewModel.selectedMedia.length} ${viewModel.selectedMedia.length == 1 ? "item" : "items"}',
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: TextButton(
                    onPressed: () => viewModel.clearAllMedia(),
                    child: const Text('Clear All'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: viewModel.selectedMedia.length,
                itemBuilder: (context, index) {
                  return _buildMediaItem(context, viewModel, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaItem(BuildContext context, CreatePostViewModel viewModel, int index) {
    final media = viewModel.selectedMedia[index];
    final isVideo = viewModel.isVideo[index];

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: isVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          AppAssets.post,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: AppColors.black.withOpacity(0.3),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: AppColors.white,
                            size: 48,
                          ),
                        ),
                      ],
                    )
                  : Image.file(
                      File(media.path),
                      fit: BoxFit.cover,
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: AppColors.surface.withOpacity(0.9),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => viewModel.removeMedia(index),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.close,
                      color: AppColors.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            if (isVideo)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VIDEO',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButtonsCard(BuildContext context, CreatePostViewModel viewModel) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.add_photo_alternate,
                  color: AppColors.onSurface,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Add Media',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: viewModel.isLoading ? null : () => viewModel.pickImages(),
                    icon: const Icon(
                      Icons.photo_library,
                      size: 20,
                      color: AppColors.white,
                    ),
                    label: const Text(AppStrings.pickImages),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: viewModel.isLoading ? null : () => viewModel.pickVideo(),
                    icon: const Icon(Icons.videocam, size: 20),
                    label: const Text(AppStrings.pickVideos),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(BuildContext context, CreatePostViewModel viewModel) {
    final canPost = viewModel.canPost && !viewModel.isLoading;

    return FilledButton(
      onPressed: canPost ? () => viewModel.uploadPost() : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.performanceGreen,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: canPost ? 2 : 0,
      ),
      child: viewModel.isLoading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2.5,
                        value: viewModel.uploadProgress > 0 ? viewModel.uploadProgress : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            viewModel.uploadStatus.isNotEmpty 
                                ? viewModel.uploadStatus 
                                : 'Uploading...',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (viewModel.uploadProgress > 0 && viewModel.totalUploadItems > 0)
                            Text(
                              '${(viewModel.uploadProgress * 100).toStringAsFixed(0)}% (${viewModel.currentUploadIndex}/${viewModel.totalUploadItems})',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (viewModel.uploadProgress > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: viewModel.uploadProgress,
                      backgroundColor: AppColors.white, // Remaining/unfilled part - white
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent), // Active progress - yellow
                      minHeight: 3,
                    ),
                  ),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload, color: AppColors.white),
                SizedBox(width: 8),
                Text(
                  AppStrings.uploadPost,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

