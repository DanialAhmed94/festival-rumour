import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/locator.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/viewmodels/base_view_model.dart';
import '../../../../core/providers/festival_provider.dart';

/// ViewModel for ProfileListView that manages followers, following, and festivals.
class ProfileListViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = AuthService();

  // --- Private State ---
  int _currentTab = 0;
  bool _showingList = false;
  String? _userId; // User ID whose followers/following we're viewing
  String? _userDisplayName; // User's display name (fetched from Firestore)

  // Separate search queries per tab
  String _followersSearch = '';
  String _followingSearch = '';
  String _festivalsSearch = '';

  // Pagination state
  int? _followersLastIndex;
  int? _followingLastIndex;
  bool _hasMoreFollowers = true;
  bool _hasMoreFollowing = true;
  bool _isLoadingMoreFollowers = false;
  bool _isLoadingMoreFollowing = false;
  bool _isLoadingInitialFollowers = false; // Separate flag for initial load
  bool _isLoadingInitialFollowing = false; // Separate flag for initial load

  // --- Data Lists ---
  final List<Map<String, dynamic>> _allFollowers = [];
  final List<Map<String, dynamic>> _allFollowing = [];
  final List<Map<String, String>> _allFestivals = [];

  // --- Filtered Lists ---
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  List<Map<String, String>> _festivals = [];
  
  // Loading state for festivals
  bool _isLoadingFestivals = false;
  bool _hasLoadedFestivals = false; // Track if festivals have been loaded at least once
  bool get isLoadingFestivals => _isLoadingFestivals;
  bool get hasLoadedFestivals => _hasLoadedFestivals;

  // --- Getters ---
  int get currentTab => _currentTab;
  bool get showingList => _showingList;

  List<Map<String, dynamic>> get followers => _followers;
  List<Map<String, dynamic>> get following => _following;
  List<Map<String, String>> get festivals => _festivals;
  bool get hasMoreFollowers => _hasMoreFollowers;
  bool get hasMoreFollowing => _hasMoreFollowing;
  bool get isLoadingMoreFollowers => _isLoadingMoreFollowers;
  bool get isLoadingMoreFollowing => _isLoadingMoreFollowing;
  bool get isLoadingInitialFollowers => _isLoadingInitialFollowers;
  bool get isLoadingInitialFollowing => _isLoadingInitialFollowing;
  String? get userDisplayName => _userDisplayName;

  // --- Public Methods ---

  /// Change active tab and refresh UI
  void setTab(int tab) {
    if (_currentTab != tab) {
      _currentTab = tab;
      
      // Note: For festivals tab, we need context to access FestivalProvider
      // This will be handled in the view when the tab is selected
      if (_userId != null) {
        if (tab == 0 && _allFollowers.isEmpty && _followersLastIndex == null) {
          // Followers tab - load if not loaded
          loadFollowers();
        } else if (tab == 1 && _allFollowing.isEmpty && _followingLastIndex == null) {
          // Following tab - load if not loaded
          loadFollowing();
        }
        // Festivals tab loading will be handled in the view with context
      }
      
      _applySearchFilter();
      notifyListeners();
    }
  }

  void showProfileList() {
    _showingList = true;
    notifyListeners();
  }

  void closeProfileList() {
    _showingList = false;
    notifyListeners();
  }

  /// Initialize with userId
  void initialize(String? userId) {
    if (kDebugMode) {
      print('🔄 [ProfileListViewModel.initialize] Called');
      print('   userId parameter: $userId');
      print('   Current _userId: $_userId');
    }
    
    // If userId is null, try to get it from AuthService as fallback
    String? finalUserId = userId;
    if (finalUserId == null) {
      finalUserId = _authService.userUid ?? _authService.currentUser?.uid;
      if (kDebugMode) {
        print('⚠️ [ProfileListViewModel.initialize] userId was null, trying fallback');
        print('   _authService.userUid: ${_authService.userUid}');
        print('   _authService.currentUser?.uid: ${_authService.currentUser?.uid}');
        print('   finalUserId after fallback: $finalUserId');
      }
    }
    
    _userId = finalUserId;
    _followersLastIndex = null;
    _followingLastIndex = null;
    _hasMoreFollowers = true;
    _hasMoreFollowing = true;
    _allFollowers.clear();
    _allFollowing.clear();
    _followers.clear();
    _following.clear();
    _followersSearch = '';
    _followingSearch = '';
    _hasLoadedFestivals = false; // Reset festivals loading flag
    _allFestivals.clear();
    _festivals = [];
    
    // Load initial data
    if (_userId != null) {
      if (kDebugMode) {
        print('📥 [ProfileListViewModel.initialize] Loading followers and following for userId: $_userId');
      }
      // Load data asynchronously
      loadFollowers();
      loadFollowing();
      // Festivals will be loaded when tab is selected (needs context for FestivalProvider)
    } else {
      if (kDebugMode) {
        print('❌ [ProfileListViewModel.initialize] userId is still null after fallback, cannot load followers/following');
      }
    }
    
    _festivals = List.from(_allFestivals);
    notifyListeners();
  }

  /// Load followers from Firebase with pagination
  Future<void> loadFollowers({bool loadMore = false}) async {
    if (_userId == null) {
      if (kDebugMode) {
        print('⚠️ Cannot load followers: userId is null');
      }
      return;
    }
    
    // Only skip if we're not loading more AND data is already loaded AND we're not refreshing
    if (!loadMore && _allFollowers.isNotEmpty && _followersLastIndex != null) {
      if (kDebugMode) {
        print('ℹ️ Followers already loaded, skipping...');
      }
      return;
    }
    
    if (loadMore && (!_hasMoreFollowers || _isLoadingMoreFollowers)) {
      if (kDebugMode) {
        print('ℹ️ Cannot load more followers: hasMore=$_hasMoreFollowers, isLoading=$_isLoadingMoreFollowers');
      }
      return;
    }

    _isLoadingMoreFollowers = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('🔄 Loading followers for userId: $_userId (loadMore: $loadMore, lastIndex: $_followersLastIndex)');
      }
      
      final result = await _firestoreService.getFollowersPaginated(
        _userId!,
        limit: 20,
        lastIndex: loadMore ? _followersLastIndex : null,
      );

      final followers = (result['followers'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];

      if (loadMore) {
        _allFollowers.addAll(followers);
      } else {
        _allFollowers.clear();
        _allFollowers.addAll(followers);
      }

      _followersLastIndex = result['nextIndex'] as int?;
      _hasMoreFollowers = result['hasMore'] as bool? ?? false;

      // Apply search filter
      _applySearchFilter();

      if (kDebugMode) {
        print('✅ Loaded ${followers.length} followers (total: ${_allFollowers.length}, hasMore: $_hasMoreFollowers)');
        if (followers.isNotEmpty) {
          print('   Sample follower: ${followers.first}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('⚠️ Error loading followers: $e');
        print('   Stack trace: $stackTrace');
      }
    } finally {
      if (loadMore) {
        _isLoadingMoreFollowers = false;
      } else {
        _isLoadingInitialFollowers = false;
      }
      notifyListeners();
    }
  }

  /// Load following from Firebase with pagination
  Future<void> loadFollowing({bool loadMore = false}) async {
    if (_userId == null) {
      if (kDebugMode) {
        print('⚠️ Cannot load following: userId is null');
      }
      return;
    }
    
    // Only skip if we're not loading more AND data is already loaded AND we're not refreshing
    if (!loadMore && _allFollowing.isNotEmpty && _followingLastIndex != null) {
      if (kDebugMode) {
        print('ℹ️ Following already loaded, skipping...');
      }
      return;
    }
    
    if (loadMore && (!_hasMoreFollowing || _isLoadingMoreFollowing)) {
      if (kDebugMode) {
        print('ℹ️ Cannot load more following: hasMore=$_hasMoreFollowing, isLoading=$_isLoadingMoreFollowing');
      }
      return;
    }

    if (loadMore) {
      _isLoadingMoreFollowing = true;
    } else {
      _isLoadingInitialFollowing = true;
    }
    notifyListeners();

    try {
      if (kDebugMode) {
        print('🔄 [loadFollowing] Starting to load following for userId: $_userId');
        print('   loadMore: $loadMore');
        print('   lastIndex: ${loadMore ? _followingLastIndex : null}');
      }
      
      final result = await _firestoreService.getFollowingPaginated(
        _userId!,
        limit: 20,
        lastIndex: loadMore ? _followingLastIndex : null,
      );

      if (kDebugMode) {
        print('📦 [loadFollowing] Received result from FirestoreService:');
        print('   result keys: ${result.keys}');
        print('   result[following] type: ${result['following'].runtimeType}');
        print('   result[following] length: ${(result['following'] as List?)?.length ?? 'null'}');
        print('   result[nextIndex]: ${result['nextIndex']}');
        print('   result[hasMore]: ${result['hasMore']}');
      }

      final following = (result['following'] as List<dynamic>?)
          ?.map((e) {
            if (kDebugMode) {
              print('   Mapping item: $e (type: ${e.runtimeType})');
            }
            return e as Map<String, dynamic>;
          })
          .toList() ?? [];

      if (kDebugMode) {
        print('📋 [loadFollowing] Processed following list:');
        print('   following.length: ${following.length}');
        if (following.isNotEmpty) {
          print('   First following item: ${following.first}');
          print('   First following keys: ${following.first.keys}');
        }
      }

      if (loadMore) {
        _allFollowing.addAll(following);
        if (kDebugMode) {
          print('➕ [loadFollowing] Added to existing list. New total: ${_allFollowing.length}');
        }
      } else {
        _allFollowing.clear();
        _allFollowing.addAll(following);
        if (kDebugMode) {
          print('🔄 [loadFollowing] Replaced list. New total: ${_allFollowing.length}');
        }
      }

      _followingLastIndex = result['nextIndex'] as int?;
      _hasMoreFollowing = result['hasMore'] as bool? ?? false;

      if (kDebugMode) {
        print('📊 [loadFollowing] Updated pagination state:');
        print('   _followingLastIndex: $_followingLastIndex');
        print('   _hasMoreFollowing: $_hasMoreFollowing');
        print('   _allFollowing.length: ${_allFollowing.length}');
      }

      // Apply search filter
      _applySearchFilter();

      if (kDebugMode) {
        print('✅ [loadFollowing] Successfully loaded ${following.length} following');
        print('   Total in _allFollowing: ${_allFollowing.length}');
        print('   Total in _following (filtered): ${_following.length}');
        if (following.isNotEmpty) {
          print('   Sample following: ${following.first}');
        }
        if (_following.isNotEmpty) {
          print('   Sample filtered following: ${_following.first}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [loadFollowing] Error loading following: $e');
        print('   Stack trace: $stackTrace');
      }
    } finally {
      if (loadMore) {
        _isLoadingMoreFollowing = false;
      } else {
        _isLoadingInitialFollowing = false;
      }
      notifyListeners();
      if (kDebugMode) {
        print('🏁 [loadFollowing] Finished loading. _isLoadingMoreFollowing: ${loadMore ? false : "N/A"}, _isLoadingInitialFollowing: ${!loadMore ? false : "N/A"}');
      }
    }
  }

  /// Load favorite festivals with festival names from FestivalProvider
  /// This method should be called with BuildContext to access FestivalProvider
  Future<void> loadFavoriteFestivals(BuildContext context) async {
    if (_userId == null) {
      if (kDebugMode) {
        print('⚠️ Cannot load favorite festivals: userId is null');
      }
      return;
    }
    
    if (_isLoadingFestivals) {
      if (kDebugMode) {
        print('ℹ️ Already loading favorite festivals, skipping...');
      }
      return;
    }
    
    _isLoadingFestivals = true;
    notifyListeners();
    
    try {
      if (kDebugMode) {
        print('🔄 Loading favorite festivals with names for userId: $_userId');
      }
      
      // Get favorite festival IDs from Firebase
      final favoriteIds = await _firestoreService.getFavoriteFestivalIds(_userId!);
      
      if (kDebugMode) {
        print('📋 Found ${favoriteIds.length} favorite festival IDs: $favoriteIds');
      }
      
      // Clear existing festivals
      _allFestivals.clear();
      
      if (favoriteIds.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ No favorite festivals found');
        }
        _festivals = [];
        _applySearchFilter();
        _isLoadingFestivals = false;
        notifyListeners();
        return;
      }
      
      // Get FestivalProvider to access festival data
      final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
      
      // Map favorite IDs to festival names
      final favoriteFestivals = <Map<String, String>>[];
      for (final id in favoriteIds) {
        final festival = festivalProvider.getFestivalById(id);
        if (festival != null) {
          favoriteFestivals.add({
            'title': festival.title,
            'location': festival.location,
          });
          if (kDebugMode) {
            print('✅ Found festival: ${festival.title} (ID: $id)');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Festival with ID $id not found in FestivalProvider');
          }
        }
      }
      
      _allFestivals.clear();
      _allFestivals.addAll(favoriteFestivals);
      
      if (kDebugMode) {
        print('✅ Loaded ${_allFestivals.length} favorite festivals into _allFestivals');
        print('   _festivalsSearch before filter: "$_festivalsSearch"');
      }
      
      // Apply search filter (this will show all if search is empty)
      _applySearchFilter();
      
      if (kDebugMode) {
        print('✅ After filter: ${_festivals.length} festivals in _festivals (from ${_allFestivals.length} total)');
      }
      
      _isLoadingFestivals = false;
      _hasLoadedFestivals = true; // Mark as loaded
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error loading favorite festivals: $e');
        print('   Stack trace: $stackTrace');
      }
      _isLoadingFestivals = false;
      _hasLoadedFestivals = true; // Mark as loaded even on error to prevent infinite retries
      notifyListeners();
    }
  }

  /// Refresh all lists
  void refreshList(BuildContext context) {
    if (_userId != null) {
      _followersLastIndex = null;
      _followingLastIndex = null;
      _hasMoreFollowers = true;
      _hasMoreFollowing = true;
      _allFollowers.clear();
      _allFollowing.clear();
      loadFollowers();
      loadFollowing();
    }
    // Reset festivals loading state and reload
    _hasLoadedFestivals = false;
    _allFestivals.clear();
    _festivals = [];
    // Reload festivals if on festivals tab
    if (_currentTab == 2) {
      loadFavoriteFestivals(context);
    }
    notifyListeners();
  }

  /// Search only followers
  void searchFollowers(String query) {
    _followersSearch = query.toLowerCase();
    _followers = _allFollowers
        .where((item) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          final username = (item['username'] as String? ?? '').toLowerCase();
          return name.contains(_followersSearch) || username.contains(_followersSearch);
        })
        .toList();
    notifyListeners();
  }

  /// Search only following
  void searchFollowing(String query) {
    if (kDebugMode) {
      print('🔍 [searchFollowing] Called with query: "$query"');
      print('   _allFollowing.length: ${_allFollowing.length}');
    }
    
    _followingSearch = query.toLowerCase();
    if (_followingSearch.isEmpty) {
      // No search query - show all following
      _following = List.from(_allFollowing);
      if (kDebugMode) {
        print('   No search query - showing all ${_following.length} following');
      }
    } else {
      // Filter following based on search query
      _following = _allFollowing
          .where((item) {
            final name = (item['name'] as String? ?? '').toLowerCase();
            final username = (item['username'] as String? ?? '').toLowerCase();
            final matches = name.contains(_followingSearch) || username.contains(_followingSearch);
            if (kDebugMode && _allFollowing.length <= 5) {
              print('   Item: name="$name", username="$username", matches=$matches');
            }
            return matches;
          })
          .toList();
      if (kDebugMode) {
        print('   Filtered to ${_following.length} following');
      }
    }
    notifyListeners();
  }

  /// Search only festivals
  void searchFestivals(String query) {
    _festivalsSearch = query.toLowerCase();
    if (_festivalsSearch.isEmpty) {
      // No search query - show all festivals
      _festivals = List.from(_allFestivals);
    } else {
      // Filter festivals based on search query
      _festivals = _allFestivals
          .where((item) =>
              item['title']!.toLowerCase().contains(_festivalsSearch) ||
              item['location']!.toLowerCase().contains(_festivalsSearch))
          .toList();
    }
    notifyListeners();
  }

  /// Unfollow user
  Future<void> unfollowUser(Map<String, dynamic> user) async {
    final userId = user['userId'] as String?;
    if (userId == null) return;

    try {
      final currentUserId = _authService.userUid;
      if (currentUserId == null) return;

      await _firestoreService.unfollowUser(currentUserId, userId);
      
      // Remove from local lists
      _following.removeWhere((item) => item['userId'] == userId);
      _allFollowing.removeWhere((item) => item['userId'] == userId);
      _applySearchFilter();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error unfollowing user: $e');
      }
    }
  }

  /// Remove follower
  Future<void> removeFollower(Map<String, dynamic> follower) async {
    final userId = follower['userId'] as String?;
    if (userId == null) return;

    try {
      final currentUserId = _authService.userUid;
      if (currentUserId == null) return;

      await _firestoreService.unfollowUser(userId, currentUserId);
      
      // Remove from local lists
      _followers.removeWhere((item) => item['userId'] == userId);
      _allFollowers.removeWhere((item) => item['userId'] == userId);
      _applySearchFilter();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error removing follower: $e');
      }
    }
  }

  /// Return current list based on active tab
  List<Map<String, dynamic>> getCurrentList() {
    switch (_currentTab) {
      case 0:
        return _followers;
      case 1:
        return _following;
      case 2:
        return _festivals.map((e) => e as Map<String, dynamic>).toList();
      default:
        return _followers;
    }
  }

  /// Load user's display name from Firestore
  Future<void> _loadUserDisplayName() async {
    if (_userId == null) return;
    
    try {
      final userData = await _firestoreService.getUserData(_userId!);
      _userDisplayName = userData?['displayName'] as String?;
      
      // Fallback to Firebase Auth displayName if Firestore doesn't have it
      if (_userDisplayName == null || _userDisplayName!.isEmpty) {
        _userDisplayName = _authService.currentUser?.displayName;
      }
      
      if (kDebugMode) {
        print('📝 [ProfileListViewModel._loadUserDisplayName] Loaded display name: $_userDisplayName');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [ProfileListViewModel._loadUserDisplayName] Error loading display name: $e');
      }
      // Fallback to Firebase Auth displayName on error
      _userDisplayName = _authService.currentUser?.displayName;
      notifyListeners();
    }
  }

  // --- Private Helpers ---
  void _applySearchFilter() {
    if (kDebugMode) {
      print('🔍 [_applySearchFilter] Called');
      print('   _allFollowing.length: ${_allFollowing.length}');
      print('   _allFollowers.length: ${_allFollowers.length}');
      print('   _followingSearch: "$_followingSearch"');
      print('   _followersSearch: "$_followersSearch"');
    }
    
    // Always apply filters - the search methods handle empty queries
    searchFollowers(_followersSearch);
    searchFollowing(_followingSearch);
    searchFestivals(_festivalsSearch);
    
    if (kDebugMode) {
      print('   After filter:');
      print('   _following.length: ${_following.length}');
      print('   _followers.length: ${_followers.length}');
    }
  }

  @override
  void init() {
    super.init();
    _showingList = true;
    // Don't call refreshList here - wait for initialize() to be called with userId
  }
}
