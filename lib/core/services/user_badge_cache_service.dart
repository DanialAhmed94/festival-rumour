import 'package:flutter/foundation.dart';

import '../di/locator.dart';
import 'firestore_service.dart';
import 'referral_service.dart';

/// In-memory cache of "is this user a valid Pioneer?" keyed by uid.
///
/// Mirrors [UserPhotoCacheService]. Chosen over denormalizing a `pioneer:true`
/// flag onto chat messages because the badge EXPIRES after 1 year — expiry must
/// be re-evaluated live on read ([ReferralService.isPioneerBadgeValid]), which a
/// frozen per-message flag could never honor.
class UserBadgeCacheService extends ChangeNotifier {
  final FirestoreService _firestoreService = locator<FirestoreService>();

  final Map<String, bool> _pioneerCache = {};

  bool hasCached(String userId) => _pioneerCache.containsKey(userId);

  /// Synchronous read for render paths; null if not yet fetched.
  bool? getCachedPioneer(String userId) => _pioneerCache[userId];

  Future<bool> getPioneer(String userId) async {
    if (_pioneerCache.containsKey(userId)) return _pioneerCache[userId]!;
    await _fetchAndCache(userId);
    return _pioneerCache[userId] ?? false;
  }

  /// Fetch any uncached uids; returns true if a network fill ran (so callers can
  /// bump a UI epoch). Deduped per uid across many messages.
  Future<bool> batchFetchPioneerIfNeeded(List<String> userIds) async {
    final toFetch = <String>[
      for (final id in userIds)
        if (id.isNotEmpty && !_pioneerCache.containsKey(id)) id,
    ];
    if (toFetch.isEmpty) return false;
    await Future.wait(toFetch.toSet().map(_fetchAndCache));
    return true;
  }

  Future<void> _fetchAndCache(String userId) async {
    try {
      final data = await _firestoreService.getUserData(userId);
      final badge = (data?['pioneerBadge'] as Map?)?.cast<String, dynamic>();
      _pioneerCache[userId] = ReferralService.isPioneerBadgeValid(badge);
    } catch (e) {
      if (kDebugMode) {
        print('UserBadgeCacheService: error fetching $userId: $e');
      }
      _pioneerCache[userId] = false;
    }
  }

  void invalidate(String userId) => _pioneerCache.remove(userId);

  void clearAll() => _pioneerCache.clear();
}
