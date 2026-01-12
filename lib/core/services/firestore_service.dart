import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../exceptions/app_exception.dart';
import '../exceptions/exception_mapper.dart';
import 'error_handler_service.dart';
import 'network_service.dart';

/// Service for interacting with Cloud Firestore
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  final NetworkService _networkService = NetworkService();

  /// Default collection name for global posts
  static const String defaultPostsCollection = 'festivalrumorglobalfeed';

  // Cache for user profile data (images/videos)
  // Key: "userId_images" or "userId_videos", Value: {data, timestamp}
  final Map<String, Map<String, dynamic>> _profileCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5); // Cache expires after 5 minutes

  /// Clear cache for a specific user or all users
  void clearProfileCache({String? userId}) {
    if (userId != null) {
      _profileCache.remove('${userId}_images');
      _profileCache.remove('${userId}_videos');
      if (kDebugMode) {
        print('🗑️ Cleared cache for user: $userId');
      }
    } else {
      _profileCache.clear();
      if (kDebugMode) {
        print('🗑️ Cleared all profile cache');
      }
    }
  }

  /// Generate festival-specific collection name
  /// Format: {festivalId}_{festivalName}_rumour
  /// Example: "1_Glastonbury_Festival_rumour"
  static String getFestivalCollectionName(int festivalId, String festivalName) {
    // Sanitize festival name: remove special characters, replace spaces with underscores
    final sanitizedName = festivalName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscore
        .toLowerCase();
    
    return '${festivalId}_${sanitizedName}_rumour';
  }

  /// Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save user data to Firestore after successful signup
  /// 
  /// [userId] - Firebase Auth user ID
  /// [email] - User email
  /// [password] - User password (will be hashed before storing)
  /// [displayName] - User display name
  /// [phoneNumber] - User phone number (optional)
  /// [interests] - User interests list (optional)
  /// [photoUrl] - User profile photo URL (optional)
  /// [additionalData] - Any additional user data (optional)
  Future<void> saveUserData({
    required String userId,
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
    List<String>? interests,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Hash the password before storing
      final hashedPassword = _hashPassword(password);

      // Prepare user data document
      final userData = <String, dynamic>{
        'userId': userId,
        'email': email,
        'password': hashedPassword, // Store hashed password
        'appIdentifier': 'festivalrumor', // Identify this app's users
        'postCount': 0, // Initialize post count to 0
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add optional fields if provided
      if (displayName != null && displayName.isNotEmpty) {
        userData['displayName'] = displayName;
      }

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        userData['phoneNumber'] = phoneNumber;
      }

      if (interests != null && interests.isNotEmpty) {
        userData['interests'] = interests;
      }

      if (photoUrl != null && photoUrl.isNotEmpty) {
        userData['photoUrl'] = photoUrl;
      }

      // Add any additional data
      if (additionalData != null && additionalData.isNotEmpty) {
        userData.addAll(additionalData);
      }

      // Save to Firestore in 'users' collection
      await _firestore.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: false), // Don't merge - create new document
      );

      if (kDebugMode) {
        print('User data saved to Firestore: $userId');
      }
    } catch (e, stackTrace) {
      // Map exception using centralized exception handling
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.saveUserData');
      rethrow;
    }
  }

  /// Update user data in Firestore
  Future<void> updateUserData({
    required String userId,
    String? displayName,
    String? phoneNumber,
    List<String>? interests,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) {
        updateData['displayName'] = displayName;
      }

      if (phoneNumber != null) {
        updateData['phoneNumber'] = phoneNumber;
      }

      if (interests != null) {
        updateData['interests'] = interests;
      }

      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
      }

      if (additionalData != null && additionalData.isNotEmpty) {
        updateData.addAll(additionalData);
      }

      await _firestore.collection('users').doc(userId).update(updateData);

      if (kDebugMode) {
        print('User data updated in Firestore: $userId');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.updateUserData');
      rethrow;
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        return doc.data();
      }
      
      return null;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserData');
      rethrow;
    }
  }

  /// Add a festival to user's favorites
  /// Stores festival ID in an array field 'favoriteFestivals' in user document
  Future<void> addFavoriteFestival(String userId, int festivalId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'favoriteFestivals': FieldValue.arrayUnion([festivalId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Added festival $festivalId to favorites for user $userId');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.addFavoriteFestival');
      rethrow;
    }
  }

  /// Remove a festival from user's favorites
  Future<void> removeFavoriteFestival(String userId, int festivalId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'favoriteFestivals': FieldValue.arrayRemove([festivalId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Removed festival $festivalId from favorites for user $userId');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.removeFavoriteFestival');
      rethrow;
    }
  }

  /// Get list of favorite festival IDs for a user
  /// Returns empty list if user has no favorites or doesn't exist
  Future<List<int>> getFavoriteFestivalIds(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        return [];
      }

      final data = doc.data();
      final favorites = data?['favoriteFestivals'] as List<dynamic>?;
      
      if (favorites == null || favorites.isEmpty) {
        return [];
      }

      // Convert to List<int>, filtering out any invalid values
      return favorites
          .map((e) => e is int ? e : (e is String ? int.tryParse(e) : null))
          .whereType<int>()
          .toList();
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getFavoriteFestivalIds');
      rethrow;
    }
  }

  /// Check if a festival is in user's favorites
  Future<bool> isFestivalFavorited(String userId, int festivalId) async {
    try {
      final favoriteIds = await getFavoriteFestivalIds(userId);
      return favoriteIds.contains(festivalId);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.isFestivalFavorited');
      rethrow;
    }
  }

  /// Search users by display name
  /// Returns a list of user data matching the search query
  /// Limits results to 20 for performance
  Future<List<Map<String, dynamic>>> searchUsersByName(String searchQuery, {int limit = 20}) async {
    try {
      if (searchQuery.trim().isEmpty) {
        return [];
      }

      final query = searchQuery.trim().toLowerCase();
      
      // Get all users with appIdentifier = 'festivalrumor'
      // Note: Firestore doesn't support case-insensitive search natively,
      // so we fetch and filter in memory for accurate results
      final querySnapshot = await _firestore
          .collection('users')
          .where('appIdentifier', isEqualTo: 'festivalrumor')
          .limit(100) // Fetch more to filter, but limit for performance
          .get();

      final results = <Map<String, dynamic>>[];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final displayName = data['displayName'] as String? ?? '';
        final email = data['email'] as String? ?? '';
        
        // Case-insensitive search in displayName or email
        if (displayName.toLowerCase().contains(query) || 
            email.toLowerCase().contains(query)) {
          results.add({
            'userId': doc.id,
            'displayName': displayName,
            'email': email,
            'photoUrl': data['photoUrl'] as String?,
            'bio': data['bio'] as String?,
          });
          
          // Limit results
          if (results.length >= limit) {
            break;
          }
        }
      }

      if (kDebugMode) {
        print('✅ Found ${results.length} users matching "$searchQuery"');
      }

      return results;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.searchUsersByName');
      rethrow;
    }
  }

  /// Check if user exists in Firestore by app identifier
  Future<bool> isFestivalRumorUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['appIdentifier'] == 'festivalrumor';
      }
      
      return false;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.isFestivalRumorUser');
      rethrow;
    }
  }

  /// Save post to Firestore
  /// 
  /// [postData] - Map containing post data (username, content, imagePath, etc.)
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// [mediaCount] - Post counter increment (always 1 per post, regardless of media items count)
  /// Returns the document ID of the created post
  Future<String> savePost(
    Map<String, dynamic> postData, {
    String? collectionName,
    int mediaCount = 1, // Always 1 per post (one post = one count)
  }) async {
    try {
      // Convert DateTime to Timestamp if present
      final dataToSave = Map<String, dynamic>.from(postData);
      if (dataToSave['createdAt'] is DateTime) {
        dataToSave['createdAt'] = Timestamp.fromDate(dataToSave['createdAt'] as DateTime);
      } else if (!dataToSave.containsKey('createdAt')) {
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
      }

      // Use provided collection name or default
      final targetCollection = collectionName ?? defaultPostsCollection;

      // Add to collection (will be created if it doesn't exist)
      final docRef = await _firestore
          .collection(targetCollection)
          .add(dataToSave);

      if (kDebugMode) {
        print('Post saved to Firestore collection "$targetCollection": ${docRef.id}');
      }

      // Increment user's post counter by 1 per post (regardless of media items)
      // If userId is available, increment counter by 1
      final userId = postData['userId'] as String?;
      if (kDebugMode) {
        print('🔢 Post counter increment check:');
        print('   userId: $userId');
        print('   increment: $mediaCount (always 1 per post)');
        print('   userId is not null: ${userId != null}');
        print('   userId is not empty: ${userId != null && userId.isNotEmpty}');
        print('   mediaCount > 0: ${mediaCount > 0}');
      }
      if (userId != null && userId.isNotEmpty && mediaCount > 0) {
        try {
          if (kDebugMode) {
            print('🔄 Incrementing post count by $mediaCount (1 per post) for user: $userId');
          }
          await incrementUserPostCount(userId, count: mediaCount);
          if (kDebugMode) {
            print('✅ Successfully incremented post count by 1');
          }
        } catch (e, stackTrace) {
          // Log error but don't fail post creation if counter update fails
          if (kDebugMode) {
            print('⚠️ Failed to increment post count for user $userId: $e');
            print('   Stack trace: $stackTrace');
          }
        }

        // Clear profile cache for this user since new post was created
        clearProfileCache(userId: userId);
      } else {
        if (kDebugMode) {
          print('⚠️ Skipping post count increment: userId=${userId != null && userId.isNotEmpty}, mediaCount=$mediaCount');
        }
      }

      return docRef.id;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.savePost');
      rethrow;
    }
  }

  /// Save job post to Firestore
  /// 
  /// [jobData] - Map containing job post data
  /// [category] - Job category (e.g., 'Festival Gizza', 'Festie Heroes')
  /// 
  /// Returns the document ID of the saved job
  Future<String> saveJob(
    Map<String, dynamic> jobData, {
    required String category,
  }) async {
    try {
      // Convert DateTime to Timestamp if present
      final dataToSave = Map<String, dynamic>.from(jobData);
      if (dataToSave['postedDate'] is DateTime) {
        dataToSave['postedDate'] = Timestamp.fromDate(dataToSave['postedDate'] as DateTime);
      } else if (!dataToSave.containsKey('postedDate')) {
        dataToSave['postedDate'] = FieldValue.serverTimestamp();
      }
      
      if (dataToSave['createdAt'] is DateTime) {
        dataToSave['createdAt'] = Timestamp.fromDate(dataToSave['createdAt'] as DateTime);
      } else if (!dataToSave.containsKey('createdAt')) {
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
      }

      // Sanitize category name for collection name
      final sanitizedCategory = category
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '') // Remove special chars
          .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscore
          .toLowerCase();

      // Use category-specific collection: jobs_{category}
      // Example: jobs_festival_gizza, jobs_festie_heroes
      final collectionName = 'jobs_$sanitizedCategory';

      if (kDebugMode) {
        print('💼 Saving job to Firestore collection: $collectionName');
        print('   Category: $category');
        print('   UserId: ${dataToSave['userId']}');
      }

      // Add to collection (will be created if it doesn't exist)
      final docRef = await _firestore
          .collection(collectionName)
          .add(dataToSave);

      if (kDebugMode) {
        print('✅ Job saved to Firestore collection "$collectionName": ${docRef.id}');
      }

      return docRef.id;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.saveJob');
      rethrow;
    }
  }

  /// Get all jobs posted by a user, organized by category
  /// 
  /// [userId] - The user ID whose jobs to fetch
  /// Returns a map with category as key and list of jobs as value
  Future<Map<String, List<Map<String, dynamic>>>> getUserJobs(String userId) async {
    try {
      if (kDebugMode) {
        print('💼 Fetching jobs for user: $userId');
      }

      final Map<String, List<Map<String, dynamic>>> jobsByCategory = {};
      
      // Known categories
      final categories = ['Festival Gizza', 'Festie Heroes'];
      
      for (final category in categories) {
        // Sanitize category name for collection name
        final sanitizedCategory = category
            .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
            .replaceAll(RegExp(r'\s+'), '_')
            .toLowerCase();
        
        final collectionName = 'jobs_$sanitizedCategory';
        
        try {
          // Try querying with orderBy first (requires index)
          Query query = _firestore
              .collection(collectionName)
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true);

          QuerySnapshot querySnapshot;
          try {
            querySnapshot = await query.get();
          } catch (e) {
            // Check if this is a Firestore index error (FAILED_PRECONDITION)
            final isIndexError = e is FirebaseException && 
                (e.code == 'failed-precondition' || 
                 e.message?.toLowerCase().contains('index') == true ||
                 e.message?.toLowerCase().contains('requires an index') == true) ||
                e.toString().toLowerCase().contains('index') ||
                e.toString().toLowerCase().contains('failed-precondition');
            
            if (isIndexError) {
              // Silently fall back to querying without orderBy and sort in memory
              // This is expected behavior when indexes don't exist yet
              if (kDebugMode) {
                print('⚠️ Index not found for $collectionName, falling back to in-memory sort');
              }
              querySnapshot = await _firestore
                  .collection(collectionName)
                  .where('userId', isEqualTo: userId)
                  .get();
            } else {
              rethrow; // Re-throw if it's a different error
            }
          }
          
          final jobs = <Map<String, dynamic>>[];
          for (var doc in querySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            data['jobId'] = doc.id; // Add document ID
            data['category'] = category; // Add category name
            jobs.add(data);
          }

          // Sort by createdAt descending if we queried without orderBy
          if (jobs.isNotEmpty && jobs.first['createdAt'] != null) {
            jobs.sort((a, b) {
              final aTime = a['createdAt'];
              final bTime = b['createdAt'];
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              
              // Handle both Timestamp and DateTime
              DateTime aDate;
              DateTime bDate;
              
              if (aTime is Timestamp) {
                aDate = aTime.toDate();
              } else if (aTime is DateTime) {
                aDate = aTime;
              } else {
                return 0;
              }
              
              if (bTime is Timestamp) {
                bDate = bTime.toDate();
              } else if (bTime is DateTime) {
                bDate = bTime;
              } else {
                return 0;
              }
              
              return bDate.compareTo(aDate); // Descending order
            });
          }
          
          if (jobs.isNotEmpty) {
            jobsByCategory[category] = jobs;
            if (kDebugMode) {
              print('✅ Found ${jobs.length} jobs in category "$category"');
            }
          }
        } catch (e) {
          // If collection doesn't exist or query fails, skip this category
          if (kDebugMode) {
            print('⚠️ Error fetching jobs from $collectionName: $e');
          }
          continue;
        }
      }
      
      if (kDebugMode) {
        print('✅ Total categories with jobs: ${jobsByCategory.length}');
      }
      
      return jobsByCategory;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserJobs');
      rethrow;
    }
  }

  /// Get all jobs from all users, organized by category (paginated)
  /// 
  /// [limit] - Number of jobs per category to fetch (default: 10)
  /// [lastDocuments] - Map of category to last document for pagination
  /// Returns a map with 'jobsByCategory', 'lastDocuments', and 'hasMore' flags
  Future<Map<String, dynamic>> getAllJobsPaginated({
    int limit = 10,
    Map<String, DocumentSnapshot>? lastDocuments,
  }) async {
    try {
      if (kDebugMode) {
        print('💼 Fetching all jobs from all users (paginated, limit: $limit)');
      }

      final Map<String, List<Map<String, dynamic>>> jobsByCategory = {};
      final Map<String, DocumentSnapshot> newLastDocuments = {};
      final Map<String, bool> hasMoreByCategory = {};
      
      // Known categories
      final categories = ['Festival Gizza', 'Festie Heroes'];
      
      for (final category in categories) {
        // Sanitize category name for collection name
        final sanitizedCategory = category
            .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
            .replaceAll(RegExp(r'\s+'), '_')
            .toLowerCase();
        
        final collectionName = 'jobs_$sanitizedCategory';
        final lastDoc = lastDocuments?[category];
        
        try {
          // Try querying with orderBy first (requires index)
          Query query = _firestore
              .collection(collectionName)
              .orderBy('createdAt', descending: true)
              .limit(limit);

          // Add pagination cursor if provided
          if (lastDoc != null) {
            query = query.startAfterDocument(lastDoc);
          }

          QuerySnapshot querySnapshot;
          try {
            querySnapshot = await query.get();
          } catch (e) {
            // Check if this is a Firestore index error (FAILED_PRECONDITION)
            final isIndexError = e is FirebaseException && 
                (e.code == 'failed-precondition' || 
                 e.message?.toLowerCase().contains('index') == true ||
                 e.message?.toLowerCase().contains('requires an index') == true) ||
                e.toString().toLowerCase().contains('index') ||
                e.toString().toLowerCase().contains('failed-precondition');
            
            if (isIndexError) {
              // Silently fall back to querying without orderBy and sort in memory
              if (kDebugMode) {
                print('⚠️ Index not found for $collectionName, falling back to in-memory sort');
              }
              querySnapshot = await _firestore
                  .collection(collectionName)
                  .limit(limit)
                  .get();
            } else {
              rethrow; // Re-throw if it's a different error
            }
          }
          
          final jobs = <Map<String, dynamic>>[];
          DocumentSnapshot? newLastDoc;
          
          for (var doc in querySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            data['jobId'] = doc.id; // Add document ID
            data['category'] = category; // Add category name
            jobs.add(data);
            newLastDoc = doc; // Track last document
          }

          // Sort by createdAt descending if we queried without orderBy
          if (jobs.isNotEmpty && jobs.first['createdAt'] != null) {
            jobs.sort((a, b) {
              final aTime = a['createdAt'];
              final bTime = b['createdAt'];
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              
              // Handle both Timestamp and DateTime
              DateTime aDate;
              DateTime bDate;
              
              if (aTime is Timestamp) {
                aDate = aTime.toDate();
              } else if (aTime is DateTime) {
                aDate = aTime;
              } else {
                return 0;
              }
              
              if (bTime is Timestamp) {
                bDate = bTime.toDate();
              } else if (bTime is DateTime) {
                bDate = bTime;
              } else {
                return 0;
              }
              
              return bDate.compareTo(aDate); // Descending order
            });
            
            // Apply limit if we queried without orderBy
            if (jobs.length > limit) {
              jobs.removeRange(limit, jobs.length);
              newLastDoc = querySnapshot.docs.length > limit 
                  ? querySnapshot.docs[limit - 1] 
                  : querySnapshot.docs.isNotEmpty 
                      ? querySnapshot.docs.last 
                      : null;
            }
          }
          
          // Check if there are more jobs
          bool hasMore = false;
          if (querySnapshot.docs.length == limit && newLastDoc != null) {
            try {
              final nextQuery = _firestore
                  .collection(collectionName)
                  .orderBy('createdAt', descending: true)
                  .startAfterDocument(newLastDoc)
                  .limit(1);
              final nextSnapshot = await nextQuery.get();
              hasMore = nextSnapshot.docs.isNotEmpty;
            } catch (e) {
              // If check fails, assume there might be more if we got full limit
              hasMore = querySnapshot.docs.length == limit;
            }
          }
          
          if (jobs.isNotEmpty) {
            jobsByCategory[category] = jobs;
            if (newLastDoc != null) {
              newLastDocuments[category] = newLastDoc;
            }
            hasMoreByCategory[category] = hasMore;
            if (kDebugMode) {
              print('✅ Found ${jobs.length} jobs in category "$category" (hasMore: $hasMore)');
            }
          } else {
            hasMoreByCategory[category] = false;
          }
        } catch (e) {
          // If collection doesn't exist or query fails, skip this category
          if (kDebugMode) {
            print('⚠️ Error fetching jobs from $collectionName: $e');
          }
          hasMoreByCategory[category] = false;
          continue;
        }
      }
      
      if (kDebugMode) {
        print('✅ Total categories with jobs: ${jobsByCategory.length}');
      }
      
      return {
        'jobsByCategory': jobsByCategory,
        'lastDocuments': newLastDocuments,
        'hasMoreByCategory': hasMoreByCategory,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getAllJobsPaginated');
      rethrow;
    }
  }

  /// Get all jobs from all users, organized by category
  /// 
  /// Returns a map with category as key and list of jobs as value
  Future<Map<String, List<Map<String, dynamic>>>> getAllJobs() async {
    try {
      if (kDebugMode) {
        print('💼 Fetching all jobs from all users');
      }

      final Map<String, List<Map<String, dynamic>>> jobsByCategory = {};
      
      // Known categories
      final categories = ['Festival Gizza', 'Festie Heroes'];
      
      for (final category in categories) {
        // Sanitize category name for collection name
        final sanitizedCategory = category
            .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
            .replaceAll(RegExp(r'\s+'), '_')
            .toLowerCase();
        
        final collectionName = 'jobs_$sanitizedCategory';
        
        try {
          // Try querying with orderBy first (requires index)
          Query query = _firestore
              .collection(collectionName)
              .orderBy('createdAt', descending: true);

          QuerySnapshot querySnapshot;
          try {
            querySnapshot = await query.get();
          } catch (e) {
            // Check if this is a Firestore index error (FAILED_PRECONDITION)
            final isIndexError = e is FirebaseException && 
                (e.code == 'failed-precondition' || 
                 e.message?.toLowerCase().contains('index') == true ||
                 e.message?.toLowerCase().contains('requires an index') == true) ||
                e.toString().toLowerCase().contains('index') ||
                e.toString().toLowerCase().contains('failed-precondition');
            
            if (isIndexError) {
              // Silently fall back to querying without orderBy and sort in memory
              if (kDebugMode) {
                print('⚠️ Index not found for $collectionName, falling back to in-memory sort');
              }
              querySnapshot = await _firestore
                  .collection(collectionName)
                  .get();
            } else {
              rethrow; // Re-throw if it's a different error
            }
          }
          
          final jobs = <Map<String, dynamic>>[];
          for (var doc in querySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            data['jobId'] = doc.id; // Add document ID
            data['category'] = category; // Add category name
            jobs.add(data);
          }

          // Sort by createdAt descending if we queried without orderBy
          if (jobs.isNotEmpty && jobs.first['createdAt'] != null) {
            jobs.sort((a, b) {
              final aTime = a['createdAt'];
              final bTime = b['createdAt'];
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              
              // Handle both Timestamp and DateTime
              DateTime aDate;
              DateTime bDate;
              
              if (aTime is Timestamp) {
                aDate = aTime.toDate();
              } else if (aTime is DateTime) {
                aDate = aTime;
              } else {
                return 0;
              }
              
              if (bTime is Timestamp) {
                bDate = bTime.toDate();
              } else if (bTime is DateTime) {
                bDate = bTime;
              } else {
                return 0;
              }
              
              return bDate.compareTo(aDate); // Descending order
            });
          }
          
          if (jobs.isNotEmpty) {
            jobsByCategory[category] = jobs;
            if (kDebugMode) {
              print('✅ Found ${jobs.length} jobs in category "$category"');
            }
          }
        } catch (e) {
          // If collection doesn't exist or query fails, skip this category
          if (kDebugMode) {
            print('⚠️ Error fetching jobs from $collectionName: $e');
          }
          continue;
        }
      }
      
      if (kDebugMode) {
        print('✅ Total categories with jobs: ${jobsByCategory.length}');
      }
      
      return jobsByCategory;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getAllJobs');
      rethrow;
    }
  }

  /// Update a job post
  /// 
  /// [jobId] - The job document ID
  /// [category] - Job category (e.g., 'Festival Gizza', 'Festie Heroes')
  /// [jobData] - Updated job data
  Future<void> updateJob(
    String jobId,
    String category,
    Map<String, dynamic> jobData,
  ) async {
    try {
      // Sanitize category name for collection name
      final sanitizedCategory = category
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      
      final collectionName = 'jobs_$sanitizedCategory';
      
      // Convert DateTime to Timestamp if present
      final dataToUpdate = Map<String, dynamic>.from(jobData);
      if (dataToUpdate['postedDate'] is DateTime) {
        dataToUpdate['postedDate'] = Timestamp.fromDate(dataToUpdate['postedDate'] as DateTime);
      }
      
      dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();
      
      if (kDebugMode) {
        print('💼 Updating job: $jobId in collection: $collectionName');
      }
      
      await _firestore
          .collection(collectionName)
          .doc(jobId)
          .update(dataToUpdate);
      
      if (kDebugMode) {
        print('✅ Job updated successfully');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.updateJob');
      rethrow;
    }
  }

  /// Delete a job post
  /// 
  /// [jobId] - The job document ID
  /// [category] - Job category (e.g., 'Festival Gizza', 'Festie Heroes')
  Future<void> deleteJob(String jobId, String category) async {
    try {
      // Sanitize category name for collection name
      final sanitizedCategory = category
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      
      final collectionName = 'jobs_$sanitizedCategory';
      
      if (kDebugMode) {
        print('💼 Deleting job: $jobId from collection: $collectionName');
      }
      
      await _firestore
          .collection(collectionName)
          .doc(jobId)
          .delete();
      
      if (kDebugMode) {
        print('✅ Job deleted successfully');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.deleteJob');
      rethrow;
    }
  }

  /// Increment user's post count in Firestore
  /// Uses atomic increment to safely handle concurrent updates
  /// 
  /// [userId] - The user ID whose post count should be incremented
  /// [count] - The number to increment by (defaults to 1)
  Future<void> incrementUserPostCount(String userId, {int count = 1}) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        'postCount': FieldValue.increment(count),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ Incremented post count by $count for user: $userId');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.incrementUserPostCount');
      rethrow;
    }
  }

  /// Get posts created by a specific user from a collection (with pagination)
  /// 
  /// [userId] - The user ID to filter posts by
  /// [collectionName] - Collection name to search in
  /// [isVideoOnly] - If true, only return posts with videos. If false, only return posts with images (no videos)
  /// [limit] - Number of posts to fetch (default: 20)
  /// [lastDocument] - Last document from previous page for pagination
  /// Returns map with 'posts' list, 'lastDocument', and 'hasMore' flag
  Future<Map<String, dynamic>> getUserPostsPaginated({
    required String userId,
    required String collectionName,
    bool? isVideoOnly, // null = all posts, true = only videos, false = only images
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Try querying with orderBy first (requires index)
      Query query = _firestore
          .collection(collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // Add pagination cursor if provided
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await query.get();
      } catch (e) {
        // Check if this is a Firestore index error (FAILED_PRECONDITION)
        final isIndexError = e is FirebaseException && 
            (e.code == 'failed-precondition' || 
             e.message?.toLowerCase().contains('index') == true ||
             e.message?.toLowerCase().contains('requires an index') == true) ||
            e.toString().toLowerCase().contains('index') ||
            e.toString().toLowerCase().contains('failed-precondition');
        
        if (isIndexError) {
          // Silently fall back to querying without orderBy and sort in memory
          // This is expected behavior when indexes don't exist yet
          querySnapshot = await _firestore
              .collection(collectionName)
              .where('userId', isEqualTo: userId)
              .get();
        } else {
          rethrow; // Re-throw if it's a different error
        }
      }

      var posts = <Map<String, dynamic>>[];
      DocumentSnapshot? newLastDocument;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id;

        // Filter by video/image type if specified
        if (isVideoOnly != null) {
          final isVideo = data['isVideo'] as bool? ?? false;
          final isVideoList = data['isVideoList'] as List<dynamic>?;
          final hasVideo = isVideo || (isVideoList != null && isVideoList.any((v) => v == true));

          if (isVideoOnly && !hasVideo) {
            continue; // Skip non-video posts when only videos requested
          }
          if (!isVideoOnly && hasVideo) {
            continue; // Skip video posts when only images requested
          }
        }

        posts.add(data);
        newLastDocument = doc; // Track last document for pagination
      }

      // If we queried without orderBy, sort and limit in memory
      if (posts.isNotEmpty && posts.first['createdAt'] != null) {
        posts.sort((a, b) {
          final aTime = a['createdAt'];
          final bTime = b['createdAt'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          DateTime aDate;
          DateTime bDate;
          
          if (aTime is Timestamp) {
            aDate = aTime.toDate();
          } else if (aTime is DateTime) {
            aDate = aTime;
          } else {
            return 0;
          }
          
          if (bTime is Timestamp) {
            bDate = bTime.toDate();
          } else if (bTime is DateTime) {
            bDate = bTime;
          } else {
            return 0;
          }
          
          return bDate.compareTo(aDate); // Descending order
        });

        // Apply limit if we queried without orderBy
        if (querySnapshot.docs.length > limit) {
          posts = posts.take(limit).toList();
          newLastDocument = querySnapshot.docs[limit - 1];
        }
      }

      // Check if there are more posts
      final hasMore = querySnapshot.docs.length == limit;

      if (kDebugMode) {
        print('Fetched ${posts.length} user posts from collection "$collectionName" for userId: $userId (hasMore: $hasMore)');
      }

      return {
        'posts': posts,
        'lastDocument': newLastDocument,
        'hasMore': hasMore,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserPostsPaginated');
      rethrow;
    }
  }

  /// Get all posts created by a specific user from a collection
  /// 
  /// [userId] - The user ID to filter posts by
  /// [collectionName] - Collection name to search in
  /// [isVideoOnly] - If true, only return posts with videos. If false, only return posts with images (no videos)
  /// Returns list of post data maps
  /// 
  /// @deprecated Use getUserPostsPaginated for better performance
  Future<List<Map<String, dynamic>>> getUserPosts({
    required String userId,
    required String collectionName,
    bool? isVideoOnly, // null = all posts, true = only videos, false = only images
  }) async {
    try {
      // Try querying with orderBy first (requires index)
      Query query = _firestore
          .collection(collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await query.get();
      } catch (e) {
        // Check if this is a Firestore index error (FAILED_PRECONDITION)
        final isIndexError = e is FirebaseException && 
            (e.code == 'failed-precondition' || 
             e.message?.toLowerCase().contains('index') == true ||
             e.message?.toLowerCase().contains('requires an index') == true) ||
            e.toString().toLowerCase().contains('index') ||
            e.toString().toLowerCase().contains('failed-precondition');
        
        if (isIndexError) {
          // Silently fall back to querying without orderBy and sort in memory
          // This is expected behavior when indexes don't exist yet
          querySnapshot = await _firestore
              .collection(collectionName)
              .where('userId', isEqualTo: userId)
              .get();
        } else {
          rethrow; // Re-throw if it's a different error
        }
      }

      final posts = <Map<String, dynamic>>[];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id;

        // Filter by video/image type if specified
        if (isVideoOnly != null) {
          final isVideo = data['isVideo'] as bool? ?? false;
          final isVideoList = data['isVideoList'] as List<dynamic>?;
          final hasVideo = isVideo || (isVideoList != null && isVideoList.any((v) => v == true));

          if (isVideoOnly && !hasVideo) {
            continue; // Skip non-video posts when only videos requested
          }
          if (!isVideoOnly && hasVideo) {
            continue; // Skip video posts when only images requested
          }
        }

        posts.add(data);
      }

      // Sort by createdAt descending if we queried without orderBy
      if (posts.isNotEmpty && posts.first['createdAt'] != null) {
        posts.sort((a, b) {
          final aTime = a['createdAt'];
          final bTime = b['createdAt'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          // Handle both Timestamp and DateTime
          DateTime aDate;
          DateTime bDate;
          
          if (aTime is Timestamp) {
            aDate = aTime.toDate();
          } else if (aTime is DateTime) {
            aDate = aTime;
          } else {
            return 0;
          }
          
          if (bTime is Timestamp) {
            bDate = bTime.toDate();
          } else if (bTime is DateTime) {
            bDate = bTime;
          } else {
            return 0;
          }
          
          return bDate.compareTo(aDate); // Descending order
        });
      }

      if (kDebugMode) {
        print('Fetched ${posts.length} user posts from collection "$collectionName" for userId: $userId');
      }

      return posts;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserPosts');
      rethrow;
    }
  }

  /// Get user's images from a specific collection
  /// Helper method to extract images from posts
  /// Returns list of image URLs (for backward compatibility)
  /// For profile grid: Only returns the first image per post (to match postInfos - one tile per post)
  List<String> _extractImagesFromPosts(List<Map<String, dynamic>> posts) {
    final images = <String>[];
    for (var post in posts) {
      final mediaPaths = post['mediaPaths'] as List<dynamic>?;
      final isVideoList = post['isVideoList'] as List<dynamic>?;
      
      if (mediaPaths != null && mediaPaths.isNotEmpty) {
        // Only extract the first image (to match postInfos - one tile per post)
        // Find the first non-video media item
        String? firstImage;
        for (int i = 0; i < mediaPaths.length; i++) {
          final isVideo = (isVideoList != null && i < isVideoList.length) 
              ? (isVideoList[i] as bool? ?? false)
              : (post['isVideo'] as bool? ?? false);
          
          if (!isVideo) {
            firstImage = mediaPaths[i] as String;
            break; // Use first non-video image
          }
        }
        
        // Only add if we found an image (skip posts with only videos)
        if (firstImage != null) {
          images.add(firstImage);
        }
      } else if (post['imagePath'] != null && !(post['isVideo'] as bool? ?? false)) {
        // Fallback for old posts with single imagePath
        images.add(post['imagePath'] as String);
      }
    }
    return images;
  }

  /// Extract lightweight post info (postId, mediaUrl, collectionName) from posts
  /// Used for profile grid - only loads essential data
  /// For images grid: Only returns postInfos for posts that have at least one image
  /// (to match _extractImagesFromPosts - one tile per post with images)
  List<Map<String, dynamic>> _extractPostInfoFromPosts(
    List<Map<String, dynamic>> posts,
    String collectionName,
  ) {
    final postInfos = <Map<String, dynamic>>[];
    for (var post in posts) {
      final postId = post['postId'] as String? ?? '';
      if (postId.isEmpty) continue;

      final mediaPaths = post['mediaPaths'] as List<dynamic>?;
      final isVideoList = post['isVideoList'] as List<dynamic>?;
      
      if (mediaPaths != null && mediaPaths.isNotEmpty) {
        // Find the first image (non-video) media item to match _extractImagesFromPosts
        String? firstImageUrl;
        bool? firstIsVideo;
        bool hasMultipleMedia = mediaPaths.length > 1;
        
        for (int i = 0; i < mediaPaths.length; i++) {
          final isVideo = (isVideoList != null && i < isVideoList.length) 
              ? (isVideoList[i] as bool? ?? false)
              : (post['isVideo'] as bool? ?? false);
          
          if (!isVideo) {
            // Found first image
            firstImageUrl = mediaPaths[i] as String;
            firstIsVideo = false;
            break;
          }
        }
        
        // Only add postInfo if we found an image (skip video-only posts for images grid)
        if (firstImageUrl != null) {
          postInfos.add({
            'postId': postId,
            'mediaUrl': firstImageUrl, // First image (matches _extractImagesFromPosts)
            'collectionName': collectionName,
            'isVideo': firstIsVideo ?? false,
            'hasMultipleMedia': hasMultipleMedia, // Flag to show icon overlay
          });
        }
      } else if (post['imagePath'] != null && !(post['isVideo'] as bool? ?? false)) {
        // Fallback for old posts with single imagePath (only if not a video)
        postInfos.add({
          'postId': postId,
          'mediaUrl': post['imagePath'] as String,
          'collectionName': collectionName,
          'isVideo': false,
          'hasMultipleMedia': false, // Old posts have single media
        });
      }
    }
    return postInfos;
  }

  /// Get user's videos from a specific collection
  /// Helper method to extract videos from posts
  /// Returns list of video URLs (only first video per post)
  List<String> _extractVideosFromPosts(List<Map<String, dynamic>> posts) {
    final videos = <String>[];
    for (var post in posts) {
      final mediaPaths = post['mediaPaths'] as List<dynamic>?;
      final isVideoList = post['isVideoList'] as List<dynamic>?;
      
      if (mediaPaths != null) {
        // Only extract the first video per post (similar to images)
        for (int i = 0; i < mediaPaths.length; i++) {
          final isVideo = (isVideoList != null && i < isVideoList.length) 
              ? (isVideoList[i] as bool? ?? false)
              : (post['isVideo'] as bool? ?? false);
          
          if (isVideo) {
            videos.add(mediaPaths[i] as String);
            break; // Only take first video per post
          }
        }
      } else if (post['imagePath'] != null && (post['isVideo'] as bool? ?? false)) {
        // Fallback for old posts with single video
        videos.add(post['imagePath'] as String);
      }
    }
    return videos;
  }

  /// Extract video post info from posts (for reels grid)
  /// Returns list of post info maps with first video URL and hasMultipleMedia flag
  List<Map<String, dynamic>> _extractVideoInfoFromPosts(
    List<Map<String, dynamic>> posts,
    String collectionName,
  ) {
    final postInfos = <Map<String, dynamic>>[];
    for (var post in posts) {
      final postId = post['postId'] as String? ?? '';
      if (postId.isEmpty) continue;

      final mediaPaths = post['mediaPaths'] as List<dynamic>?;
      final isVideoList = post['isVideoList'] as List<dynamic>?;
      
      if (mediaPaths != null && mediaPaths.isNotEmpty) {
        // Find the first video media item to match _extractVideosFromPosts
        String? firstVideoUrl;
        bool hasMultipleMedia = false;
        int videoCount = 0;
        
        for (int i = 0; i < mediaPaths.length; i++) {
          final isVideo = (isVideoList != null && i < isVideoList.length) 
              ? (isVideoList[i] as bool? ?? false)
              : (post['isVideo'] as bool? ?? false);
          
          if (isVideo) {
            videoCount++;
            if (firstVideoUrl == null) {
              // Found first video
              firstVideoUrl = mediaPaths[i] as String;
            }
          }
        }
        
        // Set hasMultipleMedia if post has multiple videos
        hasMultipleMedia = videoCount > 1;
        
        // Only add postInfo if we found a video (skip image-only posts for videos grid)
        if (firstVideoUrl != null) {
          postInfos.add({
            'postId': postId,
            'mediaUrl': firstVideoUrl, // First video (matches _extractVideosFromPosts)
            'collectionName': collectionName,
            'isVideo': true,
            'hasMultipleMedia': hasMultipleMedia, // Flag to show icon overlay (true if multiple videos)
          });
        }
      } else if (post['imagePath'] != null && (post['isVideo'] as bool? ?? false)) {
        // Fallback for old posts with single video
        postInfos.add({
          'postId': postId,
          'mediaUrl': post['imagePath'] as String,
          'collectionName': collectionName,
          'isVideo': true,
          'hasMultipleMedia': false, // Old posts have single media
        });
      }
    }
    return postInfos;
  }

  /// Get user's images with pagination and caching
  /// [userId] - User ID
  /// [festivalCollectionNames] - Optional list of festival collection names to query
  /// [limit] - Number of images per page (default: 20)
  /// [lastDocument] - Last document from previous page for pagination
  /// [useCache] - Whether to use cached data if available (default: true)
  /// Returns map with 'images' list, 'lastDocument', 'hasMore', and 'cached' flag
  Future<Map<String, dynamic>> getUserImagesPaginated(
    String userId, {
    List<String>? festivalCollectionNames,
    int limit = 20,
    Map<String, DocumentSnapshot?>? lastDocuments, // Map of collectionName -> lastDocument
    bool useCache = true,
  }) async {
    try {
      final cacheKey = '${userId}_images';
      
      // Check cache if this is first page and cache is enabled
      if (useCache && lastDocuments == null) {
        final cached = _profileCache[cacheKey];
        if (cached != null) {
          final cacheTime = cached['timestamp'] as DateTime;
          if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
            if (kDebugMode) {
              print('📦 Using cached images for user: $userId');
            }
            return {
              'images': List<String>.from(cached['data'] as List),
              'postInfos': cached['postInfos'] != null 
                  ? List<Map<String, dynamic>>.from(cached['postInfos'] as List)
                  : <Map<String, dynamic>>[],
              'lastDocuments': null,
              'hasMore': false,
              'cached': true,
            };
          } else {
            // Cache expired, remove it
            _profileCache.remove(cacheKey);
          }
        }
      }

      // Check network status - if offline and no cache, return empty immediately
      final hasInternet = await _networkService.hasInternetConnection();
      if (!hasInternet) {
        if (kDebugMode) {
          print('📴 Offline - returning cached data or empty result');
        }
        // If we have cache (even if expired), return it when offline
        if (useCache && lastDocuments == null) {
          final cached = _profileCache[cacheKey];
          if (cached != null) {
            if (kDebugMode) {
              print('📦 Using expired cache (offline mode)');
            }
            return {
              'images': List<String>.from(cached['data'] as List),
              'postInfos': cached['postInfos'] != null 
                  ? List<Map<String, dynamic>>.from(cached['postInfos'] as List)
                  : <Map<String, dynamic>>[],
              'lastDocuments': null,
              'hasMore': false,
              'cached': true,
            };
          }
        }
        // No cache available offline
        return {
          'images': <String>[],
          'postInfos': <Map<String, dynamic>>[],
          'lastDocuments': null,
          'hasMore': false,
          'cached': false,
        };
      }

      final allImages = <String>[];
      final newLastDocuments = <String, DocumentSnapshot?>{};
      bool hasMore = false;

      // Create list of all collection queries to run in parallel
      final collectionQueries = <Future<Map<String, dynamic>>>[];

      // Add global feed query
      final globalLastDoc = lastDocuments?[defaultPostsCollection];
      collectionQueries.add(
        getUserPostsPaginated(
          userId: userId,
          collectionName: defaultPostsCollection,
          isVideoOnly: false,
          limit: limit,
          lastDocument: globalLastDoc,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            if (kDebugMode) print('Timeout fetching global posts');
            return {
              'posts': <Map<String, dynamic>>[],
              'lastDocument': null,
              'hasMore': false,
            };
          },
        ),
      );

      // Add festival collection queries if provided (limit to first 20)
      if (festivalCollectionNames != null && festivalCollectionNames.isNotEmpty) {
        final limitedCollections = festivalCollectionNames.take(20).toList();
        for (var collectionName in limitedCollections) {
          final collectionLastDoc = lastDocuments?[collectionName];
          collectionQueries.add(
            getUserPostsPaginated(
              userId: userId,
              collectionName: collectionName,
              isVideoOnly: false,
              limit: limit,
              lastDocument: collectionLastDoc,
            )
                .timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    if (kDebugMode) print('Timeout fetching from $collectionName');
                    return {
                      'posts': <Map<String, dynamic>>[],
                      'lastDocument': null,
                      'hasMore': false,
                    };
                  },
                )
                .catchError((e) {
                  return {
                    'posts': <Map<String, dynamic>>[],
                    'lastDocument': null,
                    'hasMore': false,
                  };
                }),
          );
        }
      }

      // Execute all queries in parallel
      final results = await Future.wait(collectionQueries).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('Timeout waiting for all queries');
          return List<Map<String, dynamic>>.filled(
            collectionQueries.length,
            {
              'posts': <Map<String, dynamic>>[],
              'lastDocument': null,
              'hasMore': false,
            },
          );
        },
      );

      // Extract images and post info from all results and track pagination state
      int collectionIndex = 0;
      final allPostInfos = <Map<String, dynamic>>[];
      
      // Global feed
      final globalResult = results[collectionIndex++];
      final globalPosts = globalResult['posts'] as List<Map<String, dynamic>>;
      allImages.addAll(_extractImagesFromPosts(globalPosts));
      allPostInfos.addAll(_extractPostInfoFromPosts(globalPosts, defaultPostsCollection));
      if (globalResult['lastDocument'] != null) {
        newLastDocuments[defaultPostsCollection] = globalResult['lastDocument'] as DocumentSnapshot;
      }
      if (globalResult['hasMore'] == true) {
        hasMore = true;
      }

      // Festival collections
      if (festivalCollectionNames != null && festivalCollectionNames.isNotEmpty) {
        final limitedCollections = festivalCollectionNames.take(20).toList();
        for (var collectionName in limitedCollections) {
          if (collectionIndex >= results.length) break;
          
          final result = results[collectionIndex++];
          final posts = result['posts'] as List<Map<String, dynamic>>;
          allImages.addAll(_extractImagesFromPosts(posts));
          allPostInfos.addAll(_extractPostInfoFromPosts(posts, collectionName));
          
          if (result['lastDocument'] != null) {
            newLastDocuments[collectionName] = result['lastDocument'] as DocumentSnapshot;
          }
          if (result['hasMore'] == true) {
            hasMore = true;
          }
        }
      }

      // Cache first page results (both URLs and post info)
      if (lastDocuments == null && allImages.isNotEmpty) {
        _profileCache[cacheKey] = {
          'data': allImages,
          'postInfos': allPostInfos, // Store post metadata for fetching full details later
          'timestamp': DateTime.now(),
        };
      }

      if (kDebugMode) {
        print('Found ${allImages.length} images for user: $userId (hasMore: $hasMore)');
      }

      return {
        'images': allImages,
        'postInfos': allPostInfos, // Return post metadata for profile grid
        'lastDocuments': newLastDocuments.isEmpty ? null : newLastDocuments,
        'hasMore': hasMore,
        'cached': false,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserImagesPaginated');
      rethrow;
    }
  }

  /// Get all user's images from all collections (global + festival collections)
  /// [festivalCollectionNames] - Optional list of festival collection names to query
  /// Returns list of image URLs from posts
  /// 
  /// @deprecated Use getUserImagesPaginated for better performance
  Future<List<String>> getUserImages(
    String userId, {
    List<String>? festivalCollectionNames,
  }) async {
    try {
      final allImages = <String>[];

      // Create list of all collection queries to run in parallel
      final collectionQueries = <Future<List<Map<String, dynamic>>>>[];

      // Add global feed query (most important, run first)
      collectionQueries.add(
        getUserPosts(
          userId: userId,
          collectionName: defaultPostsCollection,
          isVideoOnly: false, // Only images
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            if (kDebugMode) print('Timeout fetching global posts');
            return <Map<String, dynamic>>[];
          },
        ),
      );

      // Add festival collection queries if provided (limit to first 20 to avoid too many queries)
      if (festivalCollectionNames != null && festivalCollectionNames.isNotEmpty) {
        final limitedCollections = festivalCollectionNames.take(20).toList();
        for (var collectionName in limitedCollections) {
          collectionQueries.add(
            getUserPosts(
              userId: userId,
              collectionName: collectionName,
              isVideoOnly: false, // Only images
            )
                .timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    if (kDebugMode) print('Timeout fetching from $collectionName');
                    return <Map<String, dynamic>>[];
                  },
                )
                .catchError((e) {
                  // Return empty list on error instead of throwing
                  return <Map<String, dynamic>>[];
                }),
          );
        }
      }

      // Execute all queries in parallel with timeout
      final results = await Future.wait(collectionQueries).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('Timeout waiting for all queries');
          return List<List<Map<String, dynamic>>>.filled(
            collectionQueries.length,
            <Map<String, dynamic>>[],
          );
        },
      );

      // Extract images from all results
      for (var posts in results) {
        allImages.addAll(_extractImagesFromPosts(posts));
      }

      if (kDebugMode) {
        print('Found ${allImages.length} images for user: $userId');
      }

      return allImages;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserImages');
      rethrow;
    }
  }

  /// Get user's videos with pagination and caching
  /// [userId] - User ID
  /// [festivalCollectionNames] - Optional list of festival collection names to query
  /// [limit] - Number of videos per page (default: 20)
  /// [lastDocument] - Last document from previous page for pagination
  /// [useCache] - Whether to use cached data if available (default: true)
  /// Returns map with 'videos' list, 'lastDocument', 'hasMore', and 'cached' flag
  Future<Map<String, dynamic>> getUserVideosPaginated(
    String userId, {
    List<String>? festivalCollectionNames,
    int limit = 20,
    Map<String, DocumentSnapshot?>? lastDocuments, // Map of collectionName -> lastDocument
    bool useCache = true,
  }) async {
    try {
      final cacheKey = '${userId}_videos';
      
      // Check cache if this is first page and cache is enabled
      if (useCache && lastDocuments == null) {
        final cached = _profileCache[cacheKey];
        if (cached != null) {
          final cacheTime = cached['timestamp'] as DateTime;
          if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
            if (kDebugMode) {
              print('📦 Using cached videos for user: $userId');
            }
            return {
              'videos': List<String>.from(cached['data'] as List),
              'postInfos': cached['postInfos'] != null 
                  ? List<Map<String, dynamic>>.from(cached['postInfos'] as List)
                  : <Map<String, dynamic>>[],
              'lastDocuments': null,
              'hasMore': false,
              'cached': true,
            };
          } else {
            // Cache expired, remove it
            _profileCache.remove(cacheKey);
          }
        }
      }

      // Check network status - if offline and no cache, return empty immediately
      final hasInternet = await _networkService.hasInternetConnection();
      if (!hasInternet) {
        if (kDebugMode) {
          print('📴 Offline - returning cached data or empty result');
        }
        // If we have cache (even if expired), return it when offline
        if (useCache && lastDocuments == null) {
          final cached = _profileCache[cacheKey];
          if (cached != null) {
            if (kDebugMode) {
              print('📦 Using expired cache (offline mode)');
            }
            return {
              'videos': List<String>.from(cached['data'] as List),
              'postInfos': cached['postInfos'] != null 
                  ? List<Map<String, dynamic>>.from(cached['postInfos'] as List)
                  : <Map<String, dynamic>>[],
              'lastDocuments': null,
              'hasMore': false,
              'cached': true,
            };
          }
        }
        // No cache available offline
        return {
          'videos': <String>[],
          'postInfos': <Map<String, dynamic>>[],
          'lastDocuments': null,
          'hasMore': false,
          'cached': false,
        };
      }

      final allVideos = <String>[];
      final newLastDocuments = <String, DocumentSnapshot?>{};
      bool hasMore = false;

      // Create list of all collection queries to run in parallel
      final collectionQueries = <Future<Map<String, dynamic>>>[];

      // Add global feed query
      final globalLastDoc = lastDocuments?[defaultPostsCollection];
      collectionQueries.add(
        getUserPostsPaginated(
          userId: userId,
          collectionName: defaultPostsCollection,
          isVideoOnly: true,
          limit: limit,
          lastDocument: globalLastDoc,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            if (kDebugMode) print('Timeout fetching global posts');
            return {
              'posts': <Map<String, dynamic>>[],
              'lastDocument': null,
              'hasMore': false,
            };
          },
        ),
      );

      // Add festival collection queries if provided (limit to first 20)
      if (festivalCollectionNames != null && festivalCollectionNames.isNotEmpty) {
        final limitedCollections = festivalCollectionNames.take(20).toList();
        for (var collectionName in limitedCollections) {
          final collectionLastDoc = lastDocuments?[collectionName];
          collectionQueries.add(
            getUserPostsPaginated(
              userId: userId,
              collectionName: collectionName,
              isVideoOnly: true,
              limit: limit,
              lastDocument: collectionLastDoc,
            )
                .timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    if (kDebugMode) print('Timeout fetching from $collectionName');
                    return {
                      'posts': <Map<String, dynamic>>[],
                      'lastDocument': null,
                      'hasMore': false,
                    };
                  },
                )
                .catchError((e) {
                  return {
                    'posts': <Map<String, dynamic>>[],
                    'lastDocument': null,
                    'hasMore': false,
                  };
                }),
          );
        }
      }

      // Execute all queries in parallel
      final results = await Future.wait(collectionQueries).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('Timeout waiting for all queries');
          return List<Map<String, dynamic>>.filled(
            collectionQueries.length,
            {
              'posts': <Map<String, dynamic>>[],
              'lastDocument': null,
              'hasMore': false,
            },
          );
        },
      );

      // Extract videos and post info from all results and track pagination state
      int collectionIndex = 0;
      final allPostInfos = <Map<String, dynamic>>[];
      
      // Global feed
      final globalResult = results[collectionIndex++];
      final globalPosts = globalResult['posts'] as List<Map<String, dynamic>>;
      allVideos.addAll(_extractVideosFromPosts(globalPosts));
      allPostInfos.addAll(_extractVideoInfoFromPosts(globalPosts, defaultPostsCollection));
      if (globalResult['lastDocument'] != null) {
        newLastDocuments[defaultPostsCollection] = globalResult['lastDocument'] as DocumentSnapshot;
      }
      if (globalResult['hasMore'] == true) {
        hasMore = true;
      }

      // Festival collections
      if (festivalCollectionNames != null && festivalCollectionNames.isNotEmpty) {
        final limitedCollections = festivalCollectionNames.take(20).toList();
        for (var collectionName in limitedCollections) {
          if (collectionIndex >= results.length) break;
          
          final result = results[collectionIndex++];
          final posts = result['posts'] as List<Map<String, dynamic>>;
          allVideos.addAll(_extractVideosFromPosts(posts));
          allPostInfos.addAll(_extractVideoInfoFromPosts(posts, collectionName));
          
          if (result['lastDocument'] != null) {
            newLastDocuments[collectionName] = result['lastDocument'] as DocumentSnapshot;
          }
          if (result['hasMore'] == true) {
            hasMore = true;
          }
        }
      }

      // Cache first page results (both URLs and post info)
      if (lastDocuments == null && allVideos.isNotEmpty) {
        _profileCache[cacheKey] = {
          'data': allVideos,
          'postInfos': allPostInfos, // Store post metadata for fetching full details later
          'timestamp': DateTime.now(),
        };
      }

      if (kDebugMode) {
        print('Found ${allVideos.length} videos for user: $userId (hasMore: $hasMore)');
      }

      return {
        'videos': allVideos,
        'postInfos': allPostInfos, // Return post metadata for profile grid
        'lastDocuments': newLastDocuments.isEmpty ? null : newLastDocuments,
        'hasMore': hasMore,
        'cached': false,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserVideosPaginated');
      rethrow;
    }
  }

  /// Get all user's videos from all collections (global + festival collections)
  /// [festivalCollectionNames] - Optional list of festival collection names to query
  /// Returns list of video URLs from posts
  /// 
  /// @deprecated Use getUserVideosPaginated for better performance
  Future<List<String>> getUserVideos(
    String userId, {
    List<String>? festivalCollectionNames,
  }) async {
    try {
      final allVideos = <String>[];

      // Create list of all collection queries to run in parallel
      final collectionQueries = <Future<List<Map<String, dynamic>>>>[];

      // Add global feed query (most important, run first)
      collectionQueries.add(
        getUserPosts(
          userId: userId,
          collectionName: defaultPostsCollection,
          isVideoOnly: true, // Only videos
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            if (kDebugMode) print('Timeout fetching global posts');
            return <Map<String, dynamic>>[];
          },
        ),
      );

      // Add festival collection queries if provided (limit to first 20 to avoid too many queries)
      if (festivalCollectionNames != null && festivalCollectionNames.isNotEmpty) {
        final limitedCollections = festivalCollectionNames.take(20).toList();
        for (var collectionName in limitedCollections) {
          collectionQueries.add(
            getUserPosts(
              userId: userId,
              collectionName: collectionName,
              isVideoOnly: true, // Only videos
            )
                .timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    if (kDebugMode) print('Timeout fetching from $collectionName');
                    return <Map<String, dynamic>>[];
                  },
                )
                .catchError((e) {
                  // Return empty list on error instead of throwing
                  return <Map<String, dynamic>>[];
                }),
          );
        }
      }

      // Execute all queries in parallel with timeout
      final results = await Future.wait(collectionQueries).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('Timeout waiting for all queries');
          return List<List<Map<String, dynamic>>>.filled(
            collectionQueries.length,
            <Map<String, dynamic>>[],
          );
        },
      );

      // Extract videos from all results
      for (var posts in results) {
        allVideos.addAll(_extractVideosFromPosts(posts));
      }

      if (kDebugMode) {
        print('Found ${allVideos.length} videos for user: $userId');
      }

      return allVideos;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserVideos');
      rethrow;
    }
  }

  /// Get all posts from collection (one-time fetch)
  /// Posts are ordered by createdAt in descending order (newest first)
  /// 
  /// [limit] - Optional limit on number of posts to fetch
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  Future<List<Map<String, dynamic>>> getPosts({
    int? limit,
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      Query query = _firestore
          .collection(targetCollection)
          .orderBy('createdAt', descending: true);

      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      final posts = <Map<String, dynamic>>[];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id; // Add document ID to data
        posts.add(data);
      }

      if (kDebugMode) {
        print('Fetched ${posts.length} posts from Firestore collection "$targetCollection"');
      }

      return posts;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getPosts');
      rethrow;
    }
  }

  /// Get paginated posts from collection
  /// 
  /// [limit] - Number of posts to fetch (default: 2)
  /// [lastDocument] - The last document from previous page (for pagination)
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns a map with 'posts' list and 'lastDocument' for next page
  Future<Map<String, dynamic>> getPostsPaginated({
    int limit = 2,
    DocumentSnapshot? lastDocument,
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      Query query = _firestore
          .collection(targetCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // If lastDocument is provided, start after it for pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();

      final posts = <Map<String, dynamic>>[];
      DocumentSnapshot? newLastDocument;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id; // Add document ID to data
        posts.add(data);
        newLastDocument = doc; // Track the last document
      }

      if (kDebugMode) {
        print('Fetched ${posts.length} posts (paginated, limit: $limit) from Firestore collection "$targetCollection"');
      }

      // Determine if there are more posts
      // If we got exactly the limit, there might be more posts
      // We'll check by trying to get one more document
      bool hasMore = false;
      if (querySnapshot.docs.length == limit && newLastDocument != null) {
        try {
          final nextQuery = _firestore
              .collection(targetCollection)
              .orderBy('createdAt', descending: true)
              .startAfterDocument(newLastDocument)
              .limit(1);
          final nextSnapshot = await nextQuery.get();
          hasMore = nextSnapshot.docs.isNotEmpty;
          
          if (kDebugMode) {
            print('Has more posts check: ${hasMore} (fetched ${posts.length}, limit: $limit)');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error checking for more posts: $e');
          }
          // If check fails, assume there might be more if we got full limit
          hasMore = querySnapshot.docs.length == limit;
        }
      } else {
        // If we got less than the limit, there are no more posts
        hasMore = false;
        if (kDebugMode) {
          print('No more posts: fetched ${posts.length} which is less than limit $limit');
        }
      }

      return {
        'posts': posts,
        'lastDocument': newLastDocument,
        'hasMore': hasMore,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getPostsPaginated');
      rethrow;
    }
  }

  /// Get real-time stream of posts from collection
  /// 
  /// This method returns a Stream that automatically updates whenever
  /// any user creates, modifies, or deletes a post.
  /// 
  /// Posts are ordered by createdAt in descending order (newest first)
  /// 
  /// [limit] - Optional limit on number of posts to fetch
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns a Stream of post data maps
  /// 
  /// Note: The caller is responsible for canceling the stream subscription
  /// to prevent memory leaks. Always cancel in dispose() method.
  Stream<List<Map<String, dynamic>>> getPostsStream({
    int? limit,
    String? collectionName,
  }) {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      Query query = _firestore
          .collection(targetCollection)
          .orderBy('createdAt', descending: true);

      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      return query
          .snapshots()
          .handleError((error, stackTrace) {
            // Log error but don't stop the stream
            if (kDebugMode) {
              print('Error in posts stream: $error');
            }
            final exception = ExceptionMapper.mapToAppException(error, stackTrace);
            _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getPostsStream');
          })
          .map((querySnapshot) {
            final posts = <Map<String, dynamic>>[];
            for (var doc in querySnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              data['postId'] = doc.id; // Add document ID to data
              posts.add(data);
            }

            if (kDebugMode) {
              print('Real-time update: ${posts.length} posts from Firestore collection "$targetCollection"');
            }

            return posts;
          });
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getPostsStream');
      // Return empty stream on error
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  /// Update post likes count
  /// 
  /// [postId] - The post document ID
  /// [newLikesCount] - New likes count
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  Future<void> updatePostLikes(
    String postId,
    int newLikesCount, {
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      await _firestore
          .collection(targetCollection)
          .doc(postId)
          .update({
        'likes': newLikesCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.updatePostLikes');
      rethrow;
    }
  }

  /// Update post comments count
  /// 
  /// [postId] - The post document ID
  /// [newCommentsCount] - New comments count
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  Future<void> updatePostComments(
    String postId,
    int newCommentsCount, {
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      await _firestore
          .collection(targetCollection)
          .doc(postId)
          .update({
        'comments': newCommentsCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.updatePostComments');
      rethrow;
    }
  }

  /// Save user reaction to a post
  /// 
  /// [postId] - The post document ID
  /// [userId] - The user's Firebase Auth UID
  /// [emotion] - The emoji/emotion string (e.g., '👍', '❤️', '😂', etc.)
  /// [previousEmotion] - The previous emotion if user is changing reaction (optional)
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  Future<void> saveUserReaction(
    String postId,
    String userId,
    String emotion, {
    String? previousEmotion,
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      // Use batch write for atomic updates
      final batch = _firestore.batch();

      // Save/update user reaction document
      final reactionRef = _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('reactions')
          .doc(userId);

      batch.set(reactionRef, {
        'userId': userId,
        'postId': postId,
        'emotion': emotion,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update reaction counts in post document
      final postRef = _firestore
          .collection(targetCollection)
          .doc(postId);

      // Get current reaction counts
      final postDoc = await postRef.get();
      final currentData = postDoc.data() ?? {};
      final currentCounts = Map<String, dynamic>.from(currentData['reactionCounts'] ?? {});

      // Decrement previous emotion count if user is changing reaction
      if (previousEmotion != null && previousEmotion.isNotEmpty) {
        final prevCount = (currentCounts[previousEmotion] as int?) ?? 0;
        if (prevCount > 0) {
          currentCounts[previousEmotion] = prevCount - 1;
        } else {
          currentCounts.remove(previousEmotion);
        }
      }

      // Increment new emotion count
      final currentCount = (currentCounts[emotion] as int?) ?? 0;
      currentCounts[emotion] = currentCount + 1;

      // Update post document with new reaction counts
      batch.update(postRef, {
        'reactionCounts': currentCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();

      if (kDebugMode) {
        print('User reaction saved: postId=$postId, userId=$userId, emotion=$emotion, previousEmotion=$previousEmotion');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.saveUserReaction');
      rethrow;
    }
  }

  /// Get user reaction for a specific post
  /// 
  /// [postId] - The post document ID
  /// [userId] - The user's Firebase Auth UID
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns the emotion emoji string, or null if no reaction exists
  Future<String?> getUserReaction(
    String postId,
    String userId, {
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      final doc = await _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('reactions')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        return data?['emotion'] as String?;
      }

      return null;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUserReaction');
      rethrow;
    }
  }

  /// Get user reactions for multiple posts in batch
  /// 
  /// OPTIMIZED: Uses Collection Group Query to fetch all user reactions in a single query
  /// instead of N separate reads (much more performant for large numbers of posts)
  /// 
  /// [postIds] - List of post document IDs (optional, for filtering)
  /// [userId] - The user's Firebase Auth UID
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns a map of postId -> emotion emoji string
  /// 
  /// Note: Collection Group Query works across all collections with 'reactions' subcollection,
  /// so it will find reactions in any collection. If collectionName is provided, we use
  /// fallback method for better performance with specific collections.
  Future<Map<String, String>> getUserReactions(
    List<String> postIds,
    String userId, {
    String? collectionName,
  }) async {
    // If collectionName is provided, use fallback method for better performance
    if (collectionName != null) {
      return _getUserReactionsFallback(postIds, userId, collectionName: collectionName);
    }
    
    try {
      final reactions = <String, String>{};

      // OPTIMIZED: Use Collection Group Query to fetch all reactions for this user in ONE query
      // This is much more efficient than N separate reads
      // Note: Requires a composite index in Firestore: reactions collection group, userId, createdAt
      final querySnapshot = await _firestore
          .collectionGroup('reactions') // Query across all 'reactions' subcollections
          .where('userId', isEqualTo: userId)
          .get();

      // Process results and build map
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String?;
        final emotion = data['emotion'] as String?;
        
        if (postId != null && emotion != null) {
          // If postIds filter is provided, only include matching posts
          if (postIds.isEmpty || postIds.contains(postId)) {
            reactions[postId] = emotion;
          }
        }
      }

      if (kDebugMode) {
        print('Loaded ${reactions.length} user reactions in single query (was ${postIds.length} separate reads)');
      }

      return reactions;
    } catch (e, stackTrace) {
      // Fallback to individual reads if collection group query fails
      // (e.g., if index not created yet)
      if (kDebugMode) {
        print('Collection group query failed, falling back to individual reads: $e');
      }
      
      return _getUserReactionsFallback(postIds, userId, collectionName: collectionName);
    }
  }

  /// Fallback method: Get user reactions using individual reads
  /// Used when collection group query is not available
  Future<Map<String, String>> _getUserReactionsFallback(
    List<String> postIds,
    String userId, {
    String? collectionName,
  }) async {
    try {
      final reactions = <String, String>{};

      // Fetch reactions for all posts in parallel (less efficient but works without index)
      final futures = postIds.map((postId) async {
        final emotion = await getUserReaction(postId, userId, collectionName: collectionName);
        if (emotion != null) {
          reactions[postId] = emotion;
        }
      });

      await Future.wait(futures);

      if (kDebugMode) {
        print('Loaded ${reactions.length} user reactions using fallback method');
      }

      return reactions;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService._getUserReactionsFallback');
      rethrow;
    }
  }

  /// Save a comment to a post
  /// 
  /// [postId] - The post document ID
  /// [userId] - The user's Firebase Auth UID
  /// [username] - The username of the commenter
  /// [content] - The comment text
  /// [userPhotoUrl] - Optional user profile photo URL
  /// [parentCommentId] - Optional parent comment ID if this is a reply
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns the comment document ID
  Future<String> saveComment({
    required String postId,
    required String userId,
    required String username,
    required String content,
    String? userPhotoUrl,
    String? parentCommentId,
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      // Use batch write for atomic updates
      final batch = _firestore.batch();

      // Create comment document
      final commentRef = _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('comments')
          .doc();

      final commentData = {
        'postId': postId,
        'userId': userId,
        'username': username,
        'content': content,
        'userPhotoUrl': userPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Add parentCommentId if this is a reply
      if (parentCommentId != null) {
        commentData['parentCommentId'] = parentCommentId;
      }
      
      batch.set(commentRef, commentData);

      // Always increment comment count in post document (for both top-level comments and replies)
      final postRef = _firestore
          .collection(targetCollection)
          .doc(postId);

      batch.update(postRef, {
        'comments': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If this is a reply, also increment replyCount on parent comment
      if (parentCommentId != null) {
        final parentCommentRef = _firestore
            .collection(targetCollection)
            .doc(postId)
            .collection('comments')
            .doc(parentCommentId);
        
        batch.update(parentCommentRef, {
          'replyCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit batch
      await batch.commit();

      if (kDebugMode) {
        print('Comment saved: postId=$postId, commentId=${commentRef.id}, parentCommentId=$parentCommentId');
      }

      return commentRef.id;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.saveComment');
      rethrow;
    }
  }
  
  /// Save a reply to a comment (convenience method)
  /// 
  /// [postId] - The post document ID
  /// [parentCommentId] - The parent comment ID
  /// [userId] - The user's Firebase Auth UID
  /// [username] - The username of the commenter
  /// [content] - The reply text
  /// [userPhotoUrl] - Optional user profile photo URL
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns the reply document ID
  Future<String> saveReply({
    required String postId,
    required String parentCommentId,
    required String userId,
    required String username,
    required String content,
    String? userPhotoUrl,
    String? collectionName,
  }) async {
    return saveComment(
      postId: postId,
      userId: userId,
      username: username,
      content: content,
      userPhotoUrl: userPhotoUrl,
      parentCommentId: parentCommentId,
      collectionName: collectionName,
    );
  }
  
  /// Get real-time stream of replies for a comment
  /// 
  /// This method returns a Stream that automatically updates whenever
  /// any user adds, modifies, or deletes a reply to the comment.
  /// 
  /// [postId] - The post document ID
  /// [parentCommentId] - The parent comment ID
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns a Stream of reply data maps
  /// 
  /// Note: The caller is responsible for canceling the stream subscription
  /// to prevent memory leaks. Always cancel in dispose() method.
  Stream<List<Map<String, dynamic>>> getRepliesStream({
    required String postId,
    required String parentCommentId,
    String? collectionName,
  }) {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      return _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('comments')
          .where('parentCommentId', isEqualTo: parentCommentId)
          .orderBy('createdAt', descending: false) // Oldest first
          .snapshots()
          .handleError((error, stackTrace) {
            // Log error but don't stop the stream
            if (kDebugMode) {
              print('Error in replies stream: $error');
            }
            final exception = ExceptionMapper.mapToAppException(error, stackTrace);
            _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getRepliesStream');
          })
          .map((querySnapshot) {
            final replies = <Map<String, dynamic>>[];
            for (var doc in querySnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              data['commentId'] = doc.id; // Add document ID to data
              replies.add(data);
            }

            if (kDebugMode) {
              print('Real-time update: ${replies.length} replies for comment: $parentCommentId');
            }

            return replies;
          });
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getRepliesStream');
      // Return empty stream on error
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  /// Get all comments for a post (one-time fetch)
  /// 
  /// [postId] - The post document ID
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns list of comment data maps
  Future<List<Map<String, dynamic>>> getComments(
    String postId, {
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      final querySnapshot = await _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false) // Oldest first
          .get();

      final comments = <Map<String, dynamic>>[];
      // Filter to only top-level comments (no parentCommentId)
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Only include top-level comments (no parentCommentId field or null)
        if (data['parentCommentId'] == null) {
        data['commentId'] = doc.id; // Add document ID to data
        comments.add(data);
        }
      }

      if (kDebugMode) {
        print('Fetched ${comments.length} comments for post: $postId');
      }

      return comments;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getComments');
      rethrow;
    }
  }

  /// Get a single post by ID with full details (comments count, reactions, etc.)
  /// 
  /// [postId] - The post document ID
  /// [collectionName] - Collection name where post is stored
  /// Returns post data map with all details, or null if not found
  Future<Map<String, dynamic>?> getPostById({
    required String postId,
    required String collectionName,
  }) async {
    try {
      final doc = await _firestore
          .collection(collectionName)
          .doc(postId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          print('⚠️ Post not found: $postId in collection $collectionName');
        }
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      data['postId'] = doc.id;

      if (kDebugMode) {
        print('✅ Fetched post: $postId from collection $collectionName');
      }

      return data;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getPostById');
      rethrow;
    }
  }

  /// Get paginated comments for a post
  /// 
  /// [postId] - The post document ID
  /// [limit] - Number of comments to fetch (default: 10)
  /// [lastDocument] - The last document from previous page (for pagination)
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns a map with 'comments' list and 'lastDocument' for next page
  Future<Map<String, dynamic>> getCommentsPaginated({
    required String postId,
    int limit = 10,
    DocumentSnapshot? lastDocument,
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      Query query = _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false) // Oldest first
          .limit(limit * 2); // Fetch more to account for filtering

      // If lastDocument is provided, start after it for pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();

      final comments = <Map<String, dynamic>>[];
      DocumentSnapshot? newLastDocument;

      // Filter to only top-level comments (no parentCommentId)
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Only include top-level comments (no parentCommentId field or null)
        if (data['parentCommentId'] == null) {
        data['commentId'] = doc.id; // Add document ID to data
        comments.add(data);
        newLastDocument = doc; // Track the last document
          
          // Stop if we have enough top-level comments
          if (comments.length >= limit) {
            break;
          }
        }
      }

      if (kDebugMode) {
        print('Fetched ${comments.length} comments (paginated, limit: $limit) for post: $postId');
      }

      // Determine if there are more comments
      bool hasMore = false;
      if (querySnapshot.docs.length == limit && newLastDocument != null) {
        try {
          // Check for more top-level comments
          final nextQuery = _firestore
              .collection(targetCollection)
              .doc(postId)
              .collection('comments')
              .orderBy('createdAt', descending: false)
              .startAfterDocument(newLastDocument)
              .limit(10); // Check a few more to find top-level ones
          
          final nextSnapshot = await nextQuery.get();
          // Check if any of the next documents are top-level
          hasMore = nextSnapshot.docs.any((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['parentCommentId'] == null;
          });
          
          if (kDebugMode) {
            print('Has more comments check: ${hasMore} (fetched ${comments.length}, limit: $limit)');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error checking for more comments: $e');
          }
          // If check fails, assume there might be more if we got full limit
          hasMore = querySnapshot.docs.length == limit;
        }
      } else {
        // If we got less than the limit, there are no more comments
        hasMore = false;
        if (kDebugMode) {
          print('No more comments: fetched ${comments.length} which is less than limit $limit');
        }
      }

      return {
        'comments': comments,
        'lastDocument': newLastDocument,
        'hasMore': hasMore,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getCommentsPaginated');
      rethrow;
    }
  }

  /// Get real-time stream of comments for a post
  /// 
  /// This method returns a Stream that automatically updates whenever
  /// any user adds, modifies, or deletes a comment on the post.
  /// 
  /// [postId] - The post document ID
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  /// Returns a Stream of comment data maps
  /// 
  /// Note: The caller is responsible for canceling the stream subscription
  /// to prevent memory leaks. Always cancel in dispose() method.
  Stream<List<Map<String, dynamic>>> getCommentsStream(
    String postId, {
    String? collectionName,
  }) {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      return _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false) // Oldest first
          .snapshots()
          .handleError((error, stackTrace) {
            // Log error but don't stop the stream
            if (kDebugMode) {
              print('Error in comments stream: $error');
            }
            final exception = ExceptionMapper.mapToAppException(error, stackTrace);
            _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getCommentsStream');
          })
          .map((querySnapshot) {
            final comments = <Map<String, dynamic>>[];
            // Filter to only top-level comments (no parentCommentId)
            for (var doc in querySnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              // Only include top-level comments (no parentCommentId field or null)
              if (data['parentCommentId'] == null) {
              data['commentId'] = doc.id; // Add document ID to data
              comments.add(data);
              }
            }

            if (kDebugMode) {
              print('Real-time update: ${comments.length} top-level comments for post: $postId');
            }

            return comments;
          });
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getCommentsStream');
      // Return empty stream on error
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  /// Remove user reaction from a post
  /// 
  /// [postId] - The post document ID
  /// [userId] - The user's Firebase Auth UID
  /// [emotion] - The emotion being removed (to decrement count)
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  Future<void> removeUserReaction(
    String postId,
    String userId,
    String emotion, {
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      // Use batch write for atomic updates
      final batch = _firestore.batch();

      // Delete user reaction document
      final reactionRef = _firestore
          .collection(targetCollection)
          .doc(postId)
          .collection('reactions')
          .doc(userId);

      batch.delete(reactionRef);

      // Decrement reaction count in post document
      final postRef = _firestore
          .collection(targetCollection)
          .doc(postId);

      // Get current reaction counts
      final postDoc = await postRef.get();
      final currentData = postDoc.data() ?? {};
      final currentCounts = Map<String, dynamic>.from(currentData['reactionCounts'] ?? {});

      // Decrement emotion count
      final currentCount = (currentCounts[emotion] as int?) ?? 0;
      if (currentCount > 1) {
        currentCounts[emotion] = currentCount - 1;
      } else {
        // Remove emotion from map if count reaches 0
        currentCounts.remove(emotion);
      }

      // Update post document with updated reaction counts
      batch.update(postRef, {
        'reactionCounts': currentCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();

      if (kDebugMode) {
        print('User reaction removed: postId=$postId, userId=$userId, emotion=$emotion');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.removeUserReaction');
      rethrow;
    }
  }

  /// Check if a chat room exists in Firestore
  /// 
  /// [chatRoomId] - The chat room document ID to check
  /// Returns true if the chat room exists, false otherwise
  Future<bool> checkChatRoomExists(String chatRoomId) async {
    try {
      final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      return doc.exists;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.checkChatRoomExists');
      return false;
    }
  }

  /// Get all user IDs from users collection where appIdentifier is 'festivalrumor'
  /// 
  /// Returns a list of user IDs (document IDs from users collection)
  Future<List<String>> getAllFestivalRumorUserIds() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('appIdentifier', isEqualTo: 'festivalrumor')
          .get();

      final userIds = querySnapshot.docs.map((doc) => doc.id).toList();

      if (kDebugMode) {
        print('Found ${userIds.length} users with appIdentifier=festivalrumor');
      }

      return userIds;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getAllFestivalRumorUserIds');
      return [];
    }
  }

  /// Create a public chat room for a festival
  /// 
  /// [chatRoomId] - The chat room document ID (format: {festivalID}_{festivalName}_PublicChat)
  /// [festivalName] - The name of the festival
  /// [festivalId] - The festival ID
  /// [memberIds] - List of user IDs to add as members
  /// Returns the created chat room document ID
  Future<String> createPublicChatRoom({
    required String chatRoomId,
    required String festivalName,
    required int festivalId,
    required List<String> memberIds,
  }) async {
    try {
      final chatRoomData = <String, dynamic>{
        'name': '$festivalName Community',
        'isPublic': true,
        'festivalID': festivalId,
        'members': memberIds,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('chatRooms').doc(chatRoomId).set(
        chatRoomData,
        SetOptions(merge: false), // Don't merge - create new document
      );

      if (kDebugMode) {
        print('✅ Created public chat room: $chatRoomId');
        print('   Name: ${chatRoomData['name']}');
        print('   Members: ${memberIds.length}');
      }

      return chatRoomId;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.createPublicChatRoom');
      rethrow;
    }
  }

  /// Generate chat room ID for a festival
  /// Format: {festivalID}_{festivalName}_PublicChat
  /// Example: "1_Glastonbury_Festival_PublicChat"
  static String getFestivalChatRoomId(int festivalId, String festivalName) {
    // Sanitize festival name: remove special characters, replace spaces with underscores
    final sanitizedName = festivalName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscore
        .toLowerCase();
    
    return '${festivalId}_${sanitizedName}_PublicChat';
  }

  /// Add a new user to all existing public chat rooms
  /// This is called automatically when a new user signs up
  /// 
  /// [userId] - The new user's Firebase Auth UID
  /// 
  /// This method is non-blocking - if it fails, it won't prevent signup from completing
  /// Uses batch writes for efficiency when there are multiple chat rooms
  Future<void> addUserToAllPublicChatRooms(String userId) async {
    try {
      // Query all public chat rooms
      final querySnapshot = await _firestore
          .collection('chatRooms')
          .where('isPublic', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // No public chat rooms exist yet - this is fine, just return
        if (kDebugMode) {
          print('ℹ️ No public chat rooms exist yet for user: $userId');
        }
        return;
      }

      // Firestore batch write limit is 500 operations
      // If we have more than 500 chat rooms, we'll need to split into multiple batches
      const maxBatchSize = 500;
      final docs = querySnapshot.docs;
      
      // Process in batches if needed
      for (int i = 0; i < docs.length; i += maxBatchSize) {
        final batch = _firestore.batch();
        final batchDocs = docs.skip(i).take(maxBatchSize).toList();
        
        for (var doc in batchDocs) {
          final chatRoomRef = doc.reference;
          // Use arrayUnion to add user ID (won't add if already exists)
          batch.update(chatRoomRef, {
            'members': FieldValue.arrayUnion([userId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Commit this batch
        await batch.commit();
        
        if (kDebugMode) {
          print('✅ Added user $userId to ${batchDocs.length} public chat rooms (batch ${(i ~/ maxBatchSize) + 1})');
        }
      }

      if (kDebugMode) {
        print('✅ Successfully added user $userId to all ${docs.length} public chat rooms');
      }
    } catch (e, stackTrace) {
      // Log error but don't throw - this is a non-critical operation
      // Signup should still succeed even if adding to chat rooms fails
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.addUserToAllPublicChatRooms');
      
      if (kDebugMode) {
        print('⚠️ Failed to add user $userId to public chat rooms: $e');
        print('   Signup will still complete successfully');
      }
      // Don't rethrow - this is intentionally non-blocking
    }
  }

  /// Send a message to a chat room
  /// 
  /// [chatRoomId] - The chat room document ID
  /// [userId] - The sender's user ID
  /// [username] - The sender's username
  /// [content] - The message content
  /// [userPhotoUrl] - Optional user profile photo URL
  /// Returns the message document ID
  Future<String> sendChatMessage({
    required String chatRoomId,
    required String userId,
    required String username,
    required String content,
    String? userPhotoUrl,
  }) async {
    try {
      // Use batch write for atomic updates
      final batch = _firestore.batch();

      // Create message document
      final messageRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc();

      final messageData = {
        'chatRoomId': chatRoomId,
        'userId': userId,
        'username': username,
        'content': content,
        'userPhotoUrl': userPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      batch.set(messageRef, messageData);

      // Update chat room's lastMessage and lastMessageTime
      final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
      batch.update(chatRoomRef, {
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();

      if (kDebugMode) {
        print('✅ Sent message to chat room: $chatRoomId');
      }

      return messageRef.id;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.sendChatMessage');
      rethrow;
    }
  }

  /// Get real-time stream of messages for a chat room
  /// 
  /// [chatRoomId] - The chat room document ID
  /// [limit] - Maximum number of messages to load (default: 50)
  /// Returns a Stream of message data maps
  /// 
  /// Note: The caller is responsible for canceling the stream subscription
  Stream<List<Map<String, dynamic>>> getChatMessagesStream(
    String chatRoomId, {
    int limit = 50,
  }) {
    try {
      return _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('createdAt', descending: false) // Oldest first
          .limit(limit)
          .snapshots()
          .handleError((error, stackTrace) {
            // Log error but don't stop the stream
            if (kDebugMode) {
              print('Error in chat messages stream: $error');
            }
            final exception = ExceptionMapper.mapToAppException(error, stackTrace);
            _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getChatMessagesStream');
          })
          .map((querySnapshot) {
            final messages = <Map<String, dynamic>>[];
            for (var doc in querySnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              data['messageId'] = doc.id; // Add document ID to data
              messages.add(data);
            }

            if (kDebugMode) {
              print('Real-time update: ${messages.length} messages for chat room: $chatRoomId');
            }

            return messages;
          });
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getChatMessagesStream');
      // Return empty stream on error
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  /// Get paginated messages for a chat room (for loading older messages)
  /// 
  /// [chatRoomId] - The chat room document ID
  /// [limit] - Number of messages to load
  /// [lastMessage] - Last message timestamp for pagination (optional)
  /// Returns a map with 'messages' list and 'lastMessage' timestamp
  Future<Map<String, dynamic>> getChatMessagesPaginated({
    required String chatRoomId,
    int limit = 20,
    Timestamp? lastMessage,
  }) async {
    try {
      Query query = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // If lastMessage is provided, start after it for pagination
      if (lastMessage != null) {
        query = query.startAfter([lastMessage]);
      }

      final querySnapshot = await query.get();

      final messages = <Map<String, dynamic>>[];
      Timestamp? newLastMessage;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['messageId'] = doc.id;
        messages.add(data);
        
        // Track the oldest message timestamp for next pagination
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          if (newLastMessage == null || createdAt.compareTo(newLastMessage) < 0) {
            newLastMessage = createdAt;
          }
        }
      }

      // Reverse to show oldest first (chronological order)
      // Use reversed.toList() to create a new reversed list
      final reversedMessages = messages.reversed.toList();

      return {
        'messages': reversedMessages,
        'lastMessage': newLastMessage,
        'hasMore': querySnapshot.docs.length == limit,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getChatMessagesPaginated');
      rethrow;
    }
  }

  /// Delete a message from Firestore (delete for everyone)
  /// 
  /// [chatRoomId] - The chat room document ID
  /// [messageId] - The message document ID to delete
  /// [userId] - The user ID who is deleting (must be the message sender)
  /// Returns true if deletion was successful
  Future<bool> deleteChatMessageForEveryone({
    required String chatRoomId,
    required String messageId,
    required String userId,
  }) async {
    try {
      // First, verify the message exists and belongs to the user
      final messageRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      
      if (!messageDoc.exists) {
        if (kDebugMode) {
          print('⚠️ Message not found: $messageId');
        }
        return false;
      }

      final messageData = messageDoc.data() as Map<String, dynamic>;
      final messageUserId = messageData['userId'] as String?;

      // Verify the user is the message sender
      if (messageUserId != userId) {
        if (kDebugMode) {
          print('⚠️ User $userId is not the sender of message $messageId');
        }
        return false;
      }

      // Delete the message
      await messageRef.delete();

      // Update chat room's lastMessage if this was the last message
      final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
      final chatRoomDoc = await chatRoomRef.get();
      
      if (chatRoomDoc.exists) {
        final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;
        final lastMessage = chatRoomData['lastMessage'] as String?;
        
        // If the deleted message was the last message, update chat room
        if (lastMessage == messageData['content']) {
          // Get the most recent message to update lastMessage
          final recentMessagesQuery = await _firestore
              .collection('chatRooms')
              .doc(chatRoomId)
              .collection('messages')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          if (recentMessagesQuery.docs.isNotEmpty) {
            final recentMessage = recentMessagesQuery.docs.first.data();
            await chatRoomRef.update({
              'lastMessage': recentMessage['content'] as String? ?? '',
              'lastMessageTime': recentMessage['createdAt'],
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            // No messages left, clear lastMessage
            await chatRoomRef.update({
              'lastMessage': '',
              'lastMessageTime': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (kDebugMode) {
        print('✅ Deleted message for everyone: $messageId');
      }

      return true;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.deleteChatMessageForEveryone');
      rethrow;
    }
  }

  /// Get users by phone numbers (for matching contacts with app users)
  /// 
  /// [phoneNumbers] - List of phone numbers to search for
  /// Returns a map of originalPhoneNumber -> userId
  Future<Map<String, String>> getUsersByPhoneNumbers(List<String> phoneNumbers) async {
    try {
      if (phoneNumbers.isEmpty) return {};

      final phoneToUserId = <String, String>{};
      
      // Helper function to normalize phone number
      String normalizePhone(String phone) {
        return phone
            .replaceAll(RegExp(r'[\s\-\(\)\+]'), '')
            .replaceAll(RegExp(r'^00'), '') // Remove leading 00
            .replaceAll(RegExp(r'^0'), ''); // Remove leading 0
      }

      // Helper function to get last 10 digits
      String getLast10Digits(String phone) {
        if (phone.length >= 10) {
          return phone.length > 10 
              ? phone.substring(phone.length - 10)
              : phone;
        }
        return phone;
      }

      // Create a map of normalized phone -> original phone for lookup
      final normalizedToOriginal = <String, String>{};
      for (final phone in phoneNumbers) {
        if (phone.isNotEmpty) {
          final normalized = normalizePhone(phone);
          if (normalized.isNotEmpty) {
            normalizedToOriginal[normalized] = phone;
          }
        }
      }

      if (normalizedToOriginal.isEmpty) return {};

      // Strategy 1: Try direct queries with whereIn (batch of 10)
      final batchSize = 10;
      final normalizedPhones = normalizedToOriginal.keys.toList();
      final processedPhones = <String>{};

      for (int i = 0; i < normalizedPhones.length; i += batchSize) {
        final batch = normalizedPhones.skip(i).take(batchSize).toList();
        
        try {
          // Try querying with normalized phone numbers
          final querySnapshot = await _firestore
              .collection('users')
              .where('phoneNumber', whereIn: batch)
              .where('appIdentifier', isEqualTo: 'festivalrumor')
              .get();

          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            final storedPhone = data['phoneNumber'] as String?;
            if (storedPhone != null) {
              final storedNormalized = normalizePhone(storedPhone);
              
              // Match with batch phones
              for (var contactNormalized in batch) {
                if (storedNormalized == contactNormalized) {
                  final originalPhone = normalizedToOriginal[contactNormalized]!;
                  phoneToUserId[originalPhone] = doc.id;
                  processedPhones.add(contactNormalized);
                  break;
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error in batch query: $e');
          }
        }
      }

      // Strategy 2: For unmatched phones, fetch all users and match by last 10 digits
      final unmatchedPhones = normalizedPhones
          .where((phone) => !processedPhones.contains(phone))
          .toList();

      if (unmatchedPhones.isNotEmpty) {
        try {
          // Fetch all users with appIdentifier = 'festivalrumor' and phoneNumber field
          final allUsersSnapshot = await _firestore
              .collection('users')
              .where('appIdentifier', isEqualTo: 'festivalrumor')
              .where('phoneNumber', isNotEqualTo: null)
              .get();

          // Create a map of last 10 digits -> userId for all users
          final last10ToUserId = <String, List<MapEntry<String, String>>>{};
          for (var doc in allUsersSnapshot.docs) {
            final data = doc.data();
            final storedPhone = data['phoneNumber'] as String?;
            if (storedPhone != null && storedPhone.isNotEmpty) {
              final storedNormalized = normalizePhone(storedPhone);
              final last10 = getLast10Digits(storedNormalized);
              if (last10.length >= 10) {
                if (!last10ToUserId.containsKey(last10)) {
                  last10ToUserId[last10] = [];
                }
                last10ToUserId[last10]!.add(MapEntry(storedNormalized, doc.id));
              }
            }
          }

          // Match unmatched contact phones by last 10 digits
          for (var contactNormalized in unmatchedPhones) {
            final contactLast10 = getLast10Digits(contactNormalized);
            if (contactLast10.length >= 10) {
              final matches = last10ToUserId[contactLast10];
              if (matches != null && matches.isNotEmpty) {
                // Use the first match (or could implement more sophisticated matching)
                final originalPhone = normalizedToOriginal[contactNormalized]!;
                phoneToUserId[originalPhone] = matches.first.value;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error in fallback matching: $e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Found ${phoneToUserId.length} users matching phone numbers out of ${phoneNumbers.length} contacts');
      }

      return phoneToUserId;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getUsersByPhoneNumbers');
      rethrow;
    }
  }

  /// Check if a private chat room with the given name already exists for a user
  /// 
  /// [chatRoomName] - The name to check
  /// [userId] - The user ID (creator or member)
  /// Returns true if a private chat room with the same name exists
  Future<bool> privateChatRoomNameExists(String chatRoomName, String userId) async {
    try {
      final normalizedName = chatRoomName.trim().toLowerCase();
      
      // Query private chat rooms where user is creator
      final createdRoomsQuery = await _firestore
          .collection('chatRooms')
          .where('isPublic', isEqualTo: false)
          .where('createdBy', isEqualTo: userId)
          .get();

      // Check created rooms for duplicate names
      for (var doc in createdRoomsQuery.docs) {
        final data = doc.data();
        final existingName = data['name'] as String?;
        if (existingName != null) {
          final normalizedExisting = existingName.trim().toLowerCase();
          if (normalizedName == normalizedExisting) {
            if (kDebugMode) {
              print('⚠️ Private chat room with name "$chatRoomName" already exists (created by user)');
            }
            return true;
          }
        }
      }

      // Query private chat rooms where user is a member
      final memberRoomsQuery = await _firestore
          .collection('chatRooms')
          .where('isPublic', isEqualTo: false)
          .where('members', arrayContains: userId)
          .get();

      // Check member rooms for duplicate names
      for (var doc in memberRoomsQuery.docs) {
        final data = doc.data();
        final existingName = data['name'] as String?;
        if (existingName != null) {
          final normalizedExisting = existingName.trim().toLowerCase();
          if (normalizedName == normalizedExisting) {
            if (kDebugMode) {
              print('⚠️ Private chat room with name "$chatRoomName" already exists (user is member)');
            }
            return true;
          }
        }
      }

      return false;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.privateChatRoomNameExists');
      // On error, return false to allow creation (fail open)
      return false;
    }
  }

  /// Create a private chat room
  /// 
  /// [chatRoomName] - The name of the chat room
  /// [creatorId] - The user ID who created the chat room
  /// [memberIds] - List of user IDs to add as members (includes creator)
  /// Returns the created chat room document ID
  Future<String> createPrivateChatRoom({
    required String chatRoomName,
    required String creatorId,
    required List<String> memberIds,
  }) async {
    try {
      // Generate unique chat room ID
      final chatRoomId = _firestore.collection('chatRooms').doc().id;

      // Ensure creator is in members list
      final allMembers = <String>{...memberIds, creatorId}.toList();

      final chatRoomData = <String, dynamic>{
        'name': chatRoomName,
        'isPublic': false,
        'createdBy': creatorId,
        'members': allMembers,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('chatRooms').doc(chatRoomId).set(
        chatRoomData,
        SetOptions(merge: false), // Don't merge - create new document
      );

      if (kDebugMode) {
        print('✅ Created private chat room: $chatRoomId');
        print('   Name: $chatRoomName');
        print('   Creator: $creatorId');
        print('   Members: ${allMembers.length}');
      }

      return chatRoomId;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.createPrivateChatRoom');
      rethrow;
    }
  }

  /// Delete a private chat room and all its resources
  /// 
  /// [chatRoomId] - The chat room document ID to delete
  /// [userId] - The user ID who is deleting (must be the creator)
  /// Returns true if deletion was successful
  Future<bool> deletePrivateChatRoom({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      // First, verify the chat room exists and user is the creator
      final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
      final chatRoomDoc = await chatRoomRef.get();
      
      if (!chatRoomDoc.exists) {
        if (kDebugMode) {
          print('⚠️ Chat room not found: $chatRoomId');
        }
        return false;
      }

      final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;
      final createdBy = chatRoomData['createdBy'] as String?;
      final isPublic = chatRoomData['isPublic'] as bool? ?? false;

      // Only allow deletion of private chat rooms
      if (isPublic) {
        if (kDebugMode) {
          print('⚠️ Cannot delete public chat rooms');
        }
        return false;
      }

      // Verify the user is the creator
      if (createdBy != userId) {
        if (kDebugMode) {
          print('⚠️ User $userId is not the creator of chat room $chatRoomId');
        }
        return false;
      }

      // Delete all messages in the messages subcollection
      final messagesRef = chatRoomRef.collection('messages');
      final messagesSnapshot = await messagesRef.get();
      
      // Firestore batch write limit is 500 operations
      // Delete messages in batches if needed
      const batchSize = 500;
      final batches = <WriteBatch>[];
      WriteBatch currentBatch = _firestore.batch();
      int operationCount = 0;

      for (var messageDoc in messagesSnapshot.docs) {
        if (operationCount >= batchSize) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
        currentBatch.delete(messageDoc.reference);
        operationCount++;
      }

      // Add the last batch if it has operations
      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      // Commit all batches
      for (var batch in batches) {
        await batch.commit();
      }

      // Delete the chat room document
      await chatRoomRef.delete();

      if (kDebugMode) {
        print('✅ Deleted private chat room: $chatRoomId');
        print('   Deleted ${messagesSnapshot.docs.length} messages');
      }

      return true;
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.deletePrivateChatRoom');
      rethrow;
    }
  }

  /// Get private chat rooms for a user
  /// Returns chat rooms where user is the creator or a member
  /// 
  /// [userId] - The user ID
  /// Returns a stream of chat room data maps
  Stream<List<Map<String, dynamic>>> getPrivateChatRoomsForUser(String userId) {
    try {
      // Query chat rooms where:
      // 1. isPublic == false (private rooms)
      // 2. createdBy == userId OR members array contains userId
      
      // Note: Firestore doesn't support OR queries directly, so we need two queries
      // We'll combine them using StreamZip
      
      final createdRoomsStream = _firestore
          .collection('chatRooms')
          .where('isPublic', isEqualTo: false)
          .where('createdBy', isEqualTo: userId)
          .snapshots();

      final memberRoomsStream = _firestore
          .collection('chatRooms')
          .where('isPublic', isEqualTo: false)
          .where('members', arrayContains: userId)
          .snapshots();

      // Combine both streams - use StreamZip or combine manually
      return createdRoomsStream.asyncMap((createdSnapshot) async {
        // Get member rooms snapshot
        final memberSnapshot = await _firestore
            .collection('chatRooms')
            .where('isPublic', isEqualTo: false)
            .where('members', arrayContains: userId)
            .get();

        final allRooms = <String, Map<String, dynamic>>{};

        // Process created rooms
        for (var doc in createdSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['chatRoomId'] = doc.id;
          allRooms[doc.id] = data;
        }

        // Process member rooms (may overlap with created rooms)
        for (var doc in memberSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['chatRoomId'] = doc.id;
          allRooms[doc.id] = data; // Will overwrite if already exists (no duplicates)
        }

        final roomsList = allRooms.values.toList();
        
        // Sort by updatedAt or createdAt (newest first)
        roomsList.sort((a, b) {
          final aTime = a['updatedAt'] ?? a['createdAt'];
          final bTime = b['updatedAt'] ?? b['createdAt'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return (bTime as Timestamp).compareTo(aTime as Timestamp);
        });

        if (kDebugMode) {
          print('✅ Found ${roomsList.length} private chat rooms for user: $userId');
        }

        return roomsList;
      }).handleError((error, stackTrace) {
        if (kDebugMode) {
          print('Error in private chat rooms stream: $error');
        }
        final exception = ExceptionMapper.mapToAppException(error, stackTrace);
        _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getPrivateChatRoomsForUser');
        return <Map<String, dynamic>>[];
      });
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getPrivateChatRoomsForUser');
      // Return empty stream on error
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  /// Delete a post from Firestore and its media from Firebase Storage
  /// 
  /// [postId] - The post document ID to delete
  /// [userId] - The user ID (to verify ownership)
  /// [collectionName] - Optional collection name (defaults to 'festivalrumorglobalfeed')
  Future<void> deletePost({
    required String postId,
    required String userId,
    String? collectionName,
  }) async {
    try {
      final targetCollection = collectionName ?? defaultPostsCollection;
      
      // Get the post document first to verify ownership and get media URLs
      final postRef = _firestore.collection(targetCollection).doc(postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) {
        if (kDebugMode) {
          print('⚠️ Post not found: $postId');
        }
        throw Exception('Post not found');
      }

      final postData = postDoc.data() as Map<String, dynamic>? ?? {};
      final postUserId = postData['userId'] as String?;

      // Verify the user owns the post
      if (postUserId != userId) {
        if (kDebugMode) {
          print('⚠️ User $userId does not own post $postId');
        }
        throw Exception('You can only delete your own posts');
      }

      // Get media paths from the post
      final mediaPaths = <String>[];
      
      // Check for old format (single imagePath)
      if (postData['imagePath'] != null) {
        final imagePath = postData['imagePath'] as String?;
        if (imagePath != null && imagePath.isNotEmpty && 
            (imagePath.startsWith('http://') || imagePath.startsWith('https://'))) {
          mediaPaths.add(imagePath);
        }
      }
      
      // Check for new format (mediaPaths array)
      if (postData['mediaPaths'] != null) {
        final paths = postData['mediaPaths'] as List<dynamic>?;
        if (paths != null) {
          for (final path in paths) {
            if (path is String && path.isNotEmpty &&
                (path.startsWith('http://') || path.startsWith('https://'))) {
              mediaPaths.add(path);
            }
          }
        }
      }

      // Delete media files from Firebase Storage
      if (mediaPaths.isNotEmpty) {
        await _deletePostMediaFromStorage(mediaPaths);
      }

      // Delete all subcollections (reactions, comments)
      await _deletePostSubcollections(postRef);

      // Delete the post document
      await postRef.delete();

      // Decrement user's post count
      // Always decrement by 1 per post (same as increment - one post = one count)
      // This matches the increment logic where we always increment by 1 regardless of media items
      try {
        const int postCountDecrement = 1; // Always 1 per post
        if (kDebugMode) {
          print('🔢 Post counter decrement: Will decrement by 1 (post had ${mediaPaths.length} media items)');
        }
        await decrementUserPostCount(userId, count: postCountDecrement);
      } catch (e) {
        // Log error but don't fail deletion if counter update fails
        if (kDebugMode) {
          print('⚠️ Failed to decrement post count for user $userId: $e');
        }
      }

      // Clear profile cache for this user
      clearProfileCache(userId: userId);

      if (kDebugMode) {
        print('✅ Post deleted successfully: $postId');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.deletePost');
      rethrow;
    }
  }

  /// Delete media files from Firebase Storage
  /// 
  /// [mediaUrls] - List of media URLs to delete
  Future<void> _deletePostMediaFromStorage(List<String> mediaUrls) async {
    try {
      for (final url in mediaUrls) {
        try {
          // Extract the storage path from the download URL
          // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token=...
          final uri = Uri.parse(url);
          final pathSegments = uri.pathSegments;
          
          if (pathSegments.length >= 2 && pathSegments[0] == 'v0' && pathSegments[1] == 'b') {
            // Extract the path from the URL
            // The path is URL-encoded in the 'o' parameter
            final pathParam = uri.queryParameters['alt'] == 'media' 
                ? pathSegments[pathSegments.length - 1] 
                : null;
            
            if (pathParam != null) {
              // Decode the path
              final decodedPath = Uri.decodeComponent(pathParam);
              
              // Create storage reference
              final ref = FirebaseStorage.instance.refFromURL(url);
              
              // Delete the file
              await ref.delete();
              
              if (kDebugMode) {
                print('✅ Deleted media from Storage: $decodedPath');
              }
            } else {
              // Fallback: try to delete using the full URL
              final ref = FirebaseStorage.instance.refFromURL(url);
              await ref.delete();
              
              if (kDebugMode) {
                print('✅ Deleted media from Storage (fallback): $url');
              }
            }
          } else {
            // Try direct deletion using refFromURL
            try {
              final ref = FirebaseStorage.instance.refFromURL(url);
              await ref.delete();
              if (kDebugMode) {
                print('✅ Deleted media from Storage: $url');
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Could not delete media from Storage: $url - $e');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error deleting media from Storage: $url - $e');
          }
          // Continue with other files even if one fails
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _deletePostMediaFromStorage: $e');
      }
      // Don't throw - media deletion failures shouldn't prevent post deletion
    }
  }

  /// Delete all subcollections of a post (reactions, comments)
  /// 
  /// [postRef] - Reference to the post document
  Future<void> _deletePostSubcollections(DocumentReference postRef) async {
    try {
      // Delete reactions subcollection
      final reactionsRef = postRef.collection('reactions');
      final reactionsSnapshot = await reactionsRef.get();
      
      if (reactionsSnapshot.docs.isNotEmpty) {
        // Firestore batch write limit is 500 operations
        const batchSize = 500;
        WriteBatch? currentBatch;
        int operationCount = 0;

        for (var doc in reactionsSnapshot.docs) {
          if (currentBatch == null || operationCount >= batchSize) {
            if (currentBatch != null) {
              await currentBatch.commit();
            }
            currentBatch = _firestore.batch();
            operationCount = 0;
          }
          currentBatch.delete(doc.reference);
          operationCount++;
        }

        if (currentBatch != null && operationCount > 0) {
          await currentBatch.commit();
        }

        if (kDebugMode) {
          print('✅ Deleted ${reactionsSnapshot.docs.length} reactions');
        }
      }

      // Delete comments subcollection
      final commentsRef = postRef.collection('comments');
      final commentsSnapshot = await commentsRef.get();
      
      if (commentsSnapshot.docs.isNotEmpty) {
        // Firestore batch write limit is 500 operations
        const batchSize = 500;
        WriteBatch? currentBatch;
        int operationCount = 0;

        for (var doc in commentsSnapshot.docs) {
          if (currentBatch == null || operationCount >= batchSize) {
            if (currentBatch != null) {
              await currentBatch.commit();
            }
            currentBatch = _firestore.batch();
            operationCount = 0;
          }
          currentBatch.delete(doc.reference);
          operationCount++;
        }

        if (currentBatch != null && operationCount > 0) {
          await currentBatch.commit();
        }

        if (kDebugMode) {
          print('✅ Deleted ${commentsSnapshot.docs.length} comments');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error deleting subcollections: $e');
      }
      // Don't throw - subcollection deletion failures shouldn't prevent post deletion
    }
  }

  /// Decrement user's post count in Firestore
  /// Uses atomic decrement to safely handle concurrent updates
  /// Ensures count never goes below 0
  /// 
  /// [userId] - The user ID whose post count should be decremented
  /// [count] - The number to decrement by (defaults to 1)
  Future<void> decrementUserPostCount(String userId, {int count = 1}) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // Get current count first to ensure it doesn't go negative
      final userDoc = await userRef.get();
      final currentData = userDoc.data() as Map<String, dynamic>? ?? {};
      final currentCount = currentData['postCount'] as int? ?? 0;
      
      // Calculate new count and ensure it's not negative
      final newCount = (currentCount - count).clamp(0, double.infinity).toInt();
      
      // Only update if the count would change
      if (newCount != currentCount) {
        await userRef.update({
          'postCount': newCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('✅ Decremented post count for user $userId: $currentCount -> $newCount (decrement by $count)');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Post count already at minimum (0), cannot decrement further');
        }
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.decrementUserPostCount');
      // Don't rethrow - counter updates are not critical
      if (kDebugMode) {
        print('⚠️ Failed to decrement post count: $e');
      }
    }
  }

  // ==================== FOLLOW/UNFOLLOW METHODS ====================

  /// Follow a user
  /// Adds the targetUserId to currentUserId's following list
  /// Adds currentUserId to targetUserId's followers list
  /// Updates follower/following counts atomically
  /// 
  /// [currentUserId] - The user who is following
  /// [targetUserId] - The user being followed
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      if (kDebugMode) {
        print('🔄 [followUser] Called');
        print('   currentUserId: $currentUserId');
        print('   targetUserId: $targetUserId');
      }
      
      if (currentUserId == targetUserId) {
        throw Exception('Cannot follow yourself');
      }

      // Check if already following to prevent duplicates
      final isAlreadyFollowing = await isFollowing(currentUserId, targetUserId);
      if (isAlreadyFollowing) {
        if (kDebugMode) {
          print('ℹ️ [followUser] User $currentUserId is already following $targetUserId, skipping...');
        }
        return;
      }

      // Get current user document to check if following array exists
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>? ?? {};
      final currentFollowing = (currentUserData['following'] as List<dynamic>?) ?? [];
      
      if (kDebugMode) {
        print('📊 [followUser] Current user data BEFORE update:');
        print('   following array exists: ${currentUserData.containsKey('following')}');
        print('   following array length: ${currentFollowing.length}');
        print('   following array content: $currentFollowing');
        print('   followingCount: ${currentUserData['followingCount']}');
        print('   Already contains targetUserId: ${currentFollowing.contains(targetUserId)}');
      }

      final batch = _firestore.batch();
      
      // Add targetUserId to currentUserId's following array
      // Use arrayUnion which will create the array if it doesn't exist
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      
      // If following array doesn't exist, we need to set it first
      if (!currentUserData.containsKey('following')) {
        if (kDebugMode) {
          print('⚠️ [followUser] following array does not exist, creating it...');
        }
        // Set the array if it doesn't exist
        batch.set(currentUserRef, {
          'following': [targetUserId],
          'followingCount': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Array exists, use arrayUnion
        batch.update(currentUserRef, {
          'following': FieldValue.arrayUnion([targetUserId]),
          'followingCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Add currentUserId to targetUserId's followers array
      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayUnion([currentUserId]),
        'followersCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        print('✅ [followUser] Successfully followed');
        print('   User $currentUserId followed $targetUserId');
        
        // Verify the update
        final verifyDoc = await _firestore.collection('users').doc(currentUserId).get();
        final verifyData = verifyDoc.data() as Map<String, dynamic>? ?? {};
        final verifyFollowing = (verifyData['following'] as List<dynamic>?) ?? [];
        print('   Verification - following array length: ${verifyFollowing.length}');
        print('   Verification - followingCount: ${verifyData['followingCount']}');
        print('   Verification - contains targetUserId: ${verifyFollowing.contains(targetUserId)}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [followUser] Error: $e');
        print('   Stack trace: $stackTrace');
      }
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.followUser');
      rethrow;
    }
  }

  /// Unfollow a user
  /// Removes the targetUserId from currentUserId's following list
  /// Removes currentUserId from targetUserId's followers list
  /// Updates follower/following counts atomically
  /// Ensures counts never go below 0
  /// 
  /// [currentUserId] - The user who is unfollowing
  /// [targetUserId] - The user being unfollowed
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      if (currentUserId == targetUserId) {
        throw Exception('Cannot unfollow yourself');
      }

      // Get current counts to ensure they don't go negative
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>? ?? {};
      final targetUserData = targetUserDoc.data() as Map<String, dynamic>? ?? {};
      
      final currentFollowingCount = (currentUserData['followingCount'] as int?) ?? 0;
      final targetFollowersCount = (targetUserData['followersCount'] as int?) ?? 0;

      final batch = _firestore.batch();
      
      // Remove targetUserId from currentUserId's following array
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final newCurrentFollowingCount = (currentFollowingCount - 1).clamp(0, double.infinity).toInt();
      batch.update(currentUserRef, {
        'following': FieldValue.arrayRemove([targetUserId]),
        'followingCount': newCurrentFollowingCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove currentUserId from targetUserId's followers array
      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      final newTargetFollowersCount = (targetFollowersCount - 1).clamp(0, double.infinity).toInt();
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayRemove([currentUserId]),
        'followersCount': newTargetFollowersCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        print('✅ User $currentUserId unfollowed $targetUserId');
        print('   Current user following: $currentFollowingCount -> $newCurrentFollowingCount');
        print('   Target user followers: $targetFollowersCount -> $newTargetFollowersCount');
      }
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.unfollowUser');
      rethrow;
    }
  }

  /// Check if currentUserId is following targetUserId
  /// 
  /// [currentUserId] - The user to check
  /// [targetUserId] - The user being checked
  /// Returns true if following, false otherwise
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      if (currentUserId == targetUserId) {
        return false;
      }

      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final data = userDoc.data();
      final following = (data?['following'] as List<dynamic>?) ?? [];
      
      return following.contains(targetUserId);
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.isFollowing');
      return false;
    }
  }

  /// Get followers list for a user with pagination
  /// 
  /// [userId] - The user whose followers to fetch
  /// [limit] - Maximum number of followers to fetch per page (default: 20)
  /// [lastIndex] - Last index for pagination (null for first page)
  /// Returns a map with 'followers' list and 'nextIndex' for next page
  Future<Map<String, dynamic>> getFollowersPaginated(
    String userId, {
    int limit = 20,
    int? lastIndex,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      final followerIds = (data?['followers'] as List<dynamic>?) ?? [];

      if (followerIds.isEmpty) {
        return {
          'followers': <Map<String, dynamic>>[],
          'nextIndex': null,
          'hasMore': false,
        };
      }

      // Get paginated follower IDs
      final startIndex = lastIndex ?? 0;
      final endIndex = (startIndex + limit).clamp(0, followerIds.length);
      final paginatedIds = followerIds.sublist(startIndex, endIndex);

      // Fetch user data for each follower ID
      final followers = <Map<String, dynamic>>[];
      for (var followerId in paginatedIds) {
        try {
          final followerDoc = await _firestore.collection('users').doc(followerId.toString()).get();
          if (followerDoc.exists) {
            final followerData = followerDoc.data() ?? {};
            followers.add({
              'userId': followerId.toString(),
              'name': followerData['displayName'] ?? followerData['name'] ?? 'Unknown User',
              'username': followerData['username'] ?? '@${followerId.toString().substring(0, 8)}',
              'image': followerData['photoUrl'] ?? followerData['profilePhotoUrl'] ?? '',
              'photoUrl': followerData['photoUrl'] ?? followerData['profilePhotoUrl'],
            });
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error fetching follower $followerId: $e');
          }
        }
      }

      final hasMore = endIndex < followerIds.length;

      return {
        'followers': followers,
        'nextIndex': hasMore ? endIndex : null,
        'hasMore': hasMore,
      };
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getFollowersPaginated');
      rethrow;
    }
  }

  /// Get following list for a user with pagination
  /// 
  /// [userId] - The user whose following to fetch
  /// [limit] - Maximum number of following to fetch per page (default: 20)
  /// [lastIndex] - Last index for pagination (null for first page)
  /// Returns a map with 'following' list and 'nextIndex' for next page
  Future<Map<String, dynamic>> getFollowingPaginated(
    String userId, {
    int limit = 20,
    int? lastIndex,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [FirestoreService.getFollowingPaginated] Called');
        print('   userId: $userId');
        print('   limit: $limit');
        print('   lastIndex: $lastIndex');
      }
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (kDebugMode) {
        print('📄 [FirestoreService.getFollowingPaginated] User document exists: ${userDoc.exists}');
      }
      
      if (!userDoc.exists) {
        if (kDebugMode) {
          print('⚠️ [FirestoreService.getFollowingPaginated] User document does not exist');
        }
        return {
          'following': <Map<String, dynamic>>[],
          'nextIndex': null,
          'hasMore': false,
        };
      }
      
      final data = userDoc.data();
      
      if (kDebugMode) {
        print('📊 [FirestoreService.getFollowingPaginated] User document data keys: ${data?.keys}');
      }
      
      final followingIds = (data?['following'] as List<dynamic>?) ?? [];

      if (kDebugMode) {
        print('👥 [FirestoreService.getFollowingPaginated] Following IDs:');
        print('   followingIds type: ${followingIds.runtimeType}');
        print('   followingIds length: ${followingIds.length}');
        if (followingIds.isNotEmpty) {
          print('   First 3 IDs: ${followingIds.take(3).toList()}');
        }
      }

      if (followingIds.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ [FirestoreService.getFollowingPaginated] No following IDs found, returning empty list');
        }
        return {
          'following': <Map<String, dynamic>>[],
          'nextIndex': null,
          'hasMore': false,
        };
      }

      // Get paginated following IDs
      final startIndex = lastIndex ?? 0;
      final endIndex = (startIndex + limit).clamp(0, followingIds.length);
      final paginatedIds = followingIds.sublist(startIndex, endIndex);

      if (kDebugMode) {
        print('📑 [FirestoreService.getFollowingPaginated] Pagination:');
        print('   startIndex: $startIndex');
        print('   endIndex: $endIndex');
        print('   paginatedIds.length: ${paginatedIds.length}');
        print('   paginatedIds: $paginatedIds');
      }

      // Fetch user data for each following ID
      final following = <Map<String, dynamic>>[];
      for (var followingId in paginatedIds) {
        try {
          if (kDebugMode) {
            print('   🔄 Fetching user data for followingId: $followingId');
          }
          
          final followingDoc = await _firestore.collection('users').doc(followingId.toString()).get();
          
          if (kDebugMode) {
            print('      Document exists: ${followingDoc.exists}');
          }
          
          if (followingDoc.exists) {
            final followingData = followingDoc.data() ?? {};
            
            if (kDebugMode) {
              print('      Data keys: ${followingData.keys}');
              print('      displayName: ${followingData['displayName']}');
              print('      name: ${followingData['name']}');
              print('      username: ${followingData['username']}');
              print('      photoUrl: ${followingData['photoUrl']}');
              print('      profilePhotoUrl: ${followingData['profilePhotoUrl']}');
            }
            
            final userData = {
              'userId': followingId.toString(),
              'name': followingData['displayName'] ?? followingData['name'] ?? 'Unknown User',
              'username': followingData['username'] ?? '@${followingId.toString().substring(0, 8)}',
              'image': followingData['photoUrl'] ?? followingData['profilePhotoUrl'] ?? '',
              'photoUrl': followingData['photoUrl'] ?? followingData['profilePhotoUrl'],
            };
            
            if (kDebugMode) {
              print('      ✅ Created user data: $userData');
            }
            
            following.add(userData);
          } else {
            if (kDebugMode) {
              print('      ⚠️ User document does not exist for followingId: $followingId');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('      ❌ Error fetching following $followingId: $e');
          }
        }
      }

      final hasMore = endIndex < followingIds.length;

      if (kDebugMode) {
        print('✅ [FirestoreService.getFollowingPaginated] Returning result:');
        print('   following.length: ${following.length}');
        print('   nextIndex: ${hasMore ? endIndex : null}');
        print('   hasMore: $hasMore');
        if (following.isNotEmpty) {
          print('   First following item: ${following.first}');
        }
      }

      return {
        'following': following,
        'nextIndex': hasMore ? endIndex : null,
        'hasMore': hasMore,
      };
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [FirestoreService.getFollowingPaginated] Exception: $e');
        print('   Stack trace: $stackTrace');
      }
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getFollowingPaginated');
      rethrow;
    }
  }

  /// Get follower count for a user
  /// 
  /// [userId] - The user whose follower count to fetch
  /// Returns the follower count (0 if not found or negative)
  Future<int> getFollowerCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      // Try to get from cached count first
      final cachedCount = data?['followersCount'] as int?;
      if (cachedCount != null) {
        return cachedCount.clamp(0, double.infinity).toInt(); // Ensure non-negative
      }

      // Fallback: count array length
      final followers = (data?['followers'] as List<dynamic>?) ?? [];
      return followers.length.clamp(0, double.infinity).toInt(); // Ensure non-negative
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getFollowerCount');
      return 0;
    }
  }

  /// Get following count for a user
  /// 
  /// [userId] - The user whose following count to fetch
  /// Returns the following count (0 if not found or negative)
  Future<int> getFollowingCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      // Try to get from cached count first
      final cachedCount = data?['followingCount'] as int?;
      if (cachedCount != null) {
        return cachedCount.clamp(0, double.infinity).toInt(); // Ensure non-negative
      }

      // Fallback: count array length
      final following = (data?['following'] as List<dynamic>?) ?? [];
      return following.length.clamp(0, double.infinity).toInt(); // Ensure non-negative
    } catch (e, stackTrace) {
      final exception = ExceptionMapper.mapToAppException(e, stackTrace);
      _errorHandler.handleError(exception, stackTrace, 'FirestoreService.getFollowingCount');
      return 0;
    }
  }
}

