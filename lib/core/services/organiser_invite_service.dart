import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Calls the `sendOrganiserInvite` Cloud Function (codebase `default`) to email a
/// festival organiser. Two variants share the same endpoint:
///  - [sendOrganiserInvite]: "join us" invite (Create Post → Tag Festival Organiser).
///  - [sendFestivalListingInvite]: "list your festival" invite (search → not found).
///
/// Best-effort by design: every failure path returns `false` and never throws,
/// so a failed invite can never break the calling flow.
class OrganiserInviteService {
  OrganiserInviteService._();

  static const String _baseUrl =
      "https://us-central1-crapapps-65472.cloudfunctions.net";

  /// "Join us / register" invite. [inviterName] / [festivalName] are optional
  /// context woven into the email copy.
  static Future<bool> sendOrganiserInvite({
    required String organiserEmail,
    String? inviterName,
    String? festivalName,
  }) {
    return _send(
      organiserEmail: organiserEmail,
      inviterName: inviterName,
      festivalName: festivalName,
    );
  }

  /// "List your festival" invite, sent when a searched festival isn't found.
  /// [festivalName] is the name the user searched for; [inviterName] is the
  /// requesting user's name (both go into the email subject + body).
  static Future<bool> sendFestivalListingInvite({
    required String organiserEmail,
    String? festivalName,
    String? inviterName,
  }) {
    return _send(
      organiserEmail: organiserEmail,
      festivalName: festivalName,
      inviterName: inviterName,
      inviteType: "listing",
    );
  }

  /// Returns `true` only when the backend reports the mail was sent.
  static Future<bool> _send({
    required String organiserEmail,
    String? inviterName,
    String? festivalName,
    String? inviteType,
  }) async {
    final email = organiserEmail.trim();
    if (email.isEmpty) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('[ORG_INVITE] abort — user not logged in');
        }
        return false;
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse("$_baseUrl/sendOrganiserInvite"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "organiserEmail": email,
          if (inviterName != null && inviterName.trim().isNotEmpty)
            "inviterName": inviterName.trim(),
          if (festivalName != null && festivalName.trim().isNotEmpty)
            "festivalName": festivalName.trim(),
          if (inviteType != null) "inviteType": inviteType,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      if (kDebugMode) {
        print('[ORG_INVITE] HTTP ${response.statusCode}: ${response.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[ORG_INVITE] send error (swallowed): $e');
      }
      return false;
    }
  }
}
