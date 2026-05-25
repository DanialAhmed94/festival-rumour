import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../../../core/constants/app_durations.dart';
import 'post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/user_photo_cache_service.dart';

class HomeViewModel extends BaseViewModel {
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
  
  // Pagination state
  dynamic _lastDocument; // Last document for pagination
  bool _hasMorePosts = true; // Whether there are more posts to load
  bool _isLoadingMore = false; // Whether we're currently loading more posts
  static const int _initialLimit = 10; // Initial number of posts to load
  static const int _loadMoreLimit = 10; // Number of posts to load per "load more"
  /// In-memory cap: when exceeded, drop the oldest [_feedMemoryTrimChunk] into [_detachedOlderTail]
  /// so the list stays bounded; user can restore from the buffer via [restoreDetachedOlderPosts].
  /// If [_maxLoadedFeedPosts] is too small (e.g. ≤ [_initialLimit]), the first "load more"
  /// fills over the cap and trim removes the newly loaded tail; the visible list stays at the
  /// initial length even though Firestore returned more documents.
  static const int _maxLoadedFeedPosts = 100;
  static const int _feedMemoryTrimChunk = 50;
  /// Posts removed from the tail (oldest) kept for re-attach when user scrolls near the bottom again.
  final List<PostModel> _detachedOlderTail = [];
  /// Firestore [DocumentSnapshot]s from paginated queries, keyed by post id — used to set [_lastDocument]
  /// without an extra `doc(id).get()` after trim/restore.
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _feedCursorDocByPostId = {};
  static const int _maxDetachedOlderPosts = 200;
  /// Fixed Firestore limit for the global feed snapshot stream (newest-first).
  /// Does not grow with pagination — see Phase 2 / docs. Older paginated rows may
  /// not receive live metadata updates until refresh.
  static const int _realtimeStreamPostLimit = 80;
  
  bool get hasMorePosts => _hasMorePosts;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasDetachedOlderChunk => _detachedOlderTail.isNotEmpty;

  /// Detached-tail buffer size (trim stash); for diagnostics / debug logs only.
  int get detachedBufferLength => _detachedOlderTail.length;

  HomeViewModel() {
    searchFocusNode = FocusNode();
    searchController.addListener(() {
      if (searchController.text != searchQuery) {
        setSearchQuery(searchController.text);
      }
    });
    // Re-enrich feed posts immediately when a user's photo/name is updated
    // in the cache (e.g. after the user edits their profile in Settings).
    _userPhotoCacheService.addListener(_onUserPhotoCacheUpdated);
  }

  /// Synchronous pass: update any allPosts entries whose cached photo/name
  /// differs from what the PostModel currently holds.
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

    posts.clear();
    allPosts.clear();
    _detachedOlderTail.clear();
    _feedCursorDocByPostId.clear();

    searchFocusNode.dispose();
    searchController.dispose();
    
