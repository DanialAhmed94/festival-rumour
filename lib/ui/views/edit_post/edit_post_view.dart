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
                        _buildFestivalSection(context, viewModel),
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
            const Icon(
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

  Widget _buildFestivalSection(BuildContext context, EditPostViewModel viewModel) {
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
                const Icon(Icons.festival, color: AppColors.onSurface, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select a festival *',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (viewModel.selectedFestival != null)
                  GestureDetector(
                    onTap: () => viewModel.selectFestival(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'You must select a festival to share this post in its Rumours feed.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),

            if (viewModel.selectedFestival != null)
              _buildSelectedChip(context, viewModel),

            if (viewModel.selectedFestival != null)
              const SizedBox(height: 12),

            _buildSearchField(context, viewModel),
            const SizedBox(height: 8),
            _buildFestivalList(context, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChip(BuildContext context, EditPostViewModel viewModel) {
    final festival = viewModel.selectedFestival!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  festival.title,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (festival.date.isNotEmpty && festival.date != 'Date TBD')
                  Text(
                    festival.date,
                    style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => viewModel.selectFestival(null),
            child: const Icon(Icons.close, color: AppColors.onSurfaceVariant, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, EditPostViewModel viewModel) {
    return TextField(
      controller: viewModel.searchController,
      onChanged: viewModel.onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search festivals...',
        hintStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 20),
        suffixIcon: viewModel.isSearchMode
            ? GestureDetector(
                onTap: viewModel.clearSearch,
                child: const Icon(Icons.clear, color: AppColors.onSurfaceVariant, size: 20),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.onSurfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.onSurfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        isDense: true,
      ),
      style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
      cursorColor: AppColors.accent,
    );
  }

  Widget _buildFestivalList(BuildContext context, EditPostViewModel viewModel) {
    if (viewModel.festivalsError != null &&
        viewModel.festivals.isEmpty &&
        !viewModel.festivalsLoading &&
        !viewModel.isSearching) {
      return _buildErrorState(context, viewModel);
    }

    if (viewModel.festivalsLoading || viewModel.isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
        ),
      );
    }

    final items = viewModel.festivals;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            viewModel.isSearchMode
                ? 'No festivals found for "${viewModel.searchController?.text}"'
                : 'No festivals available.',
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final festival = entry.value;
          final isSelected = viewModel.selectedFestival?.id == festival.id;

          if (!viewModel.isSearchMode &&
              index == items.length - 3 &&
              viewModel.hasMoreFestivals &&
              !viewModel.festivalsLoadingMore) {
            viewModel.loadMoreFestivals();
          }

          return InkWell(
            onTap: () => viewModel.selectFestival(festival),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.accent, width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20,
                    color: isSelected ? AppColors.accent : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          festival.title,
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (festival.date.isNotEmpty && festival.date != 'Date TBD')
                          Text(
                            festival.date,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(festival.status),
                ],
              ),
            ),
          );
        }),
        if (viewModel.festivalsLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ),
          ),
        if (viewModel.hasMoreFestivals && !viewModel.festivalsLoadingMore && !viewModel.isSearchMode)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: viewModel.loadMoreFestivals,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Load more festivals',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(FestivalStatus status) {
    Color badgeColor;
    String label;
    switch (status) {
      case FestivalStatus.live:
        badgeColor = Colors.green;
        label = 'Live';
        break;
      case FestivalStatus.upcoming:
        badgeColor = Colors.blue;
        label = 'Upcoming';
        break;
      case FestivalStatus.past:
        badgeColor = Colors.grey;
        label = 'Past';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, EditPostViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            viewModel.festivalsError ?? 'Failed to load festivals',
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: viewModel.retryLoadFestivals,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, EditPostViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: viewModel.isLoading
            ? null
            : () {
                final error = viewModel.validate();
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                viewModel.save();
              },
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
