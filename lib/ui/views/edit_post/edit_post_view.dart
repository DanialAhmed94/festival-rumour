import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../homeview/post_model.dart';
import '../festival/festival_model.dart';
import 'edit_post_view_model.dart';

class EditPostView extends BaseView<EditPostViewModel> {
  const EditPostView({super.key});

  @override
  EditPostViewModel createViewModel() => EditPostViewModel();

  @override
  void onViewModelReady(EditPostViewModel viewModel) {
    super.onViewModelReady(viewModel);
  }

  @override
  Widget buildView(BuildContext context, EditPostViewModel viewModel) {
    // One-time init from route arguments; festivals from provider (no API call)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (viewModel.post == null && args != null) {
      PostModel? post;
      String? collectionName;
      if (args is Map) {
        post = args['post'] as PostModel?;
        collectionName = args['collectionName'] as String?;
      } else if (args is PostModel) {
        post = args;
      }
      if (post != null) {
        final festivalProvider =
            Provider.of<FestivalProvider>(context, listen: false);
        final festivals = festivalProvider.allFestivals;
        viewModel.onFestivalsLoaded = (list) {
          if (context.mounted) festivalProvider.setAllFestivals(list);
        };
        viewModel.initialize(post,
            collectionName: collectionName, festivals: festivals);
      }
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    if (viewModel.post == null) {
      return Scaffold(
        backgroundColor: AppColors.screenBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: Text('Invalid post')),
      );
    }

    return Consumer<EditPostViewModel>(
      builder: (context, vm, _) {
        if (vm.successMessage != null && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  vm.successMessage!,
                  style: const TextStyle(color: Colors.black),
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            vm.clearSuccessMessage();
            Navigator.of(context).pop<bool>(true);
          });
        }
        return Scaffold(
          backgroundColor: AppColors.screenBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, viewModel),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildContentCard(context, viewModel),
                        const SizedBox(height: 16),
                        _buildUrlCard(context, viewModel),
                        const SizedBox(height: 20),
                        _buildAddToFestivalSection(context, viewModel),
                        const SizedBox(height: 24),
                        _buildSaveButton(context, viewModel),
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, EditPostViewModel viewModel) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFC2E95),
      child: ResponsivePadding(
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
            CustomBackButton(onTap: () => Navigator.pop(context)),
            const SizedBox(width: AppDimensions.spaceS),
            Expanded(
              child: ResponsiveTextWidget(
                'Edit Post',
                fontSize: context.getConditionalMainFont(),
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, EditPostViewModel viewModel) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: viewModel.contentController,
          maxLines: null,
          minLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
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
          onChanged: (_) => viewModel.notifyListeners(),
        ),
      ),
    );
  }

  Widget _buildUrlCard(BuildContext context, EditPostViewModel viewModel) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              Icons.link,
              color: AppColors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: viewModel.postUrlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Add link (optional)',
                  hintStyle: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                ),
                cursorColor: AppColors.accent,
                onChanged: (_) => viewModel.notifyListeners(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddToFestivalSection(
    BuildContext context,
    EditPostViewModel viewModel,
  ) {
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
                Icon(
                  Icons.festival,
                  color: AppColors.onSurface,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Add this post to a festival',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a festival to also show this post in its Rumours feed.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            if (viewModel.festivals.isEmpty && !viewModel.festivalsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No festivals available.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              )
            else if (viewModel.festivals.isEmpty && viewModel.festivalsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.onSurfaceVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<FestivalModel?>(
                    value: viewModel.selectedFestival,
                    isExpanded: true,
                    hint: const Text('Select a festival (optional)'),
                    items: [
                      const DropdownMenuItem<FestivalModel?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...viewModel.festivals.map((f) {
                        return DropdownMenuItem<FestivalModel?>(
                          value: f,
                          child: Text(
                            f.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: viewModel.selectFestival,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, EditPostViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: viewModel.canSave && !viewModel.isLoading
            ? () => viewModel.save()
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: viewModel.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.black,
                ),
              )
            : const Text(AppStrings.save),
      ),
    );
  }
}
