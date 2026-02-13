import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class NotificationServiceApi {
  static const String _baseUrl =
      "https://us-central1-crapapps-65472.cloudfunctions.net";

  /// Send push notification to multiple users by userIds
  static Future<bool> sendPushNotification({
    required List<String> userIds,
    required String title,
    required String message,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print("❌ User not logged in");
        return false;
      }

      final idToken = await user.getIdToken();

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
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        print("✅ Notification processed");
        print("Sent: ${decoded['sentCount']}");
        print("Failed: ${decoded['failedCount']}");

        return true;
      } else {
        print("❌ Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error sending notification: $e");
      return false;
    }
  }
}
