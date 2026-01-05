/// Lightweight post information for profile grid display
/// Contains only essential data needed for initial display
class ProfilePostInfo {
  final String postId;
  final String mediaUrl; // Image or video URL
  final String collectionName; // Collection where post is stored
  final bool isVideo;

  ProfilePostInfo({
    required this.postId,
    required this.mediaUrl,
    required this.collectionName,
    required this.isVideo,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'mediaUrl': mediaUrl,
      'collectionName': collectionName,
      'isVideo': isVideo,
    };
  }

  factory ProfilePostInfo.fromMap(Map<String, dynamic> map) {
    return ProfilePostInfo(
      postId: map['postId'] as String,
      mediaUrl: map['mediaUrl'] as String,
      collectionName: map['collectionName'] as String,
      isVideo: map['isVideo'] as bool,
    );
  }
}

