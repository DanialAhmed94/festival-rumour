import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/network_service.dart';
import '../homeview/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Mock DocumentSnapshot for PostModel.fromFirestore
class MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic> _dataMap;

  MockDocumentSnapshot(this.id, Map<String, dynamic> data) : _dataMap = data;

  String get documentID => id;
  String? get docId => id;
  Map<String, dynamic>? get dataMap => _dataMap;
  Map<String, dynamic> data() => _dataMap;
}

class PostsViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final NetworkService _networkService = locator<NetworkService>();
  
  // Real posts data from Firestore
  List<PostModel> _posts = [];
  String? _collectionName;
  StreamSubscription<List<Map<String, dynamic>>>? _postsSubscription;

  List<PostModel> get posts => _posts;
  String? get collectionName => _collectionName;

  /// Initialize with posts data from arguments
  /// [postsData] - List of post data maps from Firestore
  /// [collectionName] - Collection name where posts are stored
  void initialize(List<Map<String, dynamic>>? postsData, {String? collectionName}) {
    _collectionName = collectionName;
    
    if (postsData != null && postsData.isNotEmpty) {
      _posts = postsData.map((data) {
        try {
          if (kDebugMode) {
            print('🔄 Converting post data to PostModel...');
            print('   Post ID: ${data['postId']}');
            print('   Has username: ${data['username'] != null}');
            print('   Has content: ${data['content'] != null}');
          }
          final postModel = PostModel.fromFirestore(_createDocumentSnapshot(data));
          if (kDebugMode) {
            print('   ✅ Successfully converted to PostModel');
          }
          return postModel;
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ Error parsing post: $e');
            print('   Stack trace: $stackTrace');
            print('   Post data keys: ${data.keys.toList()}');
          }
          return null;
        }
      }).whereType<PostModel>().toList();

      if (kDebugMode) {
        print('✅ Initialized PostsViewModel with ${_posts.length} posts (from ${postsData.length} raw posts)');
        if (_posts.isEmpty && postsData.isNotEmpty) {
          print('⚠️ WARNING: All posts failed to convert to PostModel!');
        }
      }
      
      // Load user reactions for all posts (await to ensure reactions are loaded before UI shows)
      _loadUserReactions().then((_) {
        // Start real-time listener for updates after reactions are loaded
        _startPostsListener();
        
        // Notify listeners after reactions are loaded
        if (!isDisposed) {
          notifyListeners();
        }
      });
      
      // Notify listeners immediately so UI can show posts (reactions will update when loaded)
      notifyListeners();
    } else {
      _posts = [];
      if (kDebugMode) {
        print('⚠️ No posts data provided to PostsViewModel');
      }
    }
  }

  /// Start listening to real-time posts updates
  /// This stream updates existing posts with new reaction counts and comment counts
  void _startPostsListener() {
    if (isDisposed || _posts.isEmpty || _collectionName == null) return;

    // Cancel existing subscription if any
    _postsSubscription?.cancel();
    _postsSubscription = null;

    // Get post IDs to filter stream updates
    final postIds = _posts
        .where((post) => post.postId != null)
        .map((post) => post.postId!)
        .toSet();

    if (postIds.isEmpty) return;

    // Listen to real-time updates for posts in this collection
    // Use a limit that includes our posts + small buffer
    final streamLimit = _posts.length + 5;
    
    _postsSubscription = _firestoreService
        .getPostsStream(limit: streamLimit, collectionName: _collectionName)
        .listen(
          (postsData) {
            // Check if disposed before processing
            if (isDisposed) return;

            // Filter to only posts we're displaying
            final relevantPostsData = postsData.where((data) {
              final postId = data['postId'] as String?;
              return postId != null && postIds.contains(postId);
            }).toList();

            if (relevantPostsData.isEmpty) return;

            // Update existing posts with real-time data
            final updatedPostsMap = <String, PostModel>{};
            for (var post in _posts) {
              if (post.postId != null) {
                updatedPostsMap[post.postId!] = post;
              }
            }

            // Update posts that exist in both stream and our loaded list
            bool hasUpdates = false;
            for (var data in relevantPostsData) {
              final postId = data['postId'] as String?;
              if (postId != null && postIds.contains(postId)) {
                try {
                  final oldPost = updatedPostsMap[postId] ?? _posts.firstWhere(
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
                    hasUpdates = true;
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

            // Update _posts with updated posts (preserve order)
            bool reactionsChanged = false;
            _posts = _posts.map((post) {
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
              _loadUserReactions().then((_) {
                if (!isDisposed && hasUpdates) {
                  notifyListeners();
                }
              });
            } else if (hasUpdates) {
              // Has updates but no reaction changes, just notify listeners
              if (!isDisposed) {
                notifyListeners();
              }
            }
          },
          onError: (error, stackTrace) {
            if (isDisposed) return;
            if (kDebugMode) {
              print('Error in posts stream: $error');
            }
          },
          cancelOnError: false,
        );
  }

  /// Load user reactions for all posts
  Future<void> _loadUserReactions() async {
    // Check if disposed before processing
    if (isDisposed) return;
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ No user logged in, skipping user reactions load');
      }
      return; // User not logged in
    }

    try {
      // Get all post IDs
      final postIds = _posts
          .where((post) => post.postId != null)
          .map((post) => post.postId!)
          .toList();

      if (postIds.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No post IDs to load reactions for');
        }
        return;
      }

      if (kDebugMode) {
        print('📥 Loading user reactions for ${postIds.length} post(s)');
      }

      // Fetch user reactions in batch
      final userReactions = await _firestoreService.getUserReactions(
        postIds,
        currentUser.uid,
        collectionName: _collectionName,
      );

      // Check again if disposed after async operation
      if (isDisposed) return;

      // Update posts with user reactions
      bool hasUpdates = false;
      for (int i = 0; i < _posts.length; i++) {
        final post = _posts[i];
        if (post.postId != null && userReactions.containsKey(post.postId)) {
          final reaction = userReactions[post.postId];
          if (post.userReaction != reaction) {
            _posts[i] = post.copyWith(
              userReaction: reaction,
            );
            hasUpdates = true;
            if (kDebugMode) {
              print('   ✅ Post ${post.postId}: user reaction = $reaction');
            }
          }
        } else if (post.postId != null && post.userReaction != null) {
          // Clear reaction if user no longer has a reaction
          _posts[i] = post.copyWith(userReaction: null);
          hasUpdates = true;
        }
      }

      if (kDebugMode) {
        print('✅ Loaded ${userReactions.length} user reaction(s)');
        if (hasUpdates) {
          print('   🔄 Updated ${_posts.where((p) => p.userReaction != null).length} post(s) with user reactions');
        }
      }
      
      // Notify listeners after updating reactions
      if (hasUpdates && !isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading user reactions: $e');
      }
      // Don't throw - reactions are optional
    }
  }

  /// Helper method to create a DocumentSnapshot-like object from Map
  dynamic _createDocumentSnapshot(Map<String, dynamic> data) {
    final postId = data['postId'] as String? ?? '';
    return MockDocumentSnapshot(postId, data);
  }

  /// Handle reaction selection from PostWidget
  /// 
  /// [postId] - The post ID
  /// [emotion] - The emoji/emotion string (empty string to remove reaction)
  Future<void> handleReactionSelected(String postId, String emotion) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    // Find the post
    final postIndex = _posts.indexWhere((p) => p.postId == postId);
    if (postIndex < 0) return;

    final post = _posts[postIndex];
    final previousEmotion = post.userReaction;

    // If removing reaction (empty string) or same reaction, remove it
    if (emotion.isEmpty || emotion == previousEmotion) {
      if (previousEmotion == null) return; // No reaction to remove

      try {
        // Update reaction counts locally
        final updatedCounts = Map<String, int>.from(post.reactionCounts ?? {});
        
        // Decrement emotion count
        final currentCount = updatedCounts[previousEmotion] ?? 0;
        if (currentCount > 1) {
          updatedCounts[previousEmotion] = currentCount - 1;
        } else {
          updatedCounts.remove(previousEmotion);
        }

        // Update local state immediately
        _posts[postIndex] = post.copyWith(
          userReaction: null,
          reactionCounts: updatedCounts,
        );

        notifyListeners();

        // Save to Firestore in background
        await _firestoreService.removeUserReaction(
          postId,
          currentUser.uid,
          previousEmotion,
          collectionName: _collectionName,
        );

        if (kDebugMode) {
          print('Reaction removed: postId=$postId, emotion=$previousEmotion');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error removing reaction: $e');
        }
        // Revert local state on error
        _posts[postIndex] = post;
        notifyListeners();
      }
      return;
    }

    // Adding or changing reaction
    try {
      // Update reaction counts locally
      final updatedCounts = Map<String, int>.from(post.reactionCounts ?? {});
      
      // Decrement previous emotion count if user is changing reaction
      if (previousEmotion != null && previousEmotion.isNotEmpty) {
        final prevCount = updatedCounts[previousEmotion] ?? 0;
        if (prevCount > 1) {
          updatedCounts[previousEmotion] = prevCount - 1;
        } else {
          updatedCounts.remove(previousEmotion);
        }
      }

      // Increment new emotion count
      final currentCount = updatedCounts[emotion] ?? 0;
      updatedCounts[emotion] = currentCount + 1;

      // Update local state immediately for responsive UI
      _posts[postIndex] = post.copyWith(
        userReaction: emotion,
        reactionCounts: updatedCounts,
      );

      notifyListeners();

      // Save to Firestore in background
      await _firestoreService.saveUserReaction(
        postId,
        currentUser.uid,
        emotion,
        previousEmotion: previousEmotion,
        collectionName: _collectionName,
      );

      if (kDebugMode) {
        print('Reaction updated: postId=$postId, emotion=$emotion, previousEmotion=$previousEmotion');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating reaction: $e');
      }
      // Revert local state on error
      _posts[postIndex] = post;
      notifyListeners();
    }
  }

  /// Delete a post
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
    final postIndex = _posts.indexWhere((p) => p.postId == postId);
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

    final post = _posts[postIndex];

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
    // This prevents unnecessary UI updates when offline
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
        collectionName: _collectionName,
      ).timeout(
        const Duration(seconds: 15), // Reduced from 30 to 15 seconds
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

      // Remove post from local list
      _posts.removeAt(postIndex);
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

        // Navigate back if no posts left
        if (_posts.isEmpty && context.mounted) {
          Navigator.of(context).pop();
        }
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

  @override
  void onDispose() {
    // Cancel the real-time listener when view is disposed
    _postsSubscription?.cancel();
    _postsSubscription = null;
    
    // Clear references to prevent memory leaks
    _posts.clear();
    
    super.onDispose();
  }

  // PostWidget handles all interactions (likes, comments, reactions, etc.)
  // Comments are loaded only when user taps comment icon (handled by PostWidget)
}
