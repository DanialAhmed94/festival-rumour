import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Service for managing local storage (SharedPreferences)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserDisplayName = 'user_display_name';
  static const String _keyUserPhotoUrl = 'user_photo_url';
  static const String _keyRecentUserSearches = 'recent_user_searches';
  static const String _keyUserSearchCache = 'user_search_cache';
  static const int _maxCacheSize = 20; // Maximum number of cached searches

  static const String _keyFcmToken = 'fcm_token';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, value);
  }

  /// Returns null when never set (caller should sync from permission); otherwise stored choice.
  Future<bool?> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled);
  }

  Future<void> setFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFcmToken, token);
  }

  Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFcmToken);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking login status: $e');
      }
      return false;
    }
  }

  /// Set login status. Optionally save display name and photo URL (e.g. at login).
  Future<void> setLoggedIn(
    bool isLoggedIn, {
    String? userId,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, isLoggedIn);
      if (userId != null) {
        await prefs.setString(_keyUserId, userId);
      }
      if (displayName != null) {
        await prefs.setString(_keyUserDisplayName, displayName);
      }
      if (photoUrl != null) {
        await prefs.setString(_keyUserPhotoUrl, photoUrl);
      }
      if (kDebugMode) {
        print('Login status saved: $isLoggedIn');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving login status: $e');
      }
    }
  }

  /// Save or update user display name and/or photo URL locally.
  Future<void> setUserProfile({String? displayName, String? photoUrl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (displayName != null) {
        await prefs.setString(_keyUserDisplayName, displayName);
      }
      if (photoUrl != null) {
        await prefs.setString(_keyUserPhotoUrl, photoUrl);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving user profile to storage: $e');
      }
    }
  }

  Future<String?> getStoredDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserDisplayName);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stored display name: $e');
      }
      return null;
    }
  }

  Future<String?> getStoredPhotoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserPhotoUrl);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stored photo URL: $e');
      }
      return null;
    }
  }

  /// Get stored user ID
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user ID: $e');
      }
      return null;
    }
  }

  /// Save recent user search query
  Future<void> saveRecentUserSearch(String query) async {
    try {
      if (query.trim().isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final List<String> recentSearches =
          prefs.getStringList(_keyRecentUserSearches) ?? [];

      // Remove if already exists (to move to top)
      recentSearches.remove(query.trim());
      // Add to beginning
      recentSearches.insert(0, query.trim());

      // Keep only last 10 searches
      if (recentSearches.length > 10) {
        recentSearches.removeRange(10, recentSearches.length);
      }

      await prefs.setStringList(_keyRecentUserSearches, recentSearches);

      if (kDebugMode) {
        print('💾 Saved recent search: $query');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving recent search: $e');
      }
    }
  }

  /// Get recent user searches
  Future<List<String>> getRecentUserSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> recentSearches =
          prefs.getStringList(_keyRecentUserSearches) ?? [];
      return recentSearches;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting recent searches: $e');
      }
      return [];
    }
  }

  /// Clear recent user searches
  Future<void> clearRecentUserSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRecentUserSearches);
      if (kDebugMode) {
        print('🗑️ Cleared recent user searches');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing recent searches: $e');
      }
    }
  }

  /// Get cached search results for a query
  Future<List<Map<String, dynamic>>?> getCachedSearchResults(
    String query,
  ) async {
    try {
      if (query.trim().isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_keyUserSearchCache}_${query.trim().toLowerCase()}';
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final results =
            decoded.map((item) => Map<String, dynamic>.from(item)).toList();

        if (kDebugMode) {
          print('💾 Cache hit for query: "$query" (${results.length} results)');
        }

        return results;
      }

      if (kDebugMode) {
        print('❌ Cache miss for query: "$query"');
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cached search results: $e');
      }
      return null;
    }
  }

  /// Save search results to cache
  Future<void> saveCachedSearchResults(
    String query,
    List<Map<String, dynamic>> results,
  ) async {
    try {
      if (query.trim().isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final normalizedQuery = query.trim().toLowerCase();
      final cacheKey = '${_keyUserSearchCache}_$normalizedQuery';

      // Encode results to JSON
      final jsonString = jsonEncode(results);
      await prefs.setString(cacheKey, jsonString);

      // Manage cache size - remove oldest entries if cache is too large
      await _manageCacheSize(prefs);

      if (kDebugMode) {
        print(
          '💾 Cached search results for query: "$query" (${results.length} results)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving cached search results: $e');
      }
    }
  }

  /// Manage cache size by removing oldest entries
  Future<void> _manageCacheSize(SharedPreferences prefs) async {
    try {
      // Get all cache keys
      final allKeys = prefs.getKeys();
      final cacheKeys =
          allKeys.where((key) => key.startsWith(_keyUserSearchCache)).toList();

      if (cacheKeys.length > _maxCacheSize) {
        // Sort by key (which includes timestamp or we can use access time)
        // For simplicity, remove the oldest entries (first ones alphabetically)
        final keysToRemove =
            cacheKeys.take(cacheKeys.length - _maxCacheSize).toList();

        for (final key in keysToRemove) {
          await prefs.remove(key);
        }

        if (kDebugMode) {
          print('🗑️ Removed ${keysToRemove.length} old cache entries');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error managing cache size: $e');
      }
    }
  }

  /// Clear all cached search results
  Future<void> clearSearchCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final cacheKeys =
          allKeys.where((key) => key.startsWith(_keyUserSearchCache)).toList();

      for (final key in cacheKeys) {
        await prefs.remove(key);
      }

      if (kDebugMode) {
        print('🗑️ Cleared all search cache (${cacheKeys.length} entries)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing search cache: $e');
      }
    }
  }

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserDisplayName);
      await prefs.remove(_keyUserPhotoUrl);
      await prefs.remove(_keyRecentUserSearches);
      await prefs.remove(_keyNotificationsEnabled);
      await clearSearchCache();
      if (kDebugMode) {
        print('All storage data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing storage: $e');
      }
    }
  }
}
