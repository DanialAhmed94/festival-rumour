import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_numbers.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/error_handler_service.dart';
import '../../../core/exceptions/exception_mapper.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/providers/festival_provider.dart';
import '../homeview/post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/user_photo_cache_service.dart';

/// ViewModel for festival-specific rumors screen
/// Reuses HomeViewModel logic but uses festival-specific Firestore collection
class RumorsViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final NetworkService _networkService = locator<NetworkService>();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  final UserPhotoCacheService _userPhotoCacheService = locator<UserPhotoCacheService>();
  
  List<PostModel> posts = [];
  List<PostModel> allPosts = []; // Store all posts
  String selectedFilter = AppStrings.allPosts; // Default filter - show live posts
  String get currentFilter => selectedFilter;
  String searchQuery = ''; // Search query
  late FocusNode searchFocusNode; // Search field focus node
  final TextEditingController searchController = TextEditingController();
  
  StreamSubscription<List<Map<String, dynamic>>>? _postsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _sharedPostsSubscription;
  Timer? _sharedPostsRefreshTimer;
  
  // Pagination state
  dynamic _lastDocument; // Last document for pagination
  bool _hasMorePosts = true; // Whether there are more posts to load
  bool _isLoadingMore = false; // Whether we're currently loading more posts
  static const int _initialLimit = 10; // Initial number of posts to load
  static const int _loadMoreLimit = 10; // Number of posts to load per "load more"
  /// In-memory window (aligned with global feed — see `docs/global-feed-performance.md`).
  static const int _maxLoadedFeedPosts = 100;
  static const int _feedMemoryTrimChunk = 50;
  static const int _maxDetachedOlderPosts = 200;
  /// Fixed Firestore limit for festival collection snapshot stream (newest-first).
  static const int _realtimeStreamPostLimit = 80;

  /// Oldest posts evicted from [allPosts] by trim; re-attached via [restoreDetachedOlderPosts].
  final List<PostModel> _detachedOlderTail = [];
  /// Snapshots from paginated queries for cursor sync (no per-trim `doc().get()`).
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _feedCursorDocByPostId = {};

  // Festival-specific collection name and display title
  String? _festivalCollectionName;
  String? _festivalTitle; // Human-readable festival name for app bar
  int? _festivalId; // Selected festival id, to detect when user selects a different festival (e.g. from discover search)
  bool _isInitialized = false; // Track if already initialized
  DateTime? _newestPostTimestamp; // Track newest post timestamp for efficient stream updates

  bool get hasMorePosts => _hasMorePosts;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasDetachedOlderChunk => _detachedOlderTail.isNotEmpty;
  int get detachedBufferLength => _detachedOlderTail.length;
  String? get festivalCollectionName => _festivalCollectionName;
  String? get festivalTitle => _festivalTitle;
  
  RumorsViewModel() {
    searchFocusNode = FocusNode();
    searchController.addListener(() {
      if (searchController.text != searchQuery) {
        setSearchQuery(searchController.text);
      }
    });
    // Keep enriched photo/username current when the user updates their profile.
    _userPhotoCacheService.addListener(_onUserPhotoCacheUpdated);
  }

  /// Synchronous pass: update any allPosts entries whose cached photo/name
  /// differs from what the PostModel currently holds (mirrors HomeViewModel).
  void _onUserPhotoCacheUpdated() {
    if (isDisposed) return;
    bool changed = false;
    for (int i = 0; i < allPosts.length; i++) {
      final post = allPosts[i];
      final uid = post.userId;
      if (uid == null || uid.isEmpty) continue;
      final cachedPhoto = _userPhotoCacheService.getCachedPhotoUrl(uid);
      final cachedName = _userPhotoCacheService.getCachedDisplayName(uid);
      String? newPhoto;
      String? newName;
      if (cachedPhoto != null && cachedPhoto.isNotEmpty && post.userPhotoUrl != cachedPhoto) {
        newPhoto = cachedPhoto;
      }
      if (cachedName != null && cachedName.isNotEmpty && post.username != cachedName) {
        newName = cachedName;
      }
      if (newPhoto != null || newName != null) {
        allPosts[i] = post.copyWith(userPhotoUrl: newPhoto, username: newName);
        changed = true;
      }
    }
    if (changed) _applyFilterNotifyIfChanged();
  }

  @override
  void onDispose() {
    _userPhotoCacheService.removeListener(_onUserPhotoCacheUpdated);
    _postsSubscription?.cancel();
    _postsSubscription = null;
    _sharedPostsSubscription?.cancel();
    _sharedPostsSubscription = null;
    _sharedPostsRefreshTimer?.cancel();
    _sharedPostsRefreshTimer = null;
    
    // Clear references to prevent memory leaks
    posts.clear();
    allPosts.clear();
    _detachedOlderTail.clear();
    _feedCursorDocByPostId.clear();
    
    // Reset initialization flag
    _isInitialized = false;
    _festivalId = null;
    _festivalCollectionName = null;
    _festivalTitle = null;
    _newestPostTimestamp = null;
    
    // Dispose controllers and focus nodes
    searchFocusNode.dispose();
    searchController.dispose();
    
    super.onDispose();
  }

  /// Initialize the rumors view with festival collection
  /// This should be called from the view after getting festival from provider
  /// Only initializes once to prevent multiple Firestore queries
  void initialize(BuildContext context) {
    if (kDebugMode) {
      print('📰 [RumorsVM] initialize() called, _isInitialized=$_isInitialized');
    }
    // Prevent multiple initializations
    if (_isInitialized) {
      if (kDebugMode) {
        print('📰 [RumorsVM] initialize: already initialized, skipping');
      }
      return;
    }

    // Get festival from provider
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;

    if (selectedFestival == null) {
      if (kDebugMode) {
        print('📰 [RumorsVM] initialize: no festival selected, aborting');
      }
      return;
    }

    if (kDebugMode) {
      print('📰 [RumorsVM] initialize: setting up for festival id=${selectedFestival.id} "${selectedFestival.title}"');
    }
    _festivalId = selectedFestival.id;
    _festivalTitle = selectedFestival.title;
    // Generate festival collection name
    _festivalCollectionName = FirestoreService.getFestivalCollectionName(
      selectedFestival.id,
      selectedFestival.title,
    );

    if (kDebugMode) {
      print('🎪 Initializing rumors for festival: $_festivalTitle');
      print('🎪 Collection name: $_festivalCollectionName');
    }

    // Mark as initialized BEFORE loading posts to prevent race conditions
    _isInitialized = true;
    
    // Load initial posts and ensure collection exists
    loadInitialPosts();
  }

  /// Re-initialize with the current selected festival if it changed (e.g. user selected a festival from discover search).
  /// Call this when the Rumors tab is shown so it loads rumours for the latest selected festival.
  void reinitializeIfFestivalChanged(BuildContext context) {
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;
    if (kDebugMode) {
      print('📰 [RumorsVM] reinitializeIfFestivalChanged: _festivalId=$_festivalId, selectedFestival?.id=${selectedFestival?.id}, selectedFestival?.title=${selectedFestival?.title}');
    }
    if (selectedFestival == null) {
      if (kDebugMode) print('📰 [RumorsVM] reinitializeIfFestivalChanged: early return (no selected festival)');
      return;
    }
    if (_festivalId == selectedFestival.id) {
      if (kDebugMode) print('📰 [RumorsVM] reinitializeIfFestivalChanged: early return (same festival id)');
      return;
    }

    if (kDebugMode) {
      print('📰 [RumorsVM] festival changed from $_festivalId to ${selectedFestival.id}, re-initializing for "${selectedFestival.title}"');
    }
    _postsSubscription?.cancel();
    _postsSubscription = null;
    posts.clear();
    allPosts.clear();
    _detachedOlderTail.clear();
    _feedCursorDocByPostId.clear();
    _isInitialized = false;
    _festivalId = null;
    _festivalCollectionName = null;
    _festivalTitle = null;
    _newestPostTimestamp = null;
    _lastDocument = null;
    _hasMorePosts = true;
    initialize(context);
  }

  /// Load initial posts from festival collection
  /// Also ensures collection exists even if empty
  Future<void> loadInitialPosts() async {
    if (_festivalCollectionName == null) {
      if (kDebugMode) {
        print('⚠️ Festival collection name not set, cannot load posts');
      }
      return;
    }

    await handleAsync(() async {
      setLoading(true);
      
      try {
        _detachedOlderTail.clear();
        _feedCursorDocByPostId.clear();

        final result = await _firestoreService.getPostsPaginated(
          limit: _initialLimit,
          collectionName: _festivalCollectionName,
        );

        _mergeDocSnapshotsFromPaginatedResult(result);

        final postsData = result['posts'] as List<Map<String, dynamic>>;
        _lastDocument = result['lastDocument'];
        _hasMorePosts = result['hasMore'] as bool? ?? false;

        allPosts.clear();
        final loadedIds = <String>{};
        for (var postData in postsData) {
          try {
            var post = PostModel.fromFirestore(
              _createDocumentSnapshot(postData),
            );
            if (post.userId != null && post.userId!.isNotEmpty) {
              if (post.sourceCollection == null) {
                post = post.copyWith(sourceCollection: _festivalCollectionName);
              }
              allPosts.add(post);
              if (post.postId != null) loadedIds.add(post.postId!);
            }
          } catch (e, stackTrace) {
            if (kDebugMode) {
              print('Error parsing post: $e');
              print('Stack trace: $stackTrace');
            }
          }
        }

        if (kDebugMode) {
          print('📥 [RumorsVM] Fetching shared posts for $_festivalCollectionName...');
        }
        final sharedPosts = await _firestoreService
            .getPostsSharedToFestival(_festivalCollectionName!);
        if (kDebugMode) {
          print('📥 [RumorsVM] Got ${sharedPosts.length} shared posts from global feed');
          for (final sp in sharedPosts) {
            print('   id=${sp['postId']}, comments=${sp['comments']}, likes=${sp['likes']}, sharedToFestivals=${sp['sharedToFestivals']}, sourceCollection=${sp['sourceCollection']}');
          }
        }
        for (var postData in sharedPosts) {
          try {
            var post = PostModel.fromFirestore(
              _createDocumentSnapshot(postData),
            );
            if (post.userId != null &&
                post.userId!.isNotEmpty &&
                post.postId != null &&
                !loadedIds.contains(post.postId)) {
              if (post.sourceCollection == null) {
                post = post.copyWith(sourceCollection: FirestoreService.defaultPostsCollection);
              }
              allPosts.add(post);
              loadedIds.add(post.postId!);
              if (kDebugMode) {
                print('📥 [RumorsVM] Added shared post: ${post.postId}, source=${post.sourceCollection}');
              }
            }
          } catch (e) {
            if (kDebugMode) print('Error parsing shared post: $e');
          }
        }

        allPosts.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(0);
          final bTime = b.createdAt ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

        // Initialize newest post timestamp from loaded posts
        if (allPosts.isNotEmpty) {
          final sortedPosts = List<PostModel>.from(allPosts);
          sortedPosts.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(0);
            final bTime = b.createdAt ?? DateTime(0);
            return bTime.compareTo(aTime);
          });
          final newestPost = sortedPosts.first;
          if (newestPost.createdAt != null) {
            _newestPostTimestamp = newestPost.createdAt;
          }
        }

        // If collection is empty, ensure it exists by creating a metadata document
        // This ensures the collection appears in Firestore console
        if (allPosts.isEmpty) {
          await _ensureCollectionExists();
        }

        _pruneFeedCursorDocsToStoredPosts();

        await _enrichPostsWithUserPhotos();
        await _loadUserReactions();
        _applyFilterNotifyIfChanged();

        // Start real-time listener (will be skipped if no posts, which is fine)
        _startPostsListener();

        if (kDebugMode) {
          print('✅ Loaded ${allPosts.length} posts from festival collection');
        }
      } catch (e, stackTrace) {
        final exception = ExceptionMapper.mapToAppException(e, stackTrace);
        _errorHandler.handleError(exception, stackTrace, 'RumorsViewModel.loadInitialPosts');
        rethrow;
      } finally {
        setLoading(false);
      }
    }, 
    errorMessage: AppStrings.failedToLoadPosts,
    minimumLoadingDuration: AppDurations.minimumLoadingDuration);
  }

  void _mergeDocSnapshotsFromPaginatedResult(Map<String, dynamic> result) {
    final raw = result['docSnapshotsByPostId'];
    if (raw == null || raw is! Map) return;
    raw.forEach((k, v) {
      if (k is String && v is DocumentSnapshot<Map<String, dynamic>>) {
        _feedCursorDocByPostId[k] = v;
      }
    });
  }

  void _pruneFeedCursorDocsToStoredPosts() {
    final before = _feedCursorDocByPostId.length;
    final keep = <String>{};
    for (final p in allPosts) {
      final id = p.postId;
      if (id != null && id.isNotEmpty) keep.add(id);
    }
    for (final p in _detachedOlderTail) {
      final id = p.postId;
      if (id != null && id.isNotEmpty) keep.add(id);
    }
    _feedCursorDocByPostId.removeWhere((k, _) => !keep.contains(k));
    if (kDebugMode && before != _feedCursorDocByPostId.length) {
      print(
        '[FestivalFeed] cursorCachePrune: $before -> ${_feedCursorDocByPostId.length} (keepIds=${keep.length})',
      );
    }
  }

  Future<void> _syncPaginationCursorFromCachedDoc() async {
    if (allPosts.isEmpty || _festivalCollectionName == null) return;
    final id = allPosts.last.postId;
    if (id == null || id.isEmpty) return;
    var snap = _feedCursorDocByPostId[id];
    if (snap == null) {
      if (kDebugMode) {
        print('[FestivalFeed] cursorSync: cache MISS lastPostId=$id -> GET');
      }
      try {
        snap = await _firestoreService.getGlobalFeedPostSnapshot(
          id,
          collectionName: _festivalCollectionName,
        );
        if (snap != null) {
          _feedCursorDocByPostId[id] = snap;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[FestivalFeed] cursorSync: fallback GET failed id=$id: $e');
        }
      }
    }
    if (snap != null) {
      _lastDocument = snap;
    } else if (kDebugMode) {
      print('[FestivalFeed] cursorSync: no snapshot for last post id=$id');
    }
  }

  void _capDetachedOlderTail() {
    if (_detachedOlderTail.length <= _maxDetachedOlderPosts) return;
    final dropped = _detachedOlderTail.length - _maxDetachedOlderPosts;
    for (var i = _maxDetachedOlderPosts; i < _detachedOlderTail.length; i++) {
      final id = _detachedOlderTail[i].postId;
      if (id != null && id.isNotEmpty) {
        _feedCursorDocByPostId.remove(id);
      }
    }
    _detachedOlderTail.removeRange(
      _maxDetachedOlderPosts,
      _detachedOlderTail.length,
    );
    if (kDebugMode) {
      print(
        '[FestivalFeed] bufferCap: dropped $dropped detached rows (remaining=${_detachedOlderTail.length})',
      );
    }
  }

  bool _trimAllPostsIfOverMemoryCap() {
    var trimmed = false;
    while (allPosts.length > _maxLoadedFeedPosts) {
      if (allPosts.length < _feedMemoryTrimChunk) break;
      final start = allPosts.length - _feedMemoryTrimChunk;
      final removed = List<PostModel>.from(allPosts.sublist(start));
      allPosts.removeRange(start, allPosts.length);
      _detachedOlderTail.insertAll(0, removed);
      _capDetachedOlderTail();
      trimmed = true;
    }
    return trimmed;
  }

  Future<void> restoreDetachedOlderPosts() async {
    if (isDisposed) return;
    if (_isLoadingMore) return;
    if (_detachedOlderTail.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final chunk = List<PostModel>.from(_detachedOlderTail);
      _detachedOlderTail.clear();

      final room = _maxLoadedFeedPosts - allPosts.length;
      if (room <= 0) {
        _detachedOlderTail.insertAll(0, chunk);
        return;
      }

      final existingIds = <String>{
        for (final p in allPosts)
          if (p.postId != null && p.postId!.isNotEmpty) p.postId!,
      };
      final deduped = <PostModel>[];
      for (final p in chunk) {
        final id = p.postId;
        if (id == null || id.isEmpty) continue;
        if (existingIds.contains(id)) continue;
        existingIds.add(id);
        deduped.add(p);
      }

      final takeCount =
          deduped.length < room ? deduped.length : room;
      final attach = deduped.sublist(0, takeCount);
      final remainder = deduped.sublist(takeCount);
      if (remainder.isNotEmpty) {
        _detachedOlderTail.insertAll(0, remainder);
        _capDetachedOlderTail();
      }

      if (attach.isEmpty) {
        _detachedOlderTail.insertAll(0, chunk);
        await _syncPaginationCursorFromCachedDoc();
        if (!isDisposed) {
          _pruneFeedCursorDocsToStoredPosts();
          _applyFilterNotifyIfChanged();
        }
        return;
      }

      final enrichStart = allPosts.length;
      allPosts.addAll(attach);

      await _enrichPostsWithUserPhotos(
        indices: List<int>.generate(attach.length, (i) => i + enrichStart),
      );
      final attachIds = attach
          .map((p) => p.postId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      await _loadUserReactions(postIds: attachIds);

      _pruneFeedCursorDocsToStoredPosts();
      await _syncPaginationCursorFromCachedDoc();

      if (!isDisposed) {
        _applyFilterNotifyIfChanged();
      }
    } catch (e) {
      if (kDebugMode) print('[FestivalFeed] restore: $e');
    } finally {
      if (!isDisposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Ensure collection exists by creating a metadata document if collection is empty
  /// This makes the collection visible in Firestore console even when there are no posts
  Future<void> _ensureCollectionExists() async {
    if (_festivalCollectionName == null || isDisposed) return;

    try {
      // Import Firestore to access collection directly
      final firestore = FirebaseFirestore.instance;
      
      // Check if collection has any documents
      final collectionRef = firestore.collection(_festivalCollectionName!);
      final snapshot = await collectionRef.limit(1).get();
      
      // If collection is empty, create a metadata document
      if (snapshot.docs.isEmpty) {
        await collectionRef.doc('_metadata').set({
          'type': 'collection_metadata',
          'createdAt': FieldValue.serverTimestamp(),
          'festivalCollectionName': _festivalCollectionName,
        }, SetOptions(merge: true));
        
        if (kDebugMode) {
          print('📝 Created metadata document for empty collection: $_festivalCollectionName');
        }
      }
    } catch (e) {
      // Don't throw - this is optional and shouldn't block the UI
      if (kDebugMode) {
        print('⚠️ Error ensuring collection exists: $e');
      }
    }
  }

  /// Real-time updates for the festival collection — capped at [_realtimeStreamPostLimit].
  void _startPostsListener() {
    if (isDisposed || _festivalCollectionName == null) return;

    _postsSubscription?.cancel();
    _postsSubscription = null;

    _postsSubscription = _firestoreService
        .getPostsStream(
          limit: _realtimeStreamPostLimit,
          collectionName: _festivalCollectionName,
        )
        .listen(
          (postsData) async {
            if (isDisposed) return;

            final loadedPostIds = allPosts
                .where((post) => post.postId != null)
                .map((post) => post.postId!)
                .toSet();

            final newPostsData = <Map<String, dynamic>>[];
            final existingPostsData = <Map<String, dynamic>>[];

            for (var data in postsData) {
              final postId = data['postId'] as String?;
              if (postId != null) {
                if (loadedPostIds.contains(postId)) {
                  existingPostsData.add(data);
                } else {
                  newPostsData.add(data);
                }
              }
            }

            if (newPostsData.isNotEmpty) {
              final newestCreatedAt = allPosts.isNotEmpty && allPosts.first.createdAt != null
                  ? allPosts.first.createdAt!
                  : null;

              final newPosts = <PostModel>[];
              for (var data in newPostsData) {
                try {
                  var newPost = PostModel.fromFirestore(
                    _createDocumentSnapshot(data),
                  );
                  if (newPost.userId == null || newPost.userId!.isEmpty) continue;
                  if (newPost.sourceCollection == null) {
                    newPost = newPost.copyWith(sourceCollection: _festivalCollectionName);
                  }
                  if (newestCreatedAt == null ||
                      (newPost.createdAt != null && newPost.createdAt!.isAfter(newestCreatedAt))) {
                    newPosts.add(newPost);
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error parsing new festival post: $e');
                  }
                }
              }

              if (newPosts.isNotEmpty) {
                newPosts.sort((a, b) {
                  final aTime = a.createdAt ?? DateTime(0);
                  final bTime = b.createdAt ?? DateTime(0);
                  return bTime.compareTo(aTime);
                });
                final newestNewPost = newPosts.first;
                if (newestNewPost.createdAt != null) {
                  if (_newestPostTimestamp == null ||
                      newestNewPost.createdAt!.isAfter(_newestPostTimestamp!)) {
                    _newestPostTimestamp = newestNewPost.createdAt;
                  }
                }
                allPosts.insertAll(0, newPosts);

                await _enrichPostsWithUserPhotos(
                  indices: List<int>.generate(newPosts.length, (i) => i),
                );

                await _loadUserReactions(
                  postIds: newPosts
                      .map((p) => p.postId)
                      .whereType<String>()
                      .where((id) => id.isNotEmpty)
                      .toList(),
                );

                if (kDebugMode) {
                  print('✅ [RumorsVM] Added ${newPosts.length} new post(s) from stream');
                }
              }
            }

            final updatedPostsMap = <String, PostModel>{};
            for (var post in allPosts) {
              if (post.postId != null) {
                updatedPostsMap[post.postId!] = post;
              }
            }

            for (var data in existingPostsData) {
              final postId = data['postId'] as String?;
              if (postId != null && loadedPostIds.contains(postId)) {
                try {
                  final oldPost = updatedPostsMap[postId] ?? allPosts.firstWhere(
                    (p) => p.postId == postId,
                    orElse: () => PostModel(
                      postId: postId,
                      username: 'Unknown',
                      timeAgo: 'Unknown',
                      content: '',
                      imagePath: '',
                      likes: 0,
                      comments: 0,
                      status: 'live',
                    ),
                  );

                  var updatedPost = PostModel.fromFirestore(
                    _createDocumentSnapshot(data),
                  );
                  if (updatedPost.sourceCollection == null) {
                    updatedPost = updatedPost.copyWith(sourceCollection: _festivalCollectionName);
                  }
                  // Preserve reaction AND cache-enriched photo/username from oldPost.
                  // Post documents bake in photo/username at creation time and are never
                  // retroactively updated — the in-memory enriched values are always fresher.
                  final postWithReaction = updatedPost.copyWith(
                    userReaction: oldPost.userReaction,
                    userPhotoUrl: oldPost.userPhotoUrl ?? updatedPost.userPhotoUrl,
                    username: oldPost.username.isNotEmpty
                        ? oldPost.username
                        : updatedPost.username,
                  );
                  updatedPostsMap[postId] = postWithReaction;
                } catch (e) {
                  if (kDebugMode) {
                    print('Error parsing post update: $e');
                  }
                }
              }
            }

            var reactionsChanged = false;
            final idsForReactionRefresh = <String>{};
            allPosts = allPosts.map((post) {
              if (post.postId != null && updatedPostsMap.containsKey(post.postId)) {
                final updatedPost = updatedPostsMap[post.postId]!;
                if (post.reactionCounts != updatedPost.reactionCounts) {
                  reactionsChanged = true;
                  idsForReactionRefresh.add(post.postId!);
                }
                return updatedPost;
              }
              return post;
            }).toList();

            if (reactionsChanged && idsForReactionRefresh.isNotEmpty) {
              await _loadUserReactions(postIds: idsForReactionRefresh.toList());
            }

            if (!isDisposed) {
              _applyFilterNotifyIfChanged();
            }
          },
          onError: (error, stackTrace) {
            if (kDebugMode) {
              print('Error in festival posts stream: $error');
            }
            final exception = ExceptionMapper.mapToAppException(error, stackTrace);
            _errorHandler.handleError(
              exception,
              stackTrace,
              'RumorsViewModel._startPostsListener',
            );
          },
          cancelOnError: false,
        );

    _sharedPostsSubscription?.cancel();
    if (kDebugMode) {
      print('🔄 [RumorsVM] Starting shared posts stream for: $_festivalCollectionName');
    }
    _sharedPostsSubscription = _firestoreService
        .getSharedPostsStream(_festivalCollectionName!)
        .listen(
          (sharedData) {
            if (isDisposed) return;
            if (kDebugMode) {
              print('🔄 [RumorsVM] Shared stream fired with ${sharedData.length} posts');
            }
            bool changed = false;

            final streamMap = <String, PostModel>{};
            for (var postData in sharedData) {
              try {
                var post = PostModel.fromFirestore(
                  _createDocumentSnapshot(postData),
                );
                if (post.postId != null &&
                    post.userId != null &&
                    post.userId!.isNotEmpty) {
                  if (post.sourceCollection == null) {
                    post = post.copyWith(sourceCollection: FirestoreService.defaultPostsCollection);
                  }
                  streamMap[post.postId!] = post;
                }
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ [RumorsVM] Error parsing shared post: $e');
                }
              }
            }

            if (kDebugMode) {
              print('🔄 [RumorsVM] Parsed ${streamMap.length} valid shared posts from stream');
              print('🔄 [RumorsVM] Current allPosts count: ${allPosts.length}');
              for (final entry in streamMap.entries) {
                final p = entry.value;
                print('   streamPost: id=${p.postId}, comments=${p.comments}, likes=${p.likes}, source=${p.sourceCollection}');
              }
            }

            for (int i = 0; i < allPosts.length; i++) {
              final existing = allPosts[i];
              if (existing.postId != null && streamMap.containsKey(existing.postId)) {
                final updated = streamMap[existing.postId]!;
                if (kDebugMode) {
                  print('🔍 [RumorsVM] Comparing postId=${existing.postId}: '
                      'comments ${existing.comments}->${updated.comments}, '
                      'likes ${existing.likes}->${updated.likes}');
                }
                if (existing.comments != updated.comments ||
                    existing.likes != updated.likes ||
                    existing.reactionCounts != updated.reactionCounts ||
                    existing.content != updated.content) {
                  allPosts[i] = updated.copyWith(
                    userReaction: existing.userReaction,
                    userPhotoUrl: existing.userPhotoUrl ?? updated.userPhotoUrl,
                    username: existing.username.isNotEmpty
                        ? existing.username
                        : updated.username,
                  );
                  changed = true;
                  if (kDebugMode) {
                    print('✅ [RumorsVM] Updated shared post ${existing.postId}');
                  }
                }
                streamMap.remove(existing.postId);
              }
            }

            if (streamMap.isNotEmpty && kDebugMode) {
              print('➕ [RumorsVM] Adding ${streamMap.length} new shared posts');
            }
            for (final post in streamMap.values) {
              allPosts.add(post);
              changed = true;
            }

            if (kDebugMode) {
              print('🔄 [RumorsVM] Changed=$changed');
            }
            if (changed) {
              allPosts.sort((a, b) {
                final aTime = a.createdAt ?? DateTime(0);
                final bTime = b.createdAt ?? DateTime(0);
                return bTime.compareTo(aTime);
              });
              _applyFilterNotifyIfChanged();
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('❌ [RumorsVM] Shared posts stream error: $error');
            }
          },
        );

    // Periodic refresh to catch count changes on shared posts (the ref stream
    // only fires when refs are added/removed, not when the source post updates).
    _sharedPostsRefreshTimer?.cancel();
    _sharedPostsRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshSharedPostCounts(),
    );
  }

  /// Re-fetch shared posts to pick up count changes (comments, likes, reactions).
  Future<void> _refreshSharedPostCounts() async {
    if (isDisposed || _festivalCollectionName == null) return;

    try {
      final freshPosts = await _firestoreService
          .getPostsSharedToFestival(_festivalCollectionName!);
      if (isDisposed) return;

      bool changed = false;
      final freshMap = <String, Map<String, dynamic>>{};
      for (final data in freshPosts) {
        final id = data['postId'] as String?;
        if (id != null) freshMap[id] = data;
      }

      for (int i = 0; i < allPosts.length; i++) {
        final existing = allPosts[i];
        if (existing.postId == null || !freshMap.containsKey(existing.postId)) continue;
        final freshData = freshMap[existing.postId]!;
        final freshComments = (freshData['comments'] as int?) ?? 0;
        final freshLikes = (freshData['likes'] as int?) ?? 0;
        if (existing.comments != freshComments || existing.likes != freshLikes) {
          var updated = PostModel.fromFirestore(
            _createDocumentSnapshot(freshData),
          );
          if (updated.sourceCollection == null) {
            final src = freshData['sourceCollection'] as String? ?? FirestoreService.defaultPostsCollection;
            updated = updated.copyWith(sourceCollection: src);
          }
          allPosts[i] = updated.copyWith(
            userReaction: existing.userReaction,
            userPhotoUrl: existing.userPhotoUrl ?? updated.userPhotoUrl,
            username: existing.username.isNotEmpty
                ? existing.username
                : updated.username,
          );
          changed = true;
        }
      }

      if (changed && !isDisposed) {
        _applyFilterNotifyIfChanged();
      }
    } catch (_) {}
  }

  /// Enrich posts with userPhotoUrl/displayName via cache.
  /// Pass [indices] to only process those rows (prepend / pagination).
  Future<void> _enrichPostsWithUserPhotos({List<int>? indices}) async {
    if (isDisposed) return;

    try {
      final postsToEnrich = <int, String>{};
      final idxList = indices ??
          List<int>.generate(allPosts.length, (i) => i);

      for (final i in idxList) {
        if (i < 0 || i >= allPosts.length) continue;
        final post = allPosts[i];
        if (post.userId != null && post.userId!.isNotEmpty) {
          postsToEnrich[i] = post.userId!;
        }
      }

      if (postsToEnrich.isEmpty) return;

      final uniqueUserIds = postsToEnrich.values.toSet().toList();
      final userDataMap = await _userPhotoCacheService.batchFetch(uniqueUserIds);

      if (isDisposed) return;

      int enrichedCount = 0;
      for (final entry in postsToEnrich.entries) {
        final index = entry.key;
        final userId = entry.value;
        final photoUrl = userDataMap[userId];
        final displayName = _userPhotoCacheService.getCachedDisplayName(userId);

        bool changed = false;
        String? newPhoto;
        String? newName;

        if (photoUrl != null && photoUrl.isNotEmpty &&
            allPosts[index].userPhotoUrl != photoUrl) {
          newPhoto = photoUrl;
          changed = true;
        }
        if (displayName != null && displayName.isNotEmpty &&
            allPosts[index].username != displayName) {
          newName = displayName;
          changed = true;
        }

        if (changed) {
          allPosts[index] = allPosts[index].copyWith(
            userPhotoUrl: newPhoto,
            username: newName,
          );
          enrichedCount++;
        }
      }

      if (enrichedCount > 0) {
        _applyFilterNotifyIfChanged();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enriching posts with userPhotoUrl: $e');
      }
    }
  }

  /// Load user reactions. Pass [postIds] to limit work; omit for all loaded posts.
  Future<void> _loadUserReactions({List<String>? postIds}) async {
    if (isDisposed) return;
    if (postIds != null && postIds.isEmpty) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final idSet = postIds != null ? postIds.toSet() : null;

      final byCollection = <String, List<String>>{};
      for (final post in allPosts) {
        if (post.postId == null) continue;
        if (idSet != null && !idSet.contains(post.postId)) continue;
        final col = post.sourceCollection ?? _festivalCollectionName ?? FirestoreService.defaultPostsCollection;
        (byCollection[col] ??= []).add(post.postId!);
      }

      if (byCollection.values.every((list) => list.isEmpty)) return;

      final allReactions = <String, String>{};
      for (final entry in byCollection.entries) {
        if (entry.value.isEmpty) continue;
        final reactions = await _firestoreService.getUserReactions(
          entry.value,
          currentUser.uid,
          collectionName: entry.key,
        );
        allReactions.addAll(reactions);
      }

      if (isDisposed) return;

      for (int i = 0; i < allPosts.length; i++) {
        final post = allPosts[i];
        if (post.postId != null && allReactions.containsKey(post.postId)) {
          allPosts[i] = post.copyWith(
            userReaction: allReactions[post.postId],
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user reactions: $e');
      }
    }
  }

  /// Load more posts (pagination)
  Future<void> loadMorePosts() async {
    if (isDisposed) return;
    if (_isLoadingMore || !_hasMorePosts || _festivalCollectionName == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      await _syncPaginationCursorFromCachedDoc();

      final result = await _firestoreService.getPostsPaginated(
        limit: _loadMoreLimit,
        lastDocument: _lastDocument,
        collectionName: _festivalCollectionName,
      );

      _mergeDocSnapshotsFromPaginatedResult(result);

      final postsData = result['posts'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'];
      _hasMorePosts = result['hasMore'] as bool? ?? false;

      final newPosts = postsData.map((data) {
        try {
          var post = PostModel.fromFirestore(_createDocumentSnapshot(data));
          if (post.userId == null || post.userId!.isEmpty) return null;
          if (post.sourceCollection == null) {
            post = post.copyWith(sourceCollection: _festivalCollectionName);
          }
          return post;
        } catch (e) {
          if (kDebugMode) print('Error parsing post: $e');
          return null;
        }
      }).whereType<PostModel>().toList();

      final existingIds = <String>{
        for (final p in allPosts)
          if (p.postId != null && p.postId!.isNotEmpty) p.postId!,
      };
      final uniqueNewPosts = <PostModel>[];
      for (final p in newPosts) {
        final id = p.postId;
        if (id == null || id.isEmpty) continue;
        if (existingIds.contains(id)) continue;
        existingIds.add(id);
        uniqueNewPosts.add(p);
      }

      if (isDisposed) return;

      if (newPosts.isEmpty) {
        _hasMorePosts = false;
      } else if (uniqueNewPosts.isEmpty) {
        _pruneFeedCursorDocsToStoredPosts();
      } else {
        final enrichStart = allPosts.length;
        allPosts.addAll(uniqueNewPosts);
        await _enrichPostsWithUserPhotos(
          indices:
              List<int>.generate(uniqueNewPosts.length, (i) => i + enrichStart),
        );
        await _loadUserReactions(
          postIds: uniqueNewPosts
              .map((p) => p.postId)
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList(),
        );
        final didTrim = _trimAllPostsIfOverMemoryCap();
        if (didTrim) {
          await _syncPaginationCursorFromCachedDoc();
        }
        _pruneFeedCursorDocsToStoredPosts();
      }

      _applyFilterNotifyIfChanged();
    } catch (e) {
      if (kDebugMode) {
        print('[FestivalFeed] loadMore: $e');
      }
    } finally {
      if (!isDisposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Refresh posts after comment (to update comment counts)
  Future<void> refreshPostsAfterComment() async {
    if (_festivalCollectionName == null) return;
    
    try {
      await _loadUserReactions();
      _applyFilterNotifyIfChanged();
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing posts after comment: $e');
      }
    }
  }

  /// Filtered slice of [allPosts] (search + status).
  List<PostModel> _computeFilteredPosts() {
    final searchLower = searchQuery.toLowerCase();
    final hasSearch = searchQuery.isNotEmpty;

    return allPosts.where((post) {
      if (post.userId == null || post.userId!.isEmpty) return false;

      if (selectedFilter == AppStrings.live && post.status != AppStrings.live) {
        return false;
      } else if (selectedFilter == AppStrings.upcoming && post.status != AppStrings.upcoming) {
        return false;
      } else if (selectedFilter == AppStrings.past && post.status != AppStrings.past) {
        return false;
      }

      if (hasSearch) {
        final usernameLower = post.username.toLowerCase();
        final contentLower = post.content.toLowerCase();
        if (!usernameLower.contains(searchLower) && !contentLower.contains(searchLower)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  static bool _feedRowsVisuallyEqual(PostModel a, PostModel b) {
    if (identical(a, b)) return true;
    return a.postId == b.postId &&
        a.comments == b.comments &&
        a.likes == b.likes &&
        a.totalReactions == b.totalReactions &&
        a.userReaction == b.userReaction &&
        a.username == b.username &&
        a.userPhotoUrl == b.userPhotoUrl &&
        a.content == b.content &&
        a.status == b.status &&
        a.timeAgo == b.timeAgo &&
        a.imagePath == b.imagePath &&
        a.isVideo == b.isVideo &&
        a.postUrl == b.postUrl &&
        a.linkPreviewImageUrl == b.linkPreviewImageUrl &&
        a.linkPreviewTitle == b.linkPreviewTitle &&
        _reactionMapsEqual(a.reactionCounts, b.reactionCounts) &&
        _stringListsEqual(a.mediaPaths, b.mediaPaths) &&
        _boolListsEqual(a.isVideoList, b.isVideoList);
  }

  static bool _reactionMapsEqual(Map<String, int>? a, Map<String, int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _stringListsEqual(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _boolListsEqual(List<bool>? a, List<bool>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _filteredSnapshotsEqual(List<PostModel> a, List<PostModel> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_feedRowsVisuallyEqual(a[i], b[i])) return false;
    }
    return true;
  }

  void _applyFilterNotifyIfChanged() {
    if (isDisposed) return;
    final next = _computeFilteredPosts();
    if (_filteredSnapshotsEqual(posts, next)) return;
    posts = next;
    notifyListeners();
  }

  /// Set filter (all, live, upcoming, past)
  void setFilter(String filter) {
    selectedFilter = filter;
    posts = _computeFilteredPosts();
    notifyListeners();
  }

  // Search methods
  void setSearchQuery(String query) {
    searchQuery = query;
    posts = _computeFilteredPosts();
    notifyListeners();
  }

  void clearSearch() {
    searchQuery = '';
    searchController.clear();
    posts = _computeFilteredPosts();
    notifyListeners();
  }

  void unfocusSearch() {
    if (isDisposed) return;
    
    try {
      searchFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) print('Error unfocusing search: $e');
    }
  }

  String get currentSearchQuery => searchQuery;

  /// Update user reaction for a post
  /// 
  /// [postIndex] - Index of the post in the posts list
  /// [emotion] - The emoji/emotion string (e.g., '👍', '❤️', '😂', etc.)
  Future<void> updatePostReaction(int postIndex, String emotion) async {
    if (postIndex < 0 || postIndex >= posts.length || _festivalCollectionName == null) return;

    final post = posts[postIndex];
    final currentUser = _authService.currentUser;

    if (post.postId == null || currentUser == null) return;

    try {
      final previousEmotion = post.userReaction;
      
      // Update reaction counts locally
      final updatedCounts = Map<String, int>.from(post.reactionCounts ?? {});
      
      // Decrement previous emotion count if changing
      if (previousEmotion != null && previousEmotion.isNotEmpty) {
        final prevCount = updatedCounts[previousEmotion] ?? 0;
        if (prevCount > 0) {
          updatedCounts[previousEmotion] = prevCount - 1;
        } else {
          updatedCounts.remove(previousEmotion);
        }
      }
      
      // Increment new emotion count
      final currentCount = updatedCounts[emotion] ?? 0;
      updatedCounts[emotion] = currentCount + 1;

      // Update local state immediately for responsive UI
      posts[postIndex] = post.copyWith(
        userReaction: emotion,
        reactionCounts: updatedCounts,
      );
      
      // Also update in allPosts
      final allPostsIndex = allPosts.indexWhere((p) => p.postId == post.postId);
      if (allPostsIndex >= 0) {
        allPosts[allPostsIndex] = allPosts[allPostsIndex].copyWith(
          userReaction: emotion,
          reactionCounts: updatedCounts,
        );
      }

      notifyListeners();

      // Save to Firestore in background
      await _firestoreService.saveUserReaction(
        post.postId!,
        currentUser.uid,
        emotion,
        previousEmotion: previousEmotion,
        collectionName: post.sourceCollection ?? _festivalCollectionName,
      );

      if (kDebugMode) {
        print('Reaction updated: postId=${post.postId}, emotion=$emotion, previousEmotion=$previousEmotion');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating reaction: $e');
      }
      // Revert local state on error
      final originalPost = post;
      posts[postIndex] = originalPost;
      final allPostsIndex = allPosts.indexWhere((p) => p.postId == post.postId);
      if (allPostsIndex >= 0) {
        allPosts[allPostsIndex] = originalPost;
      }
      notifyListeners();
    }
  }

  /// Remove user reaction from a post
  /// 
  /// [postIndex] - Index of the post in the posts list
  Future<void> removePostReaction(int postIndex) async {
    if (postIndex < 0 || postIndex >= posts.length || _festivalCollectionName == null) return;

    final post = posts[postIndex];
    final currentUser = _authService.currentUser;

    if (post.postId == null || currentUser == null) return;

    final emotionToRemove = post.userReaction;
    if (emotionToRemove == null) return; // No reaction to remove

    try {
      // Update reaction counts locally
      final updatedCounts = Map<String, int>.from(post.reactionCounts ?? {});
      
      // Decrement emotion count
      final currentCount = updatedCounts[emotionToRemove] ?? 0;
      if (currentCount > 1) {
        updatedCounts[emotionToRemove] = currentCount - 1;
      } else {
        updatedCounts.remove(emotionToRemove);
      }

      // Update local state immediately
      posts[postIndex] = post.copyWith(
        userReaction: null,
        reactionCounts: updatedCounts,
      );
      
      // Also update in allPosts
      final allPostsIndex = allPosts.indexWhere((p) => p.postId == post.postId);
      if (allPostsIndex >= 0) {
        allPosts[allPostsIndex] = allPosts[allPostsIndex].copyWith(
          userReaction: null,
          reactionCounts: updatedCounts,
        );
      }

      notifyListeners();

      // Remove from Firestore in background
      await _firestoreService.removeUserReaction(
        post.postId!,
        currentUser.uid,
        emotionToRemove,
        collectionName: post.sourceCollection ?? _festivalCollectionName,
      );

      if (kDebugMode) {
        print('Reaction removed: postId=${post.postId}, emotion=$emotionToRemove');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing reaction: $e');
      }
      // Revert local state on error
      final originalPost = post;
      posts[postIndex] = originalPost;
      final allPostsIndex = allPosts.indexWhere((p) => p.postId == post.postId);
      if (allPostsIndex >= 0) {
        allPosts[allPostsIndex] = originalPost;
      }
      notifyListeners();
    }
  }

  /// Navigate to create post screen
  Future<void> goToCreatePost() async {
    if (_festivalCollectionName == null) {
      if (kDebugMode) {
        print('⚠️ Festival collection not set, cannot create post');
      }
      return;
    }
    
    // Navigate to create post with festival collection context
    final createdPost = await _navigationService.navigateTo<PostModel>(
      AppRoutes.createPost,
      arguments: _festivalCollectionName, // Pass collection name as argument
    );
    
    // If a post was created, the real-time stream listener will automatically pick it up from Firestore
    // No need to add it locally - this prevents duplicates and ensures we get the latest data
    if (createdPost != null && createdPost.postId != null) {
      if (kDebugMode) {
        print('✅ Post created. Real-time listener will add it from Firestore.');
      }
      // The stream listener will automatically detect and add the new post
      // No need to restart listener - it's already listening
    }
  }

  /// Navigate to subscription screen
  void goToSubscription() {
    _navigationService.navigateTo(AppRoutes.subscription);
  }

  /// Delete a post from the festival feed
  /// 
  /// [postId] - The post ID to delete
  /// [context] - BuildContext for showing dialogs
  Future<void> deletePost(String postId, BuildContext context) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ User not authenticated, cannot delete post');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to delete posts'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Find the post
    final postIndex = posts.indexWhere((p) => p.postId == postId);
    if (postIndex < 0) {
      if (kDebugMode) {
        print('⚠️ Post not found: $postId');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final post = posts[postIndex];

    // Verify the user owns the post
    if (post.userId != currentUser.uid) {
      if (kDebugMode) {
        print('⚠️ User does not own this post');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only delete your own posts'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check internet connectivity BEFORE showing loading dialog
    bool hasInternet = false;
    try {
      hasInternet = await _networkService.hasInternetConnection().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking internet connection: $e');
      }
      hasInternet = false;
    }

    // If no internet, show error immediately and return
    if (!hasInternet) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check your network and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      if (kDebugMode) {
        print('❌ No internet connection - aborting delete operation');
      }
      return;
    }

    // Show loading indicator only after confirming internet connection
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      await _firestoreService.deletePost(
        postId: postId,
        userId: currentUser.uid,
        collectionName: post.sourceCollection ?? _festivalCollectionName,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
            'Delete operation timed out. Please check your internet connection and try again.',
            const Duration(seconds: 15),
          );
        },
      );

      // Clear cached images for this post
      if (post.allMediaPaths.isNotEmpty) {
        for (final mediaUrl in post.allMediaPaths) {
          if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
            try {
              await CachedNetworkImage.evictFromCache(mediaUrl).timeout(
                const Duration(seconds: 5),
              );
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Error clearing cache for $mediaUrl: $e');
              }
              // Ignore cache clearing errors
            }
          }
        }
      }

      posts.removeAt(postIndex);
      final allPostsIndex = allPosts.indexWhere((p) => p.postId == postId);
      if (allPostsIndex >= 0) {
        allPosts.removeAt(allPostsIndex);
      }
      notifyListeners();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (kDebugMode) {
        print('✅ Post deleted successfully: $postId');
      }
    } on TimeoutException catch (e) {
      // Handle timeout specifically
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Operation timed out. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (kDebugMode) {
        print('❌ Timeout deleting post: $e');
      }
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors
      if (context.mounted) {
        Navigator.of(context).pop();
        String errorMessage = 'Failed to delete post. ';
        if (e.code == 'permission-denied') {
          errorMessage = 'You do not have permission to delete this post.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Service temporarily unavailable. Please check your internet connection and try again.';
        } else if (e.code == 'deadline-exceeded') {
          errorMessage = 'Operation timed out. Please check your internet connection and try again.';
        } else {
          errorMessage += 'Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (kDebugMode) {
        print('❌ Firebase error deleting post: ${e.code} - ${e.message}');
      }
    } catch (e) {
      // Handle other errors
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Provide user-friendly error message
        String errorMessage = 'Failed to delete post. ';
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('network') || errorString.contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
        } else if (errorString.contains('timeout')) {
          errorMessage = 'Operation timed out. Please check your internet connection and try again.';
        } else if (errorString.contains('permission') || errorString.contains('denied')) {
          errorMessage = 'You do not have permission to delete this post.';
        } else if (errorString.contains('not found')) {
          errorMessage = 'Post not found. It may have already been deleted.';
        } else {
          errorMessage += 'Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (kDebugMode) {
        print('❌ Error deleting post: $e');
      }
    }
  }

  Future<void> navigateToEditPost(BuildContext context, PostModel post) async {
    final result = await _navigationService.navigateTo<bool>(
      AppRoutes.editPost,
      arguments: post,
    );
    if (result == true) {
      refreshPostsAfterComment();
    }
  }

  dynamic _createDocumentSnapshot(Map<String, dynamic> data) {
    final postId = data['postId'] as String? ?? '';
    return _MockDocumentSnapshot(postId, data);
  }
}

/// Mock DocumentSnapshot for converting Map to PostModel
class _MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic> data;

  _MockDocumentSnapshot(this.id, this.data);

  String get docId => id;
  
  Map<String, dynamic>? get dataMap => data;
  
  dynamic operator [](String key) => data[key];
}
