import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_numbers.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_handler_service.dart';
import '../../../core/exceptions/exception_mapper.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_durations.dart';
import 'post_model.dart';

class HomeViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
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
  
  bool get hasMorePosts => _hasMorePosts;
  bool get isLoadingMore => _isLoadingMore;
  
  HomeViewModel() {
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
    
    // Dispose controllers and focus nodes
    searchFocusNode.dispose();
    searchController.dispose();
    
    super.onDispose();
  }

  /// Start listening to real-time posts updates
  /// This stream updates existing posts AND detects new posts created by other users
  void _startPostsListener() {
    if (isDisposed) return;

    // Cancel existing subscription if any
    _postsSubscription?.cancel();
    _postsSubscription = null;

    // Listen to real-time updates for posts
    // Use a limit that includes loaded posts + buffer to detect new posts
    // We need enough buffer to catch new posts at the top
    final streamLimit = allPosts.isEmpty ? _initialLimit : (allPosts.length + 10);
    
    _postsSubscription = _firestoreService
        .getPostsStream(limit: streamLimit)
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

            // Process new posts and add them to the beginning of allPosts
            if (newPostsData.isNotEmpty) {
              if (kDebugMode) {
                print('🆕 Detected ${newPostsData.length} new post(s) from other users');
              }

              final newPosts = <PostModel>[];
              for (var data in newPostsData) {
                try {
                  final newPost = PostModel.fromFirestore(
                    _createDocumentSnapshot(data),
                  );
                  newPosts.add(newPost);
                } catch (e) {
                  if (kDebugMode) {
                    print('Error parsing new post: $e');
                  }
                }
              }

              // Add new posts to the beginning of allPosts (newest first)
              if (newPosts.isNotEmpty) {
                allPosts.insertAll(0, newPosts);
                
                // Enrich new posts with user photos
                await _enrichPostsWithUserPhotos();
                
                // Load user reactions for new posts
                await _loadUserReactions();
                
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
                  
                  // Preserve user reaction from old post (it's loaded separately)
                  final postWithReaction = updatedPost.copyWith(
                    userReaction: oldPost.userReaction,
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
            bool reactionsChanged = false;
            allPosts = allPosts.map((post) {
              if (post.postId != null && updatedPostsMap.containsKey(post.postId)) {
                final updatedPost = updatedPostsMap[post.postId]!;
                // Check if reaction counts changed
                if (post.reactionCounts != updatedPost.reactionCounts) {
                  reactionsChanged = true;
                }
                return updatedPost;
              }
              return post;
            }).toList();

            // Only reload reactions if reaction counts actually changed
            // This avoids unnecessary Firestore reads on every stream update
            if (reactionsChanged) {
              await _loadUserReactions();
            }
            
            // Apply filter to update displayed posts
            if (!isDisposed) {
              _applyFilter();
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
      
      // Convert Firestore data to PostModel list
      allPosts = postsData.map((data) {
        try {
          return PostModel.fromFirestore(
            _createDocumentSnapshot(data),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing post: $e');
          }
          return null;
        }
      }).whereType<PostModel>().toList();
      
      if (kDebugMode) {
        print('Loaded ${allPosts.length} posts from Firestore');
      }
      
      // Load user reactions for all posts
      await _loadUserReactions();
      
      // Apply initial filter
      _applyFilter();
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

      // Load initial batch (10 posts)
      final result = await _firestoreService.getPostsPaginated(
        limit: _initialLimit,
        lastDocument: _lastDocument,
      );

      final postsData = result['posts'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'];
      _hasMorePosts = result['hasMore'] as bool? ?? false;

      // Convert Firestore data to PostModel list
      allPosts = postsData.map((data) {
        try {
          return PostModel.fromFirestore(
            _createDocumentSnapshot(data),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing post: $e');
          }
          return null;
        }
      }).whereType<PostModel>().toList();

      if (kDebugMode) {
        print('📥 Loaded initial ${allPosts.length} posts. Has more: $_hasMorePosts');
      }

      // Enrich posts with userPhotoUrl from Firestore if missing
      await _enrichPostsWithUserPhotos();

      // Load user reactions for all posts
      await _loadUserReactions();

      // Apply initial filter
      _applyFilter();

      // Start real-time listener to detect new posts and updates
      _startPostsListener();
    },
    errorMessage: AppStrings.failedToLoadPosts,
    minimumLoadingDuration: AppDurations.minimumLoadingDuration);
  }

  /// Load more posts (next batch)
  Future<void> loadMorePosts() async {
    if (isDisposed || _isLoadingMore || !_hasMorePosts) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // Load next batch
      final result = await _firestoreService.getPostsPaginated(
        limit: _loadMoreLimit,
        lastDocument: _lastDocument,
      );

      final postsData = result['posts'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'];
      _hasMorePosts = result['hasMore'] as bool? ?? false;

      // Convert Firestore data to PostModel list
      final newPosts = postsData.map((data) {
        try {
          return PostModel.fromFirestore(
            _createDocumentSnapshot(data),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing post: $e');
          }
          return null;
        }
      }).whereType<PostModel>().toList();

      if (kDebugMode) {
        print('Loaded ${newPosts.length} more posts. Has more: $_hasMorePosts. Total posts now: ${allPosts.length + newPosts.length}');
      }

      // Check if disposed after async operation
      if (isDisposed) return;

      // If no new posts were loaded, there are no more posts
      if (newPosts.isEmpty) {
        _hasMorePosts = false;
        if (kDebugMode) {
          print('No new posts loaded, setting hasMorePosts to false');
        }
      } else {
        // Add new posts to existing list
        allPosts.addAll(newPosts);
      }

      // Enrich new posts with userPhotoUrl if missing
      await _enrichPostsWithUserPhotos();

      // Load user reactions for new posts
      await _loadUserReactions();

      // Apply filter to include new posts
      _applyFilter();

      // Restart real-time listener to include new posts
      _startPostsListener();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading more posts: $e');
      }
      // Don't show error to user for load more failures
    } finally {
      if (!isDisposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
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
        if (kDebugMode && entry.value != null) {
          print('✅ Found photoUrl for userId ${entry.key}: ${entry.value}');
        } else if (kDebugMode) {
          print('⚠️ No photoUrl found for userId ${entry.key}');
        }
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
          if (kDebugMode) {
            print('✅ Enriched post at index $index with photoUrl: $photoUrl');
          }
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
    // Check if disposed before processing
    if (isDisposed) return;
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) return; // User not logged in

    try {
      // Get all post IDs
      final postIds = allPosts
          .where((post) => post.postId != null)
          .map((post) => post.postId!)
          .toList();

      if (postIds.isEmpty) return;

      // Fetch user reactions in batch
      final userReactions = await _firestoreService.getUserReactions(
        postIds,
        currentUser.uid,
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
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user reactions: $e');
      }
      // Don't throw - reactions are optional
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
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    // Single pass filtering for better performance
    final searchLower = searchQuery.toLowerCase();
    final hasSearch = searchQuery.isNotEmpty;

    posts = allPosts.where((post) {
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

    notifyListeners(); // Notify UI of changes (comment counts, reaction counts, etc.)
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
