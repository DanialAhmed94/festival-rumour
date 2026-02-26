import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String? postId; // Firestore document ID
  final String username;
  final String timeAgo;
  final String content;
  final String imagePath; // For backward compatibility - use first media item if multiple
  final int likes;
  final int comments;
  final String status; // 'live', 'past', 'upcoming'
  final bool isVideo; // Whether the first media is a video (for backward compatibility)
  final List<String>? mediaPaths; // List of all media paths (images and videos)
  final List<bool>? isVideoList; // List indicating which items are videos
  final DateTime? createdAt; // Timestamp when post was created
  final String? userReaction; // Current user's selected emotion/emoji for this post
  final Map<String, int>? reactionCounts; // Count of reactions per emotion (e.g., {'👍': 5, '❤️': 3})
  final String? userPhotoUrl; // User's profile photo URL from Firestore
  final String? userId; // User ID to fetch profile photo if userPhotoUrl is missing
  final String? postUrl; // Optional URL attached to the post
  final String? linkPreviewImageUrl; // Thumbnail for link preview (og:image)
  final String? linkPreviewTitle; // Title/headline for link preview (og:title)

  PostModel({
    this.postId,
    required this.username,
    required this.timeAgo,
    required this.content,
    required this.imagePath,
    required this.likes,
    required this.comments,
    required this.status,
    this.isVideo = false, // Default to false for backward compatibility
    this.mediaPaths,
    this.isVideoList,
    this.createdAt,
    this.userReaction,
    this.reactionCounts,
    this.userPhotoUrl,
    this.userId,
    this.postUrl,
    this.linkPreviewImageUrl,
    this.linkPreviewTitle,
  });

  /// Get total reaction count (sum of all emotion counts)
  int get totalReactions {
    if (reactionCounts == null || reactionCounts!.isEmpty) return 0;
    return reactionCounts!.values.fold(0, (sum, count) => sum + count);
  }

  // Helper getter to check if post has multiple media items
  bool get hasMultipleMedia {
    if (mediaPaths != null && mediaPaths!.isNotEmpty) {
      return mediaPaths!.length > 1;
    }
    return false; // Old posts have single media
  }

  // Helper getter to get all media items (for backward compatibility, returns single item list)
  List<String> get allMediaPaths {
    if (mediaPaths != null && mediaPaths!.isNotEmpty) {
      return mediaPaths!;
    }
    return [imagePath]; // Fallback to single imagePath for old posts
  }

  /// True when the post has at least one non-empty media path (image or video).
  bool get hasMedia {
    final paths = allMediaPaths;
    return paths.any((p) => p.trim().isNotEmpty);
  }

  // Helper getter to check if item at index is video
  bool isVideoAtIndex(int index) {
    if (isVideoList != null && index < isVideoList!.length) {
      return isVideoList![index];
    }
    // Fallback for old posts with single item
    return index == 0 && isVideo;
  }

  /// Create PostModel from Firestore document
  factory PostModel.fromFirestore(dynamic doc) {
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
    Timestamp? createdAtTimestamp;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAtTimestamp = data['createdAt'] as Timestamp;
      } else if (data['createdAt'] is DateTime) {
        // Convert DateTime to Timestamp for consistency
        createdAtTimestamp = Timestamp.fromDate(data['createdAt'] as DateTime);
      }
    }
    
    final createdAt = createdAtTimestamp;
    
    // Calculate timeAgo from createdAt
    String timeAgo = "Just now";
    if (createdAt != null) {
      final now = DateTime.now();
      final postTime = createdAt.toDate();
      final difference = now.difference(postTime);
      
      if (difference.inMinutes < 1) {
        timeAgo = "Just now";
      } else if (difference.inMinutes < 60) {
        timeAgo = "${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago";
      } else if (difference.inHours < 24) {
        timeAgo = "${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago";
      } else {
        timeAgo = "${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago";
      }
    }
    
    return PostModel(
      postId: docId,
      username: data['username'] as String? ?? 'Unknown',
      timeAgo: timeAgo,
      content: data['content'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      likes: (data['likes'] as int?) ?? 0,
      comments: (data['comments'] as int?) ?? 0,
      status: data['status'] as String? ?? 'live',
      isVideo: (data['isVideo'] as bool?) ?? false,
      mediaPaths: data['mediaPaths'] != null ? List<String>.from(data['mediaPaths']) : null,
      isVideoList: data['isVideoList'] != null ? List<bool>.from(data['isVideoList'].map((e) => e as bool)) : null,
      createdAt: createdAt?.toDate(),
      userReaction: data['userReaction'] as String?, // Will be set separately when loading user reactions
      reactionCounts: data['reactionCounts'] != null 
          ? Map<String, int>.from(
              (data['reactionCounts'] as Map).map(
                (key, value) => MapEntry(key.toString(), (value as num).toInt()),
              ),
            )
          : null,
      userPhotoUrl: data['userPhotoUrl'] as String?,
      userId: data['userId'] as String?,
      postUrl: data['postUrl'] as String?,
      linkPreviewImageUrl: data['linkPreviewImageUrl'] as String?,
      linkPreviewTitle: data['linkPreviewTitle'] as String?,
    );
  }

  /// Convert PostModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'content': content,
      'imagePath': imagePath,
      'likes': likes,
      'comments': comments,
      'status': status,
      'isVideo': isVideo,
      'mediaPaths': mediaPaths,
      'isVideoList': isVideoList,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'userPhotoUrl': userPhotoUrl,
      'userId': userId,
      'postUrl': postUrl,
      'linkPreviewImageUrl': linkPreviewImageUrl,
      'linkPreviewTitle': linkPreviewTitle,
    };
  }

  PostModel copyWith({
    String? postId,
    String? username,
    String? timeAgo,
    String? content,
    String? imagePath,
    int? likes,
    int? comments,
    String? status,
    bool? isVideo,
    List<String>? mediaPaths,
    List<bool>? isVideoList,
    DateTime? createdAt,
    String? userReaction,
    Map<String, int>? reactionCounts,
    String? userPhotoUrl,
    String? userId,
    String? postUrl,
    String? linkPreviewImageUrl,
    String? linkPreviewTitle,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      username: username ?? this.username,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      status: status ?? this.status,
      isVideo: isVideo ?? this.isVideo,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      isVideoList: isVideoList ?? this.isVideoList,
      createdAt: createdAt ?? this.createdAt,
      userReaction: userReaction ?? this.userReaction,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      userId: userId ?? this.userId,
      postUrl: postUrl ?? this.postUrl,
      linkPreviewImageUrl: linkPreviewImageUrl ?? this.linkPreviewImageUrl,
      linkPreviewTitle: linkPreviewTitle ?? this.linkPreviewTitle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostModel &&
        other.username == username &&
        other.timeAgo == timeAgo &&
        other.content == content &&
        other.imagePath == imagePath &&
        other.likes == likes &&
        other.comments == comments &&
        other.status == status &&
        other.isVideo == isVideo &&
        other.mediaPaths == mediaPaths &&
        other.isVideoList == isVideoList &&
        other.postUrl == postUrl &&
        other.linkPreviewImageUrl == linkPreviewImageUrl &&
        other.linkPreviewTitle == linkPreviewTitle;
  }

  @override
  int get hashCode {
    return username.hashCode ^
    timeAgo.hashCode ^
    content.hashCode ^
    imagePath.hashCode ^
    likes.hashCode ^
    comments.hashCode ^
    status.hashCode ^
    isVideo.hashCode ^
    (mediaPaths?.hashCode ?? 0) ^
    (isVideoList?.hashCode ?? 0) ^
    (postUrl?.hashCode ?? 0) ^
    (linkPreviewImageUrl?.hashCode ?? 0) ^
    (linkPreviewTitle?.hashCode ?? 0);
  }

  @override
  String toString() {
    return 'PostModel(username: $username, timeAgo: $timeAgo, content: $content, imagePath: $imagePath, likes: $likes, comments: $comments, status: $status, isVideo: $isVideo, mediaCount: ${mediaPaths?.length ?? 1})';
  }
}
