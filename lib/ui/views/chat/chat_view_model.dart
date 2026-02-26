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
import '../../../core/services/current_chat_room_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/exceptions/exception_mapper.dart';
import '../../../services/notification_service.dart';
import 'chat_message_model.dart';

class ChatViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();

  /// Don't use post-image URLs as profile photos (they often 404). Return null for those.
  static String? _sanitizeProfilePhotoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final lower = url.trim().toLowerCase();
    if (lower.contains('post_images') || lower.contains('posts%2fpost_images')) {
      return null;
    }
    return url.trim();
  }

  int _selectedTab = 0; // 0 = Public, 1 = Private
  bool _isInChatRoom = false;
  Map<String, dynamic>? _currentChatRoom;
  String? _chatRoomId; // Chat room ID from navigation
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  List<ChatMessageModel> _messages = [];
  String? _currentUsername;
  String? _currentUserPhotoUrl;
  String? _currentUserId; // Current user's ID for message comparison
  Set<String> _deletedMessageIds = {}; // Track messages deleted "for me"

  int get selectedTab => _selectedTab;
  bool get isInChatRoom => _isInChatRoom;
  Map<String, dynamic>? get currentChatRoom => _currentChatRoom;
  List<ChatMessageModel> get messages => _messages
      .where((message) => !_deletedMessageIds.contains(message.messageId))
      .toList(); // Filter out deleted messages
  String? get chatRoomId => _chatRoomId;

  bool _isSendingMessage = false;
  bool get isSendingMessage => _isSendingMessage;

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

  /// Chats filtered by search query (by name / otherUserName / lastMessage).
  List<Map<String, dynamic>> get filteredPrivateChats {
    if (_chatSearchQuery.isEmpty) return _privateChats;
    final q = _chatSearchQuery;
    return _privateChats.where((chat) {
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

  /// Delete all selected chat rooms. Returns the number of rooms successfully deleted.
  Future<int> deleteSelectedChatRooms() async {
    if (_selectedChatRoomIds.isEmpty) return 0;
    int deleted = 0;
    for (final id in List<String>.from(_selectedChatRoomIds)) {
      final success = await deletePrivateChatRoom(id);
      if (success) deleted++;
      _selectedChatRoomIds.remove(id);
    }
    _isSelectionMode = false;
    notifyListeners();
    return deleted;
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

    try {
      final success = await _firestoreService.deletePrivateChatRoom(
        chatRoomId: chatRoomId,
        userId: currentUser.uid,
      );

      if (success) {
        // Remove from local list
        _privateChats.removeWhere((chat) => chat['chatRoomId'] == chatRoomId);
        notifyListeners();
        
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
            _privateChats = enriched;
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

  /// Initialize chat room with chatRoomId from navigation
  Future<void> initializeChatRoom(String? chatRoomId) async {
    if (chatRoomId == null || chatRoomId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ No chat room ID provided');
      }
      return;
    }

    // Clear any existing messages first to prevent showing old/dummy messages
    _messages.clear();
    setBusy(true);
    notifyListeners();

    // Cancel any existing subscription before starting a new one
    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _chatRoomId = chatRoomId;
    locator<CurrentChatRoomService>().setCurrentChatRoom(chatRoomId);
    locator<ChatBadgeService>().clearBadge(chatRoomId);

    // Load current user info
    await _loadCurrentUserInfo();
    
    // Load chat room data
    await _loadChatRoomData();
    
    // Start listening to messages
    _startMessagesListener();
    
    _isInChatRoom = true;
    notifyListeners();
  }

  /// Load current user information
  Future<void> _loadCurrentUserInfo() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _currentUserId = currentUser.uid;

    try {
      // Get user data from Firestore
      final userData = await _firestoreService.getUserData(currentUser.uid);
      if (userData != null) {
        _currentUsername = userData['displayName'] as String? ?? 
                          userData['username'] as String? ?? 
                          currentUser.displayName ?? 
                          'User';
        _currentUserPhotoUrl = _sanitizeProfilePhotoUrl(
          userData['photoUrl'] as String? ?? currentUser.photoURL,
        );
      } else {
        // Fallback to Firebase Auth data
        _currentUsername = currentUser.displayName ?? 'User';
        _currentUserPhotoUrl = _sanitizeProfilePhotoUrl(currentUser.photoURL);
      }
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
        };
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading chat room data: $e');
      }
    }
  }

  /// Start listening to real-time messages
  void _startMessagesListener() {
    if (_chatRoomId == null || isDisposed) return;

    // Cancel existing subscription
    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _messagesSubscription = _firestoreService
        .getChatMessagesStream(_chatRoomId!, limit: 100)
        .listen(
          (messagesData) {
            if (isDisposed) return;

            // Convert to ChatMessageModel
            final newMessages = <ChatMessageModel>[];
            for (var messageData in messagesData) {
              try {
                final lat = messageData['lat'];
                final lng = messageData['lng'];
                final message = ChatMessageModel(
                  messageId: messageData['messageId'] as String?,
                  userId: messageData['userId'] as String? ?? '',
                  username: messageData['username'] as String? ?? 'Unknown',
                  content: messageData['content'] as String? ?? '',
                  createdAt: (messageData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  userPhotoUrl: _sanitizeProfilePhotoUrl(messageData['userPhotoUrl'] as String?),
                  chatRoomId: messageData['chatRoomId'] as String? ?? _chatRoomId ?? '',
                  type: messageData['type'] as String?,
                  lat: lat is num ? lat.toDouble() : null,
                  lng: lng is num ? lng.toDouble() : null,
                  festivalName: messageData['festivalName'] as String?,
                );
                newMessages.add(message);
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing message: $e');
                }
              }
            }

            _messages = newMessages;
            if (!isDisposed) setBusy(false);
            notifyListeners();

            // Auto-scroll to bottom after a short delay to allow UI to update
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!isDisposed && scrollController.hasClients) {
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
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
    locator<CurrentChatRoomService>().clearCurrentChatRoom();
    messageController.clear();
    _messages.clear();
    _deletedMessageIds.clear(); // Clear deleted messages when exiting
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    notifyListeners();
  }

  /// Delete message for me (only removes from user's view)
  void deleteMessageForMe(String messageId) {
    _deletedMessageIds.add(messageId);
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
        // Also remove from local list and deleted set
        _messages.removeWhere((msg) => msg.messageId == messageId);
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

      // Notify other room members (fire-and-forget; don't block UI)
      final members = _currentChatRoom?['members'] as List<dynamic>?;
      if (members == null || members.isEmpty || _currentUserId == null) {
        if (kDebugMode) {
          print('[NOTIF] Trigger: skipped — no members or currentUser (members=${members?.length ?? 0}, currentUserId=$_currentUserId)');
        }
      } else {
        final otherMemberIds = members
            .map((e) => e.toString())
            .where((id) => id != _currentUserId)
            .toList();
        if (otherMemberIds.isEmpty) {
          if (kDebugMode) print('[NOTIF] Trigger: skipped — no other members in room');
        } else {
          if (kDebugMode) {
            print('[NOTIF] Trigger: sending push to ${otherMemberIds.length} other member(s), chatRoomId=$_chatRoomId');
          }
          _sendPushNotificationToMembers(
            otherMemberIds: otherMemberIds,
            content: content,
          );
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
    if (kDebugMode) {
      print('[NOTIF] Trigger: chatRoomName=$roomName');
    }
    // Single request for any group size. Backend (sendNotification) must send exactly one FCM per userId in the list, not one message to the whole list per userId.
    NotificationServiceApi.sendPushNotification(
      userIds: otherMemberIds,
      title: _currentUsername ?? 'New message',
      message: content,
      chatRoomId: _chatRoomId,
      chatRoomName: roomName,
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
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _privateChatsSubscription?.cancel();
    _privateChatsSubscription = null;
    messageController.dispose();
    scrollController.dispose();
    super.onDispose();
  }
}
