import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_assets.dart';
import '../homeview/post_model.dart';

class CreatePostViewModel extends BaseViewModel {
  final ImagePicker _picker = ImagePicker();
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final TextEditingController postTextController = TextEditingController();

  // Store selected media files (images and videos)
  List<XFile> selectedMedia = [];
  List<bool> isVideo = []; // Track which items are videos

  String? _collectionName; // Festival collection name (if creating post in rumors context)
  
  String? get collectionName => _collectionName;
  
  /// Initialize with collection name (called when navigating from rumors)
  void initialize(String? collectionName) {
    _collectionName = collectionName;
    if (kDebugMode && collectionName != null) {
      print('🎪 CreatePostViewModel initialized with collection: $collectionName');
    }
  }

  /// Getter to check if media is selected
  bool get hasMedia => selectedMedia.isNotEmpty;

  /// Getter to check if post is valid (has text or media)
  bool get canPost => postTextController.text.trim().isNotEmpty || hasMedia;

  @override
  void dispose() {
    postTextController.dispose();
    super.dispose();
  }

  /// Pick images from gallery (multiple selection)
  Future<void> pickImages() async {
    await handleAsync(() async {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        selectedMedia.addAll(pickedFiles);
        isVideo.addAll(List.filled(pickedFiles.length, false));
        notifyListeners();
      }
    }, 
    errorMessage: AppStrings.failtouploadimage,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }

  /// Pick video from gallery
  Future<void> pickVideo() async {
    await handleAsync(() async {
      final XFile? pickedVideo = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedVideo != null) {
        selectedMedia.add(pickedVideo);
        isVideo.add(true);
        notifyListeners();
      }
    }, 
    errorMessage: AppStrings.failedToUploadVideo,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }

