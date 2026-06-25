import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for chat messages
class ChatMessageModel {
  final String? messageId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;
  final String? userPhotoUrl;
  final String chatRoomId;

  /// Frozen label at parse time so list rows do not re-do [DateTime.now] work every build.
  final String? _cachedTimeAgo;
  /// Optional message type: 'location' (shared location), 'media' (images/videos
  /// album), or 'audio' (voice note). null = plain text.
  final String? type;
  final double? lat;
  final double? lng;
  final String? festivalName;

  /// Media payload (Storage download URLs). For 'media' this is the image/video
  /// album; for 'audio' it holds the single voice-note URL.
  final List<String>? mediaUrls;

  /// Parallel to [mediaUrls]; true = video, false = image. Only meaningful for 'media'.
  final List<bool>? isVideoList;

  /// Voice-note length in milliseconds (audio only).
  final int? audioDurationMs;

  /// Optional poster-frame URL for the first video (nullable).
  final String? thumbnailUrl;

  ChatMessageModel({
    this.messageId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
    this.userPhotoUrl,
    required this.chatRoomId,
    String? cachedTimeAgo,
    this.type,
    this.lat,
    this.lng,
    this.festivalName,
    this.mediaUrls,
    this.isVideoList,
    this.audioDurationMs,
    this.thumbnailUrl,
  }) : _cachedTimeAgo = cachedTimeAgo;

  static String timeAgoLabel(DateTime createdAt, DateTime referenceNow) {
    final difference = referenceNow.difference(createdAt);

    if (createdAt.year == referenceNow.year &&
        createdAt.month == referenceNow.month &&
        createdAt.day == referenceNow.day) {
      final hour = createdAt.hour;
      final minute = createdAt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    }
  }

  bool get isLocationMessage =>
      type == 'location' && lat != null && lng != null;

  /// Album of images/videos.
  bool get isMediaMessage =>
      type == 'media' && (mediaUrls?.isNotEmpty ?? false);

  /// Single voice note.
  bool get isAudioMessage =>
      type == 'audio' && (mediaUrls?.isNotEmpty ?? false);

  bool isVideoAtIndex(int i) =>
      (isVideoList != null && i < isVideoList!.length) ? isVideoList![i] : false;

  /// Create ChatMessageModel from Firestore document
  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAtTs = data['createdAt'] as Timestamp?;
    final createdAt = createdAtTs?.toDate() ?? DateTime.now();
    final lat = data['lat'];
    final lng = data['lng'];
    final cached = timeAgoLabel(createdAt, DateTime.now());
    return ChatMessageModel(
      messageId: doc.id,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? 'Unknown',
      content: data['content'] as String? ?? '',
      createdAt: createdAt,
      userPhotoUrl: data['userPhotoUrl'] as String?,
      chatRoomId: data['chatRoomId'] as String? ?? '',
      cachedTimeAgo: cached,
      type: data['type'] as String?,
      lat: lat is num ? lat.toDouble() : null,
      lng: lng is num ? lng.toDouble() : null,
      festivalName: data['festivalName'] as String?,
      mediaUrls: _parseStringList(data['mediaUrls']),
      isVideoList: _parseBoolList(data['isVideoList']),
      audioDurationMs: (data['audioDurationMs'] as num?)?.toInt(),
      thumbnailUrl: data['thumbnailUrl'] as String?,
    );
  }

  static List<String>? _parseStringList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : null;

  static List<bool>? _parseBoolList(dynamic v) =>
      v is List ? v.map((e) => e == true).toList() : null;

  /// Convert ChatMessageModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'userId': userId,
      'username': username,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'userPhotoUrl': userPhotoUrl,
      'chatRoomId': chatRoomId,
    };
    if (type != null) map['type'] = type;
    if (lat != null) map['lat'] = lat;
    if (lng != null) map['lng'] = lng;
    if (festivalName != null) map['festivalName'] = festivalName;
    if (mediaUrls != null) map['mediaUrls'] = mediaUrls;
    if (isVideoList != null) map['isVideoList'] = isVideoList;
    if (audioDurationMs != null) map['audioDurationMs'] = audioDurationMs;
    if (thumbnailUrl != null) map['thumbnailUrl'] = thumbnailUrl;
    return map;
  }

  /// Get time ago string (e.g., "5 minutes ago", "2:30 PM")
  String get timeAgo => _cachedTimeAgo ?? timeAgoLabel(createdAt, DateTime.now());

  /// Create a copy with updated fields
  ChatMessageModel copyWith({
    String? messageId,
    String? userId,
    String? username,
    String? content,
    DateTime? createdAt,
    String? userPhotoUrl,
    String? chatRoomId,
    String? cachedTimeAgo,
    String? type,
    double? lat,
    double? lng,
    String? festivalName,
    List<String>? mediaUrls,
    List<bool>? isVideoList,
    int? audioDurationMs,
    String? thumbnailUrl,
  }) {
    final nextCreated = createdAt ?? this.createdAt;
    return ChatMessageModel(
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      createdAt: nextCreated,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      cachedTimeAgo: cachedTimeAgo ??
          (createdAt != null
              ? timeAgoLabel(nextCreated, DateTime.now())
              : _cachedTimeAgo),
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      festivalName: festivalName ?? this.festivalName,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      isVideoList: isVideoList ?? this.isVideoList,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
