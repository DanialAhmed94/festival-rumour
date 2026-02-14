import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks unread notification count per chat room. Persisted so badge survives app restart.
/// Increment when a chat notification is received; clear when user opens that room.
class ChatBadgeService extends ChangeNotifier {
  static const String _keyBadgeCounts = 'chat_room_badge_counts';

  Map<String, int> _counts = {};
  bool _loaded = false;

  int getBadgeCount(String? chatRoomId) {
    if (chatRoomId == null || chatRoomId.isEmpty) return 0;
    return _counts[chatRoomId] ?? 0;
  }

  /// Call when chat list is shown so we pick up any updates from background handler.
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyBadgeCounts);
      if (json != null && json.isNotEmpty) {
        final decoded = jsonDecode(json) as Map<String, dynamic>?;
        if (decoded != null) {
          _counts = decoded.map((k, v) => MapEntry(k, (v is int) ? v : 0));
        }
      } else {
        _counts = {};
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[ChatBadge] loadFromStorage error: $e');
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await loadFromStorage();
  }

  Future<void> incrementBadge(String? chatRoomId) async {
    if (chatRoomId == null || chatRoomId.isEmpty) return;
    await _ensureLoaded();
    _counts[chatRoomId] = (_counts[chatRoomId] ?? 0) + 1;
    await _save();
    notifyListeners();
  }

  Future<void> clearBadge(String? chatRoomId) async {
    if (chatRoomId == null || chatRoomId.isEmpty) return;
    await _ensureLoaded();
    _counts.remove(chatRoomId);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBadgeCounts, jsonEncode(_counts));
    } catch (e) {
      if (kDebugMode) print('[ChatBadge] _save error: $e');
    }
  }

}
