
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/post_data_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/router/app_router.dart';

class ProfileViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final NetworkService _networkService = locator<NetworkService>();
  final PostDataService _postDataService = locator<PostDataService>();

  // Profile content tabs: 0 = Posts, 1 = Reels, 2 = Reposts
  int _selectedTab = 0;
  
  // Profile list tabs: 0 = Followers, 1 = Following, 2 = Festivals
  int currentTab = 0;

  // In-profile subview state to keep navbar visible
  bool showingList = false;
  int listInitialTab = 0;

  // User data
  int _postCount = 0;
  String? _userBio;
  String? _userDisplayName;
  String? _userPhotoUrl;
  List<String> _userImages = [];
  List<String> _userVideos = [];
  List<Map<String, dynamic>> _imagePostInfos = []; // Lightweight post info for images
  List<Map<String, dynamic>> _videoPostInfos = []; // Lightweight post info for videos
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool _isRefreshingProfile = false; // Prevent multiple simultaneous refreshes
  bool _hasRefreshedProfile = false; // Track if we've already refreshed in this lifecycle
  
  // Follow state
  bool _isFollowing = false;
  bool _isLoadingFollowStatus = false;
  bool _hasLoadedFollowStatus = false;
  int _followersCount = 0;
  int _followingCount = 0;
  
  // Favorite festivals state
  int _favoriteFestivalsCount = 0;
  StreamSubscription<DocumentSnapshot>? _favoriteFestivalsSubscription;
  
  // User search functionality
  String _userSearchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchActive = false;
  Timer? _searchDebounceTimer;
  final FocusNode userSearchFocusNode = FocusNode();
  final TextEditingController userSearchController = TextEditingController();
  
  String get userSearchQuery => _userSearchQuery;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isSearchActive => _isSearchActive;
  bool get hasSearchResults => _userSearchQuery.isNotEmpty && _searchResults.isNotEmpty;
  
  String? get userBio => _userBio;
  String? get userDisplayName => _userDisplayName ?? _authService.userDisplayName;
  String? get userPhotoUrl => _userPhotoUrl ?? _authService.userPhotoUrl;
  
  // Store selected post data for sub-navigation
  List<Map<String, dynamic>>? _selectedPostData;
  String? _selectedPostCollectionName;

  // Pagination state for images
  Map<String, DocumentSnapshot?>? _imagesLastDocuments;
  bool _hasMoreImages = true;
  bool _isLoadingMoreImages = false;

  // Pagination state for videos
  Map<String, DocumentSnapshot?>? _videosLastDocuments;
  bool _hasMoreVideos = true;
  bool _isLoadingMoreVideos = false;
  
  // Real-time listener for user document changes (post count)
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  // Getters
  int get selectedTab => _selectedTab;
  AuthService get authService => _authService;
  int get postCount => _postCount;
  List<String> get userImages => _userImages;
  List<String> get userVideos => _userVideos;
  List<Map<String, dynamic>> get imagePostInfos => _imagePostInfos;
  List<Map<String, dynamic>> get videoPostInfos => _videoPostInfos;
  bool get hasMoreImages => _hasMoreImages;
  bool get hasMoreVideos => _hasMoreVideos;
  bool get isLoadingMoreImages => _isLoadingMoreImages;
  bool get isLoadingMoreVideos => _isLoadingMoreVideos;
  
  // Follow state getters
  bool get isFollowing => _isFollowing;
  bool get isLoadingFollowStatus => _isLoadingFollowStatus;
  int get followersCount => _followersCount;
  int get followingCount => _followingCount;
  int get favoriteFestivalsCount => _favoriteFestivalsCount;
  
  // Getters for selected post data (used when navigating via sub-navigation)
  List<Map<String, dynamic>>? get selectedPostData => _selectedPostData;
  String? get selectedPostCollectionName => _selectedPostCollectionName;

  // Mock data for lists
  final List<Map<String, String>> followers = [
    {
      'name': 'Alice Johnson',
      'username': '@alice',
      'avatar': 'https://i.pravatar.cc/100?img=1',
    },
    {
      'name': 'Bob Smith',
      'username': '@bob',
      'avatar': 'https://i.pravatar.cc/100?img=2',
    },
  ];

  final List<Map<String, String>> following = [
    {
      'name': 'Carol Lee',
      'username': '@carol',
      'avatar': 'https://i.pravatar.cc/100?img=3',
    },
  ];

  final List<Map<String, String>> festivals = [
    {
      'title': 'Summer Beats Festival',
    },
    {
      'title': 'Night Lights Carnival',
    },
  ];

  /// Set profile content tab (Posts, Reels, Reposts)
  void setSelectedTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    notifyListeners();
  }

  /// Set profile list tab (Followers, Following, Festivals)
  void setTab(int index) {
    if (index == currentTab) return;
    currentTab = index;
    notifyListeners();
  }

  List<Map<String, String>> getCurrentList() {
    if (currentTab == 0) return followers;
    if (currentTab == 1) return following;
    return festivals;
  }

  Future<void> loadData() async {
    await handleAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
  }

  // Old method kept for backward compatibility (used in ProfileView for mock data)
  void unfollowUserFromList(Map<String, String> user) {
    following.removeWhere((u) => u['username'] == user['username']);
    notifyListeners();
  }

  void openProfileList(int initialTab) {
    listInitialTab = initialTab;
    showingList = true;
    notifyListeners();
  }

  void closeProfileList() {
    showingList = false;
    notifyListeners();
  }

  /// Initialize and load user profile data
  String? _viewingUserId; // ID of the user whose profile is being viewed
  String? _fromRoute; // Route we came from (for proper back navigation)
  
  Future<void> initialize(BuildContext context, {String? userId, String? fromRoute}) async {
    // If already initialized but userId changed, reset and reinitialize
    if (_isInitialized && _viewingUserId != userId) {
      if (kDebugMode) {
        print('🔄 UserId changed from $_viewingUserId to $userId, reinitializing...');
      }
      _isInitialized = false;
      _hasRefreshedProfile = false;
      _isRefreshingProfile = false;
      // Clear existing data
      _postCount = 0;
      _userBio = null;
      _userDisplayName = null;
      _userPhotoUrl = null;
      _userImages.clear();
      _userVideos.clear();
      _imagePostInfos.clear();
      _videoPostInfos.clear();
      _imagesLastDocuments = null;
      _videosLastDocuments = null;
      _hasMoreImages = true;
      _hasMoreVideos = true;
      // Reset follow state
      _isFollowing = false;
      _isLoadingFollowStatus = false;
      _hasLoadedFollowStatus = false;
      _followersCount = 0;
      _followingCount = 0;
      _favoriteFestivalsCount = 0;
      // Cancel any existing follow status loading
      // Cancel any existing listeners
      _userDataSubscription?.cancel();
      _userDataSubscription = null;
      _favoriteFestivalsSubscription?.cancel();
      _favoriteFestivalsSubscription = null;
    }
    
    if (_isInitialized) return; // Prevent multiple initializations with same userId
    _isInitialized = true;
    _viewingUserId = userId; // Store the userId to view (null means current user)
    _fromRoute = fromRoute; // Store the route we came from
    await loadUserProfileData(context);
  }
  
  /// Get the route we came from
  String? get fromRoute => _fromRoute;
  
  /// Get the user ID to load profile for (viewingUserId if set, otherwise current user)
  String? get _targetUserId => _viewingUserId ?? _authService.userUid;
  
  /// Check if viewing own profile
  bool get isViewingOwnProfile => _viewingUserId == null;

  /// Load user's post count, images, and videos (first page)
  /// Checks network status first - if offline, immediately loads from cache
  Future<void> loadUserProfileData(BuildContext context) async {
    final targetUserId = _targetUserId;
    if (targetUserId == null) {
      if (kDebugMode) {
        print('⚠️ No user ID available, cannot load profile data');
      }
      return;
    }
    
    final currentUser = _authService.currentUser;
    if (currentUser == null && _viewingUserId == null) {
      if (kDebugMode) {
        print('⚠️ No user logged in, cannot load profile data');
      }
      return;
    }

    // Check network status first
    final hasInternet = await _networkService.hasInternetConnection();
    
    if (kDebugMode) {
      print(hasInternet ? '🌐 Online - fetching fresh data' : '📴 Offline - loading from cache');
    }

    await handleAsync(() async {
      // Get festival collection names from FestivalProvider
      final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
      final allFestivals = festivalProvider.allFestivals;
      final festivalCollectionNames = allFestivals
          .map((festival) => FirestoreService.getFestivalCollectionName(
                festival.id,
                festival.title,
              ))
          .toList();

      if (hasInternet) {
        // Online: Try to fetch fresh data, but cache will be checked first anyway
        try {
          // Load post count and bio from user document
          final userData = await _firestoreService.getUserData(targetUserId);
          final count = userData?['postCount'] as int? ?? 0;
          _postCount = count < 0 ? 0 : count; // Ensure non-negative
          
          // Load bio
          _userBio = userData?['bio'] as String?;
          
          // Load follower/following counts (ensured to be non-negative)
          _followersCount = (await _firestoreService.getFollowerCount(targetUserId)).clamp(0, double.infinity).toInt();
          _followingCount = (await _firestoreService.getFollowingCount(targetUserId)).clamp(0, double.infinity).toInt();
          
          // Load favorite festivals count (ensured to be non-negative)
          final favoriteIds = await _firestoreService.getFavoriteFestivalIds(targetUserId);
          _favoriteFestivalsCount = favoriteIds.length.clamp(0, double.infinity).toInt();
          
          // Load display name and photo URL
          if (_viewingUserId != null) {
            // Viewing another user: get from Firestore
            _userDisplayName = userData?['displayName'] as String?;
            _userPhotoUrl = userData?['photoUrl'] as String?;
            
            // Load follow status if viewing another user
            await loadFollowStatus();
          } else {
            // Viewing own profile: get from Firebase Auth
            _userDisplayName = currentUser?.displayName;
            _userPhotoUrl = currentUser?.photoURL;
          }
          
          if (kDebugMode) {
            print('📊 Initial post count: $_postCount');
            print('📝 User bio: $_userBio');
            print('👤 Display name: $_userDisplayName');
            print('📷 Photo URL: $_userPhotoUrl');
            print('👥 Followers: $_followersCount, Following: $_followingCount');
          }
          
          notifyListeners();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not load post count: $e');
          }
        }
        
        // Start real-time listener for user document changes (post count updates)
        // Only for own profile to avoid unnecessary listeners
        if (_viewingUserId == null && currentUser != null) {
          if (kDebugMode) {
            print('🔄 Starting real-time listener for user: ${currentUser!.uid}');
          }
          _startUserDataListener(currentUser!.uid);
        }

        // Load images (cache checked first, then fresh data)
        try {
          final imagesResult = await _firestoreService.getUserImagesPaginated(
            targetUserId,
            festivalCollectionNames: festivalCollectionNames,
            limit: 20,
            useCache: true, // Will use cache if available, then fetch fresh
          );
          _userImages = List<String>.from(imagesResult['images'] as List);
          _imagePostInfos = imagesResult['postInfos'] != null
              ? List<Map<String, dynamic>>.from(imagesResult['postInfos'] as List)
              : <Map<String, dynamic>>[];
          _imagesLastDocuments = imagesResult['lastDocuments'] as Map<String, DocumentSnapshot?>?;
          _hasMoreImages = imagesResult['hasMore'] as bool? ?? false;

          if (kDebugMode) {
            print('✅ Loaded images: ${_userImages.length} (hasMore: $_hasMoreImages, cached: ${imagesResult['cached'] == true})');
            print('   Post infos: ${_imagePostInfos.length}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not load images: $e');
          }
        }

        // Load videos (cache checked first, then fresh data)
        try {
          final videosResult = await _firestoreService.getUserVideosPaginated(
            targetUserId,
            festivalCollectionNames: festivalCollectionNames,
            limit: 20,
            useCache: true, // Will use cache if available, then fetch fresh
          );
          _userVideos = List<String>.from(videosResult['videos'] as List);
          _videoPostInfos = videosResult['postInfos'] != null
              ? List<Map<String, dynamic>>.from(videosResult['postInfos'] as List)
              : <Map<String, dynamic>>[];
          _videosLastDocuments = videosResult['lastDocuments'] as Map<String, DocumentSnapshot?>?;
          _hasMoreVideos = videosResult['hasMore'] as bool? ?? false;

          if (kDebugMode) {
            print('✅ Loaded videos: ${_userVideos.length} (hasMore: $_hasMoreVideos, cached: ${videosResult['cached'] == true})');
            print('   Post infos: ${_videoPostInfos.length}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not load videos: $e');
          }
        }
      } else {
        // Offline: Immediately load from cache only (no network calls)
        if (kDebugMode) {
          print('📦 Loading from cache (offline mode)');
        }

        // Try to load cached images
        try {
          final imagesResult = await _firestoreService.getUserImagesPaginated(
            targetUserId,
            festivalCollectionNames: festivalCollectionNames,
            limit: 20,
            useCache: true, // Will only use cache, won't make network calls
          );
          
          // Only use if it came from cache
          if (imagesResult['cached'] == true) {
            _userImages = List<String>.from(imagesResult['images'] as List);
            _imagePostInfos = imagesResult['postInfos'] != null
                ? List<Map<String, dynamic>>.from(imagesResult['postInfos'] as List)
                : <Map<String, dynamic>>[];
            _imagesLastDocuments = imagesResult['lastDocuments'] as Map<String, DocumentSnapshot?>?;
            _hasMoreImages = imagesResult['hasMore'] as bool? ?? false;
            
            if (kDebugMode) {
              print('✅ Loaded ${_userImages.length} cached images');
            }
          } else {
            // No cache available
            _userImages = [];
            _imagePostInfos = [];
            if (kDebugMode) {
              print('⚠️ No cached images available');
            }
          }
        } catch (e) {
          _userImages = [];
          if (kDebugMode) {
            print('⚠️ Error loading cached images: $e');
          }
        }

        // Try to load cached videos
        try {
          final videosResult = await _firestoreService.getUserVideosPaginated(
            targetUserId,
            festivalCollectionNames: festivalCollectionNames,
            limit: 20,
            useCache: true, // Will only use cache, won't make network calls
          );
          
          // Only use if it came from cache
          if (videosResult['cached'] == true) {
            _userVideos = List<String>.from(videosResult['videos'] as List);
            _videoPostInfos = videosResult['postInfos'] != null
                ? List<Map<String, dynamic>>.from(videosResult['postInfos'] as List)
                : <Map<String, dynamic>>[];
            _videosLastDocuments = videosResult['lastDocuments'] as Map<String, DocumentSnapshot?>?;
            _hasMoreVideos = videosResult['hasMore'] as bool? ?? false;
            
            if (kDebugMode) {
              print('✅ Loaded ${_userVideos.length} cached videos');
            }
          } else {
            // No cache available
            _userVideos = [];
            _videoPostInfos = [];
            if (kDebugMode) {
              print('⚠️ No cached videos available');
            }
          }
        } catch (e) {
          _userVideos = [];
          if (kDebugMode) {
            print('⚠️ Error loading cached videos: $e');
          }
        }

        // Post count - try to get from cache or keep existing value
        // Note: Post count is not cached separately, so we keep the existing value
        // But we should still start the listener for when we come back online (only for own profile)
        if (_viewingUserId == null && currentUser != null) {
          if (kDebugMode) {
            print('📊 Post count: $_postCount (using existing value - not cached separately)');
            print('🔄 Starting real-time listener for user (offline mode): ${currentUser!.uid}');
          }
          _startUserDataListener(currentUser!.uid);
          _startFavoriteFestivalsListener(currentUser!.uid);
        }
      }

      if (kDebugMode) {
        print('✅ Profile data loaded:');
        print('   Network: ${hasInternet ? "Online" : "Offline"}');
        print('   Post count: $_postCount');
        print('   Images: ${_userImages.length}');
        print('   Videos: ${_userVideos.length}');
      }
    }, errorMessage: 'Failed to load profile data');
  }

  /// Load more images (next page)
  Future<void> loadMoreImages(BuildContext context) async {
    if (_isLoadingMoreImages || !_hasMoreImages) return;

    final targetUserId = _targetUserId;
    if (targetUserId == null) return;

    _isLoadingMoreImages = true;
    notifyListeners();

    try {
      final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
      final allFestivals = festivalProvider.allFestivals;
      final festivalCollectionNames = allFestivals
          .map((festival) => FirestoreService.getFestivalCollectionName(
                festival.id,
                festival.title,
              ))
          .toList();

      final result = await _firestoreService.getUserImagesPaginated(
        targetUserId,
        festivalCollectionNames: festivalCollectionNames,
        limit: 20,
        lastDocuments: _imagesLastDocuments,
        useCache: false, // Don't use cache for pagination
      );

      final newImages = List<String>.from(result['images'] as List);
      final newPostInfos = result['postInfos'] != null
          ? List<Map<String, dynamic>>.from(result['postInfos'] as List)
          : <Map<String, dynamic>>[];
      _userImages.addAll(newImages);
      _imagePostInfos.addAll(newPostInfos);
      _imagesLastDocuments = result['lastDocuments'] as Map<String, DocumentSnapshot?>?;
      _hasMoreImages = result['hasMore'] as bool? ?? false;

      if (kDebugMode) {
        print('📥 Loaded ${newImages.length} more images (total: ${_userImages.length}, hasMore: $_hasMoreImages)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading more images: $e');
      }
    } finally {
      _isLoadingMoreImages = false;
      notifyListeners();
    }
  }

  /// Load more videos (next page)
  Future<void> loadMoreVideos(BuildContext context) async {
    if (_isLoadingMoreVideos || !_hasMoreVideos) return;

    final targetUserId = _targetUserId;
    if (targetUserId == null) return;

    _isLoadingMoreVideos = true;
    notifyListeners();

    try {
      final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
      final allFestivals = festivalProvider.allFestivals;
      final festivalCollectionNames = allFestivals
          .map((festival) => FirestoreService.getFestivalCollectionName(
                festival.id,
                festival.title,
              ))
          .toList();

      final result = await _firestoreService.getUserVideosPaginated(
        targetUserId,
        festivalCollectionNames: festivalCollectionNames,
        limit: 20,
        lastDocuments: _videosLastDocuments,
        useCache: false, // Don't use cache for pagination
      );

      final newVideos = List<String>.from(result['videos'] as List);
      final newPostInfos = result['postInfos'] != null
          ? List<Map<String, dynamic>>.from(result['postInfos'] as List)
          : <Map<String, dynamic>>[];
      _userVideos.addAll(newVideos);
      _videoPostInfos.addAll(newPostInfos);
      _videosLastDocuments = result['lastDocuments'] as Map<String, DocumentSnapshot?>?;
      _hasMoreVideos = result['hasMore'] as bool? ?? false;

      if (kDebugMode) {
        print('📥 Loaded ${newVideos.length} more videos (total: ${_userVideos.length}, hasMore: $_hasMoreVideos)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading more videos: $e');
      }
    } finally {
      _isLoadingMoreVideos = false;
      notifyListeners();
    }
  }

  /// Refresh profile data (clears cache and reloads)
  Future<void> refreshProfileData(BuildContext context) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    // Clear cache
    _firestoreService.clearProfileCache(userId: currentUser.uid);

    // Reset pagination state
    _userImages.clear();
    _userVideos.clear();
    _imagePostInfos.clear();
    _videoPostInfos.clear();
    _imagesLastDocuments = null;
    _videosLastDocuments = null;
    _hasMoreImages = true;
    _hasMoreVideos = true;

    // Reload data
    await loadUserProfileData(context);
  }

  /// Reset refresh flags to allow profile refresh
  /// This is called when navigating to settings/edit account to ensure refresh happens on return
  void resetRefreshFlags() {
    _hasRefreshedProfile = false;
    _isRefreshingProfile = false;
    if (kDebugMode) {
      print('🔄 Reset refresh flags to allow profile refresh');
    }
  }

  /// Refresh only user profile info (name, bio, profile picture) without reloading posts
  /// This is called when returning from edit profile screen
  /// Only refreshes if viewing own profile, not when viewing another user's profile
  Future<void> refreshUserProfileInfo() async {
    // If viewing another user's profile, don't refresh (would overwrite with current user's data)
    if (_viewingUserId != null) {
      if (kDebugMode) {
        print('⏳ Viewing another user profile, skipping refresh to avoid overwriting');
      }
      return;
    }
    
    // CRITICAL: Check flags FIRST to prevent multiple calls
    if (_hasRefreshedProfile || _isRefreshingProfile) {
      if (kDebugMode) {
        print('⏳ Profile info already refreshed or refreshing, skipping duplicate call...');
      }
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _hasRefreshedProfile = true; // Mark as attempted
      return;
    }

    _isRefreshingProfile = true;
    try {
      // Reload Firebase Auth user data to get updated name and profile picture
      await currentUser.reload();
      
      // Reload user data from Firestore to get updated bio and counts
      final userData = await _firestoreService.getUserData(currentUser.uid);
      
      // Update only profile picture, username, and bio
      _userBio = userData?['bio'] as String?;
      _userDisplayName = currentUser.displayName;
      _userPhotoUrl = currentUser.photoURL;
      
      _hasRefreshedProfile = true; // Mark as refreshed
      
      if (kDebugMode) {
        print('🔄 Refreshed user profile info');
        print('   Bio: $_userBio');
        print('   Display Name: $_userDisplayName');
        print('   Photo URL: $_userPhotoUrl');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not refresh user profile info: $e');
      }
      _hasRefreshedProfile = true; // Mark as attempted even on error
    } finally {
      _isRefreshingProfile = false;
    }
  }

  void onBottomNavTap(int index) {
    // Handle navigation
  }

  // Navigation actions (used elsewhere)
  Future<void> goToFollowers() async {}

  Future<void> goToFollowing() async {
    // await _navigationService.navigateTo(AppRoutes.following);
  }

  Future<void> goToFestivals() async {
    await _navigationService.navigateTo(AppRoutes.festivals);
  }

  Future<void> goToNotifications() async {
    // Using news route as notifications screen placeholder
    await _navigationService.navigateTo(AppRoutes.notification);
  }

  /// Fetch a single post with full details (comments count, reactions, etc.)
  /// [postInfo] - Lightweight post info containing postId and collectionName
  /// Returns full post data map or null if not found
  Future<Map<String, dynamic>?> fetchSinglePost(Map<String, dynamic> postInfo) async {
    final postId = postInfo['postId'] as String?;
    final collectionName = postInfo['collectionName'] as String?;

    if (postId == null || collectionName == null) {
      if (kDebugMode) {
        print('⚠️ Invalid post info: missing postId or collectionName');
      }
      return null;
    }

    try {
      if (kDebugMode) {
        print('📥 Fetching full details for post: $postId from collection: $collectionName');
      }

      final fullPost = await _firestoreService.getPostById(
        postId: postId,
        collectionName: collectionName,
      );

      if (fullPost != null) {
        // Add collectionName to the post data if not present
        fullPost['collectionName'] = collectionName;
        fullPost['postId'] = postId; // Ensure postId is set

        // Store post data in service for sub-navigation (when onNavigateToSub is used)
        _postDataService.setPostData([fullPost], collectionName: collectionName);
        
        // Also store in ViewModel for direct access
        _selectedPostData = [fullPost];
        _selectedPostCollectionName = collectionName;
        notifyListeners();

        if (kDebugMode) {
          print('✅ Fetched full post details for: $postId');
          print('   Stored post data in PostDataService for sub-navigation');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Post not found: $postId');
        }
      }

      return fullPost;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching post $postId: $e');
      }
      return null;
    }
  }

  /// Start listening to real-time user document changes (for post count updates)
  void _startUserDataListener(String userId) {
    if (isDisposed) {
      if (kDebugMode) {
        print('⚠️ Cannot start listener: ViewModel is disposed');
      }
      return;
    }

    // Cancel existing subscription if any
    _userDataSubscription?.cancel();
    _userDataSubscription = null;

    if (kDebugMode) {
      print('🔄 Setting up real-time listener for user: $userId');
    }

    try {
      _userDataSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen(
            (DocumentSnapshot snapshot) {
              if (isDisposed) {
                if (kDebugMode) {
                  print('⚠️ Listener callback called but ViewModel is disposed');
                }
                return;
              }

              if (kDebugMode) {
                print('📥 User document snapshot received');
                print('   Document exists: ${snapshot.exists}');
              }

              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>?;
                if (data != null) {
                  bool updated = false;
                  
                  // Update post count
                  final newCount = data['postCount'] as int? ?? 0;
                  final safeCount = newCount < 0 ? 0 : newCount; // Ensure non-negative
                  
                  if (_postCount != safeCount) {
                    if (kDebugMode) {
                      print('🔄 Post count updated: $_postCount -> $safeCount');
                    }
                    _postCount = safeCount;
                    updated = true;
                  }
                  
                  // Update follower/following counts from real-time updates (ensure non-negative)
                  final newFollowersCount = data['followersCount'] as int?;
                  final newFollowingCount = data['followingCount'] as int?;
                  
                  if (newFollowersCount != null) {
                    final safeFollowersCount = newFollowersCount.clamp(0, double.infinity).toInt();
                    if (_followersCount != safeFollowersCount) {
                      if (kDebugMode) {
                        print('🔄 Followers count updated: $_followersCount -> $safeFollowersCount');
                      }
                      _followersCount = safeFollowersCount;
                      updated = true;
                    }
                  }
                  
                  if (newFollowingCount != null) {
                    final safeFollowingCount = newFollowingCount.clamp(0, double.infinity).toInt();
                    if (_followingCount != safeFollowingCount) {
                      if (kDebugMode) {
                        print('🔄 Following count updated: $_followingCount -> $safeFollowingCount');
                      }
                      _followingCount = safeFollowingCount;
                      updated = true;
                    }
                  }
                  
                  // Update favorite festivals count from real-time updates
                  final favoriteFestivals = data['favoriteFestivals'] as List<dynamic>?;
                  if (favoriteFestivals != null) {
                    final newCount = favoriteFestivals.length.clamp(0, double.infinity).toInt();
                    if (_favoriteFestivalsCount != newCount) {
                      if (kDebugMode) {
                        print('🔄 Favorite festivals count updated: $_favoriteFestivalsCount -> $newCount');
                      }
                      _favoriteFestivalsCount = newCount;
                      updated = true;
                    }
                  }
                  
                  if (updated) {
                    notifyListeners();
                  } else {
                    if (kDebugMode) {
                      print('   No changes detected in user document');
                    }
                  }
                } else {
                  if (kDebugMode) {
                    print('⚠️ Document data is null');
                  }
                }
              } else {
                if (kDebugMode) {
                  print('⚠️ User document does not exist');
                }
              }
            },
            onError: (error, stackTrace) {
              if (isDisposed) return;
              if (kDebugMode) {
                print('❌ Error in user data stream: $error');
                print('   Stack trace: $stackTrace');
              }
            },
            cancelOnError: false,
          );

      if (kDebugMode) {
        print('✅ Started real-time listener for user document: $userId');
        print('   Subscription active: ${_userDataSubscription != null}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error starting user data listener: $e');
        print('   Stack trace: $stackTrace');
      }
    }
  }

  /// Search users by name with debouncing
  void searchUsers(String query) {
    _userSearchQuery = query;
    
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

  /// Perform the actual user search
  Future<void> _performUserSearch(String query) async {
    if (isDisposed) return;
    
    try {
      final currentUserId = _authService.userUid;
      final results = await _firestoreService.searchUsersByName(query);
      if (isDisposed) return;
      
      // Filter out current user from results
      _searchResults = results.where((user) {
        final userId = user['userId'] as String?;
        return userId != null && userId != currentUserId;
      }).toList();
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Found ${_searchResults.length} users matching "$query" (excluding current user)');
      }
    } catch (e) {
      if (isDisposed) return;
      
      if (kDebugMode) {
        print('❌ Error searching users: $e');
      }
      _searchResults = [];
      notifyListeners();
    }
  }

  /// Activate search mode
  void activateSearch() {
    _isSearchActive = true;
    notifyListeners();
    // Request focus after a short delay to ensure UI is updated
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isDisposed) {
        userSearchFocusNode.requestFocus();
      }
    });
  }

  /// Deactivate search mode
  void deactivateSearch() {
    _isSearchActive = false;
    _userSearchQuery = '';
    userSearchController.clear();
    _searchResults = [];
    notifyListeners();
  }

  /// Clear search
  void clearUserSearch() {
    _userSearchQuery = '';
    userSearchController.clear();
    _searchResults = [];
    notifyListeners();
  }

  /// Unfocus search field
  void unfocusUserSearch() {
    if (isDisposed) return;
    
    try {
      userSearchFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) print('Error unfocusing user search: $e');
    }
  }

  /// Load follow status (check if current user is following the viewed user)
  Future<void> loadFollowStatus() async {
    // Prevent multiple simultaneous calls
    if (_isLoadingFollowStatus || _hasLoadedFollowStatus) {
      if (kDebugMode) {
        print('⏳ Follow status already loaded or loading, skipping duplicate call...');
      }
      return;
    }

    if (_viewingUserId == null || _authService.userUid == null) {
      // Not viewing another user or not logged in
      _isFollowing = false;
      return;
    }

    _isLoadingFollowStatus = true;
    _hasLoadedFollowStatus = true;

    try {
      final currentUserId = _authService.userUid!;
      _isFollowing = await _firestoreService.isFollowing(currentUserId, _viewingUserId!);
      
      if (kDebugMode) {
        print('✅ Loaded follow status: $_isFollowing (currentUser: $currentUserId, viewingUser: $_viewingUserId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading follow status: $e');
      }
      _isFollowing = false;
    } finally {
      _isLoadingFollowStatus = false;
      notifyListeners();
    }
  }

  /// Follow the viewed user
  Future<void> followUser(BuildContext context) async {
    if (_viewingUserId == null || _authService.userUid == null) {
      return;
    }

    if (_isFollowing) {
      return; // Already following
    }

    final currentUserId = _authService.userUid!;
    final targetUserId = _viewingUserId!;

    await handleAsync(() async {
      try {
        await _firestoreService.followUser(currentUserId, targetUserId);
        _isFollowing = true;
        
        // Update target user's follower count (the user we're viewing)
        _followersCount++;
        
        // Reload current user's following count if viewing own profile
        // (The real-time listener will update it automatically, but we can also refresh)
        if (_viewingUserId == null) {
          // Viewing own profile - refresh following count
          _followingCount = await _firestoreService.getFollowingCount(currentUserId);
        }
        
        notifyListeners();
        
        if (kDebugMode) {
          print('✅ Successfully followed user: $targetUserId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error following user: $e');
        }
        rethrow;
      }
    });
  }

  /// Unfollow the viewed user
  Future<void> unfollowUser(BuildContext context) async {
    if (_viewingUserId == null || _authService.userUid == null) {
      return;
    }

    if (!_isFollowing) {
      return; // Not following
    }

    final currentUserId = _authService.userUid!;
    final targetUserId = _viewingUserId!;

    await handleAsync(() async {
      try {
        await _firestoreService.unfollowUser(currentUserId, targetUserId);
        _isFollowing = false;
        
        // Update target user's follower count (the user we're viewing)
        _followersCount = (_followersCount - 1).clamp(0, double.infinity).toInt();
        
        // Reload current user's following count if viewing own profile
        // (The real-time listener will update it automatically, but we can also refresh)
        if (_viewingUserId == null) {
          // Viewing own profile - refresh following count
          _followingCount = await _firestoreService.getFollowingCount(currentUserId);
        }
        
        notifyListeners();
        
        if (kDebugMode) {
          print('✅ Successfully unfollowed user: $targetUserId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error unfollowing user: $e');
        }
        rethrow;
      }
    });
  }

  /// Navigate to a user's profile
  Future<void> navigateToUserProfile(BuildContext context, String userId, {String? fromRoute}) async {
    // Clear search first
    clearUserSearch();
    unfocusUserSearch();
    
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
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

  /// Start listening to real-time favorite festivals changes
  void _startFavoriteFestivalsListener(String userId) {
    if (isDisposed) {
      if (kDebugMode) {
        print('⚠️ Cannot start favorite festivals listener: ViewModel is disposed');
      }
      return;
    }

    // Cancel existing subscription if any
    _favoriteFestivalsSubscription?.cancel();
    _favoriteFestivalsSubscription = null;

    if (kDebugMode) {
      print('🔄 Setting up real-time listener for favorite festivals: $userId');
    }

    try {
      _favoriteFestivalsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen(
            (DocumentSnapshot snapshot) {
              if (isDisposed) {
                if (kDebugMode) {
                  print('⚠️ Favorite festivals listener callback called but ViewModel is disposed');
                }
                return;
              }

              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>?;
                if (data != null) {
                  final favoriteFestivals = data['favoriteFestivals'] as List<dynamic>?;
                  final newCount = (favoriteFestivals?.length ?? 0).clamp(0, double.infinity).toInt();
                  
                  if (_favoriteFestivalsCount != newCount) {
                    if (kDebugMode) {
                      print('🔄 Favorite festivals count updated via listener: $_favoriteFestivalsCount -> $newCount');
                    }
                    _favoriteFestivalsCount = newCount;
                    notifyListeners();
                  }
                }
              }
            },
            onError: (error, stackTrace) {
              if (isDisposed) return;
              if (kDebugMode) {
                print('❌ Error in favorite festivals stream: $error');
              }
            },
            cancelOnError: false,
          );

      if (kDebugMode) {
        print('✅ Started real-time listener for favorite festivals: $userId');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error starting favorite festivals listener: $e');
      }
    }
  }

  @override
  void onDispose() {
    // Cancel the real-time listener when view is disposed
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    
    // Cancel favorite festivals listener
    _favoriteFestivalsSubscription?.cancel();
    _favoriteFestivalsSubscription = null;
    
    // Cancel search debounce timer
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    
    // Dispose search controllers
    userSearchFocusNode.dispose();
    userSearchController.dispose();
    
    super.onDispose();
  }

  Future<void> onPostTap(int index) async {
    // No dedicated post detail; open gallery for now
  }
}
