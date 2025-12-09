import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_handler_service.dart';
import '../../../core/exceptions/exception_mapper.dart';
import '../../../core/di/locator.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../homeview/post_model.dart';
import 'comment_model.dart';

class CommentViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  TextEditingController commentController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  bool _showEmojiGrid = false;
  
  CommentViewModel() {
    // Listen to scroll position to detect if user scrolled up
    scrollController.addListener(_onScrollChanged);
    // Listen to text changes with debouncing
    commentController.addListener(_onTextChanged);
  }
  
  void _onScrollChanged() {
    if (!scrollController.hasClients) return;
    
    // Check if user is near bottom (within 100px)
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final distanceFromBottom = maxScroll - currentScroll;
    
    // If user is more than 100px from bottom, they scrolled up
    _userScrolledUp = distanceFromBottom > 100;
  }
  
  void _onTextChanged() {
    // Debounce text changes to avoid excessive rebuilds
    _textDebounceTimer?.cancel();
    _textDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!isDisposed) {
        notifyListeners();
      }
    });
  }
  
  PostModel? _post;
  List<CommentModel> comments = [];
  StreamSubscription<List<Map<String, dynamic>>>? _commentsSubscription;
  
  // Pagination state
  dynamic _lastCommentDocument; // Last document for pagination
  bool _hasMoreComments = true; // Whether there are more comments to load
  bool _isLoadingMore = false; // Whether we're currently loading more comments
  static const int _initialLimit = 10; // Initial number of comments to load
  static const int _loadMoreLimit = 10; // Number of comments to load per "load more"
  static const int _streamBufferSize = 20; // Buffer for new comments in stream
  static const int _maxFirstPageComments = 200; // Max comments to show on first page (performance limit)
  
  // Cached comment IDs for efficient lookups
  Set<String> _loadedCommentIds = {};
  
  // Text input debouncing
  Timer? _textDebounceTimer;
  
  // Auto-scroll state
  bool _userScrolledUp = false; // Track if user manually scrolled up
  Timer? _scrollCheckTimer;
  
  // Reply management - performance optimized
  final Map<String, StreamSubscription<List<Map<String, dynamic>>>> _replySubscriptions = {};
  final Map<String, List<CommentModel>> _repliesMap = {}; // commentId -> replies list
  final Map<String, bool> _repliesExpanded = {}; // commentId -> is expanded
  final Map<String, Set<String>> _loadedReplyIds = {}; // commentId -> set of loaded reply IDs
  TextEditingController? _replyController; // Controller for reply input
  String? _replyingToCommentId; // Which comment we're currently replying to
  
  bool get hasMoreComments => _hasMoreComments;
  bool get isLoadingMore => _isLoadingMore;
  
  /// Get replies for a comment
  List<CommentModel> getReplies(String commentId) {
    return _repliesMap[commentId] ?? [];
  }
  
  /// Check if replies are expanded for a comment
  bool areRepliesExpanded(String commentId) {
    return _repliesExpanded[commentId] ?? false;
  }
  
  /// Get reply count for a comment (from model or loaded replies)
  int getReplyCount(String commentId) {
    final comment = comments.firstWhere(
      (c) => c.commentId == commentId,
      orElse: () => CommentModel(
        postId: '',
        userId: '',
        username: '',
        content: '',
        createdAt: DateTime.now(),
      ),
    );
    return comment.replyCount;
  }
  
  /// Check if currently replying to a comment
  bool isReplyingTo(String? commentId) {
    return _replyingToCommentId == commentId;
  }
  
  /// Get reply controller (creates if needed)
  TextEditingController get replyController {
    _replyController ??= TextEditingController();
    return _replyController!;
  }

  PostModel? get post => _post;

  List<String> emojis = [
    "😀", "😂", "😍", "👍", "👏", "😢", "🔥", "❤️"
  ];

  bool get showEmojiGrid => _showEmojiGrid;
  bool get canPostComment => commentController.text.trim().isNotEmpty;

  // Festival-specific collection name
  String? _collectionName;
  
  String? get collectionName => _collectionName;

  /// Initialize with post data and optional collection name
  void initialize(PostModel? post, {String? collectionName}) {
    _post = post;
    _collectionName = collectionName;
    if (post != null && post.postId != null) {
      loadInitialComments();
    }
  }

  /// Load initial comments (first 10 comments)
  Future<void> loadInitialComments() async {
    if (_post?.postId == null || isDisposed) return;

    await handleAsync(() async {
      setLoading(true);
      
      // Reset pagination state
      _lastCommentDocument = null;
      _hasMoreComments = true;
      comments.clear();

      // Load initial batch
      final result = await _firestoreService.getCommentsPaginated(
        postId: _post!.postId!,
        limit: _initialLimit,
        lastDocument: _lastCommentDocument,
        collectionName: _collectionName,
      );

      final commentsData = result['comments'] as List<Map<String, dynamic>>;
      _lastCommentDocument = result['lastDocument'];
      _hasMoreComments = result['hasMore'] as bool? ?? false;

      // Convert Firestore data to CommentModel list
      comments = commentsData.map((data) {
        try {
          return CommentModel.fromFirestore(
            _createDocumentSnapshot(data),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing comment: $e');
          }
          return null;
        }
      }).whereType<CommentModel>().toList();

      // Update cached comment IDs
      _updateLoadedCommentIds();

      if (kDebugMode) {
        print('Loaded initial ${comments.length} comments. Has more: $_hasMoreComments');
      }

      // Start real-time listener for loaded comments
      _startCommentsListener();
      
      // Reset scroll state and scroll to bottom after initial load
      _userScrolledUp = false;
      _scrollToBottom();
    },
    errorMessage: 'Failed to load comments',
    minimumLoadingDuration: AppDurations.minimumLoadingDuration);
  }

  /// Update cached comment IDs set for efficient lookups
  void _updateLoadedCommentIds() {
    _loadedCommentIds = comments
        .where((comment) => comment.commentId != null)
        .map((comment) => comment.commentId!)
        .toSet();
  }

  /// Start listening to real-time comments updates
  /// This stream updates existing comments AND adds new ones in real-time
  /// Optimized to only process loaded comments + buffer to avoid processing thousands
  void _startCommentsListener() {
    if (_post?.postId == null || isDisposed) return;

    // Cancel existing subscription if any
    _commentsSubscription?.cancel();
    _commentsSubscription = null;

    // Listen to comments stream (note: Firestore streams don't support limit)
    // We'll filter client-side to only process what we need
    _commentsSubscription = _firestoreService
        .getCommentsStream(_post!.postId!, collectionName: _collectionName)
        .listen(
          (allCommentsData) {
            // Check if disposed before processing
            if (isDisposed) return;

            if (kDebugMode) {
              print('📥 Real-time update: Received ${allCommentsData.length} total comments from stream');
            }

            // CRITICAL OPTIMIZATION: Smart filtering for performance
            // Strategy:
            // 1. First page: Show all comments up to reasonable limit (for real-time updates)
            //    This ensures new comments from other users appear immediately
            // 2. Later pages: Only process loaded comments (for performance)
            // 
            // IMPORTANT: We're on "first page" if:
            // - _lastCommentDocument == null (no pagination yet), OR
            // - _hasMoreComments == false (we've loaded all comments, so effectively first page)
            final isEffectivelyFirstPage = _lastCommentDocument == null || !_hasMoreComments;
            
            List<Map<String, dynamic>> commentsToProcess;
            
            if (isEffectivelyFirstPage) {
              // First page: Process all comments up to max limit for real-time updates
              // This ensures new comments from other users always appear immediately
              // Comments are ordered oldest first, so new comments are at the end
              final maxToShow = _maxFirstPageComments;
              
              if (allCommentsData.length > maxToShow) {
                // Take the most recent comments (newest at the end since ordered ascending)
                // This ensures we always see the latest comments including new ones from other users
                commentsToProcess = allCommentsData.sublist(
                  allCommentsData.length - maxToShow,
                  allCommentsData.length,
                );
                if (kDebugMode) {
                  print('⚡ First page: Processing ${commentsToProcess.length} most recent of ${allCommentsData.length} comments (ensures new comments appear)');
                }
              } else {
                // Process all comments if under limit - this is the common case
                commentsToProcess = allCommentsData;
                if (kDebugMode) {
                  print('📄 First page: Processing all ${commentsToProcess.length} comments (real-time updates enabled)');
                }
              }
            } else {
              // Later pages: Only process comments in our loaded range (for performance)
              // We don't want to process thousands of older comments
              final loadedCommentIdsSet = _loadedCommentIds;
              
              // Filter to only process comments we've loaded
              // This is more efficient than date comparison
              commentsToProcess = allCommentsData.where((data) {
                final commentId = data['commentId'] as String?;
                if (commentId == null) return false;
                
                // Include if it's in our loaded set (we've loaded it)
                return loadedCommentIdsSet.contains(commentId);
              }).toList();
              
              if (kDebugMode) {
                print('⚡ Later page: Processing ${commentsToProcess.length} of ${allCommentsData.length} comments (only loaded comments)');
              }
            }

            // Convert filtered stream data to CommentModel
            final processedComments = <CommentModel>[];
            for (var data in commentsToProcess) {
              try {
                final comment = CommentModel.fromFirestore(
                  _createDocumentSnapshot(data),
                );
                processedComments.add(comment);
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing comment from stream: $e');
                }
              }
            }

            if (kDebugMode) {
              final newCommentIds = processedComments
                  .where((c) => c.commentId != null && !_loadedCommentIds.contains(c.commentId))
                  .map((c) => c.commentId!)
                .toList();
              if (newCommentIds.isNotEmpty) {
                print('🆕 Detected ${newCommentIds.length} new comments in stream: $newCommentIds');
              }
            }

            // Use incremental update strategy for better performance
            final hasChanges = _updateCommentsIncrementally(processedComments);
            
            // Only notify listeners if data actually changed
            if (hasChanges) {
              _updateLoadedCommentIds(); // Update cached IDs
            notifyListeners();
            
              // Smart scroll: only scroll if user is near bottom (on first page)
              final isEffectivelyFirstPage = _lastCommentDocument == null || !_hasMoreComments;
              if (isEffectivelyFirstPage && !_userScrolledUp) {
                _scrollToBottomSmoothly();
              }
            } else if (kDebugMode) {
              print('ℹ️ No changes detected in stream update');
            }
          },
          onError: (error, stackTrace) {
            if (isDisposed) return;
            if (kDebugMode) {
              print('Error in comments stream: $error');
            }
            try {
              final exception = ExceptionMapper.mapToAppException(error, stackTrace);
              _errorHandler.handleError(exception, stackTrace, 'CommentViewModel._startCommentsListener');
            } catch (e) {
              if (kDebugMode) {
                print('Error in error handler: $e');
              }
            }
          },
          cancelOnError: false,
        );
  }

  /// Incrementally update comments list instead of replacing entire list
  /// Returns true if any changes were made
  bool _updateCommentsIncrementally(List<CommentModel> streamComments) {
    if (streamComments.isEmpty && comments.isEmpty) return false;

    // Create a map of existing comments for O(1) lookups
    final commentsMap = <String, CommentModel>{};
    final optimisticComments = <CommentModel>[];
    
    for (var comment in comments) {
      if (comment.commentId != null) {
        commentsMap[comment.commentId!] = comment;
      } else {
        // Keep optimistic comments (comments without ID yet)
        optimisticComments.add(comment);
      }
    }

    // Track if any changes were made
    bool hasChanges = false;
    final newComments = <CommentModel>[];

    // Update existing comments and collect new ones
    for (var streamComment in streamComments) {
      if (streamComment.commentId == null) continue;
      
      final existingComment = commentsMap[streamComment.commentId!];
      if (existingComment != null) {
        // Check if comment actually changed (compare content, username, replyCount, etc.)
        if (existingComment.content != streamComment.content ||
            existingComment.username != streamComment.username ||
            existingComment.userPhotoUrl != streamComment.userPhotoUrl ||
            existingComment.replyCount != streamComment.replyCount) {
          commentsMap[streamComment.commentId!] = streamComment;
          hasChanges = true;
          
          if (kDebugMode && existingComment.replyCount != streamComment.replyCount) {
            print('📊 Reply count updated for comment ${streamComment.commentId}: ${existingComment.replyCount} -> ${streamComment.replyCount}');
          }
        }
      } else {
        // New comment - always add if we're on first page, or if it's in our processed list
        // For first page: Always add new comments (they're in processedComments)
        // For later pages: Only add if it's in our loaded range (shouldn't happen, but handle it)
        final isNewComment = !_loadedCommentIds.contains(streamComment.commentId);
        
        if (isNewComment) {
          commentsMap[streamComment.commentId!] = streamComment;
          newComments.add(streamComment);
          hasChanges = true;
          
          if (kDebugMode) {
            print('🆕 Found new comment: ${streamComment.commentId} by ${streamComment.username}');
          }
        }
      }
    }

    // Replace optimistic comments with real ones if they match
    for (var optimisticComment in optimisticComments) {
      // Try to find matching real comment (by content and userId)
      CommentModel? matchingRealComment;
      try {
        matchingRealComment = streamComments.firstWhere(
          (c) => c.userId == optimisticComment.userId &&
                 c.content == optimisticComment.content &&
                 c.commentId != null,
        );
      } catch (e) {
        // No matching comment found, keep optimistic
        matchingRealComment = null;
      }
      
      if (matchingRealComment != null && matchingRealComment.commentId != null) {
        // Replace optimistic with real
        commentsMap[matchingRealComment.commentId!] = matchingRealComment;
        hasChanges = true;
        if (kDebugMode) {
          print('🔄 Replaced optimistic comment with real comment: ${matchingRealComment.commentId}');
        }
      }
      // If no match found, optimistic comment will be kept in the list
    }

    if (hasChanges) {
      // Rebuild comments list from map, preserving order (oldest first)
      var allComments = <CommentModel>[];
      
      // IMPORTANT: We're on "first page" if:
      // - _lastCommentDocument == null (no pagination yet), OR
      // - _hasMoreComments == false (we've loaded all comments, so effectively first page)
      final isEffectivelyFirstPage = _lastCommentDocument == null || !_hasMoreComments;
      
      if (isEffectivelyFirstPage) {
        // First page: use all comments from processed stream (sorted by createdAt)
        // This ensures new comments from other users appear in real-time
        // CRITICAL: Use streamComments (all processed) not just commentsMap
        // This ensures we include ALL comments from the stream, including new ones
        allComments.addAll(streamComments);
        allComments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        // Remove duplicates (in case streamComments has duplicates)
        final seenIds = <String>{};
        allComments = allComments.where((comment) {
          if (comment.commentId == null) return true; // Keep optimistic comments
          if (seenIds.contains(comment.commentId)) return false;
          seenIds.add(comment.commentId!);
          return true;
        }).toList();
        
        // Add any remaining optimistic comments that don't have real versions yet
        for (var optimistic in optimisticComments) {
          final hasRealVersion = allComments.any(
            (c) => c.commentId != null &&
                   c.userId == optimistic.userId && 
                   c.content == optimistic.content &&
                   // Match by timestamp within 5 seconds (handles timing differences)
                   (c.createdAt.difference(optimistic.createdAt).inSeconds.abs() < 5),
          );
          if (!hasRealVersion) {
            // Add optimistic comment at the end (it's the newest)
            allComments.add(optimistic);
          }
        }
        
        if (kDebugMode) {
          print('📄 First page: Showing ${allComments.length} comments (${newComments.length} new from others, ${optimisticComments.length} optimistic)');
        }
      } else {
        // Later pages: preserve existing order, only update changed comments
        // Don't add new comments here (they should be loaded via pagination)
        for (var existingComment in comments) {
          if (existingComment.commentId != null) {
            allComments.add(commentsMap[existingComment.commentId!] ?? existingComment);
          } else {
            allComments.add(existingComment);
          }
        }
        
        if (kDebugMode && newComments.isNotEmpty) {
          print('⚠️ Later page: Found ${newComments.length} new comments but not adding (use pagination)');
        }
      }

      comments = allComments;
      
      if (kDebugMode && newComments.isNotEmpty) {
        print('✨ Added ${newComments.length} new comments incrementally');
      }
    }

    return hasChanges;
  }

  /// Load more comments (next batch)
  Future<void> loadMoreComments() async {
    if (_post?.postId == null || isDisposed || _isLoadingMore || !_hasMoreComments) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // Load next batch
      final result = await _firestoreService.getCommentsPaginated(
        postId: _post!.postId!,
        limit: _loadMoreLimit,
        lastDocument: _lastCommentDocument,
        collectionName: _collectionName,
      );

      final commentsData = result['comments'] as List<Map<String, dynamic>>;
      _lastCommentDocument = result['lastDocument'];
      _hasMoreComments = result['hasMore'] as bool? ?? false;

      // Convert Firestore data to CommentModel list
      final newComments = commentsData.map((data) {
        try {
          return CommentModel.fromFirestore(
            _createDocumentSnapshot(data),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing comment: $e');
          }
          return null;
        }
      }).whereType<CommentModel>().toList();

      if (kDebugMode) {
        print('Loaded ${newComments.length} more comments. Has more: $_hasMoreComments. Total comments now: ${comments.length + newComments.length}');
      }

      // Check if disposed after async operation
      if (isDisposed) return;

      // If no new comments were loaded, there are no more comments
      if (newComments.isEmpty) {
        _hasMoreComments = false;
        if (kDebugMode) {
          print('No new comments loaded, setting hasMoreComments to false');
        }
      } else {
        // Add new comments to existing list
        comments.addAll(newComments);
        _updateLoadedCommentIds(); // Update cached IDs
      }

      // Restart real-time listener to include new comments
      _startCommentsListener();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading more comments: $e');
      }
      // Don't show error to user for load more failures
    } finally {
      if (!isDisposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Load comments for the current post (one-time fetch, used as fallback)
  Future<void> loadComments() async {
    if (_post?.postId == null) return;

    await handleAsync(() async {
      final commentsData = await _firestoreService.getComments(_post!.postId!);
      
      comments = commentsData.map((data) {
        try {
          return CommentModel.fromFirestore(
            _createDocumentSnapshot(data),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing comment: $e');
          }
          return null;
        }
      }).whereType<CommentModel>().toList();
      
      if (kDebugMode) {
        print('Loaded ${comments.length} comments');
      }
    }, 
    errorMessage: 'Failed to load comments',
    minimumLoadingDuration: AppDurations.minimumLoadingDuration);
  }

  /// Helper method to create a DocumentSnapshot-like object from Map
  dynamic _createDocumentSnapshot(Map<String, dynamic> data) {
    final commentId = data['commentId'] as String? ?? '';
    return _MockDocumentSnapshot(commentId, data);
  }

  void showEmojiKeyboard() {
    _showEmojiGrid = true;
    notifyListeners();
  }

  void hideEmojiKeyboard() {
    _showEmojiGrid = false;
    notifyListeners();
  }

  void insertEmoji(String emoji) {
    commentController.text += emoji;
    commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: commentController.text.length),
    );
    // Text change listener will handle debounced notifyListeners
  }

  Future<void> postComment() async {
    if (!canPostComment || _post?.postId == null) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final commentText = commentController.text.trim();
    if (commentText.isEmpty) return;

    await handleAsync(() async {
              // Get user info - prioritize Firestore over Firebase Auth
              // because Firestore has the uploaded profile image
              String username = _authService.userDisplayName ?? 
                               currentUser.email?.split('@')[0] ?? 
                               'Unknown User';
              
              String? userPhotoUrl;
              
              // Try to get from Firestore user data (where we save the uploaded image)
              try {
                final userData = await _firestoreService.getUserData(currentUser.uid);
                if (userData != null) {
                  if (userData['displayName'] != null) {
                    username = userData['displayName'] as String;
                  }
                  if (userData['photoUrl'] != null && (userData['photoUrl'] as String).isNotEmpty) {
                    userPhotoUrl = userData['photoUrl'] as String?;
                    if (kDebugMode) {
                      print('✅ Got userPhotoUrl from Firestore for comment: $userPhotoUrl');
                    }
                  } else {
                    if (kDebugMode) {
                      print('⚠️ Firestore userData exists but photoUrl is null or empty for comment');
                    }
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Could not fetch user data from Firestore: $e');
                }
              }
              
              // Fallback to Firebase Auth photoURL if not in Firestore
              if (userPhotoUrl == null || userPhotoUrl.isEmpty) {
                userPhotoUrl = _authService.userPhotoUrl;
                if (kDebugMode) {
                  print('📸 Got userPhotoUrl from Firebase Auth for comment: $userPhotoUrl');
                }
              }
              
              if (kDebugMode) {
                print('🎯 Final userPhotoUrl for comment: $userPhotoUrl');
              }

      // Optimistically add comment to UI immediately (before Firestore save)
      // This provides instant feedback to the user
      final now = DateTime.now();
      final optimisticComment = CommentModel(
        commentId: null, // Will be set when Firestore returns the actual ID
        postId: _post!.postId!,
        userId: currentUser.uid,
        username: username,
        content: commentText,
        createdAt: now,
        userPhotoUrl: userPhotoUrl,
        cachedTimeAgo: 'Just now', // Optimistic comment is always "Just now"
      );
      
      // Add to comments list immediately
      comments.add(optimisticComment);
      _updateLoadedCommentIds(); // Update cached IDs
      notifyListeners(); // Update UI immediately
      
      // Reset scroll state and scroll to bottom to show the newly posted comment
      _userScrolledUp = false;
      _scrollToBottomSmoothly();
      
      if (kDebugMode) {
        print('✨ Optimistically added comment to UI and scrolled to bottom');
      }

      // Save comment to Firestore
      await _firestoreService.saveComment(
        postId: _post!.postId!,
        userId: currentUser.uid,
        username: username,
        content: commentText,
        userPhotoUrl: userPhotoUrl,
        collectionName: _collectionName,
      );

      // Clear input
      commentController.clear();
      hideEmojiKeyboard();

      // The real-time listener will update the optimistic comment with the actual Firestore data
      // (including the real commentId) when it receives the update from the stream
      
      if (kDebugMode) {
        print('✅ Comment saved to Firestore. Real-time listener will update with actual data.');
      }
    }, 
    errorMessage: AppStrings.failedToPostComment,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }

  /// Toggle replies visibility for a comment (loads replies if not loaded)
  void toggleReplies(String commentId) {
    if (_repliesExpanded[commentId] == true) {
      // Collapse replies
      _repliesExpanded[commentId] = false;
      notifyListeners();
    } else {
      // Expand replies - load immediately and start listening
      _repliesExpanded[commentId] = true;
      
      // If replies are not already loaded, load them first
      if (!_replySubscriptions.containsKey(commentId) || _repliesMap[commentId] == null) {
        _loadRepliesImmediately(commentId);
      }
      
      // Start real-time listener if not already started
      if (!_replySubscriptions.containsKey(commentId)) {
        _startRepliesListener(commentId);
      }
      
      notifyListeners();
    }
  }
  
  /// Load replies immediately from Firestore (one-time fetch)
  /// This ensures replies are shown immediately when user expands
  Future<void> _loadRepliesImmediately(String commentId) async {
    if (_post?.postId == null || isDisposed) return;
    
    try {
      // Get replies stream and take first snapshot
      final repliesStream = _firestoreService.getRepliesStream(
        postId: _post!.postId!,
        parentCommentId: commentId,
      );
      
      // Get initial data
      final repliesData = await repliesStream.first;
      
      if (isDisposed) return;
      
      // Convert to CommentModel
      final processedReplies = <CommentModel>[];
      for (var data in repliesData) {
        try {
          final reply = CommentModel.fromFirestore(
            _createDocumentSnapshot(data),
          );
          processedReplies.add(reply);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing reply: $e');
          }
        }
      }
      
      // Sort by createdAt
      processedReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Update replies map
      _repliesMap[commentId] = processedReplies;
      _loadedReplyIds[commentId] = processedReplies
          .where((r) => r.commentId != null)
          .map((r) => r.commentId!)
          .toSet();
      
      if (kDebugMode) {
        print('📥 Loaded ${processedReplies.length} replies immediately for comment: $commentId');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading replies immediately: $e');
      }
      // Initialize empty list on error
      _repliesMap[commentId] = [];
      _loadedReplyIds[commentId] = {};
    }
  }
  
  /// Start listening to real-time replies for a comment
  /// Performance optimized: only loads when replies are expanded
  void _startRepliesListener(String commentId) {
    if (_post?.postId == null || isDisposed) return;
    
    // Cancel existing subscription if any
    _replySubscriptions[commentId]?.cancel();
    
    // Initialize replies list and loaded IDs
    _repliesMap[commentId] = [];
    _loadedReplyIds[commentId] = {};
    
    // Listen to replies stream
    _replySubscriptions[commentId] = _firestoreService
        .getRepliesStream(
          postId: _post!.postId!,
          parentCommentId: commentId,
          collectionName: _collectionName,
        )
        .listen(
          (repliesData) {
            if (isDisposed) return;
            
            if (kDebugMode) {
              print('📥 Real-time replies update: Received ${repliesData.length} replies for comment: $commentId');
            }
            
            // Convert to CommentModel
            final processedReplies = <CommentModel>[];
            for (var data in repliesData) {
              try {
                final reply = CommentModel.fromFirestore(
                  _createDocumentSnapshot(data),
                );
                processedReplies.add(reply);
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing reply from stream: $e');
                }
              }
            }
            
            // Incremental update for replies
            _updateRepliesIncrementally(commentId, processedReplies);
          },
          onError: (error, stackTrace) {
            if (isDisposed) return;
            if (kDebugMode) {
              print('Error in replies stream for comment $commentId: $error');
            }
            try {
              final exception = ExceptionMapper.mapToAppException(error, stackTrace);
              _errorHandler.handleError(exception, stackTrace, 'CommentViewModel._startRepliesListener');
            } catch (e) {
              if (kDebugMode) {
                print('Error in error handler: $e');
              }
            }
          },
          cancelOnError: false,
        );
  }
  
  /// Incrementally update replies list (performance optimized)
  void _updateRepliesIncrementally(String commentId, List<CommentModel> streamReplies) {
    final existingReplies = _repliesMap[commentId] ?? [];
    final loadedIds = _loadedReplyIds[commentId] ?? {};
    
    // Create map of existing replies
    final repliesMap = <String, CommentModel>{};
    for (var reply in existingReplies) {
      if (reply.commentId != null) {
        repliesMap[reply.commentId!] = reply;
      }
    }
    
    bool hasChanges = false;
    
    // Update existing or add new replies
    for (var streamReply in streamReplies) {
      if (streamReply.commentId == null) continue;
      
      final existingReply = repliesMap[streamReply.commentId!];
      if (existingReply != null) {
        // Check if reply changed
        if (existingReply.content != streamReply.content ||
            existingReply.username != streamReply.username ||
            existingReply.userPhotoUrl != streamReply.userPhotoUrl) {
          repliesMap[streamReply.commentId!] = streamReply;
          hasChanges = true;
        }
      } else {
        // New reply
        if (!loadedIds.contains(streamReply.commentId)) {
          repliesMap[streamReply.commentId!] = streamReply;
          loadedIds.add(streamReply.commentId!);
          hasChanges = true;
          
          if (kDebugMode) {
            print('🆕 New reply added: ${streamReply.commentId} to comment: $commentId');
          }
        }
      }
    }
    
    if (hasChanges) {
      // Rebuild replies list sorted by createdAt
      final allReplies = repliesMap.values.toList();
      allReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _repliesMap[commentId] = allReplies;
      _loadedReplyIds[commentId] = loadedIds;
      
      // Update reply count in parent comment
      // Use the actual loaded replies count (more accurate than Firestore count)
      final commentIndex = comments.indexWhere((c) => c.commentId == commentId);
      if (commentIndex != -1) {
        final currentReplyCount = comments[commentIndex].replyCount;
        // Use max of Firestore count and actual loaded count (handles edge cases)
        final newReplyCount = allReplies.length > currentReplyCount 
            ? allReplies.length 
            : currentReplyCount;
        
        if (newReplyCount != currentReplyCount) {
          comments[commentIndex] = comments[commentIndex].copyWith(
            replyCount: newReplyCount,
          );
          
          if (kDebugMode) {
            print('📊 Updated reply count for comment $commentId: $currentReplyCount -> $newReplyCount (${allReplies.length} loaded)');
          }
        }
      }
      
      notifyListeners();
    }
  }
  
  /// Start replying to a comment
  void startReplying(String commentId) {
    _replyingToCommentId = commentId;
    replyController.clear();
    notifyListeners();
  }
  
  /// Cancel replying
  void cancelReplying() {
    _replyingToCommentId = null;
    replyController.clear();
    notifyListeners();
  }
  
  /// Post a reply to a comment
  Future<void> postReply(String parentCommentId) async {
    if (_post?.postId == null || parentCommentId.isEmpty) return;
    
    final replyText = replyController.text.trim();
    if (replyText.isEmpty) return;
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    await handleAsync(() async {
      // Get user info
      String username = _authService.userDisplayName ?? 
                       currentUser.email?.split('@')[0] ?? 
                       'Unknown User';
      
      String? userPhotoUrl;
      
      try {
        final userData = await _firestoreService.getUserData(currentUser.uid);
        if (userData != null) {
          if (userData['displayName'] != null) {
            username = userData['displayName'] as String;
          }
          if (userData['photoUrl'] != null && (userData['photoUrl'] as String).isNotEmpty) {
            userPhotoUrl = userData['photoUrl'] as String?;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Could not fetch user data from Firestore: $e');
        }
      }
      
      if (userPhotoUrl == null || userPhotoUrl.isEmpty) {
        userPhotoUrl = _authService.userPhotoUrl;
      }
      
      // Optimistically add reply to UI
      final now = DateTime.now();
      final optimisticReply = CommentModel(
        commentId: null,
        postId: _post!.postId!,
        userId: currentUser.uid,
        username: username,
        content: replyText,
        createdAt: now,
        userPhotoUrl: userPhotoUrl,
        parentCommentId: parentCommentId,
        cachedTimeAgo: 'Just now',
      );
      
      // Add to replies list immediately
      _repliesMap[parentCommentId] ??= [];
      _repliesMap[parentCommentId]!.add(optimisticReply);
      
      // Update reply count
      final commentIndex = comments.indexWhere((c) => c.commentId == parentCommentId);
      if (commentIndex != -1) {
        comments[commentIndex] = comments[commentIndex].copyWith(
          replyCount: _repliesMap[parentCommentId]!.length,
        );
      }
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✨ Optimistically added reply to UI');
      }
      
      // Save reply to Firestore
      await _firestoreService.saveReply(
        postId: _post!.postId!,
        parentCommentId: parentCommentId,
        userId: currentUser.uid,
        username: username,
        content: replyText,
        userPhotoUrl: userPhotoUrl,
        collectionName: _collectionName,
      );
      
      // Clear input and cancel replying
      replyController.clear();
      cancelReplying();
      
      if (kDebugMode) {
        print('✅ Reply saved to Firestore. Real-time listener will update with actual data.');
      }
    },
    errorMessage: 'Failed to post reply',
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }
  
  /// Check if can post reply
  bool canPostReply() {
    return _replyingToCommentId != null && 
           replyController.text.trim().isNotEmpty;
  }

  Future<void> closeCommentView() async {
    // Close the comment view and return to previous screen
    // Pass true to indicate comments were updated
    _navigationService.pop(true);
  }

  /// Scroll to bottom of comments list (only if user is near bottom)
  void _scrollToBottomSmoothly() {
    if (!scrollController.hasClients || isDisposed) return;
    
    // Cancel any pending scroll
    _scrollCheckTimer?.cancel();
    
    // Use a small delay to ensure the list has been built
    _scrollCheckTimer = Timer(const Duration(milliseconds: 150), () {
      if (!scrollController.hasClients || isDisposed) return;
      
      // Only scroll if user is already near bottom (within 200px)
      // This prevents interrupting user if they're reading older comments
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;
      final distanceFromBottom = maxScroll - currentScroll;
      
      if (distanceFromBottom <= 200 || !_userScrolledUp) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else if (kDebugMode) {
        print('⏸️ Skipping auto-scroll: User is reading older comments');
      }
    });
  }
  
  /// Scroll to bottom immediately (for initial load)
  void _scrollToBottom() {
    if (!scrollController.hasClients || isDisposed) return;
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients && !isDisposed) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void onDispose() {
    // Cancel timers
    _textDebounceTimer?.cancel();
    _scrollCheckTimer?.cancel();
    
    // Remove scroll listener
    scrollController.removeListener(_onScrollChanged);
    commentController.removeListener(_onTextChanged);
    
    // Cancel the real-time listener when view is disposed
    _commentsSubscription?.cancel();
    _commentsSubscription = null;
    
    // Cancel all reply subscriptions
    for (var subscription in _replySubscriptions.values) {
      subscription.cancel();
    }
    _replySubscriptions.clear();
    
    // Clear references to prevent memory leaks
    comments.clear();
    _loadedCommentIds.clear();
    _repliesMap.clear();
    _repliesExpanded.clear();
    _loadedReplyIds.clear();
    _post = null;
    _lastCommentDocument = null;
    _replyingToCommentId = null;
    
    // Dispose controllers
    commentController.dispose();
    replyController.dispose();
    scrollController.dispose();
    
    super.onDispose();
  }
}

/// Mock DocumentSnapshot for converting Map to CommentModel
class _MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic> data;

  _MockDocumentSnapshot(this.id, this.data);

  String get docId => id;
  
  Map<String, dynamic>? get dataMap => data;
  
  dynamic operator [](String key) => data[key];
}
