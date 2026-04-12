import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import '../di/locator.dart';

/// In-memory cache for user profile data (photo, displayName, bio).
/// Single source of truth: Firestore `users/{uid}`.
class UserPhotoCacheService extends ChangeNotifier {
  final FirestoreService _firestoreService = locator<FirestoreService>();

  final Map<String, String?> _photoCache = {};
  final Map<String, String?> _nameCache = {};
  final Map<String, String?> _bioCache = {};

  // --------------- Photo ---------------

  bool hasCached(String userId) => _photoCache.containsKey(userId);

  String? getCachedPhotoUrl(String userId) => _photoCache[userId];

  Future<String?> getPhotoUrl(String userId) async {
    if (_photoCache.containsKey(userId)) {
      return _photoCache[userId];
    }
    await _fetchAndCacheAll(userId);
    return _photoCache[userId];
  }

  void setPhotoUrl(String userId, String? url) {
    if (_photoCache[userId] == url) return;
    _photoCache[userId] = url;
    notifyListeners();
  }

  // --------------- Display Name ---------------

  String? getCachedDisplayName(String userId) => _nameCache[userId];

  Future<String?> getDisplayName(String userId) async {
    if (_nameCache.containsKey(userId)) {
      return _nameCache[userId];
    }
    await _fetchAndCacheAll(userId);
    return _nameCache[userId];
  }

  void setDisplayName(String userId, String? name) {
    if (_nameCache[userId] == name) return;
    _nameCache[userId] = name;
    notifyListeners();
  }

  // --------------- Bio ---------------

  String? getCachedBio(String userId) => _bioCache[userId];

  Future<String?> getBio(String userId) async {
    if (_bioCache.containsKey(userId)) {
      return _bioCache[userId];
    }
    await _fetchAndCacheAll(userId);
    return _bioCache[userId];
  }

  void setBio(String userId, String? bio) {
    if (_bioCache[userId] == bio) return;
    _bioCache[userId] = bio;
    notifyListeners();
  }

  // --------------- Bulk setters ---------------

  /// Update all three fields at once after a successful edit.
  void setUserProfile(String userId, {String? photoUrl, String? displayName, String? bio}) {
    bool changed = false;
    if (photoUrl != null && _photoCache[userId] != photoUrl) {
      _photoCache[userId] = photoUrl;
      changed = true;
    }
    if (displayName != null && _nameCache[userId] != displayName) {
      _nameCache[userId] = displayName;
      changed = true;
    }
    if (bio != null && _bioCache[userId] != bio) {
      _bioCache[userId] = bio;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // --------------- Fetch from Firestore ---------------

  Future<void> _fetchAndCacheAll(String userId) async {
    try {
      final userData = await _firestoreService.getUserData(userId);
      _photoCache[userId] = userData?['photoUrl'] as String?;
      _nameCache[userId] = userData?['displayName'] as String?;
      _bioCache[userId] = userData?['bio'] as String?;
    } catch (e) {
      if (kDebugMode) {
        print('UserPhotoCacheService: Error fetching data for $userId: $e');
      }
    }
  }

  /// Kept for backward compatibility — returns photo URLs only.
  Future<Map<String, String?>> batchFetch(List<String> userIds) async {
    final result = <String, String?>{};
    final toFetch = <String>[];

    for (final id in userIds) {
      if (_photoCache.containsKey(id)) {
        result[id] = _photoCache[id];
      } else {
        toFetch.add(id);
      }
    }

    if (toFetch.isNotEmpty) {
      final futures = toFetch.map((id) async {
        await _fetchAndCacheAll(id);
        return MapEntry(id, _photoCache[id]);
      });
      final entries = await Future.wait(futures);
      for (final entry in entries) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  // --------------- Invalidation ---------------

  void invalidate(String userId) {
    _photoCache.remove(userId);
    _nameCache.remove(userId);
    _bioCache.remove(userId);
  }

  void clearAll() {
    _photoCache.clear();
    _nameCache.clear();
    _bioCache.clear();
  }
}
