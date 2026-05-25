import 'package:flutter/foundation.dart';

/// Tracks the chat room ID the user is currently viewing (if any).
/// Used to suppress tray / local notifications when the user is already in that room
/// (Firestore streams provide in-thread updates).
class CurrentChatRoomService {
  String? _currentChatRoomId;

  String? get currentChatRoomId => _currentChatRoomId;

  static String? _normalize(Object? id) {
    if (id == null) return null;
    final s = id.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Normalizes room ids from FCM / navigation (may be [String] or [int]).
  static String? normalizeChatRoomId(Object? id) => _normalize(id);

  /// True when a push targets [chatRoomId] and the user is already open on that room.
  bool isViewingChatRoom(Object? chatRoomId) {
    final incoming = _normalize(chatRoomId);
    final active = _normalize(_currentChatRoomId);
    if (incoming == null || active == null) return false;
    return incoming == active;
  }

  void setCurrentChatRoom(String? chatRoomId) {
    _currentChatRoomId = _normalize(chatRoomId);
    if (kDebugMode) {
      print('[NOTIF] CurrentChatRoomService.setCurrentChatRoom: ${_currentChatRoomId ?? "null"}');
    }
  }

  void clearCurrentChatRoom() {
    if (kDebugMode && _currentChatRoomId != null) {
      print('[NOTIF] CurrentChatRoomService.clearCurrentChatRoom: was $_currentChatRoomId');
    }
    _currentChatRoomId = null;
  }
}
