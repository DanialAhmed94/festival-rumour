import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/notification_storage_service.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../util/firebase_notification_service.dart';
import '../../../core/utils/snackbar_util.dart';

class NotificationViewModel extends BaseViewModel {
  static const int _pageSize = 10;

  final NotificationStorageService _storage = locator<NotificationStorageService>();
  List<NotificationItem> notifications = [];
  int _displayLimit = _pageSize;

  List<NotificationItem> get displayedNotifications {
    if (notifications.length <= _displayLimit) return notifications;
    return notifications.sublist(0, _displayLimit);
  }

  bool get hasMoreNotifications => _displayLimit < notifications.length;

  @override
  void init() {
    super.init();
    _storage.addListener(_onStorageChanged);
    _loadNotifications();
  }

  @override
  void onDispose() {
    _storage.removeListener(_onStorageChanged);
    super.onDispose();
  }

  void _onStorageChanged() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await _storage.getNotifications();
    notifications = list.map(_itemFromMap).toList();
    _displayLimit = _pageSize;
    notifyListeners();
  }

  void loadMore() {
    if (!hasMoreNotifications) return;
    _displayLimit = (_displayLimit + _pageSize).clamp(0, notifications.length);
    notifyListeners();
  }

  static NotificationItem _itemFromMap(Map<String, dynamic> map) {
    final listType = map['type'] as String? ?? 'chat';
    final iconData = _iconForType(listType);
    final color = _colorForType(listType);
    final ts = map['timestamp'];
    final time = ts != null ? _timeAgo(ts is int ? ts : int.tryParse(ts.toString()) ?? 0) : 'Just now';
    return NotificationItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      time: time,
      isRead: false,
      type: listType == 'chat' ? NotificationType.chat : NotificationType.update,
      icon: iconData,
      iconColor: color,
      listType: listType,
      chatRoomId: map['chatRoomId'] as String?,
      festivalId: map['festivalId'] as String?,
      postId: map['postId'] as String?,
      collectionName: map['collectionName'] as String?,
      parentCommentId: map['parentCommentId'] as String?,
      fcmType: map['fcmType'] as String?,
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble;
      case 'comment':
        return Icons.mode_comment_outlined;
      default:
        return Icons.notifications;
    }
  }

  static int _colorForType(String type) {
    switch (type) {
      case 'chat':
        return 0xFF00BCD4;
      case 'comment':
        return 0xFF7C4DFF;
      default:
        return 0xFF607D8B;
    }
  }

  static String _timeAgo(int timestampMs) {
    final diff = DateTime.now().millisecondsSinceEpoch - timestampMs;
    if (diff < 60 * 1000) return 'Just now';
    if (diff < 60 * 60 * 1000) return '${diff ~/ (60 * 1000)}m ago';
    if (diff < 24 * 60 * 60 * 1000) return '${diff ~/ (60 * 60 * 1000)}h ago';
    if (diff < 7 * 24 * 60 * 60 * 1000) return '${diff ~/ (24 * 60 * 60 * 1000)}d ago';
    return '${diff ~/ (7 * 24 * 60 * 60 * 1000)}w ago';
  }

  /// Opens chat or post comments from persisted FCM fields; removes row from inbox on success.
  Future<void> openNotification(BuildContext context, NotificationItem item) async {
    final data = item.toNavigationData();
    if (data == null) {
      SnackbarUtil.showInfoSnackBar(
        context,
        'This notification cannot be opened (missing link data).',
      );
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      SnackbarUtil.showInfoSnackBar(context, 'Sign in to open this notification.');
      return;
    }
    await markAsRead(item.id);
    // User tapped from within the app's notification list — preserve the stack
    // so back returns them to where they were, not to the festival screen.
    FirebaseNotificationService.navigateFromNotificationData(
      data,
      preserveStack: true,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _storage.removeNotification(notificationId);
    notifications.removeWhere((n) => n.id == notificationId);
    _displayLimit = _displayLimit.clamp(0, notifications.length);
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _storage.clearAll();
    notifications = [];
    notifyListeners();
  }

  int get unreadCount => notifications.length;
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final bool isRead;
  final NotificationType type;
  final IconData icon;
  final int iconColor;
  /// Stored `type` field: `comment`, `chat`, or `general`.
  final String listType;
  final String? chatRoomId;
  final String? festivalId;
  final String? postId;
  final String? collectionName;
  final String? parentCommentId;
  /// Raw FCM [RemoteMessage.data]`type` (e.g. `post_comment`, `custom_message`).
  final String? fcmType;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
    required this.type,
    required this.icon,
    required this.iconColor,
    this.listType = 'general',
    this.chatRoomId,
    this.festivalId,
    this.postId,
    this.collectionName,
    this.parentCommentId,
    this.fcmType,
  });

  /// Payload for [FirebaseNotificationService.navigateFromNotificationData].
  Map<String, dynamic>? toNavigationData() {
    final t = fcmType;
    if (t == 'post_comment' || t == 'comment_reply') {
      final pid = postId;
      final col = collectionName;
      if (pid != null &&
          pid.isNotEmpty &&
          col != null &&
          col.isNotEmpty) {
        return <String, dynamic>{
          'type': t,
          'postId': pid,
          'collectionName': col,
          if (parentCommentId != null && parentCommentId!.isNotEmpty)
            'parentCommentId': parentCommentId,
        };
      }
      return null;
    }
    final room = chatRoomId;
    if (room != null && room.isNotEmpty) {
      return <String, dynamic>{
        'type': fcmType ?? 'custom_message',
        'chatRoomId': room,
        if (festivalId != null && festivalId!.isNotEmpty) 'festivalId': festivalId,
      };
    }
    return null;
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? time,
    bool? isRead,
    NotificationType? type,
    IconData? icon,
    int? iconColor,
    String? listType,
    String? chatRoomId,
    String? festivalId,
    String? postId,
    String? collectionName,
    String? parentCommentId,
    String? fcmType,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      listType: listType ?? this.listType,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      festivalId: festivalId ?? this.festivalId,
      postId: postId ?? this.postId,
      collectionName: collectionName ?? this.collectionName,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      fcmType: fcmType ?? this.fcmType,
    );
  }
}

enum NotificationType {
  welcome,
  festival,
  social,
  reminder,
  chat,
  update,
  photo,
}
