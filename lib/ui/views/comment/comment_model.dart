import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String? commentId; // Firestore document ID
  final String postId; // Post this comment belongs to
  final String userId; // User who posted the comment
  final String username; // Username of the commenter
  final String content; // Comment text
  final DateTime createdAt; // When comment was created
  final String? userPhotoUrl; // User's profile photo URL
  final String? _cachedTimeAgo; // Cached time ago string to avoid recalculation
  final String? parentCommentId; // If this is a reply, the parent comment ID
  final int replyCount; // Number of replies to this comment
  final List<CommentModel>? replies; // Nested replies (loaded on demand for performance)

  CommentModel({
    this.commentId,
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
    this.userPhotoUrl,
    String? cachedTimeAgo,
    this.parentCommentId,
    this.replyCount = 0,
    this.replies,
  }) : _cachedTimeAgo = cachedTimeAgo;
  
  /// Check if this is a reply (has a parent comment)
  bool get isReply => parentCommentId != null;
  
  /// Check if this is a top-level comment
  bool get isTopLevel => parentCommentId == null;

  /// Create CommentModel from Firestore document
  factory CommentModel.fromFirestore(dynamic doc) {
    // Handle both DocumentSnapshot and mock document snapshot
    Map<String, dynamic> data;
    String docId;
    
    if (doc is DocumentSnapshot) {
      data = doc.data() as Map<String, dynamic>? ?? {};
      docId = doc.id;
    } else {
      // Mock document snapshot
      data = doc.dataMap ?? doc.data() as Map<String, dynamic>? ?? {};
      docId = doc.docId ?? doc.id ?? '';
    }
    
    // Get createdAt timestamp
    DateTime createdAt;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is DateTime) {
        createdAt = data['createdAt'] as DateTime;
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }
    
    // Calculate timeAgo once during model creation and cache it
    final timeAgo = _calculateTimeAgo(createdAt);
    
    return CommentModel(
      commentId: docId,
      postId: data['postId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? 'Unknown',
      content: data['content'] as String? ?? '',
      createdAt: createdAt,
      userPhotoUrl: data['userPhotoUrl'] as String?,
      cachedTimeAgo: timeAgo,
      parentCommentId: data['parentCommentId'] as String?,
      replyCount: (data['replyCount'] as int?) ?? 0,
      replies: null, // Replies loaded separately for performance
    );
  }

  /// Convert CommentModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    final map = {
      'postId': postId,
      'userId': userId,
      'username': username,
      'content': content,
      'userPhotoUrl': userPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    
    // Only include parentCommentId if this is a reply
    if (parentCommentId != null) {
      map['parentCommentId'] = parentCommentId;
    }
    
    return map;
  }

  /// Get time ago string (e.g., "5 minutes ago")
  /// Uses cached value to avoid recalculation on every access
  String get timeAgo {
    // Return cached value if available (calculated during model creation)
    if (_cachedTimeAgo != null) {
      return _cachedTimeAgo!;
    }
    
    // Fallback calculation (should rarely be needed)
    return _calculateTimeAgo(createdAt);
  }
  
  /// Calculate time ago string from a DateTime
  static String _calculateTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago";
    } else {
      return "${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago";
    }
  }
  
  /// Create a copy with updated cached timeAgo (for periodic updates if needed)
  CommentModel copyWith({
    String? commentId,
    String? postId,
    String? userId,
    String? username,
    String? content,
    DateTime? createdAt,
    String? userPhotoUrl,
    String? cachedTimeAgo,
    String? parentCommentId,
    int? replyCount,
    List<CommentModel>? replies,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      cachedTimeAgo: cachedTimeAgo ?? _cachedTimeAgo,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyCount: replyCount ?? this.replyCount,
      replies: replies ?? this.replies,
    );
  }
}

