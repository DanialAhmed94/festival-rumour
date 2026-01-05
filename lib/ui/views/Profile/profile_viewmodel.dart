
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
  List<String> _userImages = [];
  List<String> _userVideos = [];
  List<Map<String, dynamic>> _imagePostInfos = []; // Lightweight post info for images
  List<Map<String, dynamic>> _videoPostInfos = []; // Lightweight post info for videos
  bool _isInitialized = false;
  
  String? get userBio => _userBio;
  
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

  void unfollowUser(Map<String, String> user) {
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
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return; // Prevent multiple initializations
    _isInitialized = true;
    await loadUserProfileData(context);
  }

  /// Load user's post count, images, and videos (first page)
  /// Checks network status first - if offline, immediately loads from cache
  Future<void> loadUserProfileData(BuildContext context) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
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
          final userData = await _firestoreService.getUserData(currentUser.uid);
          final count = userData?['postCount'] as int? ?? 0;
          _postCount = count < 0 ? 0 : count; // Ensure non-negative
          
          // Load bio
          _userBio = userData?['bio'] as String?;
          
          if (kDebugMode) {
            print('📊 Initial post count: $_postCount');
            print('📝 User bio: $_userBio');
          }
          
          notifyListeners();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not load post count: $e');
          }
        }
        
        // Start real-time listener for user document changes (post count updates)
        if (kDebugMode) {
          print('🔄 Starting real-time listener for user: ${currentUser.uid}');
        }
        _startUserDataListener(currentUser.uid);

        // Load images (cache checked first, then fresh data)
        try {
          final imagesResult = await _firestoreService.getUserImagesPaginated(
            currentUser.uid,
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
            currentUser.uid,
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
            currentUser.uid,
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
            currentUser.uid,
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
        // But we should still start the listener for when we come back online
        if (kDebugMode) {
          print('📊 Post count: $_postCount (using existing value - not cached separately)');
          print('🔄 Starting real-time listener for user (offline mode): ${currentUser.uid}');
        }
        _startUserDataListener(currentUser.uid);
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

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

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
        currentUser.uid,
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

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

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
        currentUser.uid,
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
                  final newCount = data['postCount'] as int? ?? 0;
                  final safeCount = newCount < 0 ? 0 : newCount; // Ensure non-negative
                  
                  if (kDebugMode) {
                    print('   Current postCount in ViewModel: $_postCount');
                    print('   New postCount from Firestore: $newCount');
                    print('   Safe count (non-negative): $safeCount');
                  }
                  
                  if (_postCount != safeCount) {
                    if (kDebugMode) {
                      print('🔄 Post count updated: $_postCount -> $safeCount');
                    }
                    _postCount = safeCount;
                    notifyListeners();
                  } else {
                    if (kDebugMode) {
                      print('   Post count unchanged: $_postCount');
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

  @override
  void onDispose() {
    // Cancel the real-time listener when view is disposed
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    
    super.onDispose();
  }

  Future<void> onPostTap(int index) async {
    // No dedicated post detail; open gallery for now
  }
}
