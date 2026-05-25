import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../post_model.dart';

/// Top row (avatar, name, time, optional owner menu) for [PostWidget] / feed cards.
class PostWidgetListHeader extends StatelessWidget {
  const PostWidgetListHeader({
    super.key,
    required this.post,
    required this.leading,
    required this.showOwnerMenu,
    this.onEditSelected,
    required this.onDeleteSelected,
  });

  final PostModel post;
  final Widget leading;
  final bool showOwnerMenu;
  final VoidCallback? onEditSelected;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
          ),
          child: leading,
        ),
        title: Text(
          post.username,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        subtitle: Text(
          post.timeAgo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        trailing: showOwnerMenu
            ? PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_horiz,
                  color: AppColors.white,
                  size: 24,
                ),
                color: AppColors.screenBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditSelected?.call();
                  } else if (value == 'delete') {
                    onDeleteSelected();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
