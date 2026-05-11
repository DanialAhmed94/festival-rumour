import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class NotificationServiceApi {
  static const String _baseUrl =
      "https://us-central1-crapapps-65472.cloudfunctions.net";

  /// Omit generic DM room label so FCM titles stay `title`/`message` only (no "Direct message · …").
  static String? _chatRoomNameForPushPayload(String? chatRoomName) {
    if (chatRoomName == null) return null;
    final t = chatRoomName.trim();
    if (t.isEmpty) return null;
    if (t.toLowerCase() == 'direct message') return null;
    return t;
  }

  /// Send push notification to multiple users by userIds.
  /// Single request regardless of group size. The Cloud Function (sendNotification) must
  /// send exactly one FCM message per userId in [userIds] (e.g. for each user fetch their
  /// tokens and send once). It must NOT send one message to the entire list per userId,
  /// or recipients will get duplicate notifications (one per member in the group).
  /// [chatRoomId] optional; when set, included in FCM data so recipient can suppress
  /// notification if they are currently viewing that room.
  /// [chatRoomName] optional; when set, shown in the notification (e.g. in title).
  /// [festivalId] optional; when set, included in FCM data so recipient can
  /// distinguish private chatroom notifications from DM notifications on tap.
  ///
  /// Notifies recipients they were added to a private group. FCM payload matches chat
  /// notifications so taps open the correct screen ([festivalId] selects chat vs DM route).
  static Future<bool> notifyUsersAddedToPrivateGroup({
    required List<String> recipientUserIds,
    required String chatRoomId,
    required String roomName,
    required String addedByDisplayName,
    String? festivalId,
  }) {
    if (recipientUserIds.isEmpty) return Future.value(true);
    final actor =
        addedByDisplayName.trim().isEmpty ? 'Someone' : addedByDisplayName.trim();
    final safeRoom = roomName.trim().isEmpty ? 'Chat' : roomName.trim();
    return sendPushNotification(
      userIds: recipientUserIds,
      title: actor,
      message: 'Added you to the private group \"$safeRoom\".',
      chatRoomId: chatRoomId,
      chatRoomName: safeRoom,
      festivalId: festivalId,
    );
  }

  static Future<bool> sendPushNotification({
    required List<String> userIds,
    required String title,
    required String message,
    String? chatRoomId,
    String? chatRoomName,
    String? festivalId,
  }) async {
    final nameForPayload = _chatRoomNameForPushPayload(chatRoomName);
    print('[NOTIF] API: sendPushNotification called — userIds=${userIds.length}, chatRoomId=$chatRoomId, chatRoomName=$chatRoomName, festivalId=$festivalId, title="$title"');
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('[NOTIF] API: abort — user not logged in');
        return false;
      }

      final idToken = await user.getIdToken();
      print('[NOTIF] API: POST to sendNotification (${userIds.length} recipients)');

      final response = await http.post(
        Uri.parse("$_baseUrl/sendNotification"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "userIds": userIds,
          "title": title,
          "message": message,
          if (chatRoomId != null && chatRoomId.isNotEmpty) "chatRoomId": chatRoomId,
          if (nameForPayload != null && nameForPayload.isNotEmpty) "chatRoomName": nameForPayload,
          if (festivalId != null && festivalId.isNotEmpty) "festivalId": festivalId,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final sent = decoded['sentCount'] ?? 0;
        final failed = decoded['failedCount'] ?? 0;
        print('[NOTIF] API: ✅ Response 200, sentCount=$sent, failedCount=$failed');
        return true;
      } else {
        print('[NOTIF] API: ❌ HTTP ${response.statusCode}, body=${response.body}');
        return false;
      }
    } catch (e) {
      print('[NOTIF] API: ❌ Error: $e');
      return false;
    }
  }
}
