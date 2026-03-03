import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/models/event_model.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import 'event_view_model.dart';
import 'event_detail_view.dart';

class EventView extends BaseView<EventViewModel> {
  final int? festivalId;
  const EventView({super.key, this.festivalId});

  @override
  EventViewModel createViewModel() => EventViewModel();

  @override
  Widget buildView(BuildContext context, EventViewModel viewModel) {
    final effectiveFestivalId = festivalId ?? Provider.of<FestivalProvider>(context, listen: false).selectedFestival?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadEventsIfNeeded(effectiveFestivalId);
    });

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.eventLightGreen,
              AppColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildEventsCard(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildEventsSection(context, effectiveFestivalId),
              const SizedBox(height: AppDimensions.spaceM),
              Expanded(child: _buildEventList(context, viewModel)),
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
            AppStrings.events,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
           //                 fontWeight: FontWeight.bold,
            ),
        ],
      ),
    );
  }

  Widget _buildEventsCard(BuildContext context) {
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
            AppStrings.events,
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

  Widget _buildEventsSection(BuildContext context, int? effectiveFestivalId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const ResponsiveTextWidget(
            AppStrings.events,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.viewAll, arguments: {'tab': 0, 'festivalId': effectiveFestivalId});
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

  Widget _buildEventList(BuildContext context, EventViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (viewModel.events.isEmpty) {
      final message = viewModel.errorMessage != null
          ? AppStrings.failedToLoadEvents
          : AppStrings.noEvents;
      return Center(
        child: ResponsiveTextWidget(
          message,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }
    final displayList = viewModel.events.take(4).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final event = displayList[index];
        return _buildEventCard(context, event);
      },
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.marginS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
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
          _buildEventCardThumbnail(event),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  event.eventTitle ?? '—',
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                  maxLines: 2,
                ),
                if (event.eventDescription != null && event.eventDescription!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    event.eventDescription!,
                    textType: TextType.caption,
                    color: AppColors.grey600,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailView(event: event)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
              decoration: BoxDecoration(
                color: AppColors.eventGreen,
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

  Widget _buildEventCardThumbnail(EventModel event) {
    const size = 56.0;
    final imageUrl = event.imageUrl;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: imageUrl.isEmpty
            ? Image.asset(AppAssets.assignmentIcon, width: size, height: size, fit: BoxFit.contain)
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
                      child: const CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Image.asset(AppAssets.assignmentIcon, width: size, height: size, fit: BoxFit.contain),
              ),
      ),
    );
  }

}
