import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/api/festival_api_service.dart';
import '../../../core/constants/app_strings.dart';
import '../homeview/post_model.dart';
import '../festival/festival_model.dart';

/// ViewModel for editing a global feed post and optionally adding it to a festival.
/// Uses FestivalProvider list when available; falls back to API when provider list is empty.
class EditPostViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final FestivalApiService _festivalApiService = locator<FestivalApiService>();

  TextEditingController? contentController;
  TextEditingController? postUrlController;

  PostModel? _post;
  String? _collectionName; // null = global feed (festivalrumorglobalfeed)
  List<FestivalModel> _festivals = [];
  FestivalModel? _selectedFestival;
  bool _festivalsLoading = false;

  /// Callback to update FestivalProvider when we load festivals from API (so list is cached).
  void Function(List<FestivalModel>)? onFestivalsLoaded;

  PostModel? get post => _post;
  List<FestivalModel> get festivals => _festivals;
  FestivalModel? get selectedFestival => _selectedFestival;
  bool get festivalsLoading => _festivalsLoading;
  String? _successMessage;
  String? get successMessage => _successMessage;

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  bool get canSave =>
      (contentController?.text.trim().isNotEmpty ?? false) ||
      (postUrlController?.text.trim().isNotEmpty ?? false) ||
      _selectedFestival != null;

  /// Initialize with the post to edit. [collectionName] null = global feed.
  /// [festivals] from FestivalProvider.allFestivals; if null or empty, loads from API and notifies.
  void initialize(PostModel post,
      {String? collectionName, List<FestivalModel>? festivals}) {
    _post = post;
    _collectionName = collectionName;
    contentController?.dispose();
    postUrlController?.dispose();
    contentController = TextEditingController(text: post.content);
    postUrlController = TextEditingController(text: post.postUrl ?? '');
    if (festivals != null && festivals.isNotEmpty) {
      _festivals = List.from(festivals);
      _festivalsLoading = false;
      notifyListeners();
      return;
    }
    _loadFestivalsFromApi();
    notifyListeners();
  }

  Future<void> _loadFestivalsFromApi() async {
    if (_festivalsLoading) return;
    _festivalsLoading = true;
    notifyListeners();
    try {
      final response = await _festivalApiService.getFestivals();
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        _festivals = response.data!
            .map((json) => FestivalModel.fromApiJson(json))
            .where((f) => f.title.isNotEmpty)
            .toList();
        onFestivalsLoaded?.call(_festivals);
        if (kDebugMode) {
          print('EditPost: loaded ${_festivals.length} festivals from API');
        }
      }
    } catch (e) {
      if (kDebugMode) print('EditPost: failed to load festivals: $e');
    } finally {
      _festivalsLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    contentController?.dispose();
    postUrlController?.dispose();
    super.dispose();
  }

  void selectFestival(FestivalModel? festival) {
    _selectedFestival = festival;
    notifyListeners();
  }

  /// Save: update post in global feed; if a festival is selected, add post to that festival's rumour collection.
  Future<void> save() async {
    final p = _post;
    if (p == null || p.postId == null) return;

    String content = contentController?.text.trim() ?? '';
    String postUrl = postUrlController?.text.trim() ?? '';
    if (content.isEmpty) content = p.content;
    final postUrlOrNull = postUrl.isEmpty ? (p.postUrl) : postUrl;

    await handleAsync(() async {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to edit posts');
      }
      if (p.userId != currentUser.uid) {
        throw Exception('You can only edit your own posts');
      }

      final targetCollection =
          _collectionName ?? FirestoreService.defaultPostsCollection;

      // Fetch link preview when URL is present
      String? linkPreviewImageUrl;
      String? linkPreviewTitle;
      if (postUrlOrNull != null && postUrlOrNull.isNotEmpty) {
        try {
          String urlString = postUrlOrNull.trim();
          if (!urlString.contains(RegExp(r'^https?://', caseSensitive: false))) {
            urlString = 'https://$urlString';
          }
          final metadata = await MetadataFetch.extract(urlString)
              .timeout(const Duration(seconds: 6));
          if (metadata != null) {
            if (metadata.image != null && metadata.image!.trim().isNotEmpty) {
              final img = metadata.image!.trim();
              if (img.startsWith('http://') || img.startsWith('https://')) {
                linkPreviewImageUrl = img;
              }
            }
            if (metadata.title != null && metadata.title!.trim().isNotEmpty) {
              linkPreviewTitle = metadata.title!.trim();
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('EditPost link preview fetch failed: $e');
          }
        }
      }

      // 1) Update post in global feed (or current collection)
      final updates = <String, dynamic>{
        'content': content.isNotEmpty
            ? content
            : (p.allMediaPaths.isNotEmpty
                ? '📸 Shared media'
                : (postUrlOrNull != null ? '🔗 Shared a link' : p.content)),
        'postUrl': postUrlOrNull,
        if (linkPreviewImageUrl != null) 'linkPreviewImageUrl': linkPreviewImageUrl,
        if (linkPreviewTitle != null) 'linkPreviewTitle': linkPreviewTitle,
      };
      await _firestoreService.updatePost(
        p.postId!,
        updates,
        collectionName: targetCollection,
      );

      // 2) If user selected a festival, add this post to that festival's rumour collection
      if (_selectedFestival != null) {
        final festivalCollectionName =
            FirestoreService.getFestivalCollectionName(
          _selectedFestival!.id,
          _selectedFestival!.title,
        );
        final postData = {
          'username': p.username,
          'content': updates['content'] as String,
          'imagePath': p.imagePath,
          'likes': 0,
          'comments': 0,
          'status': AppStrings.live,
          'isVideo': p.isVideo,
          'mediaPaths': p.mediaPaths,
          'isVideoList': p.isVideoList,
          'createdAt': DateTime.now(),
          'userPhotoUrl': p.userPhotoUrl,
          'userId': p.userId,
          'postUrl': postUrlOrNull,
          if (linkPreviewImageUrl != null) 'linkPreviewImageUrl': linkPreviewImageUrl,
          if (linkPreviewTitle != null) 'linkPreviewTitle': linkPreviewTitle,
        };
        await _firestoreService.savePost(
          postData,
          collectionName: festivalCollectionName,
          mediaCount: 1,
          skipUserPostCountIncrement: true,
        );
        if (kDebugMode) {
          print(
              'EditPost: added post to festival ${_selectedFestival!.title} ($festivalCollectionName)');
        }
      }

      _successMessage = AppStrings.dataUpdated;
      notifyListeners();
    }, errorMessage: 'Failed to save changes. Please try again.');
  }
}
