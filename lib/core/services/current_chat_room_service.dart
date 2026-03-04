import 'package:flutter/foundation.dart';

/// Tracks the chat room ID the user is currently viewing (if any).
/// Used to suppress in-app notifications when the user is already in that room.
class CurrentChatRoomService {
  String? _currentChatRoomId;

  String? get currentChatRoomId => _currentChatRoomId;

  void setCurrentChatRoom(String? chatRoomId) {
    _currentChatRoomId = chatRoomId;
    if (kDebugMode) {
      print('[NOTIF] CurrentChatRoomService.setCurrentChatRoom: ${chatRoomId ?? "null"}');
    }
  }

  void clearCurrentChatRoom() {
    if (kDebugMode && _currentChatRoomId != null) {
      print('[NOTIF] CurrentChatRoomService.clearCurrentChatRoom: was $_currentChatRoomId');
    }
    _currentChatRoomId = null;
  }
}
