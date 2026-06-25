import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../di/locator.dart';
import 'firestore_service.dart';

/// Number of successful referrals required for the Pioneer badge.
const int kReferralGoal = 25;

/// Snapshot of a user's referral state read from `users/{uid}`.
class ReferralInfo {
  final String? code;
  final int count;
  final int goal;
  final bool isPioneer;
  final DateTime? badgeExpiresAt;

  const ReferralInfo({
    this.code,
    this.count = 0,
    this.goal = kReferralGoal,
    this.isPioneer = false,
    this.badgeExpiresAt,
  });

  double get progress => goal <= 0 ? 0 : (count / goal).clamp(0.0, 1.0);

  static const ReferralInfo empty = ReferralInfo();
}

/// Referral Reward System data facade.
///
/// All reward fields (`referralCode`, `referralCount`, `pioneerBadge`, `referredBy`)
/// are written ONLY by Cloud Functions — the client reads them and triggers the
/// HTTPS endpoints. Calls follow the existing `http.post` + Bearer-ID-token pattern
/// (see [NotificationServiceApi] / `deleteAccountFromServer`); `cloud_functions` is
/// intentionally not used.
class ReferralService {
  ReferralService({FirestoreService? firestoreService})
      : _firestore = firestoreService ?? locator<FirestoreService>();

  final FirestoreService _firestore;

  static const String _baseUrl =
      "https://us-central1-crapapps-65472.cloudfunctions.net";

  /// Must match the backend INVITE_BASE_URL and the /invite/<CODE> page on
  /// thefestivalapps.com (Hostinger).
  static const String inviteBaseUrl = "https://thefestivalapps.com/invite/";

  String buildInviteLink(String code) => "$inviteBaseUrl$code";

  /// True only while the Pioneer badge is active AND not past its 1-year expiry.
  /// Authoritative on-read check (the daily server sweep is only for tidiness).
  static bool isPioneerBadgeValid(Map<String, dynamic>? badge) {
    if (badge == null) return false;
    if (badge['active'] == false) return false;
    if (badge['earnedAt'] == null) return false;
    final expiresAt = _toDate(badge['expiresAt']);
    if (expiresAt == null) return false;
    return expiresAt.isAfter(DateTime.now());
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Read the caller's (or any user's) referral snapshot from Firestore.
  Future<ReferralInfo> getReferralData(String userId) async {
    try {
      final data = await _firestore.getUserData(userId);
      if (data == null) return ReferralInfo.empty;
      final badge = (data['pioneerBadge'] as Map?)?.cast<String, dynamic>();
      return ReferralInfo(
        code: data['referralCode'] as String?,
        count: (data['referralCount'] as num?)?.toInt() ?? 0,
        goal: (data['referralGoal'] as num?)?.toInt() ?? kReferralGoal,
        isPioneer: isPioneerBadgeValid(badge),
        badgeExpiresAt: _toDate(badge?['expiresAt']),
      );
    } catch (e) {
      if (kDebugMode) print('[REFERRAL] getReferralData error: $e');
      return ReferralInfo.empty;
    }
  }

  /// Returns the caller's referral code, asking the backend to generate one on
  /// first call. Returns null on failure (caller should show a retry state).
  Future<String?> getOrCreateCode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse("$_baseUrl/getOrCreateReferralCode"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({}),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['referralCode'] as String?;
      }
      if (kDebugMode) {
        print('[REFERRAL] getOrCreateCode HTTP ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('[REFERRAL] getOrCreateCode error: $e');
      return null;
    }
  }

  /// Redeem a referral code for the freshly-created [newUserUid].
  /// MUST NOT throw — a bad/expired/duplicate code must never break signup.
  /// Returns true only when the server credited a fresh referral.
  Future<bool> redeemReferralCode({
    required String code,
    required String newUserUid,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final deviceId = await _deviceId();
      final response = await http.post(
        Uri.parse("$_baseUrl/redeemReferral"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "code": normalized,
          if (deviceId != null) "deviceId": deviceId,
        }),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['alreadyRedeemed'] == true) return false;
        return decoded['success'] == true;
      }
      if (kDebugMode) {
        print('[REFERRAL] redeem HTTP ${response.statusCode}: ${response.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[REFERRAL] redeemReferralCode error (swallowed): $e');
      return false;
    }
  }

  /// Best-effort device fingerprint for same-device fraud dedupe (weak on iOS).
  Future<String?> _deviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        return (await info.androidInfo).id;
      }
      if (Platform.isIOS) {
        return (await info.iosInfo).identifierForVendor;
      }
    } catch (e) {
      if (kDebugMode) print('[REFERRAL] deviceId error: $e');
    }
    return null;
  }
}