  /// Remove media at index
  void removeMedia(int index) {
    if (index >= 0 && index < selectedMedia.length) {
      selectedMedia.removeAt(index);
      isVideo.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all media
  void clearAllMedia() {
    selectedMedia.clear();
    isVideo.clear();
    notifyListeners();
  }

  /// Upload post media (image or video) to Firebase Storage
  /// Returns the download URL, or null if upload fails
  Future<String?> _uploadPostMedia(File mediaFile, bool isVideo) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('❌ No user logged in, cannot upload media');
        }
        return null;
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch % 10000;
      final extension = isVideo ? 'mp4' : 'jpg';
      final filename = '${currentUser.uid}_${timestamp}_$random.$extension';
      
      // Create storage reference
      final folder = isVideo ? 'post_videos' : 'post_images';
      final ref = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(folder)
          .child(filename);

      // Upload file with metadata
      final metadata = SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        customMetadata: {
          'uploadedBy': currentUser.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putFile(mediaFile, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        print('📤 Media uploaded to Firebase Storage: $downloadUrl');
      }

      return downloadUrl;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error uploading post media: $e');
        print('   StackTrace: $stackTrace');
      }
      // Don't throw - let the caller handle it
      return null;
    }
  }

  /// Upload post and return the created post
  Future<void> uploadPost() async {
    if (!canPost) return;

    await handleAsync(() async {
      // Get post content
      final postContent = postTextController.text.trim();
      
      // Get current user info
      final currentUser = _authService.currentUser;
      String username = _authService.userDisplayName ?? 
                       currentUser?.email?.split('@')[0] ?? 
                       'Unknown User';
      
      // Get user photo URL - prioritize Firestore over Firebase Auth
      // because Firestore has the uploaded profile image
      String? userPhotoUrl;
      if (currentUser != null) {
        try {
          // First try to get from Firestore (where we save the uploaded image)
          final userData = await _firestoreService.getUserData(currentUser.uid);
          if (userData != null) {
            if (userData['photoUrl'] != null && (userData['photoUrl'] as String).isNotEmpty) {
              userPhotoUrl = userData['photoUrl'] as String?;
              if (kDebugMode) {
                print('✅ Got userPhotoUrl from Firestore: $userPhotoUrl');
              }
            } else {
              if (kDebugMode) {
                print('⚠️ Firestore userData exists but photoUrl is null or empty');
              }
            }
          } else {
            if (kDebugMode) {
              print('⚠️ No userData found in Firestore for userId: ${currentUser.uid}');
            }
          }
          
          // If not in Firestore, fallback to Firebase Auth photoURL
          if (userPhotoUrl == null || userPhotoUrl.isEmpty) {
            userPhotoUrl = _authService.userPhotoUrl;
            if (kDebugMode) {
              print('📸 Got userPhotoUrl from Firebase Auth: $userPhotoUrl');
            }
          }
          
          if (kDebugMode) {
            print('🎯 Final userPhotoUrl for post: $userPhotoUrl');
          }
          
          // Update username from Firestore if available
          if (userData != null && userData['displayName'] != null) {
            username = userData['displayName'] as String;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Could not fetch user data from Firestore: $e');
          }
          // Fallback to Firebase Auth photoURL
          userPhotoUrl = _authService.userPhotoUrl;
        }
      } else {
        // Fallback to Firebase Auth photoURL if no current user
        userPhotoUrl = _authService.userPhotoUrl;
      }
      
      // Upload media to Firebase Storage and get URLs
      String imagePath = AppAssets.post; // Default image (for backward compatibility)
      bool isVideoPost = false;
      List<String>? mediaPaths;
      List<bool>? isVideoList;
      
      if (selectedMedia.isNotEmpty) {
        // Upload all media files to Firebase Storage
        mediaPaths = [];
        isVideoList = List<bool>.from(isVideo);
        
        for (int i = 0; i < selectedMedia.length; i++) {
          final media = selectedMedia[i];
          final isVideoItem = isVideo[i];
          
          try {
            // Convert XFile to File for upload
            final file = File(media.path);
            if (!file.existsSync()) {
              if (kDebugMode) {
                print('⚠️ Media file does not exist: ${media.path}');
              }
              continue;
            }
            
            // Upload to Firebase Storage
            final mediaUrl = await _uploadPostMedia(file, isVideoItem);
            if (mediaUrl != null && mediaUrl.isNotEmpty) {
              mediaPaths!.add(mediaUrl);
              if (kDebugMode) {
                print('✅ Uploaded media ${i + 1}/${selectedMedia.length}: $mediaUrl');
              }
            } else {
              if (kDebugMode) {
                print('⚠️ Failed to upload media ${i + 1}, skipping');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ Error uploading media ${i + 1}: $e');
            }
            // Continue with other media files even if one fails
          }
        }
        
        // Use the first uploaded media URL for backward compatibility
        if (mediaPaths != null && mediaPaths!.isNotEmpty) {
          imagePath = mediaPaths![0];
          isVideoPost = isVideo.isNotEmpty && isVideo[0];
        } else {
          // If all uploads failed, use default image
          imagePath = AppAssets.post;
          isVideoPost = false;
          if (kDebugMode) {
            print('⚠️ All media uploads failed, using default image');
          }
        }
      }

      // Prepare post data for Firestore
      final postData = {
        'username': username,
        'content': postContent.isNotEmpty 
            ? postContent 
            : (hasMedia ? (isVideoPost ? "🎥 Shared a video" : "📸 Shared ${selectedMedia.length == 1 ? 'a media' : '${selectedMedia.length} media items'}") : ""),
        'imagePath': imagePath,
        'likes': 0,
        'comments': 0,
        'status': AppStrings.live, // Default to live posts
        'isVideo': isVideoPost,
        'mediaPaths': mediaPaths,
        'isVideoList': isVideoList,
        'createdAt': DateTime.now(), // Will be converted to Timestamp in Firestore
        'userPhotoUrl': userPhotoUrl, // User's profile photo URL
        'userId': currentUser?.uid, // User ID to fetch profile photo if needed
      };

      // Save post to Firestore (use festival collection if in rumors context)
      final postId = await _firestoreService.savePost(
        postData,
        collectionName: _collectionName, // Use festival collection if set
      );

      // Create PostModel with the created post data
      final newPost = PostModel(
        postId: postId,
        username: username,
        timeAgo: "Just now",
        content: postData['content'] as String,
        imagePath: imagePath,
        likes: 0,
        comments: 0,
        status: AppStrings.live,
        isVideo: isVideoPost,
        mediaPaths: mediaPaths,
        isVideoList: isVideoList,
        createdAt: DateTime.now(),
        userPhotoUrl: userPhotoUrl,
        userId: currentUser?.uid,
      );

      // Clear form after successful upload
      postTextController.clear();
      clearAllMedia();

      // Navigate back with the created post as result
      _navigationService.pop<PostModel>(newPost);
    }, 
    errorMessage: AppStrings.failedToUploadPost,
    minimumLoadingDuration: AppDurations.buttonLoadingDuration);
  }
}

