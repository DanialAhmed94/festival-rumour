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

  ChatMessageModel({
    this.messageId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
    this.userPhotoUrl,
    required this.chatRoomId,
  });

  /// Create ChatMessageModel from Firestore document
  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = data['createdAt'] as Timestamp?;
    
    return ChatMessageModel(
      messageId: doc.id,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? 'Unknown',
      content: data['content'] as String? ?? '',
      createdAt: createdAt?.toDate() ?? DateTime.now(),
      userPhotoUrl: data['userPhotoUrl'] as String?,
      chatRoomId: data['chatRoomId'] as String? ?? '',
    );
  }

  /// Convert ChatMessageModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'userPhotoUrl': userPhotoUrl,
      'chatRoomId': chatRoomId,
    };
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
  }) {
    return ChatMessageModel(
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      chatRoomId: chatRoomId ?? this.chatRoomId,
    );
  }
}
