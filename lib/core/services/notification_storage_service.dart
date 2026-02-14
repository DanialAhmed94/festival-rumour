import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists received push notifications. Mark as read = remove from list.
/// Keeps at most [maxNotifications] (oldest are dropped).
class NotificationStorageService extends ChangeNotifier {
  static const String _keyList = 'notification_list';
  static const int maxNotifications = 30;

  List<Map<String, dynamic>> _items = [];
  bool _loaded = false;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyList);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List<dynamic>?;
        _items = list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        if (_items.length > maxNotifications) {
          _items = _items.sublist(0, maxNotifications);
          _save();
        }
      } else {
        _items = [];
      }
      _loaded = true;
    } catch (e) {
      if (kDebugMode) print('[NotificationStorage] load error: $e');
      _items = [];
    }
  }

  Future<void> addNotification({
    required String id,
    required String title,
    required String message,
    String? chatRoomId,
    String type = 'chat',
  }) async {
    await _ensureLoaded();
    if (_items.any((e) => e['id'] == id)) return;
    _items.insert(0, {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'chatRoomId': chatRoomId,
      'type': type,
    });
    if (_items.length > maxNotifications) {
      _items = _items.sublist(0, maxNotifications);
    }
    await _save();
    notifyListeners();
  }

  Future<void> removeNotification(String id) async {
    await _ensureLoaded();
    _items.removeWhere((e) => e['id'] == id);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _items.clear();
    await _save();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    await _ensureLoaded();
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
