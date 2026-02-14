/// Tracks the chat room ID the user is currently viewing (if any).
/// Used to suppress in-app notifications when the user is already in that room.
class CurrentChatRoomService {
  String? _currentChatRoomId;

  String? get currentChatRoomId => _currentChatRoomId;

  void setCurrentChatRoom(String? chatRoomId) {
    _currentChatRoomId = chatRoomId;
  }

  void clearCurrentChatRoom() {
    _currentChatRoomId = null;
  }
}
