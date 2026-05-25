import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists received push notifications. Mark as read = remove from list.
/// Keeps at most [maxNotifications] (oldest are dropped).
class NotificationStorageService extends ChangeNotifier {
  static const String _keyList = 'notification_list';
  static const int maxNotifications = 30;

  List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  /// Builds one inbox row from FCM (shared by foreground handler and background isolate).
  static Map<String, dynamic> itemMapFromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notif = message.notification;
    final id = message.messageId ?? '${DateTime.now().millisecondsSinceEpoch}';
    final dataType = _stringData(data['type']);
    final isComment =
        dataType == 'post_comment' || dataType == 'comment_reply';
    final chatRoomId = _stringData(data['chatRoomId']);
    final listType =
        isComment ? 'comment' : (chatRoomId != null ? 'chat' : 'general');

    return <String, dynamic>{
      'id': id,
      'title': notif?.title ?? 'Notification',
      'message': notif?.body ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': listType,
      'chatRoomId': chatRoomId,
      'festivalId': _stringData(data['festivalId']),
      'postId': _stringData(data['postId']),
      'collectionName': _stringData(data['collectionName']),
      'parentCommentId': _nonEmptyStringData(data['parentCommentId']),
      'fcmType': dataType,
    };
  }

  static String? _stringData(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static String? _nonEmptyStringData(dynamic v) {
    final s = _stringData(v);
    return s;
  }

  /// Writes [message] to SharedPreferences (safe from background isolate; no [notifyListeners]).
  static Future<void> persistFromRemoteMessage(RemoteMessage message) async {
    final item = itemMapFromRemoteMessage(message);
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyList);
      List<Map<String, dynamic>> list;
      if (json != null && json.isNotEmpty) {
        final decoded = jsonDecode(json) as List<dynamic>?;
        list =
            decoded?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
                [];
      } else {
        list = [];
      }
      if (list.any((e) => e['id'] == item['id'])) return;
      list.insert(0, item);
      if (list.length > maxNotifications) {
        list = list.sublist(0, maxNotifications);
      }
      await prefs.setString(_keyList, jsonEncode(list));
    } catch (e) {
      if (kDebugMode) print('[NotificationStorage] persistFromRemoteMessage: $e');
    }
  }

  Future<void> _reloadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyList);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List<dynamic>?;
        _items =
            list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        if (_items.length > maxNotifications) {
          _items = _items.sublist(0, maxNotifications);
          await _save();
        }
      } else {
        _items = [];
      }
    } catch (e) {
      if (kDebugMode) print('[NotificationStorage] load error: $e');
      _items = [];
    }
  }

  /// Merges FCM into prefs then refreshes this instance (foreground).
  Future<void> syncFromRemoteMessage(RemoteMessage message) async {
    await NotificationStorageService.persistFromRemoteMessage(message);
    await reloadAfterExternalPersist();
  }

  /// Call after [persistFromRemoteMessage] so in-memory state matches disk.
  Future<void> reloadAfterExternalPersist() async {
    await _reloadFromPrefs();
    notifyListeners();
  }

  Future<void> addNotification({
    required String id,
    required String title,
    required String message,
    String? chatRoomId,
    String type = 'chat',
    String? festivalId,
    String? postId,
    String? collectionName,
    String? parentCommentId,
    String? fcmType,
  }) async {
    await _reloadFromPrefs();
    if (_items.any((e) => e['id'] == id)) return;
    _items.insert(0, {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'chatRoomId': chatRoomId,
      'type': type,
      'festivalId': festivalId,
      'postId': postId,
      'collectionName': collectionName,
      'parentCommentId': parentCommentId,
      'fcmType': fcmType,
    });
    if (_items.length > maxNotifications) {
      _items = _items.sublist(0, maxNotifications);
    }
    await _save();
    notifyListeners();
  }

  Future<void> removeNotification(String id) async {
    await _reloadFromPrefs();
    _items.removeWhere((e) => e['id'] == id);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _reloadFromPrefs();
    _items.clear();
    await _save();
    notifyListeners();
  }

  /// Always reads from disk so inbox matches background isolate writes.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    await _reloadFromPrefs();
    return List.unmodifiable(_items);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyList, jsonEncode(_items));
    } catch (e) {
      if (kDebugMode) print('[NotificationStorage] save error: $e');
    }
  }
}
