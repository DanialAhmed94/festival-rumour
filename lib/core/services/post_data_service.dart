import 'package:flutter/foundation.dart';

/// Service to temporarily store post data when navigating via sub-navigation
/// This is needed because PostsView created via sub-navigation doesn't have
/// access to ProfileViewModel's context
class PostDataService {
  static final PostDataService _instance = PostDataService._internal();
  factory PostDataService() => _instance;
  PostDataService._internal();

  List<Map<String, dynamic>>? _selectedPostData;
  String? _selectedPostCollectionName;

  /// Store post data for sub-navigation
  void setPostData(List<Map<String, dynamic>> posts, {String? collectionName}) {
    _selectedPostData = posts;
    _selectedPostCollectionName = collectionName;
    if (kDebugMode) {
      print('📦 PostDataService: Stored ${posts.length} posts');
    }
  }

  /// Get stored post data
  List<Map<String, dynamic>>? getPostData() {
    return _selectedPostData;
  }

  /// Get stored collection name
  String? getCollectionName() {
    return _selectedPostCollectionName;
  }

  /// Clear stored post data
  void clearPostData() {
    _selectedPostData = null;
    _selectedPostCollectionName = null;
    if (kDebugMode) {
      print('🗑️ PostDataService: Cleared post data');
    }
  }
}

