import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';

class CreateChatRoomViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final TextEditingController titleController = TextEditingController();

  List<Contact> _allContacts = [];
  List<Contact> _festivalContacts = [];
  List<Contact> _nonFestivalContacts = [];
  Set<String> _selectedContacts = {};

  // Contact data for UI
  List<Map<String, dynamic>> _festivalContactData = [];
  List<Map<String, dynamic>> _nonFestivalContactData = [];

  // Map to store contact phone -> userId mapping
  Map<String, String> _phoneToUserIdMap = {};

  // Mock contacts for fallback/demo mode
  final List<Map<String, dynamic>> _mockContacts = [
    {
      'name': AppStrings.robertFox,
      'phone': AppStrings.phone0123456789,
      'isFestival': true,
    },
  ];

  List<Contact> get allContacts => _allContacts;
  List<Contact> get festivalContacts => _festivalContacts;
  List<Contact> get nonFestivalContacts => _nonFestivalContacts;
  Set<String> get selectedContacts => _selectedContacts;

  List<Map<String, dynamic>> get festivalContactData => _festivalContactData;
  List<Map<String, dynamic>> get nonFestivalContactData =>
      _nonFestivalContactData;

  @override
  void init() {
    super.init();
    _loadContacts();
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  /// Load contacts from device or create mock contacts if unavailable
  Future<void> _loadContacts() async {
    await handleAsync(() async {
      // Check permission status first (especially important for Android)
      PermissionStatus permissionStatus = await Permission.contacts.status;
      
      // If not granted, request permission
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.contacts.request();
      }
      
      // Check if permission is permanently denied
      if (permissionStatus.isPermanentlyDenied) {
        setError(
          'Contacts permission is permanently denied. Please enable it in app settings.',
        );
        return;
      }
      
      // If still not granted after request, show error
      if (!permissionStatus.isGranted) {
        setError(AppStrings.contactsPermissionDenied);
        return;
      }

      // Now use FlutterContacts to get contacts (permission is granted)
      try {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: true,
        );

        if (contacts.isNotEmpty) {
          _allContacts = contacts;
          if (kDebugMode) {
            print("📇 Loaded ${contacts.length} contacts");
          }
        } else {
          _createMockContacts();
        }
      } catch (e) {
        // If getting contacts fails even with permission, it might be an Android issue
        if (kDebugMode) {
          print('❌ Error getting contacts: $e');
        }
        // Try to create mock contacts as fallback
        _createMockContacts();
      }

      _filterContacts();
      
      // Update UI immediately with contacts (before matching)
      _updateContactDataWithUserInfo();
      notifyListeners();
      
      // Match contacts asynchronously (non-blocking)
      // This allows UI to show contacts immediately while matching happens in background
      _matchContactsWithUsers();
    }, errorMessage: AppStrings.failedToLoadContacts);
  }

  /// Match contacts with users in Firestore by phone number
  /// This runs asynchronously and doesn't block the UI
  Future<void> _matchContactsWithUsers() async {
    try {
      // Collect all phone numbers from contacts
      final phoneNumbers = <String>[];
      for (final contact in _allContacts) {
        if (contact.phones.isNotEmpty) {
          phoneNumbers.add(contact.phones.first.number);
        }
      }

      if (phoneNumbers.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No phone numbers found in contacts');
        }
        // Still update contact data even if no phone numbers
        _updateContactDataWithUserInfo();
        notifyListeners();
        return;
      }

      // Show initial contact data (without matching) so UI isn't blocked
      _updateContactDataWithUserInfo();
      notifyListeners();

      // Get users by phone numbers from Firestore (non-blocking, runs in background)
      // Use optimized version with parallel queries and pagination
      _phoneToUserIdMap = await _firestoreService.getUsersByPhoneNumbers(
        phoneNumbers,
        useCache: true,
        maxConcurrentQueries: 5, // Process 5 batches in parallel
        pageSize: 100, // Fetch 100 users per page
      );

      // Update contact data with matching results
      _updateContactDataWithUserInfo();
      notifyListeners();

      if (kDebugMode) {
        print('✅ Matched ${_phoneToUserIdMap.length} contacts with app users');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error matching contacts with users: $e');
      }
      // Still update contact data even on error
      _updateContactDataWithUserInfo();
      notifyListeners();
    }
  }

  /// Update contact data to include user info
  void _updateContactDataWithUserInfo() {
    // Rebuild contact data with user matching info
    _festivalContactData.clear();
    _nonFestivalContactData.clear();

    for (final contact in _allContacts) {
      final displayName = contact.displayName ?? '';
      final phoneNumber =
          contact.phones.isNotEmpty ? contact.phones.first.number : '';

      // The _phoneToUserIdMap uses original phone numbers as keys
      // So we can directly look up using the original phone number
      final userId = _phoneToUserIdMap[phoneNumber];

      final contactData = {
        'id': contact.id,
        'name': displayName,
        'phone': phoneNumber,
        'isFestival':
            userId != null, // Mark as festival user if found in Firestore
        'userId': userId, // Store userId if matched
      };

      if (userId != null) {
        // User is in the app - add to festival contacts
        _festivalContactData.add(contactData);
      } else {
        // User is not in the app - add to non-festival contacts
        _nonFestivalContactData.add(contactData);
      }
    }

    if (kDebugMode) {
      print('📱 Festival Contacts (app users): ${_festivalContactData.length}');
      print(
        '📱 Non-Festival Contacts (not in app): ${_nonFestivalContactData.length}',
      );
    }
  }

  /// Create mock contacts if no real contacts available
  void _createMockContacts() {
    _allContacts.clear();

    for (final mockContact in _mockContacts) {
      final contact = Contact(
        id: mockContact['name'].hashCode.toString(),
        displayName: mockContact['name'],
        phones: [Phone(mockContact['phone'])],
      );
      _allContacts.add(contact);
    }
  }

  /// Separate festival and non-festival contacts
  /// This is now called before matching with users
  void _filterContacts() {
    _festivalContacts.clear();
    _nonFestivalContacts.clear();
    // Note: Contact data will be updated in _updateContactDataWithUserInfo after matching
  }

  void toggleContactSelection(String contactId) {
    if (_selectedContacts.contains(contactId)) {
      _selectedContacts.remove(contactId);
    } else {
      _selectedContacts.add(contactId);
    }
    notifyListeners();
  }

  bool isContactSelected(String contactId) {
    return _selectedContacts.contains(contactId);
  }

  Future<void> createChatRoom() async {
    if (titleController.text.trim().isEmpty) {
      setError(AppStrings.pleaseEnterChatRoomTitle);
      return;
    }

    if (_selectedContacts.isEmpty) {
      setError(AppStrings.pleaseSelectAtLeastOneContact);
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      setError('User not authenticated');
      return;
    }

    await handleAsync(() async {
      final chatRoomName = titleController.text.trim();

      // Check if a private chat room with the same name already exists
      final nameExists = await _firestoreService.privateChatRoomNameExists(
        chatRoomName,
        currentUser.uid,
      );

      if (nameExists) {
        setError(
          'A private chat room with this name already exists. Please choose a different name.',
        );
        return;
      }

      // Get selected contact IDs and find their user IDs
      final selectedMemberIds = <String>[];

      for (final contactId in _selectedContacts) {
        // Find contact data
        final contactData = _festivalContactData.firstWhere(
          (data) => data['id'] == contactId,
          orElse: () => {},
        );

        final userId = contactData['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          selectedMemberIds.add(userId);
        }
      }

      if (selectedMemberIds.isEmpty) {
        setError(
          'No app users selected. Please select contacts who are using the app.',
        );
        return;
      }

      // Create private chat room in Firestore
      final chatRoomId = await _firestoreService.createPrivateChatRoom(
        chatRoomName: chatRoomName,
        creatorId: currentUser.uid,
        memberIds: selectedMemberIds,
      );

      if (kDebugMode) {
        print('✅ Created private chat room: $chatRoomId');
        print('   Name: ${titleController.text.trim()}');
        print('   Members: ${selectedMemberIds.length}');
      }

      setError(null);

      // Navigate back to chat room list
      _navigationService.pop();
    }, errorMessage: 'Failed to create chat room');
  }

  void refreshContacts() {
    _loadContacts();
  }

  void inviteContact(String contactName, String phoneNumber) async {
    try {
      final inviteMessage = '''
Hey $contactName 👋,

I'm using Festival Rumour to chat and connect during festivals! 🎉  
Join me here 👉 [https://festivalrumour.com]

''';

      await Share.share(inviteMessage, subject: 'Join me on LunaFest 🎊');

      print('✅ Invite sent to $contactName');
      setError(null);
    } catch (e) {
      print('❌ Error sharing invite: $e');
      setError('Failed to send invite');
    }
  }
}
