import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/viewmodels/base_view_model.dart';

class CreateChatRoomViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final StorageService _storageService = locator<StorageService>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _recentSearches = [];
  final List<Map<String, dynamic>> _selectedUsers = [];

  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  List<String> get recentSearches => _recentSearches;
  List<Map<String, dynamic>> get selectedUsers =>
      List.unmodifiable(_selectedUsers);

  bool get hasSearchResults =>
      _searchQuery.isNotEmpty && _searchResults.isNotEmpty;
  bool get hasNoResults =>
      _searchQuery.isNotEmpty && _searchResults.isEmpty && !busy;
  bool get hasRecentSearches =>
      _recentSearches.isNotEmpty && _searchQuery.isEmpty;

  @override
  void init() {
    super.init();
    loadRecentSearches();
  }

  Future<void> loadRecentSearches() async {
    try {
      _recentSearches = await _storageService.getRecentUserSearches();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading recent searches: $e');
      }
    }
  }

  void searchUsers(String query) {
    _searchQuery = query;
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performUserSearch(query);
    });
    notifyListeners();
  }

  Future<void> _performUserSearch(String query) async {
    if (isDisposed) return;

    setBusy(true);
    try {
      final currentUserId = _authService.userUid;

      final cachedResults = await _storageService.getCachedSearchResults(query);
      if (cachedResults != null && cachedResults.isNotEmpty) {
        _searchResults = cachedResults.where((user) {
          final userId = user['userId'] as String?;
          return userId != null && userId != currentUserId;
        }).toList();

        await _storageService.saveRecentUserSearch(query);
        await loadRecentSearches();
        notifyListeners();
        setBusy(false);
        return;
      }

      final results = await _firestoreService.searchUsersByName(query);
      if (isDisposed) return;

      _searchResults = results.where((user) {
        final userId = user['userId'] as String?;
        return userId != null && userId != currentUserId;
      }).toList();

      await _storageService.saveCachedSearchResults(query, _searchResults);
      await _storageService.saveRecentUserSearch(query);
      await loadRecentSearches();
      notifyListeners();
    } catch (e) {
      if (isDisposed) return;
      if (kDebugMode) {
        print('Error searching users: $e');
      }
      _searchResults = [];
      notifyListeners();
    } finally {
      if (!isDisposed) {
        setBusy(false);
      }
    }
  }

  void searchFromRecent(String query) {
    unfocusSearch();
    searchController.text = query;
    searchUsers(query);
  }

  void clearSearch() {
    _searchQuery = '';
    searchController.clear();
    _searchResults = [];
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    try {
      await _storageService.clearRecentUserSearches();
      _recentSearches = [];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing recent searches: $e');
      }
    }
  }

  void unfocusSearch() {
    if (isDisposed) return;
    try {
      searchFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) {
        print('Error unfocusing search: $e');
      }
    }
  }

  bool isUserSelected(String userId) {
    return _selectedUsers.any((u) => u['userId'] == userId);
  }

  void toggleUserSelection(Map<String, dynamic> user) {
    final userId = user['userId'] as String?;
    if (userId == null || userId.isEmpty) return;

    final idx = _selectedUsers.indexWhere((u) => u['userId'] == userId);
    if (idx >= 0) {
      _selectedUsers.removeAt(idx);
    } else {
      _selectedUsers.add(Map<String, dynamic>.from(user));
    }
    notifyListeners();
  }

  void removeSelectedUser(String userId) {
    _selectedUsers.removeWhere((u) => u['userId'] == userId);
    notifyListeners();
  }

  /// [festivalId] and [festivalTitle] - pass from view (FestivalProvider) to scope room to selected festival.
  Future<void> createChatRoom({String? festivalId, String? festivalTitle}) async {
    if (titleController.text.trim().isEmpty) {
      setError(AppStrings.pleaseEnterChatRoomTitle);
      return;
    }

    if (_selectedUsers.isEmpty) {
      setError(AppStrings.pleaseSelectAtLeastOneContact);
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      setError('User not authenticated');
      return;
    }

    final selectedMemberIds =
        _selectedUsers
            .map((u) => u['userId'] as String?)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();

    if (selectedMemberIds.isEmpty) {
      setError('Please select at least one member to add.');
      return;
    }

    await handleAsync(() async {
      final chatRoomName = titleController.text.trim();

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

      final chatRoomId = await _firestoreService.createPrivateChatRoom(
        chatRoomName: chatRoomName,
        creatorId: currentUser.uid,
        memberIds: selectedMemberIds,
        festivalId: festivalId,
        festivalTitle: festivalTitle,
      );

      if (kDebugMode) {
        print('✅ Created private chat room: $chatRoomId');
        print('   Name: $chatRoomName');
        print('   Members: ${selectedMemberIds.length}');
      }

      setError(null);
      _navigationService.pop();
    }, errorMessage: 'Failed to create chat room');
  }

  @override
  void onDispose() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    titleController.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    super.onDispose();
  }
}
