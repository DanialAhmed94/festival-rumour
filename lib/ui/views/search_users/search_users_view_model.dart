import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/router/app_router.dart';

class SearchUsersViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final NavigationService _navigationService = locator<NavigationService>();
  final StorageService _storageService = locator<StorageService>();
  
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _recentSearches = [];
  Timer? _searchDebounceTimer;
  final FocusNode searchFocusNode = FocusNode();
  final TextEditingController searchController = TextEditingController();
  
  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  List<String> get recentSearches => _recentSearches;
  bool get hasSearchResults => _searchQuery.isNotEmpty && _searchResults.isNotEmpty;
  bool get hasNoResults => _searchQuery.isNotEmpty && _searchResults.isEmpty && !busy;
  bool get hasRecentSearches => _recentSearches.isNotEmpty && _searchQuery.isEmpty;

  /// Load recent searches from storage
  Future<void> loadRecentSearches() async {
    try {
      _recentSearches = await _storageService.getRecentUserSearches();
      notifyListeners();
      
      if (kDebugMode) {
        print('📚 Loaded ${_recentSearches.length} recent searches');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading recent searches: $e');
      }
    }
  }

  /// Search users by name with debouncing
  void searchUsers(String query) {
    _searchQuery = query;
    
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    // Debounce search to avoid too many Firestore queries
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performUserSearch(query);
    });
    
    notifyListeners();
  }

  /// Perform search from recent search item
  void searchFromRecent(String query) {
    // Dismiss keyboard first
    unfocusSearch();
    
    searchController.text = query;
    searchUsers(query);
  }

  /// Perform the actual user search (cache-first strategy)
  Future<void> _performUserSearch(String query) async {
    if (isDisposed) return;
    
    setBusy(true);
    try {
      final currentUserId = _authService.userUid;
      
      // Step 1: Check cache first
      final cachedResults = await _storageService.getCachedSearchResults(query);
      
      if (cachedResults != null && cachedResults.isNotEmpty) {
        // Filter out current user from cached results
        _searchResults = cachedResults.where((user) {
          final userId = user['userId'] as String?;
          return userId != null && userId != currentUserId;
        }).toList();
        
        // Save to recent searches
        await _storageService.saveRecentUserSearch(query);
        await loadRecentSearches();
        
        notifyListeners();
        
        if (kDebugMode) {
          print('✅ Found ${_searchResults.length} users from cache for "$query"');
        }
        
        setBusy(false);
        return; // Return early, no need to hit Firebase
      }
      
      // Step 2: Cache miss - search Firebase
      if (kDebugMode) {
        print('🔍 Cache miss, searching Firebase for "$query"');
      }
      
      final results = await _firestoreService.searchUsersByName(query);
      if (isDisposed) return;
      
      // Filter out current user from results
      final filteredResults = results.where((user) {
        final userId = user['userId'] as String?;
        return userId != null && userId != currentUserId;
      }).toList();
      
      _searchResults = filteredResults;
      
      // Step 3: Cache the Firebase results for future use
      await _storageService.saveCachedSearchResults(query, filteredResults);
      
      // Save to recent searches
      await _storageService.saveRecentUserSearch(query);
      await loadRecentSearches();
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Found ${_searchResults.length} users from Firebase for "$query" (cached for future)');
      }
    } catch (e) {
      if (isDisposed) return;
      
      if (kDebugMode) {
        print('❌ Error searching users: $e');
      }
      _searchResults = [];
      notifyListeners();
    } finally {
      if (!isDisposed) {
        setBusy(false);
      }
    }
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    searchController.clear();
    _searchResults = [];
    notifyListeners();
  }

  /// Clear recent searches
  Future<void> clearRecentSearches() async {
    try {
      await _storageService.clearRecentUserSearches();
      _recentSearches = [];
      notifyListeners();
      
      if (kDebugMode) {
        print('🗑️ Cleared recent searches');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing recent searches: $e');
      }
    }
  }

  /// Unfocus search field
  void unfocusSearch() {
    if (isDisposed) return;
    
    try {
      searchFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) print('Error unfocusing search: $e');
    }
  }

  /// Navigate to a user's profile
  Future<void> navigateToUserProfile(BuildContext context, String userId) async {
    // Hide keyboard first - do this before clearing search
    unfocusSearch();
    FocusScope.of(context).unfocus();
    
    // Wait a bit to ensure keyboard is fully dismissed
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Clear search after keyboard is dismissed
    clearSearch();
    
    if (kDebugMode) {
      print('📱 Navigate to user profile: $userId');
    }
    
    // Navigate to view user profile screen (simplified view for other users)
    Navigator.pushNamed(
      context,
      AppRoutes.viewUserProfile,
      arguments: userId,
    );
  }

  @override
  void onDispose() {
    // Cancel search debounce timer
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    
    // Dispose search controllers
    searchFocusNode.dispose();
    searchController.dispose();
    
    super.onDispose();
  }
}
