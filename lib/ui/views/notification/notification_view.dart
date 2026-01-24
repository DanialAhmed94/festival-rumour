import 'package:flutter/material.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/snackbar_util.dart';
import 'notification_view_model.dart';

class NotificationView extends BaseView<NotificationViewModel> {
  final VoidCallback? onBack;
  const NotificationView({super.key, this.onBack});

  @override
  NotificationViewModel createViewModel() => NotificationViewModel();

  @override
  Widget buildView(BuildContext context, NotificationViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [

            /// Pink AppBar Like HomeView
            Container(
              width: double.infinity,
              color: const Color(0xFFFC2E95), // Same pink as HomeView
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingM,
              ),
              child: _buildHeader(context, viewModel),
            ),

            /// Notification List
            Expanded(
              child: _buildNotificationsList(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context, NotificationViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        /// Back Button (White)
        CustomBackButton(
          // make sure your button supports this
          onTap: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),

        /// Title (White)
        const ResponsiveTextWidget(
          AppStrings.notifications,
          textType: TextType.body,
          color: Colors.white,
          fontSize: AppDimensions.textL,
          fontWeight: FontWeight.bold,
        ),

        /// Mark All Read Button
        if (viewModel.unreadCount > 0)
          GestureDetector(
            onTap: () {
              viewModel.markAllAsRead();
              SnackbarUtil.showSuccessSnackBar(
                context,
                'All notifications marked as read',
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: const ResponsiveTextWidget(
                AppStrings.markAllRead,
                textType: TextType.body,
                color: Colors.black,
                fontSize: AppDimensions.textS,
                fontWeight: FontWeight.bold,
              ),
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
      return const Center(
        child: ResponsiveTextWidget(
          AppStrings.noNotifications,
          textType: TextType.body,
          color: Colors.black, // Black empty state text
          fontSize: AppDimensions.textL,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: viewModel.notifications.length,
      itemBuilder: (context, index) {
        final notification = viewModel.notifications[index];
        return _buildNotificationCard(context, notification, viewModel);
      },
    );
  }

  Widget _buildNotificationCard(
      BuildContext context,
      NotificationItem notification,
      NotificationViewModel viewModel,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      decoration: BoxDecoration(
        color: Colors.grey.shade200, // Grey card background
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          onTap: () {
            if (!notification.isRead) {
              viewModel.markAsRead(notification.id);
              SnackbarUtil.showInfoSnackBar(
                context,
                'Notification marked as read',
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// Icon Container
                Container(
                  width: AppDimensions.imageM,
                  height: AppDimensions.imageM,
                  decoration: BoxDecoration(
                    color: Color(notification.iconColor).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  ),
                  child: Icon(
                    notification.icon,
                    color: Color(notification.iconColor),
                    size: 20,
                  ),
                ),

                const SizedBox(width: AppDimensions.spaceM),

                /// Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// Title
                      ResponsiveTextWidget(
                        notification.title,
                        textType: TextType.body,
                        color: Colors.black, // Black title
                        fontSize: AppDimensions.textL,
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.bold,
                      ),

                      const SizedBox(height: AppDimensions.spaceXS),

                      /// Message
                      ResponsiveTextWidget(
                        notification.message,
                        textType: TextType.body,
                        color: Colors.black87, // Dark readable message
                        fontSize: AppDimensions.textM,
                      ),

                      const SizedBox(height: AppDimensions.spaceS),

                      /// Time + Unread Dot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ResponsiveTextWidget(
                            notification.time,
                            textType: TextType.body,
                            color: Colors.grey, // Time light grey
                            fontSize: AppDimensions.textS,
                          ),

                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
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


