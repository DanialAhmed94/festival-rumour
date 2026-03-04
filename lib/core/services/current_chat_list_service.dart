import 'package:flutter/foundation.dart';

/// Holds the current list of chat room IDs shown on the chat list screen.
/// Updated by ChatViewModel when the private chat list is loaded.
/// Used so the app bar badge only shows when there is unread in this list.
class CurrentChatListService extends ChangeNotifier {
  List<String> _roomIds = [];

  List<String> get roomIds => List.unmodifiable(_roomIds);

  void setRoomIds(List<String> ids) {
    final newIds = ids.where((id) => id.isNotEmpty).toList();
    if (listEquals(newIds, _roomIds)) return;
    _roomIds = newIds;
    notifyListeners();
  }
}
