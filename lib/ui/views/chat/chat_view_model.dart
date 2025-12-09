import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/festival_provider.dart';
import 'chat_message_model.dart';

class ChatViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  
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

  void setSelectedTab(int tab) {
    _selectedTab = tab;
    // Load private chat rooms when switching to private tab
    if (tab == 1) {
      loadPrivateChatRooms();
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

  List<Map<String, dynamic>> get privateChats => _privateChats;

  /// Check if the current user is the creator of a chat room
  bool isChatRoomCreatedByUser(Map<String, dynamic> chat) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return false;
    
    final createdBy = chat['createdBy'] as String?;
    return createdBy != null && createdBy == currentUser.uid;
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
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting chat room: $e');
      }
      return false;
    }
  }

  /// Load private chat rooms from Firestore
  void loadPrivateChatRooms() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ User not authenticated, cannot load private chat rooms');
      }
      return;
    }

    // Cancel existing subscription
    _privateChatsSubscription?.cancel();
    _privateChatsSubscription = null;

    _privateChatsSubscription = _firestoreService
        .getPrivateChatRoomsForUser(currentUser.uid)
        .listen(
          (chatRoomsData) {
            if (isDisposed) return;

            // Convert to UI format
            _privateChats = chatRoomsData.map((roomData) {
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

              return {
                'name': roomData['name'] as String? ?? 'Chat Room',
                'chatRoomId': roomData['chatRoomId'] as String?,
                'lastMessage': roomData['lastMessage'] as String? ?? '',
                'timestamp': timestamp,
                'unreadCount': 0, // TODO: Implement unread count
                'isActive': true,
                'members': roomData['members'] as List<dynamic>? ?? [],
                'createdBy': roomData['createdBy'] as String?,
              };
            }).toList();

            notifyListeners();

            if (kDebugMode) {
              print('✅ Loaded ${_privateChats.length} private chat rooms');
            }
          },
          onError: (error, stackTrace) {
            if (kDebugMode) {
              print('Error in private chat rooms stream: $error');
            }
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
    notifyListeners();

    // Cancel any existing subscription before starting a new one
    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _chatRoomId = chatRoomId;
    
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
        _currentUserPhotoUrl = userData['photoUrl'] as String? ?? 
                              currentUser.photoURL;
      } else {
        // Fallback to Firebase Auth data
        _currentUsername = currentUser.displayName ?? 'User';
        _currentUserPhotoUrl = currentUser.photoURL;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user info: $e');
      }
      // Fallback to Firebase Auth data
      final currentUser = _authService.currentUser;
      _currentUsername = currentUser?.displayName ?? 'User';
      _currentUserPhotoUrl = currentUser?.photoURL;
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
                // Create a mock DocumentSnapshot for fromFirestore
                final message = ChatMessageModel(
                  messageId: messageData['messageId'] as String?,
                  userId: messageData['userId'] as String? ?? '',
                  username: messageData['username'] as String? ?? 'Unknown',
                  content: messageData['content'] as String? ?? '',
                  createdAt: (messageData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  userPhotoUrl: messageData['userPhotoUrl'] as String?,
                  chatRoomId: messageData['chatRoomId'] as String? ?? _chatRoomId ?? '',
                );
                newMessages.add(message);
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing message: $e');
                }
              }
            }

            _messages = newMessages;
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
          },
        );
  }

  void enterChatRoom(Map<String, dynamic> room) {
    _currentChatRoom = room;
    _isInChatRoom = true;
    notifyListeners();
  }

  void exitChatRoom() {
    _isInChatRoom = false;
    _currentChatRoom = null;
    _chatRoomId = null;
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

  /// Send a message to the chat room
  Future<void> sendMessage() async {
    if (messageController.text.trim().isEmpty || _chatRoomId == null) {
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ User not authenticated, cannot send message');
      }
      return;
    }

    final content = messageController.text.trim();
    messageController.clear();
    notifyListeners();

    try {
      await _firestoreService.sendChatMessage(
        chatRoomId: _chatRoomId!,
        userId: currentUser.uid,
        username: _currentUsername ?? 'User',
        content: content,
        userPhotoUrl: _currentUserPhotoUrl,
      );

      if (kDebugMode) {
        print('✅ Message sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending message: $e');
      }
      // Restore message text on error
      messageController.text = content;
      notifyListeners();
    }
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
