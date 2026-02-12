import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';

class ChatRoomDetailViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();

  String? _chatRoomId;
  String _roomName = '';
  String? _createdBy;
  List<Map<String, dynamic>> _members = [];

  String? get chatRoomId => _chatRoomId;
  String get roomName => _roomName;
  String? get createdBy => _createdBy;
  List<Map<String, dynamic>> get members => _members;

  String? get currentUserId => _authService.currentUser?.uid;

  bool get isCurrentUserCreator =>
      currentUserId != null && _createdBy == currentUserId;

  void setArgs(String? chatRoomId) {
    _chatRoomId = chatRoomId;
    notifyListeners();
  }

  Future<void> loadRoomDetail() async {
    if (_chatRoomId == null || _chatRoomId!.isEmpty) return;

    await handleAsync(() async {
      try {
        final roomDoc = await _firestoreService.getChatRoomDocument(_chatRoomId!);
        if (roomDoc == null) {
          setError('Room not found');
          return;
        }
        _roomName = roomDoc['name'] as String? ?? 'Chat Room';
        _createdBy = roomDoc['createdBy'] as String?;
        final memberIds = (roomDoc['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        _members = [];
        for (final uid in memberIds) {
          try {
            final userData = await _firestoreService.getUserData(uid);
            final displayName = userData?['displayName'] as String? ??
                userData?['username'] as String? ??
                'Unknown';
            final photoUrl = userData?['photoUrl'] as String?;
            final isCreator = uid == _createdBy;
            _members.add({
              'userId': uid,
              'displayName': displayName,
              'photoUrl': photoUrl,
              'isCreator': isCreator,
            });
          } catch (e) {
            if (kDebugMode) print('Error loading user $uid: $e');
            _members.add({
              'userId': uid,
              'displayName': 'Unknown',
              'photoUrl': null,
              'isCreator': uid == _createdBy,
            });
          }
        }
        _members.sort((a, b) {
          final aCreator = a['isCreator'] == true ? 1 : 0;
          final bCreator = b['isCreator'] == true ? 1 : 0;
          return bCreator.compareTo(aCreator);
        });
        setError(null);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('Error loading room detail: $e');
          print(stackTrace);
        }
        setError('Failed to load room details. Please try again.');
        rethrow;
      }
      notifyListeners();
    }, errorMessage: 'Failed to load room details');
  }

  Future<bool> removeMember(String memberId) async {
    if (_chatRoomId == null || currentUserId == null) {
      setError('Unable to remove member. Please try again.');
      notifyListeners();
      return false;
    }
    if (memberId == _createdBy) {
      setError('Cannot remove the room creator.');
      notifyListeners();
      return false;
    }

    try {
      final success = await _firestoreService.removeMemberFromPrivateChatRoom(
        chatRoomId: _chatRoomId!,
        requesterId: currentUserId!,
        memberIdToRemove: memberId,
      );
      if (success) {
        _members.removeWhere((m) => m['userId'] == memberId);
        setError(null);
        notifyListeners();
        return true;
      }
      setError('Could not remove member. Please try again.');
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error removing member: $e');
        print(stackTrace);
      }
      setError('Failed to remove member. Please try again.');
      notifyListeners();
      return false;
    }
  }

  bool canRemoveMember(Map<String, dynamic> member) {
    if (currentUserId == null) return false;
    if (!isCurrentUserCreator) return false;
    final memberId = member['userId'] as String?;
    if (memberId == null) return false;
    if (memberId == currentUserId) return false;
    if (member['isCreator'] == true) return false;
    return true;
  }

  /// Leave the room (for non-creator members). Returns true on success so view can pop with true.
  Future<bool> leaveRoom() async {
    if (_chatRoomId == null || currentUserId == null) {
      setError('Unable to leave. Please try again.');
      notifyListeners();
      return false;
    }

    try {
      final success = await _firestoreService.leavePrivateChatRoom(
        chatRoomId: _chatRoomId!,
        userId: currentUserId!,
      );
      if (success) {
        setError(null);
        return true;
      }
      setError('Could not leave the group. Please try again.');
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error leaving room: $e');
        print(stackTrace);
      }
      setError('Failed to leave the group. Please try again.');
      notifyListeners();
      return false;
    }
  }
}
