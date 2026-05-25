import 'package:flutter/material.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/snackbar_util.dart';
import 'notification_view_model.dart';

class NotificationView extends BaseView<NotificationViewModel> {
  static const Color _headerPink = Color(0xFFFC2E95);

  final VoidCallback? onBack;
  const NotificationView({super.key, this.onBack});

  @override
  NotificationViewModel createViewModel() => NotificationViewModel();

  @override
  Widget buildView(BuildContext context, NotificationViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: _headerPink,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingM,
              ),
              child: _buildHeader(context, viewModel),
            ),
            Expanded(child: _buildNotificationsList(context, viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NotificationViewModel viewModel) {
    return Row(
      children: [
        CustomBackButton(
          onTap: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        const SizedBox(width: AppDimensions.spaceS),
        const Expanded(
          child: ResponsiveTextWidget(
            AppStrings.notifications,
            textType: TextType.body,
            color: Colors.white,
            fontSize: AppDimensions.textL,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (viewModel.unreadCount > 0)
          TextButton(
            onPressed: () {
              viewModel.markAllAsRead();
              SnackbarUtil.showSuccessSnackBar(
                context,
                'All notifications marked as read',
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.white,
              backgroundColor: AppColors.white.withValues(alpha: 0.16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                side: BorderSide(
                  color: AppColors.white.withValues(alpha: 0.42),
                  width: 1,
                ),
              ),
            ),
            child: const ResponsiveTextWidget(
              AppStrings.markAllRead,
              textType: TextType.body,
              color: Colors.white,
              fontSize: AppDimensions.textS,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    NotificationViewModel viewModel,
  ) {
    if (viewModel.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 56,
                color: AppColors.grey400.withValues(alpha: 0.85),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              const ResponsiveTextWidget(
                AppStrings.noNotifications,
                textType: TextType.body,
                color: AppColors.grey700,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final displayed = viewModel.displayedNotifications;
    final hasMore = viewModel.hasMoreNotifications;
    final itemCount = displayed.length + (hasMore ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        AppDimensions.paddingL,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (hasMore && index == displayed.length) {
          return _buildLoadMoreButton(context, viewModel);
        }
        final notification = displayed[index];
        return _buildNotificationCard(context, notification, viewModel);
      },
    );
  }

  Widget _buildLoadMoreButton(
    BuildContext context,
    NotificationViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingS),
      child: Center(
        child: TextButton.icon(
          onPressed: viewModel.hasMoreNotifications ? viewModel.loadMore : null,
          icon: Icon(
            Icons.expand_more_rounded,
            size: 22,
            color: AppColors.grey700.withValues(alpha: 0.9),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.grey700,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
          ),
          label: const ResponsiveTextWidget(
            'Load more',
            textType: TextType.body,
            color: AppColors.grey700,
            fontSize: AppDimensions.textM,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem notification,
    NotificationViewModel viewModel,
  ) {
    final iconBg = Color(notification.iconColor).withValues(alpha: 0.12);
    final unread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.shadow.withValues(alpha: 0.07),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          side: BorderSide(color: AppColors.outline.withValues(alpha: 0.12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          onTap: () => viewModel.openNotification(context, notification),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread) ...[
                  Container(
                    width: 4,
                    height: 52,
                    margin: const EdgeInsets.only(
                      top: AppDimensions.paddingXS,
                      right: AppDimensions.spaceM,
                    ),
                    decoration: BoxDecoration(
                      color: _headerPink,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXS,
                      ),
                    ),
                  ),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  ),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      notification.icon,
                      color: Color(notification.iconColor),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ResponsiveTextWidget(
                              notification.title,
                              textType: TextType.body,
                              color: AppColors.onSurface,
                              fontSize: AppDimensions.textM,
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.w500,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: AppDimensions.paddingS),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceXS),
                      ResponsiveTextWidget(
                        notification.message,
                        textType: TextType.body,
                        color: AppColors.onSurfaceVariant,
                        fontSize: AppDimensions.textS,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spaceS),
                      ResponsiveTextWidget(
                        notification.time,
                        textType: TextType.caption,
                        color: AppColors.mutedText,
                        fontSize: AppDimensions.textS,
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
