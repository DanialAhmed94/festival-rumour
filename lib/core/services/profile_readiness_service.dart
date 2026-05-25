import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../di/locator.dart';
import '../models/festival_navigation_gate_outcome.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// Central gate for festival → NavBar flows: bounded auth stabilization, Firestore + retry,
/// local verification cache — does **not** send users to OTP on transient failures.
class ProfileReadinessService {
  ProfileReadinessService({
    FirebaseAuth? firebaseAuth,
    FirestoreService? firestoreService,
    StorageService? storageService,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestoreService =
           firestoreService ??
           (locator.isRegistered<FirestoreService>() ? locator<FirestoreService>() : FirestoreService()),
       _storageService =
           storageService ??
           (locator.isRegistered<StorageService>() ? locator<StorageService>() : StorageService());

  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;
  final StorageService _storageService;

  static const Duration _authStreamWait = Duration(milliseconds: 430);
  static const Duration _authBaselineDelay = Duration(milliseconds: 200);
  static const Duration _authRetryDelay = Duration(milliseconds: 250);
  static const Duration _docRaceDelay = Duration(milliseconds: 250);

  void _gateLog(String suffix) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('🎯 [festival_gate_outcome] $suffix');
    }
  }

  Future<void> persistPhoneVerificationForUser(String uid) async {
    await _storageService.setPhoneVerificationGateCache(uid);
  }

  Future<FestivalNavigationGateOutcome> evaluateFestivalNavbarGate() async {
    _gateLog('evaluate_start');

    var user = await _resolveAuthUserStable();
    user ??= _firebaseAuth.currentUser;

    if (user == null) {
      _gateLog('auth_transient_null');
      return FestivalNavigationGateOutcome.authTransientlyNull;
    }

    if (await _storageService.isPhoneVerificationCachedForUser(user.uid)) {
      _gateLog('cached_hit');
      return FestivalNavigationGateOutcome.authenticatedPhoneReady;
    }

    try {
      Map<String, dynamic>? data = await _firestoreService.getUserData(user.uid);

      if (!_phoneFieldPresent(data)) {
        await Future.delayed(_docRaceDelay);
        final serverPeek = await _firestoreService.getUserData(user.uid,
            source: Source.serverAndCache,
        );
        data = serverPeek ?? data;
      }

      if (!_phoneFieldPresent(data)) {
        await Future.delayed(_docRaceDelay);
        final serverMandatory = await _firestoreService.getUserData(user.uid,
            source: Source.server,
        );
        data = serverMandatory ?? data;
      }

      if (!_phoneFieldPresent(data)) {
        _gateLog('needs_phone_or_missing_after_retries');
        return FestivalNavigationGateOutcome.needsPhoneEnrollment;
      }

      await persistPhoneVerificationForUser(user.uid);
      _gateLog('firestore_ok_cached');
      return FestivalNavigationGateOutcome.authenticatedPhoneReady;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('⚠️ [ProfileReadinessService] gate Firestore error: $e\n$st');
      }
      _gateLog('firestore_throw');
      return FestivalNavigationGateOutcome.firestoreUnavailable;
    }
  }

  static bool _phoneFieldPresent(Map<String, dynamic>? data) {
    if (data == null) return false;
    final p = data['phoneNumber'];
    if (p == null) return false;
    return p.toString().trim().isNotEmpty;
  }

  Future<User?> _resolveAuthUserStable() async {
    User? user = _firebaseAuth.currentUser;
    if (user != null) return user;

    try {
      final first = await _firebaseAuth.authStateChanges().first.timeout(
            _authStreamWait,
            onTimeout: () => null,
          );
      if (first != null) user = first;
    } catch (_) {
      user = null;
    }
    user ??= _firebaseAuth.currentUser;
    if (user != null) return user;

    await Future.delayed(_authBaselineDelay);
    user = _firebaseAuth.currentUser;
    if (user != null) return user;

    await Future.delayed(_authRetryDelay);
    return _firebaseAuth.currentUser;
  }
}
