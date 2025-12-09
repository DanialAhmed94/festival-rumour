import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for managing local storage (SharedPreferences)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';

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

  /// Set login status
  Future<void> setLoggedIn(bool isLoggedIn, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, isLoggedIn);
      if (userId != null) {
        await prefs.setString(_keyUserId, userId);
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

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
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

