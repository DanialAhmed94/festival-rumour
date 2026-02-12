import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';

class AddChatMembersViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();

  String? _chatRoomId;
  List<String> _currentMemberIds = [];
  List<Contact> _allContacts = [];
  Set<String> _selectedContacts = {};
  List<Map<String, dynamic>> _festivalContactData = [];
  List<Map<String, dynamic>> _nonFestivalContactData = [];
  Map<String, String> _phoneToUserIdMap = {};

  String? get chatRoomId => _chatRoomId;
  Set<String> get selectedContacts => _selectedContacts;

  /// Contacts that are app users and not already in the room (for add button validation)
  List<Map<String, dynamic>> get eligibleContactData {
    return _festivalContactData
        .where((c) {
          final uid = c['userId'] as String?;
          return uid != null && !_currentMemberIds.contains(uid);
        })
        .toList();
  }

  /// All app-user contacts with flag: show in list; already-in-room are not selectable
  List<Map<String, dynamic>> get allContactsForDisplay {
    return _festivalContactData.map((c) {
      final uid = c['userId'] as String?;
      final isAlreadyInRoom = uid != null && _currentMemberIds.contains(uid);
      return Map<String, dynamic>.from(c)..['isAlreadyInRoom'] = isAlreadyInRoom;
    }).toList();
  }

  bool isAlreadyInRoom(Map<String, dynamic> contactData) {
    final uid = contactData['userId'] as String?;
    return uid != null && _currentMemberIds.contains(uid);
  }

  /// Contacts not registered in the app (show with Invite button)
  List<Map<String, dynamic>> get nonFestivalContactData => _nonFestivalContactData;

  void setArgs({required String chatRoomId, required List<String> currentMemberIds}) {
    _chatRoomId = chatRoomId;
    _currentMemberIds = List.from(currentMemberIds);
    notifyListeners();
  }

  @override
  void init() {
    super.init();
    if (Platform.isIOS) {
      _loadContactsiOS();
    } else {
      _loadContacts();
    }
  }

  Future<void> _loadContactsiOS() async {
    await handleAsync(() async {
      final granted = await FlutterContacts.requestPermission();
      if (!granted) {
        setError(AppStrings.contactsPermissionDenied);
        return;
      }
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      if (contacts.isNotEmpty) {
        _allContacts = contacts;
      }
      _updateContactDataWithUserInfo();
      await _matchContactsWithUsers();
      notifyListeners();
    }, errorMessage: AppStrings.failedToLoadContacts);
  }

  Future<void> _loadContacts() async {
    await handleAsync(() async {
      var permissionStatus = await Permission.contacts.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.contacts.request();
      }
      if (permissionStatus.isPermanentlyDenied) {
        setError('Contacts permission is permanently denied.');
        return;
      }
      if (!permissionStatus.isGranted) {
        setError(AppStrings.contactsPermissionDenied);
        return;
      }
      try {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: true,
        );
        if (contacts.isNotEmpty) _allContacts = contacts;
      } catch (e) {
        if (kDebugMode) print('Error getting contacts: $e');
      }
      _updateContactDataWithUserInfo();
      notifyListeners();
      _matchContactsWithUsers();
    }, errorMessage: AppStrings.failedToLoadContacts);
  }

  Future<void> _matchContactsWithUsers() async {
    try {
      final phoneNumbers = _allContacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => c.phones.first.number)
          .toList();
      if (phoneNumbers.isEmpty) {
        _updateContactDataWithUserInfo();
        notifyListeners();
        return;
      }
      _phoneToUserIdMap = await _firestoreService.getUsersByPhoneNumbers(
        phoneNumbers,
        useCache: true,
        maxConcurrentQueries: 5,
        pageSize: 100,
      );
      _updateContactDataWithUserInfo();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error matching contacts: $e');
      _updateContactDataWithUserInfo();
      notifyListeners();
    }
  }

  void _updateContactDataWithUserInfo() {
    _festivalContactData.clear();
    _nonFestivalContactData.clear();
    for (final contact in _allContacts) {
      final displayName = contact.displayName ?? '';
      final phoneNumber =
          contact.phones.isNotEmpty ? contact.phones.first.number : '';
      final userId = _phoneToUserIdMap[phoneNumber];
      final contactData = {
        'id': contact.id,
        'name': displayName,
        'phone': phoneNumber,
        'userId': userId,
      };
      if (userId != null) {
        _festivalContactData.add(contactData);
      } else {
        _nonFestivalContactData.add(contactData);
      }
    }
  }

  void inviteContact(String contactName, String phoneNumber) {
    try {
      final inviteMessage = '''
Hey $contactName 👋,

I'm using Festival Rumour to chat and connect during festivals! 🎉  
Join me here 👉 [https://festivalrumour.com]

''';
      Share.share(inviteMessage, subject: 'Join me on LunaFest 🎊');
      setError(null);
    } catch (e) {
      if (kDebugMode) print('Error sharing invite: $e');
      setError('Failed to send invite');
    }
  }

  void toggleContactSelection(String contactId) {
    final contactData = _festivalContactData.firstWhere(
      (data) => data['id'] == contactId,
      orElse: () => <String, dynamic>{},
    );
    final userId = contactData['userId'] as String?;
    if (userId != null && _currentMemberIds.contains(userId)) {
      return; // Already in room - do not allow selection
    }
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

  Future<void> addMembersToRoom() async {
    if (_chatRoomId == null || _chatRoomId!.isEmpty) {
      setError('Chat room not set');
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

    final newMemberIds = <String>[];
    for (final contactId in _selectedContacts) {
      final contactData = _festivalContactData.firstWhere(
            (data) => data['id'] == contactId,
            orElse: () => <String, dynamic>{},
          );
      final userId = contactData['userId'] as String?;
      if (userId != null && userId.isNotEmpty && !_currentMemberIds.contains(userId)) {
        newMemberIds.add(userId);
      }
    }

    if (newMemberIds.isEmpty) {
      setError('No valid members to add.');
      return;
    }

    await handleAsync(() async {
      final success = await _firestoreService.addMembersToPrivateChatRoom(
        chatRoomId: _chatRoomId!,
        requesterId: currentUser.uid,
        newMemberIds: newMemberIds,
      );
      if (success) {
        setError(null);
        _navigationService.pop(true);
      } else {
        setError('Only the room creator can add members.');
      }
    }, errorMessage: 'Failed to add members');
  }
}
