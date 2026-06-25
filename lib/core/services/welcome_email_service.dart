import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Calls the `sendWelcomeEmail` Cloud Function so a greeting email goes out from
/// `info@thefestivalapps.com`.
///
/// Fired on every Google and Apple sign-in (new or returning) and once after a
/// new email/password signup. Best-effort: every failure path returns `false`
/// and never throws, so it can never block or break the login/signup flow.
/// The recipient address is resolved server-side from the verified account, so
/// no email is sent in the request body — only an optional display name.
class WelcomeEmailService {
  WelcomeEmailService._();

  static const String _baseUrl =
      "https://us-central1-crapapps-65472.cloudfunctions.net";

  static Future<bool> sendWelcomeEmail({String? displayName}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) print('[WELCOME] abort — user not logged in');
        return false;
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse("$_baseUrl/sendWelcomeEmail"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          if (displayName != null && displayName.trim().isNotEmpty)
            "displayName": displayName.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      if (kDebugMode) {
        print('[WELCOME] HTTP ${response.statusCode}: ${response.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[WELCOME] sendWelcomeEmail error (swallowed): $e');
      }
      return false;
    }
  }
}
