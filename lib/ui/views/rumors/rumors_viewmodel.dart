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

/// ViewModel for festival-specific rumors screen
/// Reuses HomeViewModel logic but uses festival-specific Firestore collection
class RumorsViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final NetworkService _networkService = locator<NetworkService>();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  
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
  
  // Festival-specific collection name
  String? _festivalCollectionName;
  bool _isInitialized = false; // Track if already initialized
  DateTime? _newestPostTimestamp; // Track newest post timestamp for efficient stream updates
  
  bool get hasMorePosts => _hasMorePosts;
  bool get isLoadingMore => _isLoadingMore;
  String? get festivalCollectionName => _festivalCollectionName;
  
  RumorsViewModel() {
    searchFocusNode = FocusNode();
    // Listen to search controller changes
    searchController.addListener(() {
      if (searchController.text != searchQuery) {
        setSearchQuery(searchController.text);
      }
    });
  }

  @override
  void onDispose() {
    // Cancel the real-time listener when view is disposed
    _postsSubscription?.cancel();
    _postsSubscription = null;
    
    // Clear references to prevent memory leaks
    posts.clear();
    allPosts.clear();
    
    // Reset initialization flag
    _isInitialized = false;
    _festivalCollectionName = null;
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
    // Prevent multiple initializations
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ RumorsViewModel already initialized, skipping');
      }
      return;
    }
    
    // Get festival from provider
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;
    
    if (selectedFestival == null) {
      if (kDebugMode) {
        print('⚠️ No festival selected, cannot initialize rumors');
      }
      return;
    }
    
    // Generate festival collection name
    _festivalCollectionName = FirestoreService.getFestivalCollectionName(
      selectedFestival.id,
      selectedFestival.title,
    );
    
    if (kDebugMode) {
      print('🎪 Initializing rumors for festival: ${selectedFestival.title}');
      print('🎪 Collection name: $_festivalCollectionName');
    }
    
    // Mark as initialized BEFORE loading posts to prevent race conditions
    _isInitialized = true;
    
    // Load initial posts and ensure collection exists
    loadInitialPosts();
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
      setBusy(true);
      
      try {
        // Load initial batch of posts
        final result = await _firestoreService.getPostsPaginated(
          limit: _initialLimit,
          collectionName: _festivalCollectionName,
        );

        final postsData = result['posts'] as List<Map<String, dynamic>>;
        _lastDocument = result['lastDocument'];
        _hasMorePosts = result['hasMore'] as bool? ?? false;

        // Convert to PostModel; exclude posts with null/empty userId
        allPosts.clear();
        for (var postData in postsData) {
          try {
            final post = PostModel.fromFirestore(
              _createDocumentSnapshot(postData),
            );
            if (post.userId != null && post.userId!.isNotEmpty) {
              allPosts.add(post);
            }
          } catch (e, stackTrace) {
            if (kDebugMode) {
              print('Error parsing post: $e');
              print('Stack trace: $stackTrace');
            }
          }
        }

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

        // Load user reactions for all posts
        await _loadUserReactions();

        // Apply filters
        _applyFilter();

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
        setBusy(false);
      }
    }, 
    errorMessage: AppStrings.failedToLoadPosts,
    minimumLoadingDuration: AppDurations.minimumLoadingDuration);
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

  /// Start listening to real-time posts updates for loaded posts
  void _startPostsListener() {
    if (isDisposed || _festivalCollectionName == null) return;

    // Cancel existing subscription if any
    _postsSubscription?.cancel();
    _postsSubscription = null;

    // Listen to real-time updates - get enough posts to catch new ones
    // Use a reasonable limit that will include new posts at the top
    final streamLimit = allPosts.isEmpty ? 20 : (allPosts.length + 20);
    _postsSubscription = _firestoreService
        .getPostsStream(limit: streamLimit, collectionName: _festivalCollectionName)
        .listen(
          (postsData) {
            if (isDisposed) return;

            // Create a map of postId -> PostModel for quick lookup
            final streamPostsMap = <String, PostModel>{};
            for (var postData in postsData) {
              try {
                final post = PostModel.fromFirestore(
                  _createDocumentSnapshot(postData),
                );
                if (post.postId != null && post.userId != null && post.userId!.isNotEmpty) {
                  streamPostsMap[post.postId!] = post;
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing post from stream: $e');
                }
              }
            }

            // Get loaded post IDs
            final loadedPostIds = allPosts
                .where((post) => post.postId != null)
                .map((post) => post.postId!)
                .toSet();

            // Find new posts that aren't in our current list
            // Use timestamp comparison for efficiency if we have a newest timestamp
            final newPosts = <PostModel>[];
            if (_newestPostTimestamp != null) {
              // Only check posts newer than our newest post
              for (var post in streamPostsMap.values) {
                if (post.postId != null && 
                    !loadedPostIds.contains(post.postId) &&
                    post.createdAt != null &&
                    post.createdAt!.isAfter(_newestPostTimestamp!)) {
                  newPosts.add(post);
                }
              }
            } else {
              // Fallback: check all posts if we don't have a timestamp
              for (var post in streamPostsMap.values) {
                if (post.postId != null && !loadedPostIds.contains(post.postId)) {
                  newPosts.add(post);
                }
              }
            }
            
            // Double-check: Remove any posts that might already be in allPosts
            // This prevents duplicates from race conditions
            final currentPostIds = allPosts
                .where((post) => post.postId != null)
                .map((post) => post.postId!)
                .toSet();
            newPosts.removeWhere((newPost) => currentPostIds.contains(newPost.postId));

            // Add new posts to the beginning of the list (newest first)
            if (newPosts.isNotEmpty) {
              // Sort new posts by createdAt descending (newest first)
              newPosts.sort((a, b) {
                final aTime = a.createdAt ?? DateTime(0);
                final bTime = b.createdAt ?? DateTime(0);
                return bTime.compareTo(aTime);
              });
              
              // Update newest post timestamp
              final newestNewPost = newPosts.first;
              if (newestNewPost.createdAt != null) {
                if (_newestPostTimestamp == null || 
                    newestNewPost.createdAt!.isAfter(_newestPostTimestamp!)) {
                  _newestPostTimestamp = newestNewPost.createdAt;
                }
              }
              
              // Load user reactions for new posts
              _loadUserReactionsForPosts(newPosts).then((_) {
                if (!isDisposed) {
                  // Insert new posts at the beginning
                  allPosts.insertAll(0, newPosts);
                  if (kDebugMode) {
                    print('✅ Added ${newPosts.length} new post(s) from stream');
                  }
                  // CRITICAL: Apply filter and notify listeners to update UI
                  _applyFilter();
                  notifyListeners();
                }
              });
            }

            // Update existing posts with real-time data
            // Preserve user reactions to prevent overwriting optimistic updates
            final updatedPostsMap = <String, PostModel>{};
            for (var post in allPosts) {
              if (post.postId != null) {
                updatedPostsMap[post.postId!] = post;
              }
            }

            // Update posts that exist in both stream and our loaded list
            for (var postId in streamPostsMap.keys) {
              if (loadedPostIds.contains(postId)) {
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
                  
                  final updatedPost = streamPostsMap[postId]!;
                  
                  // Preserve user reaction from old post (it's loaded separately)
                  final postWithReaction = updatedPost.copyWith(
                    userReaction: oldPost.userReaction,
                  );
                  
                  updatedPostsMap[postId] = postWithReaction;
                } catch (e) {
                  if (kDebugMode) {
                    print('Error parsing post update: $e');
                  }

                }
              }
            }

            // Update allPosts with updated posts (preserve order)
            bool reactionsChanged = false;
            bool hasUpdates = newPosts.isNotEmpty;
            allPosts = allPosts.map((post) {
              if (post.postId != null && updatedPostsMap.containsKey(post.postId)) {
                final updatedPost = updatedPostsMap[post.postId]!;
                // Check if reaction counts changed
                if (post.reactionCounts != updatedPost.reactionCounts) {
                  reactionsChanged = true;
                }
                // Check if any data changed
                if (post.comments != updatedPost.comments ||
                    post.likes != updatedPost.likes ||
                    post.reactionCounts != updatedPost.reactionCounts) {
                  hasUpdates = true;
                }
                return updatedPost;
              }
              return post;
            }).toList();

            // Only reload reactions if reaction counts actually changed
            // This avoids unnecessary Firestore reads on every stream update
            if (reactionsChanged) {
              _loadUserReactions().then((_) {
                if (!isDisposed) {
                  _applyFilter();
                  notifyListeners();
                }
              }).catchError((error) {
                if (kDebugMode) {
                  print('Error loading user reactions: $error');
                }
                if (!isDisposed) {
                  _applyFilter();
                  notifyListeners();
                }
              });
            } else if (hasUpdates) {
              // Has updates but no reaction changes, just apply filter
              if (!isDisposed) {
                _applyFilter();
                notifyListeners();
              }
            }
          },
          onError: (error, stackTrace) {
            if (kDebugMode) {
              print('Error in posts stream: $error');
            }
            final exception = ExceptionMapper.mapToAppException(error, stackTrace);
            _errorHandler.handleError(exception, stackTrace, 'RumorsViewModel._startPostsListener');
          },
        );
  }

  /// Load user reactions for specific posts
  Future<void> _loadUserReactionsForPosts(List<PostModel> postsToLoad) async {
    if (isDisposed || postsToLoad.isEmpty) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final postIds = postsToLoad
          .where((post) => post.postId != null)
          .map((post) => post.postId!)
          .toList();

      if (postIds.isEmpty) return;

      // Get user reactions for these posts
      final userReactions = await _firestoreService.getUserReactions(
        postIds,
        currentUser.uid,
        collectionName: _festivalCollectionName,
      );

      // Check again if disposed after async operation
      if (isDisposed) return;

      // Update posts with user reactions
      for (int i = 0; i < postsToLoad.length; i++) {
        final post = postsToLoad[i];
        if (post.postId != null && userReactions.containsKey(post.postId)) {
          postsToLoad[i] = post.copyWith(
            userReaction: userReactions[post.postId],
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user reactions for new posts: $e');
      }
      // Don't throw - reactions are not critical
    }
  }

  /// Enrich posts with userPhotoUrl from Firestore if missing
  Future<void> _enrichPostsWithUserPhotos() async {
    if (isDisposed) return;

    try {
      // Find posts that need userPhotoUrl enrichment
      final postsToEnrich = <int, String>{}; // index -> userId
      for (int i = 0; i < allPosts.length; i++) {
        final post = allPosts[i];
        // If post doesn't have userPhotoUrl but has userId, we need to enrich it
        if ((post.userPhotoUrl == null || post.userPhotoUrl!.isEmpty) && 
            post.userId != null && post.userId!.isNotEmpty) {
          postsToEnrich[i] = post.userId!;
        }
      }

      if (postsToEnrich.isEmpty) {
        if (kDebugMode) {
          print('No posts need userPhotoUrl enrichment');
        }
        return;
      }

      if (kDebugMode) {
        print('Enriching ${postsToEnrich.length} posts with userPhotoUrl');
      }

      // Fetch user data for unique user IDs in parallel
      final uniqueUserIds = postsToEnrich.values.toSet().toList();
      final userDataMap = <String, String?>{}; // userId -> photoUrl

      // Parallelize user data fetching to reduce load time
      final futures = uniqueUserIds.map((userId) async {
        try {
          final userData = await _firestoreService.getUserData(userId);
          if (userData != null && userData['photoUrl'] != null) {
            return MapEntry(userId, userData['photoUrl'] as String?);
          }
          return MapEntry<String, String?>(userId, null);
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching user data for userId $userId: $e');
          }
          return MapEntry<String, String?>(userId, null);
        }
      });

      // Wait for all user data fetches to complete in parallel
      final results = await Future.wait(futures);
      for (final entry in results) {
        userDataMap[entry.key] = entry.value;
      }

      // Check again if disposed after async operations
      if (isDisposed) return;

      // Update posts with userPhotoUrl
      int enrichedCount = 0;
      for (final entry in postsToEnrich.entries) {
        final index = entry.key;
        final userId = entry.value;
        final photoUrl = userDataMap[userId];

        if (photoUrl != null && photoUrl.isNotEmpty) {
          allPosts[index] = allPosts[index].copyWith(userPhotoUrl: photoUrl);
          enrichedCount++;
        }
      }

      if (kDebugMode) {
        print('Enriched $enrichedCount posts with userPhotoUrl');
      }

      // Notify listeners to update UI
      if (enrichedCount > 0) {
        _applyFilter(); // Reapply filter to update displayed posts
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enriching posts with userPhotoUrl: $e');
      }
      // Don't throw - enrichment is optional
    }
  }

  /// Load user reactions for all posts
  Future<void> _loadUserReactions() async {
    if (isDisposed || allPosts.isEmpty) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final postIds = allPosts
          .where((post) => post.postId != null)
          .map((post) => post.postId!)
          .toList();

      if (postIds.isEmpty) return;

      // Get user reactions for all posts
      final userReactions = await _firestoreService.getUserReactions(
        postIds,
        currentUser.uid,
        collectionName: _festivalCollectionName,
      );

      // Check again if disposed after async operation
      if (isDisposed) return;

      // Update posts with user reactions
      for (int i = 0; i < allPosts.length; i++) {
        final post = allPosts[i];
        if (post.postId != null && userReactions.containsKey(post.postId)) {
          allPosts[i] = post.copyWith(
            userReaction: userReactions[post.postId],
          );
        }
      }

      if (kDebugMode) {
        print('Loaded ${userReactions.length} user reactions');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error loading user reactions: $e');
      }
      // Don't throw - reactions are not critical
    }
  }

  /// Load more posts (pagination)
  Future<void> loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _festivalCollectionName == null) return;

    await handleAsync(() async {
      _isLoadingMore = true;
      notifyListeners();

      try {
        final result = await _firestoreService.getPostsPaginated(
          limit: _loadMoreLimit,
          lastDocument: _lastDocument,
          collectionName: _festivalCollectionName,
        );

        final postsData = result['posts'] as List<Map<String, dynamic>>;
        _lastDocument = result['lastDocument'];
        _hasMorePosts = result['hasMore'] as bool? ?? false;

        // Convert to PostModel and add to existing list; exclude posts with null/empty userId
        for (var postData in postsData) {
          try {
            final post = PostModel.fromFirestore(
              _createDocumentSnapshot(postData),
            );
            if (post.userId != null && post.userId!.isNotEmpty) {
              allPosts.add(post);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing post: $e');
            }
          }
        }

        // Enrich new posts with userPhotoUrl if missing
        await _enrichPostsWithUserPhotos();

        // Load user reactions for new posts
        await _loadUserReactions();

        // Apply filters
        _applyFilter();

        if (kDebugMode) {
          print('✅ Loaded ${postsData.length} more posts (total: ${allPosts.length})');
        }
      } catch (e, stackTrace) {
        final exception = ExceptionMapper.mapToAppException(e, stackTrace);
        _errorHandler.handleError(exception, stackTrace, 'RumorsViewModel.loadMorePosts');
        rethrow;
      } finally {
        _isLoadingMore = false;
        notifyListeners();
      }
    }, 
    errorMessage: AppStrings.failedToLoadPosts);
  }

  /// Refresh posts after comment (to update comment counts)
  Future<void> refreshPostsAfterComment() async {
    if (_festivalCollectionName == null) return;
    
    try {
      // Reload user reactions to get updated comment counts
      await _loadUserReactions();
      _applyFilter();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing posts after comment: $e');
      }
    }
  }

  /// Apply filter and search to posts
  void _applyFilter() {
    final searchLower = searchQuery.toLowerCase();
    final hasSearch = searchQuery.isNotEmpty;

    posts = allPosts.where((post) {
      // Exclude posts with no userId (orphaned/invalid posts)
      if (post.userId == null || post.userId!.isEmpty) return false;

      // Apply status filter
      if (selectedFilter == AppStrings.live && post.status != AppStrings.live) {
        return false;
      } else if (selectedFilter == AppStrings.upcoming && post.status != AppStrings.upcoming) {
        return false;
      } else if (selectedFilter == AppStrings.past && post.status != AppStrings.past) {
        return false;
      }

      // Apply search filter in same pass
      if (hasSearch) {
        final usernameLower = post.username.toLowerCase();
        final contentLower = post.content.toLowerCase();
        if (!usernameLower.contains(searchLower) && !contentLower.contains(searchLower)) {
          return false;
        }
      }

      return true;
    }).toList();

    notifyListeners();
  }

  /// Set filter (all, live, upcoming, past)
  void setFilter(String filter) {
    selectedFilter = filter;
    _applyFilter();
    notifyListeners();
  }

  // Search methods
  void setSearchQuery(String query) {
    searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void clearSearch() {
    searchQuery = '';
    searchController.clear();
    _applyFilter();
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
        collectionName: _festivalCollectionName,
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
        collectionName: _festivalCollectionName,
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
      // Delete from Firestore with reduced timeout (this will also delete media from Storage)
      await _firestoreService.deletePost(
        postId: postId,
        userId: currentUser.uid,
        collectionName: _festivalCollectionName, // Use festival collection
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

  /// Helper method to create a DocumentSnapshot-like object from Map
  /// This is needed because PostModel.fromFirestore expects a DocumentSnapshot
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
