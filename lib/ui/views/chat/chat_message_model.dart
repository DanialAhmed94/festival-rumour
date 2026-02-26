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
  /// Optional: 'location' for shared-location messages
  final String? type;
  final double? lat;
  final double? lng;
  final String? festivalName;

  ChatMessageModel({
    this.messageId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
    this.userPhotoUrl,
    required this.chatRoomId,
    this.type,
    this.lat,
    this.lng,
    this.festivalName,
  });

  bool get isLocationMessage =>
      type == 'location' && lat != null && lng != null;

  /// Create ChatMessageModel from Firestore document
  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = data['createdAt'] as Timestamp?;
    final lat = data['lat'];
    final lng = data['lng'];
    return ChatMessageModel(
      messageId: doc.id,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? 'Unknown',
      content: data['content'] as String? ?? '',
      createdAt: createdAt?.toDate() ?? DateTime.now(),
      userPhotoUrl: data['userPhotoUrl'] as String?,
      chatRoomId: data['chatRoomId'] as String? ?? '',
      type: data['type'] as String?,
      lat: lat is num ? lat.toDouble() : null,
      lng: lng is num ? lng.toDouble() : null,
      festivalName: data['festivalName'] as String?,
    );
  }

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
    return map;
  }

  /// Get time ago string (e.g., "5 minutes ago", "2:30 PM")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    // If same day, show time (e.g., "2:30 PM")
    if (createdAt.year == now.year && 
        createdAt.month == now.month && 
        createdAt.day == now.day) {
      final hour = createdAt.hour;
      final minute = createdAt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
    
    // If less than 1 minute, show "Just now"
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

  /// Create a copy with updated fields
  ChatMessageModel copyWith({
    String? messageId,
    String? userId,
    String? username,
    String? content,
    DateTime? createdAt,
    String? userPhotoUrl,
    String? chatRoomId,
    String? type,
    double? lat,
    double? lng,
    String? festivalName,
  }) {
    return ChatMessageModel(
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      festivalName: festivalName ?? this.festivalName,
    );
  }
}