    super.onDispose();
  }

  /// Real-time updates for the newest posts only, capped at [_realtimeStreamPostLimit].
  /// Pagination adds older posts that are outside this window — they update on
  /// pull-refresh / re-entry, not every snapshot (see product doc).
  void _startPostsListener() {
    if (isDisposed) return;

    // Cancel existing subscription if any
    _postsSubscription?.cancel();
    _postsSubscription = null;

    _postsSubscription = _firestoreService
        .getPostsStream(limit: _realtimeStreamPostLimit)
        .listen(
          (postsData) async {
            // Check if disposed before processing
            if (isDisposed) return;

            // Create a set of loaded post IDs for quick lookup
            final loadedPostIds = allPosts
                .where((post) => post.postId != null)
                .map((post) => post.postId!)
                .toSet();

            // Separate new posts from existing posts
            final newPostsData = <Map<String, dynamic>>[];
            final existingPostsData = <Map<String, dynamic>>[];

            for (var data in postsData) {
              final postId = data['postId'] as String?;
              if (postId != null) {
                if (loadedPostIds.contains(postId)) {
                  existingPostsData.add(data);
                } else {
                  // This is a new post created by another user
                  newPostsData.add(data);
                }
              }
            }

            // Process new posts: only prepend posts that are actually newer than our current newest.
            // (Stream limit can be larger than our list, so "not in loadedPostIds" may be older posts.)
            if (newPostsData.isNotEmpty) {
              final newestCreatedAt = allPosts.isNotEmpty && allPosts.first.createdAt != null
                  ? allPosts.first.createdAt!
                  : null;

              final newPosts = <PostModel>[];
              for (var data in newPostsData) {
                try {
                  final newPost = PostModel.fromFirestore(
                    _createDocumentSnapshot(data),
                  );
                  if (newPost.userId == null || newPost.userId!.isEmpty) continue;
                  // Only treat as new if it's actually newer than our current top (or we have no posts)
                  if (newestCreatedAt == null ||
                      (newPost.createdAt != null && newPost.createdAt!.isAfter(newestCreatedAt))) {
                    newPosts.add(newPost);
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error parsing new post: $e');
                  }
                }
              }

              // Sort by createdAt descending so newest is first, then add to the beginning
              if (newPosts.isNotEmpty) {
                newPosts.sort((a, b) {
                  final aTime = a.createdAt ?? DateTime(0);
                  final bTime = b.createdAt ?? DateTime(0);
                  return bTime.compareTo(aTime);
                });
                allPosts.insertAll(0, newPosts);

                // Enrich only the prepended rows (indices 0..newCount-1 after insert)
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
                  print('✅ Added ${newPosts.length} new post(s) to list. Total posts: ${allPosts.length}');
                }
              }
            }

            // Update existing posts with real-time data
            final updatedPostsMap = <String, PostModel>{};
            for (var post in allPosts) {
              if (post.postId != null) {
                updatedPostsMap[post.postId!] = post;
              }
            }

            // Update posts that exist in both stream and our loaded list
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
                  
                  final updatedPost = PostModel.fromFirestore(
                    _createDocumentSnapshot(data),
                  );
                  
                  // Preserve user reaction from old post (it's loaded separately).
                  // Also preserve the cache-enriched photo/username: post documents store
                  // these at creation time and are never retroactively updated when a user
                  // changes their profile — the in-memory enriched values are always fresher.
                  final postWithReaction = updatedPost.copyWith(
                    userReaction: oldPost.userReaction,
                    userPhotoUrl: oldPost.userPhotoUrl ?? updatedPost.userPhotoUrl,
                    username: oldPost.username.isNotEmpty
                        ? oldPost.username
                        : updatedPost.username,
                  );
                  
                  // Check if comment count or reaction counts changed
                  if (oldPost.comments != postWithReaction.comments || 
                      oldPost.totalReactions != postWithReaction.totalReactions) {
                    if (kDebugMode) {
                      print('🔄 Post updated: postId=$postId');
                      print('   - Comments: ${oldPost.comments} -> ${postWithReaction.comments}');
                      print('   - Reactions: ${oldPost.totalReactions} -> ${postWithReaction.totalReactions}');
                    }
                  }
                  
                  updatedPostsMap[postId] = postWithReaction;
                } catch (e) {
                  if (kDebugMode) {
                    print('Error parsing post update: $e');
                  }
                }
              }
            }

            // Update allPosts with updated posts (preserve order)
            var reactionsChanged = false;
            final idsForReactionRefresh = <String>{};
            allPosts = allPosts.map((post) {
              if (post.postId != null && updatedPostsMap.containsKey(post.postId)) {
                final updatedPost = updatedPostsMap[post.postId]!;
                // Check if reaction counts changed
                if (post.reactionCounts != updatedPost.reactionCounts) {
                  reactionsChanged = true;
                  idsForReactionRefresh.add(post.postId!);
                }
                return updatedPost;
              }
              return post;
            }).toList();

            // Only reload the current user's reaction for posts whose counts changed
            if (reactionsChanged && idsForReactionRefresh.isNotEmpty) {
              await _loadUserReactions(postIds: idsForReactionRefresh.toList());
            }
            
            // Apply filter to update displayed posts
            if (!isDisposed) {
              _applyFilterNotifyIfChanged();
            }
          },
          onError: (error, stackTrace) {
            if (isDisposed) return;
            if (kDebugMode) {
              print('Error in posts stream: $error');
            }
            try {
              final exception = ExceptionMapper.mapToAppException(error, stackTrace);
              _errorHandler.handleError(exception, stackTrace, 'HomeViewModel._startPostsListener');
            } catch (e) {
              if (kDebugMode) {
                print('Error in error handler: $e');
              }
            }
          },
          cancelOnError: false,
        );
  }

  /// Load posts (one-time fetch, used for initialization or fallback)
  Future<void> loadPosts() async {
    await handleAsync(() async {
      // Fetch posts from Firestore
      final postsData = await _firestoreService.getPosts();
      
      // Single pass: parse and drop posts with null/empty userId (no extra iteration)
      allPosts = postsData.map((data) {
        try {
          final post = PostModel.fromFirestore(_createDocumentSnapshot(data));
          return (post.userId != null && post.userId!.isNotEmpty) ? post : null;
        } catch (e) {
          if (kDebugMode) print('Error parsing post: $e');
          return null;
        }
      }).whereType<PostModel>().toList();
      
      if (kDebugMode) {
        print('Loaded ${allPosts.length} posts from Firestore');
      }
      
      // Load user reactions for all posts
      await _loadUserReactions();
      
      // Apply initial filter
      _applyFilterNotifyIfChanged();
    },
    errorMessage: AppStrings.failedToLoadPosts,
    minimumLoadingDuration: AppDurations.minimumLoadingDuration);
  }

  /// Initialize posts (load initial batch and start real-time listener)
  Future<void> initialize() async {
    await loadInitialPosts();
  }

  /// Load initial posts (first 10 posts)
  Future<void> loadInitialPosts() async {
    if (isDisposed) return;

    await handleAsync(() async {
      setLoading(true);
      
      // Reset pagination state
      _lastDocument = null;
      _hasMorePosts = true;
      allPosts.clear();
      _detachedOlderTail.clear();
      _feedCursorDocByPostId.clear();

      // Load initial batch (10 posts)
      final result = await _firestoreService.getPostsPaginated(
        limit: _initialLimit,
        lastDocument: _lastDocument,
      );

      _mergeDocSnapshotsFromPaginatedResult(result);

      final postsData = result['posts'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'];
      _hasMorePosts = result['hasMore'] as bool? ?? false;

      // Single pass: parse and drop posts with null/empty userId (no extra iteration)
      allPosts = postsData.map((data) {
        try {
          final post = PostModel.fromFirestore(_createDocumentSnapshot(data));
          return (post.userId != null && post.userId!.isNotEmpty) ? post : null;
        } catch (e) {
          if (kDebugMode) print('Error parsing post: $e');
          return null;
        }
      }).whereType<PostModel>().toList();

      _pruneFeedCursorDocsToStoredPosts();

      if (kDebugMode) {
        print(
          '[GlobalFeed] initialLoad: parsed=${allPosts.length} '
          'hasMore=$_hasMorePosts initialLimit=$_initialLimit '
          'cursorDocCacheSize=${_feedCursorDocByPostId.length} '
          'detachedBuffer=${_detachedOlderTail.length}',
        );
      }

      // Enrich posts with userPhotoUrl from Firestore if missing
      await _enrichPostsWithUserPhotos();

      // Load user reactions for all posts
      await _loadUserReactions();

      // Apply initial filter
      _applyFilterNotifyIfChanged();

      // Start real-time listener to detect new posts and updates
      _startPostsListener();
    },
    errorMessage: AppStrings.failedToLoadPosts,
    minimumLoadingDuration: AppDurations.minimumLoadingDuration);
  }

  void _mergeDocSnapshotsFromPaginatedResult(Map<String, dynamic> result) {
    final raw = result['docSnapshotsByPostId'];
    if (raw == null || raw is! Map) return;
    var n = 0;
    raw.forEach((k, v) {
      if (k is String && v is DocumentSnapshot<Map<String, dynamic>>) {
        _feedCursorDocByPostId[k] = v;
        n++;
      }
    });
    if (kDebugMode && n > 0) {
      print('[GlobalFeed] cursorCacheMerge: merged $n snapshots (map size ${_feedCursorDocByPostId.length})');
    }
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
        '[GlobalFeed] cursorCachePrune: $before -> ${_feedCursorDocByPostId.length} '
        '(keepIds=${keep.length})',
      );
    }
  }

  /// Sets [_lastDocument] from the paginated-query cache, with a rare one-doc
  /// [getGlobalFeedPostSnapshot] fallback when the tail post has no cached snapshot.
  Future<void> _syncPaginationCursorFromCachedDoc() async {
    if (allPosts.isEmpty) return;
    final id = allPosts.last.postId;
    if (id == null || id.isEmpty) return;
    var snap = _feedCursorDocByPostId[id];
    if (snap == null) {
      if (kDebugMode) {
        print('[GlobalFeed] cursorSync: cache MISS lastPostId=$id -> fetching doc snapshot');
      }
      try {
        snap = await _firestoreService.getGlobalFeedPostSnapshot(id);
        if (snap != null) {
          _feedCursorDocByPostId[id] = snap;
          if (kDebugMode) {
            print('[GlobalFeed] cursorSync: fallback GET ok for $id');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('[GlobalFeed] cursorSync: fallback GET failed id=$id: $e');
        }
      }
    }
    if (snap != null) {
      _lastDocument = snap;
    } else if (kDebugMode) {
      print(
        '[GlobalFeed] cursorSync: no snapshot for last post id=$id',
      );
    }
  }

  /// Drops oldest detached rows and their cursor cache entries (bounded memory).
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
        '[GlobalFeed] bufferCap: dropped $dropped oldest detached rows '
        '(cap=$_maxDetachedOlderPosts, remaining=${_detachedOlderTail.length})',
      );
    }
  }

  /// Drops the oldest [_feedMemoryTrimChunk] rows into [_detachedOlderTail] while over [_maxLoadedFeedPosts].
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
      if (kDebugMode) {
        final ids =
            removed.map((p) => p.postId ?? '?').join(',');
        print(
          '[GlobalFeed] trimToCap: moved ${_feedMemoryTrimChunk} tail posts to detached buffer '
          'allPosts=${allPosts.length} detached=${_detachedOlderTail.length} '
          'maxCap=$_maxLoadedFeedPosts removedIds=[$ids]',
        );
      }
    }
    return trimmed;
  }

  /// Re-attaches posts previously trimmed into [_detachedOlderTail] (same Firestore order).
  Future<void> restoreDetachedOlderPosts() async {
    if (isDisposed) return;
    if (_isLoadingMore) {
      if (kDebugMode) {
        print('[GlobalFeed] restore: skip (isLoadingMore=true)');
      }
      return;
    }
    if (_detachedOlderTail.isEmpty) {
      if (kDebugMode) {
        print('[GlobalFeed] restore: skip (buffer empty)');
      }
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print(
          '[GlobalFeed] restore: start bufferSize=${_detachedOlderTail.length} '
          'allPosts=${allPosts.length} hasMore=$_hasMorePosts',
        );
      }
      final chunk = List<PostModel>.from(_detachedOlderTail);
      _detachedOlderTail.clear();

      final room = _maxLoadedFeedPosts - allPosts.length;
      if (room <= 0) {
        if (kDebugMode) {
          print(
            '[GlobalFeed] restore: no room (room=$room max=$_maxLoadedFeedPosts) '
            '-> re-queue chunk len=${chunk.length}',
          );
        }
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
        if (kDebugMode) {
          print(
            '[GlobalFeed] restore: attach empty (chunk=${chunk.length} deduped=${deduped.length}) '
            '-> re-queue full chunk',
          );
        }
        _detachedOlderTail.insertAll(0, chunk);
        await _syncPaginationCursorFromCachedDoc();
        if (!isDisposed) {
          _pruneFeedCursorDocsToStoredPosts();
          _applyFilterNotifyIfChanged();
        }
        return;
      }

      if (kDebugMode) {
        print(
          '[GlobalFeed] restore: attach=${attach.length} remainder=${remainder.length} '
          'room=$room bufferAfter=${_detachedOlderTail.length}',
        );
      }

      final enrichStart = allPosts.length;
      allPosts.addAll(attach);

      await _enrichPostsWithUserPhotos(
        indices: List<int>.generate(attach.length, (i) => i + enrichStart),
      );
      await _loadUserReactions(
        postIds: attach
            .map((p) => p.postId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(),
      );

      _pruneFeedCursorDocsToStoredPosts();
      await _syncPaginationCursorFromCachedDoc();

      if (kDebugMode) {
        print(
          '[GlobalFeed] restore: done allPosts=${allPosts.length} '
          'detached=${_detachedOlderTail.length}',
        );
      }

      if (!isDisposed) {
        _applyFilterNotifyIfChanged();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[GlobalFeed] restore: ERROR $e');
      }
    } finally {
      if (!isDisposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Load more posts (next batch)
  Future<void> loadMorePosts() async {
    if (isDisposed) return;
    if (_isLoadingMore) {
      if (kDebugMode) {
        print('[GlobalFeed] loadMore: skip (isLoadingMore=true)');
      }
      return;
    }
    if (!_hasMorePosts) {
      if (kDebugMode) {
        print(
          '[GlobalFeed] loadMore: skip (hasMore=false) '
          'detachedBuffer=${_detachedOlderTail.length}',
        );
      }
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print(
          '[GlobalFeed] loadMore: start allPosts=${allPosts.length} '
          'detached=${_detachedOlderTail.length} limit=$_loadMoreLimit',
        );
      }
      await _syncPaginationCursorFromCachedDoc();

      // Load next batch
      final result = await _firestoreService.getPostsPaginated(
        limit: _loadMoreLimit,
        lastDocument: _lastDocument,
      );

      _mergeDocSnapshotsFromPaginatedResult(result);

      final postsData = result['posts'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'];
      _hasMorePosts = result['hasMore'] as bool? ?? false;

      // Single pass: parse and drop posts with null/empty userId (no extra iteration)
      final newPosts = postsData.map((data) {
        try {
          final post = PostModel.fromFirestore(_createDocumentSnapshot(data));
          return (post.userId != null && post.userId!.isNotEmpty) ? post : null;
        } catch (e) {
          if (kDebugMode) print('Error parsing new post: $e');
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

      if (kDebugMode) {
        print(
          '[GlobalFeed] loadMore: raw page posts=${postsData.length} '
          'parsedOk=${newPosts.length} uniqueNew=${uniqueNewPosts.length} '
          'hasMore=$_hasMorePosts cursorCache=${_feedCursorDocByPostId.length}',
        );
      }

      // Check if disposed after async operation
      if (isDisposed) return;

      // If no new posts were loaded, there are no more posts
      if (newPosts.isEmpty) {
        _hasMorePosts = false;
        if (kDebugMode) {
          print('[GlobalFeed] loadMore: empty Firestore page -> hasMore=false');
        }
      } else if (uniqueNewPosts.isEmpty) {
        if (kDebugMode) {
          print(
            '[GlobalFeed] loadMore: duplicate-only page (cursor advanced via API lastDocument, '
            'no list append)',
          );
        }
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
          if (kDebugMode) {
            print('[GlobalFeed] loadMore: ran trim -> re-sync cursor');
          }
          await _syncPaginationCursorFromCachedDoc();
        }
        _pruneFeedCursorDocsToStoredPosts();

        if (kDebugMode) {
          print(
            '[GlobalFeed] loadMore: done allPosts=${allPosts.length} '
            'detached=${_detachedOlderTail.length} hasMore=$_hasMorePosts',
          );
        }
      }

      // Apply filter to include new posts (or refresh if nothing appended)
      _applyFilterNotifyIfChanged();

      // Realtime listener uses a fixed limit (Phase 2); do not resubscribe here —
      // avoids cancel/recreate churn on every page and keeps Firestore work bounded.
    } catch (e) {
      if (kDebugMode) {
        print('[GlobalFeed] loadMore: ERROR $e');
      }
      // Don't show error to user for load more failures
    } finally {
      if (!isDisposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Enrich posts with userPhotoUrl/displayName via cache.
  /// Pass [indices] to only process those rows (e.g. after prepend or pagination).
  /// Omit [indices] to process every loaded post (initial load / legacy [loadPosts]).
  Future<void> _enrichPostsWithUserPhotos({List<int>? indices}) async {
    if (isDisposed) return;

    try {
      final postsToEnrich = <int, String>{}; // index -> userId
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

      // Batch-fetch from cache (only hits Firestore for uncached users)
      final uniqueUserIds = postsToEnrich.values.toSet().toList();
      final userDataMap = await _userPhotoCacheService.batchFetch(uniqueUserIds);

      if (isDisposed) return;

      // Update posts with the latest photo URL and display name
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

  /// Load the current user's reactions. Pass [postIds] to merge reactions only for those posts
  /// (smaller fallback fan-out). Omit [postIds] to refresh all loaded posts.
  Future<void> _loadUserReactions({List<String>? postIds}) async {
    if (isDisposed) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final ids = postIds ??
          allPosts
              .where((post) => post.postId != null)
              .map((post) => post.postId!)
              .toList();

      if (ids.isEmpty) return;

      final userReactions = await _firestoreService.getUserReactions(
        ids,
        currentUser.uid,
      );

      if (isDisposed) return;

      for (int i = 0; i < allPosts.length; i++) {
        final post = allPosts[i];
        if (post.postId != null && userReactions.containsKey(post.postId)) {
          allPosts[i] = post.copyWith(
            userReaction: userReactions[post.postId],
          );
        }
      }

      if (kDebugMode) {
        print('Merged ${userReactions.length} user reaction(s) for ${ids.length} post id(s) requested');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user reactions: $e');
      }
    }
  }

  /// Helper method to create a DocumentSnapshot-like object from Map
  /// This is needed because PostModel.fromFirestore expects a DocumentSnapshot
  dynamic _createDocumentSnapshot(Map<String, dynamic> data) {
    final postId = data['postId'] as String? ?? '';
    return _MockDocumentSnapshot(postId, data);
  }

  Future<void> refreshPosts() async {
    await loadPosts();
  }

  void likePost(int index) async {
    if (index < posts.length) {
      final post = posts[index];
      final newLikesCount = post.likes + 1;
      
      // Update local state immediately
      posts[index] = post.copyWith(likes: newLikesCount);
      notifyListeners();
      
      // Update in Firestore if post has an ID
      if (post.postId != null) {
        try {
          await _firestoreService.updatePostLikes(post.postId!, newLikesCount);
        } catch (e) {
          if (kDebugMode) {
            print('Error updating likes in Firestore: $e');
          }
          // Revert local state on error
          posts[index] = post;
          notifyListeners();
        }
      }
    }
  }

  void addComment(int index) async {
    if (index < posts.length) {
      final post = posts[index];
      final newCommentsCount = post.comments + 1;
      
      // Update local state immediately
      posts[index] = post.copyWith(comments: newCommentsCount);
      notifyListeners();
      
      // Update in Firestore if post has an ID
      if (post.postId != null) {
        try {
          await _firestoreService.updatePostComments(post.postId!, newCommentsCount);
        } catch (e) {
          if (kDebugMode) {
            print('Error updating comments in Firestore: $e');
          }
          // Revert local state on error
          posts[index] = post;
          notifyListeners();
        }
      }
    }
  }

  void goToSubscription() {
    _navigationService.navigateTo(AppRoutes.subscription);
  }

  Future<void> goToCreatePost() async {
    final createdPost = await _navigationService.navigateTo<PostModel>(AppRoutes.createPost);
    // No need to manually reload - the real-time listener will automatically update
    // when the post is saved to Firestore
    if (kDebugMode && createdPost != null) {
      print('Post created. Real-time listener will update posts automatically.');
    }
  }

  /// Navigate back to festival screen
  void navigateToFestival() {
    _navigationService.navigateTo(AppRoutes.festivals);
  }

  /// Refresh posts after returning from comment view
  /// No longer needed with real-time updates, but kept for backward compatibility
  /// The real-time listener will automatically update comment counts
  Future<void> refreshPostsAfterComment() async {
    // Real-time listener handles updates automatically
    // This method is kept for backward compatibility but does nothing
    if (kDebugMode) {
      print('refreshPostsAfterComment called - real-time listener handles updates automatically');
    }
  }

  // Filter methods
  void setFilter(String filter) {
    selectedFilter = filter;
    posts = _computeFilteredPosts();
    notifyListeners();
  }

  /// Filtered slice of [allPosts] for the home feed (search + status filter).
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

  /// True when two filtered rows would render the same feed row state (Phase 4).
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

  /// Rebuilds [posts] from filters and notifies only when the visible list actually changes.
  void _applyFilterNotifyIfChanged() {
    if (isDisposed) return;
    final next = _computeFilteredPosts();
    if (_filteredSnapshotsEqual(posts, next)) return;
    posts = next;
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
    if (postIndex < 0 || postIndex >= posts.length) return;

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
    if (postIndex < 0 || postIndex >= posts.length) return;

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

  /// Delete a post from the global feed
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
      // Delete from Firestore with reduced timeout (this will also delete media from Storage)
      await _firestoreService.deletePost(
        postId: postId,
        userId: currentUser.uid,
        collectionName: null, // Global feed uses default collection
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

      // Remove post from local lists
      posts.removeAt(postIndex);
      final allPostsIndex = allPosts.indexWhere((p) => p.postId == postId);
      if (allPostsIndex >= 0) {
        allPosts.removeAt(allPostsIndex);
      }
      _feedCursorDocByPostId.remove(postId);
      if (kDebugMode) {
        print(
          '[GlobalFeed] deletePost: removed postId=$postId '
          'allPosts=${allPosts.length} cursorCache=${_feedCursorDocByPostId.length} '
          'detached=${_detachedOlderTail.length}',
        );
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
        print('[GlobalFeed] deletePost: Firestore ok postId=$postId');
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

  /// Navigate to edit post screen (global feed: pass post only; collectionName null).
  Future<void> navigateToEditPost(BuildContext context, PostModel post) async {
    final result = await _navigationService.navigateTo<bool>(
      AppRoutes.editPost,
      arguments: post,
    );
    if (result == true) {
      refreshPostsAfterComment();
    }
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
