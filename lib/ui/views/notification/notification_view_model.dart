import 'package:flutter/material.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/notification_storage_service.dart';
import '../../../core/viewmodels/base_view_model.dart';

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
    final type = map['type'] as String? ?? 'chat';
    final iconData = _iconForType(type);
    final color = _colorForType(type);
    final ts = map['timestamp'];
    final time = ts != null ? _timeAgo(ts is int ? ts : int.tryParse(ts.toString()) ?? 0) : 'Just now';
    return NotificationItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      time: time,
      isRead: false,
      type: type == 'chat' ? NotificationType.chat : NotificationType.update,
      icon: iconData,
      iconColor: color,
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble;
      default:
        return Icons.notifications;
    }
  }

  static int _colorForType(String type) {
    switch (type) {
      case 'chat':
        return 0xFF00BCD4;
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

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
    required this.type,
    required this.icon,
    required this.iconColor,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? time,
    bool? isRead,
    NotificationType? type,
    IconData? icon,
    int? iconColor,
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
