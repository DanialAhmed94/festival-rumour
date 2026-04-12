import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_badge_service.dart';
import '../../../core/services/current_chat_list_service.dart';
import '../../../core/services/current_chat_room_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/exceptions/exception_mapper.dart';
import '../../../services/notification_service.dart';
import 'chat_message_model.dart';
import '../../../core/services/user_photo_cache_service.dart';

class ChatViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final UserPhotoCacheService _userPhotoCacheService = locator<UserPhotoCacheService>();

  /// Don't use post-image URLs as profile photos (they often 404). Return null for those.
  static String? _sanitizeProfilePhotoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final lower = url.trim().toLowerCase();
    if (lower.contains('post_images') || lower.contains('posts%2fpost_images')) {
      return null;
    }
    return url.trim();
  }

  /// Get the live profile photo URL for a user from the cache (single source of truth).
  String? getUserPhotoUrl(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _userPhotoCacheService.getCachedPhotoUrl(userId);
  }

  /// Get the live display name for a user from the cache.
  String? getUserDisplayName(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _userPhotoCacheService.getCachedDisplayName(userId);
  }

  /// Pre-fetch profile photos for all unique users in the visible messages list.
  Future<void> _prefetchMessageUserPhotos() async {
    final userIds = _visibleChatMessages
        .map((m) => m.userId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (userIds.isEmpty) return;
    await _userPhotoCacheService.batchFetch(userIds);
    if (!isDisposed) notifyListeners();
  }

  int _selectedTab = 0; // 0 = Public, 1 = Private
  bool _isInChatRoom = false;
  Map<String, dynamic>? _currentChatRoom;
  String? _chatRoomId; // Chat room ID from navigation
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSubscription;

  static const int _chatPageSize = FirestoreService.chatMessagesPageSize;

  /// Older-than-live-tail pages (oldest → newest).
  final List<ChatMessageModel> _olderPagedMessages = [];

  /// Live tail from Firestore (newest [chatMessagesPageSize] messages), chronological.
  List<ChatMessageModel> _liveTailMessagesChronological = [];

  final Map<String, ChatMessageModel> _liveTailById = {};
  Set<String> _previousLiveTailMessageIds = {};

  DocumentSnapshot<Map<String, dynamic>>? _liveTailOldestSnapshot;
  QueryDocumentSnapshot<Map<String, dynamic>>? _olderPaginationCursor;

  bool _hasMoreOlderMessages = true;
  bool _isLoadingOlderMessages = false;
  DateTime? _lastOlderLoadAttempt;
  bool _stickToBottom = true;
  bool _scrollPaginationListenerAttached = false;

  /// Throttles scroll handling so we do not run pagination / stick-to-bottom logic every frame.
  Timer? _scrollHandlingThrottle;

  /// O(1) membership for messages already in [_olderPagedMessages].
  final Set<String> _olderMessageIds = {};

  /// Rebuilt when [_messages] or [_deletedMessageIds] changes — avoids O(n²) from filtering in [messages] getter on each ListView item.
  List<ChatMessageModel> _visibleChatMessages = [];

  /// Merged older + tail before visibility cutoff (hidden / memberJoined).
  List<ChatMessageModel> _messages = [];
  String? _currentUsername;
  String? _currentUserPhotoUrl;
  String? _currentUserId; // Current user's ID for message comparison
  Set<String> _deletedMessageIds = {}; // Track messages deleted "for me"

  int get selectedTab => _selectedTab;
  bool get isInChatRoom => _isInChatRoom;
  Map<String, dynamic>? get currentChatRoom => _currentChatRoom;
  List<ChatMessageModel> get messages => _visibleChatMessages;
  String? get chatRoomId => _chatRoomId;

  bool _isSendingMessage = false;
  bool get isSendingMessage => _isSendingMessage;

  bool get isLoadingOlderMessages => _isLoadingOlderMessages;

  bool get hasMoreOlderChatMessages => _hasMoreOlderMessages;

  bool _isDeletingPrivateRoom = false;
  bool get isDeletingPrivateRoom => _isDeletingPrivateRoom;

  /// [festivalId] - When switching to private tab (tab==1), pass selected festival ID for chat room screen; null for DMs only.
  void setSelectedTab(int tab, {String? festivalId}) {
    _selectedTab = tab;
    if (tab == 1) {
      loadPrivateChatRooms(festivalId: festivalId);
    }
    notifyListeners();
  }

  // Mock chat rooms data
  final List<Map<String, dynamic>> _chatRooms = [
    {
      'title': AppStrings.lunaFest,
      'subtitle': AppStrings.communityRoom,
      'image': AppAssets.post,
      'members': 156,
    },
    {
      'title': AppStrings.musicFestival,
      'subtitle': AppStrings.privateRoom,
      'image': AppAssets.post,
      'members': 89,
    },
    {
      'title': AppStrings.artCulture,
      'subtitle': AppStrings.communityRoom,
      'image': AppAssets.post,
      'members': 234,
    },
    {
      'title': AppStrings.foodDrinks,
      'subtitle': AppStrings.communityRoom,
      'image': AppAssets.post,
      'members': 178,
    },
    {
      'title': AppStrings.photography,
      'subtitle': AppStrings.privateRoom,
      'image': AppAssets.post,
      'members': 67,
    },
  ];

  List<Map<String, dynamic>> get chatRooms {
    if (_selectedTab == 0) {
      // Public rooms
      return _chatRooms.where((room) => room['subtitle'].contains(AppStrings.communityRoom)).toList();
    } else {
      // Private rooms
      return _chatRooms.where((room) => room['subtitle'].contains(AppStrings.privateRoom)).toList();
    }
  }

  // Private chat rooms from Firestore
  List<Map<String, dynamic>> _privateChats = [];
  StreamSubscription<List<Map<String, dynamic>>>? _privateChatsSubscription;

  /// Chat rooms hidden by user (soft delete). RoomId -> when they hid it. Server-stored on user doc.
  Map<String, DateTime> _hiddenChatRoomTimestamps = {};

  /// When opening a room, if user had hidden it we only show messages after this time.
  DateTime? _hiddenAtForCurrentRoom;

  /// Latest time the current user (re)joined this room; older messages are hidden until they leave again.
  DateTime? _memberJoinedAtCutoffForCurrentRoom;

  DateTime? _effectiveMessageVisibilityCutoff() {
    final h = _hiddenAtForCurrentRoom;
    final j = _memberJoinedAtCutoffForCurrentRoom;
    if (h == null) return j;
    if (j == null) return h;
    return h.isAfter(j) ? h : j;
  }

  /// When we started listening to this room (for "new message" unhide: only unhide if a message arrived after this).
  DateTime? _roomOpenedAt;

  /// Cache for other user's photo/name to avoid repeated Firestore reads (WhatsApp-style list).
  final Map<String, Map<String, dynamic>> _otherUserCache = {};

  List<Map<String, dynamic>> get privateChats => _privateChats;

  // Search within chat list
  String _chatSearchQuery = '';
  String get chatSearchQuery => _chatSearchQuery;
  void setChatSearchQuery(String value) {
    final trimmed = value.trim().toLowerCase();
    if (_chatSearchQuery == trimmed) return;
    _chatSearchQuery = trimmed;
    notifyListeners();
  }
  void clearChatSearch() {
    if (_chatSearchQuery.isEmpty) return;
    _chatSearchQuery = '';
    notifyListeners();
  }

  /// Chats that are not hidden (visible in list).
  List<Map<String, dynamic>> get visiblePrivateChats =>
      _privateChats.where((chat) => !_hiddenChatRoomTimestamps.containsKey(chat['chatRoomId'] as String?)).toList();

  /// Chats filtered by search query (by name / otherUserName / lastMessage). Excludes hidden chats.
  List<Map<String, dynamic>> get filteredPrivateChats {
    final visible = visiblePrivateChats;
    if (_chatSearchQuery.isEmpty) return visible;
    final q = _chatSearchQuery;
    return visible.where((chat) {
      final name = (chat['otherUserName'] as String? ?? chat['name'] as String? ?? '').toLowerCase();
      final lastMessage = (chat['lastMessage'] as String? ?? '').toLowerCase();
      return name.contains(q) || lastMessage.contains(q);
    }).toList();
  }

  // Multiple selection for batch delete
  bool _isSelectionMode = false;
  final Set<String> _selectedChatRoomIds = {};

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedChatRoomIds => Set.unmodifiable(_selectedChatRoomIds);
  int get selectedCount => _selectedChatRoomIds.length;

  void enterSelectionMode() {
    _isSelectionMode = true;
    _selectedChatRoomIds.clear();
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedChatRoomIds.clear();
    notifyListeners();
  }

  void toggleChatSelection(String? chatRoomId) {
    if (chatRoomId == null || chatRoomId.isEmpty) return;
    if (_selectedChatRoomIds.contains(chatRoomId)) {
      _selectedChatRoomIds.remove(chatRoomId);
    } else {
      _selectedChatRoomIds.add(chatRoomId);
    }
    notifyListeners();
  }

  bool isChatSelected(String? chatRoomId) {
    return chatRoomId != null && _selectedChatRoomIds.contains(chatRoomId);
  }

  /// Delete or hide selected chat rooms.
  /// [dmOnly] true = DM list: always hide (server deletes room when both users have hidden).
  /// [dmOnly] false = festival private list: creator = delete, non-creator = hide.
  Future<int> deleteSelectedChatRooms({bool dmOnly = false}) async {
    if (kDebugMode) {
      print('[ChatHide] deleteSelectedChatRooms: dmOnly=$dmOnly selected=${_selectedChatRoomIds.toList()}');
    }
    if (_selectedChatRoomIds.isEmpty) return 0;
    final currentUser = _authService.currentUser;
    if (currentUser == null) return 0;
    int total = 0;
    for (final id in List<String>.from(_selectedChatRoomIds)) {
      final chat = _privateChats.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['chatRoomId'] == id,
            orElse: () => null,
          );
      final isCreator = chat != null && ((chat['createdBy'] as String?) == currentUser.uid);
      final action = dmOnly ? 'hide' : (isCreator ? 'delete' : 'hide');
      if (kDebugMode) {
        print('[ChatHide] deleteSelectedChatRooms: room=$id isCreator=$isCreator action=$action');
      }
      final success = dmOnly
          ? await addHiddenChatRoom(id)
          : (isCreator ? await deletePrivateChatRoom(id) : await addHiddenChatRoom(id));
      if (success) total++;
      _selectedChatRoomIds.remove(id);
    }
    _isSelectionMode = false;
    notifyListeners();
    if (kDebugMode) {
      print('[ChatHide] deleteSelectedChatRooms: done total=$total');
    }
    return total;
  }

  /// True when user is in a private room (creator or joined) — can open room detail
  bool get canOpenChatRoomDetail {
    if (!_isInChatRoom || _currentChatRoom == null) return false;
    final isPublic = _currentChatRoom!['isPublic'] as bool? ?? true;
    return !isPublic;
  }

  /// True when user is in a private room they created (can add members)
  bool get canAddMembersToCurrentRoom {
    if (!_isInChatRoom || _currentChatRoom == null) return false;
    final isPublic = _currentChatRoom!['isPublic'] as bool? ?? true;
    if (isPublic) return false;
    return isChatRoomCreatedByUser(_currentChatRoom!);
  }

  /// Check if the current user is the creator of a chat room
  bool isChatRoomCreatedByUser(Map<String, dynamic> chat) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return false;
    
    final createdBy = chat['createdBy'] as String?;
    return createdBy != null && createdBy == currentUser.uid;
  }

  /// Navigate to chat room detail (room info + members; creator can remove others, member can leave).
  Future<void> navigateToChatRoomDetail(BuildContext context) async {
    if (_chatRoomId == null) return;
    final result = await _navigationService.navigateTo<dynamic>(
      AppRoutes.chatRoomDetail,
      arguments: _chatRoomId,
    );
    if (result == true) {
      exitChatRoom(removeFromList: true);
      return;
    }
    await _loadChatRoomData();
    notifyListeners();
  }

  /// Navigate to Add members screen; on success refresh chat room data
  Future<void> navigateToAddMembers(BuildContext context) async {
    if (_chatRoomId == null || _currentChatRoom == null) return;
    final members = _currentChatRoom!['members'] as List<dynamic>? ?? [];
    final currentMemberIds = members.map((e) => e.toString()).toList();
    final result = await _navigationService.navigateTo<bool>(
      AppRoutes.addChatMembers,
      arguments: {
        'chatRoomId': _chatRoomId!,
        'currentMemberIds': currentMemberIds,
      },
    );
    if (result == true) {
      await _loadChatRoomData();
      notifyListeners();
    }
  }

  /// Delete a private chat room created by the user
  Future<bool> deletePrivateChatRoom(String chatRoomId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ User not authenticated, cannot delete chat room');
      }
      return false;
    }

    _isDeletingPrivateRoom = true;
    notifyListeners();
    try {
      final success = await _firestoreService.deletePrivateChatRoom(
        chatRoomId: chatRoomId,
        userId: currentUser.uid,
      );

      if (success) {
        // Remove from local list
        _privateChats.removeWhere((chat) => chat['chatRoomId'] == chatRoomId);
        if (kDebugMode) {
          print('✅ Chat room deleted successfully: $chatRoomId');
        }
      }

      return success;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error deleting chat room: $e');
      }
      final appException = ExceptionMapper.mapToAppException(e, stackTrace);
      throw appException;
    } finally {
      _isDeletingPrivateRoom = false;
      notifyListeners();
    }
  }

  /// Load hidden chat rooms from server (for chat list filter). Call when opening chat list.
  Future<void> loadHiddenChatRooms() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    if (kDebugMode) {
      print('[ChatHide] loadHiddenChatRooms: loading for uid=${currentUser.uid}');
    }
    try {
      final map = await _firestoreService.getHiddenChatRooms(currentUser.uid);
      _hiddenChatRoomTimestamps = map;
      notifyListeners();
      if (kDebugMode) {
        print('[ChatHide] loadHiddenChatRooms: loaded ${map.length} hidden rooms: ${map.keys.toList()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ChatHide] loadHiddenChatRooms: error $e');
      }
    }
  }

  /// Unhide a chat (remove from hidden list). Call when user sends or receives a message in that room.
  Future<void> removeHiddenChatRoom(String chatRoomId) async {
    final currentUser = _authService.currentUser;
    if (kDebugMode) {
      print('[ChatHide] removeHiddenChatRoom: roomId=$chatRoomId hasLocal=${_hiddenChatRoomTimestamps.containsKey(chatRoomId)}');
    }
    if (currentUser == null || !_hiddenChatRoomTimestamps.containsKey(chatRoomId)) {
      if (kDebugMode) {
        print('[ChatHide] removeHiddenChatRoom: skip (no user or not in local hidden list)');
      }
      return;
    }
    try {
      await _firestoreService.removeHiddenChatRoom(
        userId: currentUser.uid,
        chatRoomId: chatRoomId,
      );
      _hiddenChatRoomTimestamps.remove(chatRoomId);
      if (_chatRoomId == chatRoomId) _hiddenAtForCurrentRoom = null;
      notifyListeners();
      if (kDebugMode) {
        print('[ChatHide] removeHiddenChatRoom: unhid $chatRoomId, cleared _hiddenAtForCurrentRoom=${_chatRoomId == chatRoomId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ChatHide] removeHiddenChatRoom: error $e');
      }
    }
  }

  /// Hide a chat from list (soft delete). User stays in room; when opened, only messages after hide time are shown.
  Future<bool> addHiddenChatRoom(String chatRoomId) async {
    final currentUser = _authService.currentUser;
    if (kDebugMode) {
      print('[ChatHide] addHiddenChatRoom: roomId=$chatRoomId');
    }
    if (currentUser == null) {
      if (kDebugMode) {
        print('[ChatHide] addHiddenChatRoom: skip (not authenticated)');
      }
      return false;
    }
    try {
      await _firestoreService.addHiddenChatRoom(
        userId: currentUser.uid,
        chatRoomId: chatRoomId,
      );
      final now = DateTime.now();
      _hiddenChatRoomTimestamps[chatRoomId] = now;
      _selectedChatRoomIds.remove(chatRoomId);
      try {
        locator<ChatBadgeService>().clearBadge(chatRoomId);
      } catch (_) {}
      notifyListeners();
      if (kDebugMode) {
        print('[ChatHide] addHiddenChatRoom: hid $chatRoomId at $now');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error hiding chat room: $e');
      }
      final appException = ExceptionMapper.mapToAppException(e, stackTrace);
      throw appException;
    }
  }

  /// Load private chat rooms from Firestore.
  /// [festivalId] - When null: 1:1 DMs only (for chat list). When set: festival-scoped private rooms (for chat room screen private tab).
  void loadPrivateChatRooms({String? festivalId}) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ User not authenticated, cannot load private chat rooms');
      }
      return;
    }

    setBusy(true);

    // Cancel existing subscription and clear list so UI doesn't show stale data
    // (e.g. DMs from chat list when we're now loading festival-scoped private rooms)
    _privateChatsSubscription?.cancel();
    _privateChatsSubscription = null;
    _privateChats = [];
    try {
      if (locator.isRegistered<CurrentChatListService>()) {
        locator<CurrentChatListService>().setRoomIds([]);
      }
    } catch (_) {}
    notifyListeners();

    _privateChatsSubscription = _firestoreService
        .getPrivateChatRoomsForUser(currentUser.uid, festivalId: festivalId)
        .listen(
          (chatRoomsData) async {
            if (isDisposed) return;

            final currentUserId = currentUser.uid;

            // Convert to UI format
            final baseList = chatRoomsData.map((roomData) {
              final lastMessageTime = roomData['lastMessageTime'] as Timestamp?;
              final lastMessageTimeUtc = lastMessageTime?.toDate();
              String timestamp = '';
              if (lastMessageTime != null) {
                final dateTime = lastMessageTime.toDate();
                final hour = dateTime.hour;
                final minute = dateTime.minute.toString().padLeft(2, '0');
                final period = hour >= 12 ? 'PM' : 'AM';
                final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                timestamp = '$displayHour:$minute $period';
              }

              return <String, dynamic>{
                'name': roomData['name'] as String? ?? 'Chat Room',
                'chatRoomId': roomData['chatRoomId'] as String?,
                'lastMessage': roomData['lastMessage'] as String? ?? '',
                'timestamp': timestamp,
                'lastMessageTimeUtc': lastMessageTimeUtc,
                'unreadCount': 0,
                'isActive': true,
                'members': roomData['members'] as List<dynamic>? ?? [],
                'createdBy': roomData['createdBy'] as String?,
              };
            }).toList();

            // Enrich with other user's photo and name for WhatsApp-style list (with cache)
            final enriched = <Map<String, dynamic>>[];
            for (final room in baseList) {
              final members = room['members'] as List<dynamic>? ?? [];
              String? otherUserId;
              for (final m in members) {
                final id = m?.toString();
                if (id != null && id.isNotEmpty && id != currentUserId) {
                  otherUserId = id;
                  break;
                }
              }

              final enrichedRoom = Map<String, dynamic>.from(room);
              if (otherUserId != null) {
                final cached = _otherUserCache[otherUserId];
                if (cached != null) {
                  enrichedRoom['otherUserPhotoUrl'] = _sanitizeProfilePhotoUrl(cached['photoUrl'] as String?);
                  enrichedRoom['otherUserName'] = cached['displayName'];
                } else {
                  try {
                    final userData = await _firestoreService.getUserData(otherUserId);
                    if (userData != null && !isDisposed) {
                      final rawPhotoUrl = userData['photoUrl'] as String? ?? userData['image'] as String?;
                      final photoUrl = _sanitizeProfilePhotoUrl(rawPhotoUrl);
                      final displayName = userData['displayName'] as String? ?? userData['username'] as String? ?? room['name'];
                      _otherUserCache[otherUserId] = {'photoUrl': photoUrl, 'displayName': displayName};
                      enrichedRoom['otherUserPhotoUrl'] = photoUrl;
                      enrichedRoom['otherUserName'] = displayName;
                    }
                  } catch (_) {}
                }
              }
              enriched.add(enrichedRoom);
            }

            if (isDisposed) return;
            // When a hidden room gets a new message, show it in the list again (local only, no server call).
            const showInListAfterNewMessageBuffer = Duration(seconds: 1);
            final toShowInList = <String>[];
            for (final r in enriched) {
              final id = r['chatRoomId'] as String?;
              if (id == null || id.isEmpty) continue;
              final hiddenAt = _hiddenChatRoomTimestamps[id];
              if (hiddenAt == null) continue;
              final lastMsg = r['lastMessageTimeUtc'] as DateTime?;
              if (lastMsg != null && lastMsg.isAfter(hiddenAt.add(showInListAfterNewMessageBuffer))) {
                toShowInList.add(id);
              }
            }
            for (final id in toShowInList) {
              _hiddenChatRoomTimestamps.remove(id);
              // Also remove from Firestore so the stale hidden entry doesn't
              // cause the "both users hidden → hard-delete room" logic to
              // trigger when the other user hides the same DM later.
              if (currentUserId.isNotEmpty) {
                unawaited(
                  _firestoreService.removeHiddenChatRoom(
                    userId: currentUserId,
                    chatRoomId: id,
                  ),
                );
              }
            }
            _privateChats = enriched;
            final roomIds = enriched
                .where((r) => !_hiddenChatRoomTimestamps.containsKey(r['chatRoomId'] as String?))
                .map((r) => r['chatRoomId'] as String?)
                .where((id) => id != null && id.isNotEmpty)
                .cast<String>()
                .toList();
            try {
              if (locator.isRegistered<CurrentChatListService>()) {
                locator<CurrentChatListService>().setRoomIds(roomIds);
              }
            } catch (_) {}
            setBusy(false);
            notifyListeners();

            if (kDebugMode) {
              print('✅ Loaded ${_privateChats.length} private chat rooms');
            }
          },
          onError: (error, stackTrace) {
            if (kDebugMode) {
              print('Error in private chat rooms stream: $error');
            }
            if (!isDisposed) setBusy(false);
          },
        );
  }

  void joinRoom(Map<String, dynamic> room) {
    // Handle join room action
    print("${AppStrings.joiningRoom}${room['title']}");
  }

  void addPrivateChat(String title, List<String> participants) {
    // Add new private chat to the list
    final newChat = {
      'name': title,
      'avatar': AppAssets.profile,
      'lastMessage': AppStrings.chatCreated,
      'timestamp': _getCurrentTime(),
      'unreadCount': 0,
      'isActive': true,
    };
    
    _privateChats.insert(0, newChat);
    notifyListeners();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Get public chat rooms - shows only the selected festival's community chat room
  List<Map<String, dynamic>> get chatRooms1 {
    // Get selected festival from provider
    // Note: This will be called from the view where we have access to context
    // For now, return empty list - will be populated in the view
    return [];
  }

  /// Get public chat rooms with context to access FestivalProvider
  List<Map<String, dynamic>> getPublicChatRooms(BuildContext context) {
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;

    if (selectedFestival == null) {
      // If no festival selected, return empty list
      return [];
    }

    // Return only one chat room with festival name + " Community"
    return [
      {
        'name': '${selectedFestival.title} Community',
        'image': AppAssets.post,
      },
    ];
  }

  // Chat room functionality
  TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  /// Initialize chat room with chatRoomId from navigation.
  /// Opens the chat screen immediately, then loads user/room data and messages in the background.
  Future<void> initializeChatRoom(String? chatRoomId) async {
    if (chatRoomId == null || chatRoomId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ No chat room ID provided');
      }
      return;
    }

    if (kDebugMode) {
      print('[ChatHide] initializeChatRoom: roomId=$chatRoomId, clearing messages & hidden state');
    }
    // Clear any existing messages and cancel previous subscription
    _scrollHandlingThrottle?.cancel();
    _scrollHandlingThrottle = null;
    _detachScrollPaginationListener();
    _messages.clear();
    _visibleChatMessages = [];
    _olderPagedMessages.clear();
    _olderMessageIds.clear();
    _liveTailMessagesChronological = [];
    _liveTailById.clear();
    _previousLiveTailMessageIds.clear();
    _liveTailOldestSnapshot = null;
    _olderPaginationCursor = null;
    _hasMoreOlderMessages = true;
    _isLoadingOlderMessages = false;
    _lastOlderLoadAttempt = null;
    _stickToBottom = true;
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _hiddenAtForCurrentRoom = null; // Resolve fresh in _initializeChatRoomAsync
    _memberJoinedAtCutoffForCurrentRoom = null;

    _chatRoomId = chatRoomId;
    locator<CurrentChatRoomService>().setCurrentChatRoom(chatRoomId);
    locator<ChatBadgeService>().clearBadge(chatRoomId);

    // Show chat screen immediately with placeholder; room name will update when loaded
    _currentChatRoom = {'name': 'Loading...'};
    _isInChatRoom = true;
    notifyListeners();

    // Load user info, room data, and messages in the background
    _initializeChatRoomAsync();
  }

  /// Runs after chat screen is visible; loads user, room, and subscribes to messages.
  Future<void> _initializeChatRoomAsync() async {
    if (_chatRoomId == null || isDisposed) return;

    setBusy(true);
    notifyListeners();

    await _loadCurrentUserInfo();
    if (isDisposed || _chatRoomId == null) return;

    await _loadChatRoomData();
    if (isDisposed || _chatRoomId == null) return;

    // If user had hidden this chat, only show messages after hide time (no old messages).
    final currentUser = _authService.currentUser;
    final roomId = _chatRoomId;
    if (currentUser != null && roomId != null) {
      if (kDebugMode) {
        print('[ChatHide] _initializeChatRoomAsync: loading hidden state for room=$roomId (source=server)');
      }
      final hiddenMap = await _firestoreService.getHiddenChatRooms(
        currentUser.uid,
        source: Source.server,
      );
      if (kDebugMode) {
        print('[ChatHide] _initializeChatRoomAsync: server hiddenMap size=${hiddenMap.length}, hasRoom=${hiddenMap.containsKey(roomId)}, localHasRoom=${_hiddenChatRoomTimestamps.containsKey(roomId)}');
      }
      if (hiddenMap.containsKey(roomId)) {
        _hiddenAtForCurrentRoom = hiddenMap[roomId];
        if (kDebugMode) {
          print('[ChatHide] _initializeChatRoomAsync: using SERVER hiddenAt=${_hiddenAtForCurrentRoom}');
        }
      } else if (_hiddenChatRoomTimestamps.containsKey(roomId)) {
        _hiddenAtForCurrentRoom = _hiddenChatRoomTimestamps[roomId];
        if (kDebugMode) {
          print('[ChatHide] _initializeChatRoomAsync: using LOCAL hiddenAt=${_hiddenAtForCurrentRoom}');
        }
      } else if (kDebugMode) {
        print('[ChatHide] _initializeChatRoomAsync: room NOT hidden -> will show all messages');
      }
    }

    _roomOpenedAt = DateTime.now();
    if (kDebugMode) {
      print('[ChatHide] _initializeChatRoomAsync: _roomOpenedAt=$_roomOpenedAt, starting message listener');
    }
    _startMessagesListener();
    // setBusy(false) is called when the messages stream emits (in the listener)
  }

  /// Load current user information
  Future<void> _loadCurrentUserInfo() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _currentUserId = currentUser.uid;

    try {
      // Get user data from the profile cache (Firestore-backed single source of truth)
      final cachedName = await _userPhotoCacheService.getDisplayName(currentUser.uid);
      final cachedPhoto = await _userPhotoCacheService.getPhotoUrl(currentUser.uid);

      _currentUsername = cachedName ??
                        currentUser.displayName ??
                        'User';
      _currentUserPhotoUrl = _sanitizeProfilePhotoUrl(
        cachedPhoto ?? currentUser.photoURL,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user info: $e');
      }
      // Fallback to Firebase Auth data
      final currentUser = _authService.currentUser;
      _currentUsername = currentUser?.displayName ?? 'User';
      _currentUserPhotoUrl = _sanitizeProfilePhotoUrl(currentUser?.photoURL);
    }
  }

  /// Check if a message is from the current user
  bool isMessageFromCurrentUser(ChatMessageModel message) {
    return _currentUserId != null && message.userId == _currentUserId;
  }

  /// Load chat room data from Firestore
  Future<void> _loadChatRoomData() async {
    if (_chatRoomId == null) return;

    try {
      final chatRoomDoc = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(_chatRoomId!)
          .get();

      if (chatRoomDoc.exists) {
        final data = chatRoomDoc.data() as Map<String, dynamic>;
        _currentChatRoom = {
          'name': data['name'] as String? ?? 'Chat Room',
          'isPublic': data['isPublic'] as bool? ?? false,
          'members': data['members'] as List<dynamic>? ?? [],
          'createdBy': data['createdBy'] as String?,
          'festivalId': data['festivalId'] as String?,
        };
        _memberJoinedAtCutoffForCurrentRoom = null;
        final uid = _currentUserId;
        if (uid != null) {
          final mj = data['memberJoinedAt'];
          if (mj is Map) {
            final raw = mj[uid];
            if (raw is Timestamp) {
              _memberJoinedAtCutoffForCurrentRoom = raw.toDate();
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading chat room data: $e');
      }
    }
  }

  ChatMessageModel? _mapRawToChatMessage(
    Map<String, dynamic> messageData, {
    String? messageIdOverride,
  }) {
    try {
      final lat = messageData['lat'];
      final lng = messageData['lng'];
      return ChatMessageModel(
        messageId: messageIdOverride ?? messageData['messageId'] as String?,
        userId: messageData['userId'] as String? ?? '',
        username: messageData['username'] as String? ?? 'Unknown',
        content: messageData['content'] as String? ?? '',
        createdAt:
            (messageData['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        userPhotoUrl: _sanitizeProfilePhotoUrl(
          messageData['userPhotoUrl'] as String?,
        ),
        chatRoomId:
            messageData['chatRoomId'] as String? ?? _chatRoomId ?? '',
        type: messageData['type'] as String?,
        lat: lat is num ? lat.toDouble() : null,
        lng: lng is num ? lng.toDouble() : null,
        festivalName: messageData['festivalName'] as String?,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing message: $e');
      }
      return null;
    }
  }

  ChatMessageModel? _mapDocToChatMessage(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final raw = doc.data();
    if (raw == null) return null;
    return _mapRawToChatMessage(raw, messageIdOverride: doc.id);
  }

  void _attachScrollPaginationListener() {
    if (_scrollPaginationListenerAttached) return;
    scrollController.addListener(_onChatScrollPagination);
    _scrollPaginationListenerAttached = true;
  }

  void _detachScrollPaginationListener() {
    if (!_scrollPaginationListenerAttached) return;
    _scrollHandlingThrottle?.cancel();
    _scrollHandlingThrottle = null;
    scrollController.removeListener(_onChatScrollPagination);
    _scrollPaginationListenerAttached = false;
  }

  void _onChatScrollPagination() {
    _scrollHandlingThrottle?.cancel();
    _scrollHandlingThrottle = Timer(const Duration(milliseconds: 100), () {
      if (isDisposed) return;
      _evaluateChatScrollMetrics();
    });
  }

  void _evaluateChatScrollMetrics() {
    if (!scrollController.hasClients || _chatRoomId == null) return;
    final pos = scrollController.position;
    const topThreshold = 100.0;
    final cursor = _olderPaginationCursor ?? _liveTailOldestSnapshot;
    if (pos.pixels <= topThreshold &&
        _hasMoreOlderMessages &&
        !_isLoadingOlderMessages &&
        cursor != null) {
      final now = DateTime.now();
      if (_lastOlderLoadAttempt != null &&
          now.difference(_lastOlderLoadAttempt!) <
              const Duration(milliseconds: 500)) {
        return;
      }
      _lastOlderLoadAttempt = now;
      unawaited(loadOlderChatMessages());
    }

    const bottomSnap = 80.0;
    _stickToBottom = pos.pixels >= pos.maxScrollExtent - bottomSnap;
  }

  /// Loads the next 40 older messages when the user scrolls near the top.
  Future<void> loadOlderChatMessages() async {
    if (_isLoadingOlderMessages ||
        !_hasMoreOlderMessages ||
        _chatRoomId == null) {
      return;
    }
    final cursor = _olderPaginationCursor ?? _liveTailOldestSnapshot;
    if (cursor == null) return;

    _isLoadingOlderMessages = true;
    notifyListeners();

    final prevMax =
        scrollController.hasClients
            ? scrollController.position.maxScrollExtent
            : 0.0;
    final prevPixels =
        scrollController.hasClients ? scrollController.position.pixels : 0.0;

    try {
      final page = await _firestoreService.fetchOlderChatMessagesPage(
        chatRoomId: _chatRoomId!,
        startAfterDocument: cursor,
        limit: _chatPageSize,
      );
      if (isDisposed) return;

      if (page.messagesChronological.isEmpty) {
        _hasMoreOlderMessages = false;
      } else {
        final batchAsc = <ChatMessageModel>[];
        for (final raw in page.messagesChronological) {
          final m = _mapRawToChatMessage(raw);
          if (m == null || m.messageId == null) continue;
          final id = m.messageId!;
          if (_olderMessageIds.contains(id) || _liveTailById.containsKey(id)) {
            continue;
          }
          batchAsc.add(m);
        }
        _mergeOlderAscendingBatch(batchAsc);
        _olderPaginationCursor = page.oldestDocument;
        _hasMoreOlderMessages = page.hasMore;
      }

      _rebuildMergedMessagesAndApplyCutoff();

      if (kDebugMode) {
        print(
          '[ChatPaging] older page loaded: +${page.messagesChronological.length} hasMore=$_hasMoreOlderMessages',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('loadOlderChatMessages: $e');
      }
    } finally {
      _isLoadingOlderMessages = false;
      notifyListeners();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isDisposed || !scrollController.hasClients) return;
        final newMax = scrollController.position.maxScrollExtent;
        scrollController.jumpTo(prevPixels + (newMax - prevMax));
      });
    }
  }

  void _rebuildMergedMessagesAndApplyCutoff() {
    final cutoff = _effectiveMessageVisibilityCutoff();
    if (cutoff == null) {
      _messages = [
        ..._olderPagedMessages,
        ..._liveTailMessagesChronological,
      ];
    } else {
      _messages = [
        for (final m in _olderPagedMessages)
          if (m.createdAt.isAfter(cutoff)) m,
        for (final m in _liveTailMessagesChronological)
          if (m.createdAt.isAfter(cutoff)) m,
      ];
    }
    _rebuildVisibleChatMessages();
    if (kDebugMode) {
      print(
        '[ChatPaging] merged: older=${_olderPagedMessages.length} tail=${_liveTailMessagesChronological.length} visible=${_messages.length} cutoff=$cutoff',
      );
    }
  }

  void _rebuildVisibleChatMessages() {
    if (_deletedMessageIds.isEmpty) {
      _visibleChatMessages = _messages;
    } else {
      _visibleChatMessages = [
        for (final m in _messages)
          if (m.messageId == null ||
              !_deletedMessageIds.contains(m.messageId))
            m,
      ];
    }
  }

  /// Merges [batchAsc] (oldest → newest) into [_olderPagedMessages] in O(n + m) without full re-sort.
  void _mergeOlderAscendingBatch(List<ChatMessageModel> batchAsc) {
    final newOnes = <ChatMessageModel>[];
    for (final m in batchAsc) {
      final id = m.messageId;
      if (id == null) continue;
      if (_olderMessageIds.contains(id) || _liveTailById.containsKey(id)) {
        continue;
      }
      newOnes.add(m);
      _olderMessageIds.add(id);
    }
    if (newOnes.isEmpty) return;

    if (_olderPagedMessages.isEmpty) {
      _olderPagedMessages.addAll(newOnes);
      return;
    }

    final merged = <ChatMessageModel>[];
    var i = 0;
    var j = 0;
    while (i < _olderPagedMessages.length && j < newOnes.length) {
      final c = _olderPagedMessages[i].createdAt.compareTo(
        newOnes[j].createdAt,
      );
      if (c <= 0) {
        merged.add(_olderPagedMessages[i++]);
      } else {
        merged.add(newOnes[j++]);
      }
    }
    while (i < _olderPagedMessages.length) {
      merged.add(_olderPagedMessages[i++]);
    }
    while (j < newOnes.length) {
      merged.add(newOnes[j++]);
    }
    _olderPagedMessages
      ..clear()
      ..addAll(merged);
  }

  void _onRecentMessagesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (isDisposed) return;

    final docs = snapshot.docs;
    final newTailChronological = <ChatMessageModel>[];
    final newIds = <String>{};

    for (final doc in docs.reversed) {
      final m = _mapDocToChatMessage(doc);
      if (m == null) continue;
      if (m.messageId != null) newIds.add(m.messageId!);
      newTailChronological.add(m);
    }

    List<ChatMessageModel>? droppedSorted;
    if (_previousLiveTailMessageIds.isNotEmpty) {
      final droppedIds = _previousLiveTailMessageIds.difference(newIds);
      if (droppedIds.isNotEmpty) {
        final droppedBatch = <ChatMessageModel>[];
        for (final id in droppedIds) {
          final old = _liveTailById[id];
          if (old == null) continue;
          if (_olderMessageIds.contains(id) || newIds.contains(id)) continue;
          droppedBatch.add(old);
        }
        if (droppedBatch.isNotEmpty) {
          droppedBatch.sort(
            (a, b) => a.createdAt.compareTo(b.createdAt),
          );
          droppedSorted = droppedBatch;
        }
      }
    }

    _liveTailById
      ..clear()
      ..addEntries([
        for (final m in newTailChronological)
          if (m.messageId != null) MapEntry(m.messageId!, m),
      ]);

    if (droppedSorted != null && droppedSorted.isNotEmpty) {
      _mergeOlderAscendingBatch(droppedSorted);
    }
    _previousLiveTailMessageIds = newIds;
    _liveTailMessagesChronological = newTailChronological;
    _liveTailOldestSnapshot = docs.isNotEmpty ? docs.last : null;

    if (_olderPaginationCursor == null) {
      _hasMoreOlderMessages = docs.length >= _chatPageSize;
    }

    _rebuildMergedMessagesAndApplyCutoff();

    if (_hiddenAtForCurrentRoom != null &&
        _chatRoomId != null &&
        _roomOpenedAt != null) {
      final hasNewMessageSinceOpen =
          _messages.any((m) => m.createdAt.isAfter(_roomOpenedAt!));
      if (hasNewMessageSinceOpen) {
        unawaited(removeHiddenChatRoom(_chatRoomId!));
      }
    }

    if (!isDisposed) setBusy(false);
    notifyListeners();

    // Pre-fetch profile photos for message authors
    unawaited(_prefetchMessageUserPhotos());

    if (_stickToBottom) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (isDisposed || !scrollController.hasClients) return;
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Live tail (newest [FirestoreService.chatMessagesPageSize] messages) + scroll to load older pages.
  void _startMessagesListener() {
    if (_chatRoomId == null || isDisposed) return;

    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _attachScrollPaginationListener();

    _messagesSubscription = _firestoreService
        .watchRecentChatMessages(_chatRoomId!, limit: _chatPageSize)
        .listen(
          _onRecentMessagesSnapshot,
          onError: (error, stackTrace) {
            if (kDebugMode) {
              print('Error in messages stream: $error');
            }
            if (!isDisposed) setBusy(false);
          },
        );
  }

  void enterChatRoom(Map<String, dynamic> room) {
    _currentChatRoom = room;
    _isInChatRoom = true;
    notifyListeners();
  }

  void exitChatRoom({bool removeFromList = false}) {
    // Only remove from list when user left the group via room detail, not on back
    if (removeFromList) {
      final roomId = _chatRoomId;
      if (roomId != null) {
        _privateChats.removeWhere((chat) => chat['chatRoomId'] == roomId);
      }
    }
    _isInChatRoom = false;
    _currentChatRoom = null;
    _chatRoomId = null;
    _hiddenAtForCurrentRoom = null;
    _memberJoinedAtCutoffForCurrentRoom = null;
    _roomOpenedAt = null;
    if (kDebugMode) {
      print('[ChatHide] exitChatRoom: cleared _hiddenAtForCurrentRoom and _roomOpenedAt');
    }
    locator<CurrentChatRoomService>().clearCurrentChatRoom();
    messageController.clear();
    _scrollHandlingThrottle?.cancel();
    _scrollHandlingThrottle = null;
    _detachScrollPaginationListener();
    _messages.clear();
    _visibleChatMessages = [];
    _olderPagedMessages.clear();
    _olderMessageIds.clear();
    _liveTailMessagesChronological = [];
    _liveTailById.clear();
    _previousLiveTailMessageIds.clear();
    _liveTailOldestSnapshot = null;
    _olderPaginationCursor = null;
    _deletedMessageIds.clear(); // Clear deleted messages when exiting
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    notifyListeners();
  }

  void _removeMessageFromLocalCaches(String messageId) {
    _olderPagedMessages.removeWhere((m) => m.messageId == messageId);
    _olderMessageIds.remove(messageId);
    _liveTailMessagesChronological.removeWhere((m) => m.messageId == messageId);
    _liveTailById.remove(messageId);
    _previousLiveTailMessageIds.remove(messageId);
    _rebuildMergedMessagesAndApplyCutoff();
  }

  /// Delete message for me (only removes from user's view)
  void deleteMessageForMe(String messageId) {
    _deletedMessageIds.add(messageId);
    _rebuildVisibleChatMessages();
    notifyListeners();

    if (kDebugMode) {
      print('✅ Message deleted for me: $messageId');
    }
  }

  /// Delete message for everyone (removes from Firestore)
  Future<bool> deleteMessageForEveryone(String messageId) async {
    if (_chatRoomId == null) return false;

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ User not authenticated, cannot delete message');
      }
      return false;
    }

    // Find the message to verify ownership
    final message = _messages.firstWhere(
      (msg) => msg.messageId == messageId,
      orElse: () => throw Exception('Message not found'),
    );

    // Verify the user is the message sender
    if (message.userId != currentUser.uid) {
      if (kDebugMode) {
        print('⚠️ User is not the sender of this message');
      }
      return false;
    }

    try {
      final success = await _firestoreService.deleteChatMessageForEveryone(
        chatRoomId: _chatRoomId!,
        messageId: messageId,
        userId: currentUser.uid,
      );

      if (success) {
        _removeMessageFromLocalCaches(messageId);
        _deletedMessageIds.remove(messageId);
        notifyListeners();

        if (kDebugMode) {
          print('✅ Message deleted for everyone: $messageId');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting message for everyone: $e');
      }
      return false;
    }
  }

  /// Send a message to the chat room. Returns true on success, false on failure (message text is restored on failure).
  Future<bool> sendMessage() async {
    if (messageController.text.trim().isEmpty || _chatRoomId == null) {
      return false;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ User not authenticated, cannot send message');
      }
      return false;
    }

    final content = messageController.text.trim();
    messageController.clear();
    _isSendingMessage = true;
    notifyListeners();

    try {
      await _firestoreService.sendChatMessage(
        chatRoomId: _chatRoomId!,
        userId: currentUser.uid,
        username: _currentUsername ?? 'User',
        content: content,
        userPhotoUrl: _sanitizeProfilePhotoUrl(_currentUserPhotoUrl),
      );

      if (kDebugMode) {
        print('✅ Message sent successfully');
      }
      _stickToBottom = true;

      // If this room was hidden, unhide it so it reappears in the chat list
      if (_chatRoomId != null && _hiddenChatRoomTimestamps.containsKey(_chatRoomId)) {
        if (kDebugMode) {
          print('[ChatHide] sendMessage: room was hidden, unhiding $_chatRoomId');
        }
        unawaited(removeHiddenChatRoom(_chatRoomId!));
      }

      // Notify current room members only (read fresh from Firestore so leavers are not notified).
      if (_currentUserId == null || _chatRoomId == null) {
        if (kDebugMode) {
          print('[NOTIF] Trigger: skipped — no chatRoomId or currentUser');
        }
      } else {
        try {
          final fresh = await _firestoreService.getChatRoomDocument(_chatRoomId!);
          final serverMembers = fresh?['members'] as List<dynamic>? ?? [];
          if (fresh != null) {
            _currentChatRoom = {
              ...?_currentChatRoom,
              'members': serverMembers,
              'name': fresh['name'] as String? ?? _currentChatRoom?['name'],
              'isPublic': fresh['isPublic'] as bool? ?? _currentChatRoom?['isPublic'] ?? false,
              'createdBy': fresh['createdBy'] as String? ?? _currentChatRoom?['createdBy'],
              'festivalId': fresh['festivalId'] as String? ?? _currentChatRoom?['festivalId'],
            };
          }
          final otherMemberIds =
              serverMembers
                  .map((e) => e.toString())
                  .where((id) => id != _currentUserId)
                  .toList();
          if (otherMemberIds.isEmpty) {
            if (kDebugMode) {
              print('[NOTIF] Trigger: skipped — no other members (server list)');
            }
          } else {
            if (kDebugMode) {
              print(
                '[NOTIF] Trigger: sending push to ${otherMemberIds.length} member(s) from server list, chatRoomId=$_chatRoomId',
              );
            }
            _sendPushNotificationToMembers(
              otherMemberIds: otherMemberIds,
              content: content,
            );
          }
          notifyListeners();
        } catch (e) {
          if (kDebugMode) {
            print('[NOTIF] Trigger: failed to load server members, skip push: $e');
          }
        }
      }
      _isSendingMessage = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending message: $e');
      }
      messageController.text = content;
      _isSendingMessage = false;
      notifyListeners();
      return false;
    }
  }

  /// Fire-and-forget: resolve chat room name (from cache or Firestore) then send push to other members.
  void _sendPushNotificationToMembers({
    required List<String> otherMemberIds,
    required String content,
  }) async {
    String? roomName = _currentChatRoom?['name'] as String?;
    if ((roomName == null || roomName.isEmpty) && _chatRoomId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .get();
        if (doc.exists && doc.data() != null) {
          roomName = doc.data()!['name'] as String?;
        }
      } catch (e) {
        if (kDebugMode) print('[NOTIF] Trigger: could not fetch room name: $e');
      }
    }
    final festivalId = _currentChatRoom?['festivalId'] as String?;
    if (kDebugMode) {
      print('[NOTIF] Trigger: chatRoomName=$roomName, festivalId=$festivalId');
    }
    NotificationServiceApi.sendPushNotification(
      userIds: otherMemberIds,
      title: _currentUsername ?? 'New message',
      message: content,
      chatRoomId: _chatRoomId,
      chatRoomName: roomName,
      festivalId: festivalId,
    ).then((ok) {
      if (kDebugMode) {
        print('[NOTIF] Trigger: API call finished success=$ok');
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('[NOTIF] Trigger: API call error $e');
      }
    });
  }

  void inviteFriends() {
    // Handle invite friends action
    print(AppStrings.invitingFriendsToChatRoom);
  }

  // Navigation methods
  void navigateBack(BuildContext context) {
    Navigator.pop(context);
  }

  void navigateToChatRoom(Map<String, dynamic> room) {
    _currentChatRoom = room;
    _isInChatRoom = true;
    notifyListeners();
  }

  void navigateBackFromChatRoom() {
    _isInChatRoom = false;
    _currentChatRoom = null;
    locator<CurrentChatRoomService>().clearCurrentChatRoom();
    messageController.clear();
    notifyListeners();
  }

  @override
  void onDispose() {
    _scrollHandlingThrottle?.cancel();
    _scrollHandlingThrottle = null;
    _detachScrollPaginationListener();
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _privateChatsSubscription?.cancel();
    _privateChatsSubscription = null;
    messageController.dispose();
    scrollController.dispose();
    super.onDispose();
  }
}
