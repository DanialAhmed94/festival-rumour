import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

class EditPostViewModel extends BaseViewModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final FestivalApiService _festivalApiService = locator<FestivalApiService>();

  TextEditingController? contentController;
  TextEditingController? postUrlController;
  TextEditingController? searchController;

  PostModel? _post;
  String? _collectionName;

  // Festival list state
  List<FestivalModel> _festivals = [];
  FestivalModel? _selectedFestival;
  bool _festivalsLoading = false;
  bool _festivalsLoadingMore = false;
  String? _festivalsError;
  int _currentPage = 0;
  bool _hasMoreFestivals = true;
  bool get hasMoreFestivals => _hasMoreFestivals;

  // Search state
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _isSearching = false;
  List<FestivalModel> _searchResults = [];

  bool get isSearchMode => _searchQuery.isNotEmpty;

  void Function(List<FestivalModel>)? onFestivalsLoaded;

  PostModel? get post => _post;
  List<FestivalModel> get festivals => isSearchMode ? _searchResults : _festivals;
  FestivalModel? get selectedFestival => _selectedFestival;
  bool get festivalsLoading => _festivalsLoading;
  bool get festivalsLoadingMore => _festivalsLoadingMore;
  bool get isSearching => _isSearching;
  String? get festivalsError => _festivalsError;

  String? _successMessage;
  String? get successMessage => _successMessage;

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  bool get canSave =>
      ((contentController?.text.trim().isNotEmpty ?? false) ||
          (postUrlController?.text.trim().isNotEmpty ?? false)) &&
      _selectedFestival != null;

  void initialize(PostModel post,
      {String? collectionName, List<FestivalModel>? festivals}) {
    _post = post;
    _collectionName = collectionName;
    contentController?.dispose();
    postUrlController?.dispose();
    searchController?.dispose();
    contentController = TextEditingController(text: post.content);
    postUrlController = TextEditingController(text: post.postUrl ?? '');
    searchController = TextEditingController();

    if (festivals != null && festivals.isNotEmpty) {
      _festivals = List.from(festivals);
      _festivalsLoading = false;
      _currentPage = 1;
      _hasMoreFestivals = false;
    }
    _scheduleNotify();
    if (_festivals.isEmpty) {
      _loadFestivalsPage(1);
    }
  }

  void _scheduleNotify() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!isDisposed) notifyListeners();
    });
  }

  // --- Pagination ---

  Future<void> _loadFestivalsPage(int page) async {
    if (page == 1) {
      _festivalsLoading = true;
      _festivalsError = null;
    } else {
      _festivalsLoadingMore = true;
    }
    notifyListeners();

    try {
      final response = await _festivalApiService.getFestivalsPage(page);
      if (isDisposed) return;

      if (response.success && response.data != null) {
        final result = response.data!;
        final newFestivals = result.list
            .map((json) => FestivalModel.fromApiJson(json))
            .where((f) => f.title.isNotEmpty)
            .toList();

        if (page == 1) {
          _festivals = newFestivals;
          onFestivalsLoaded?.call(_festivals);
        } else {
          final existingIds = _festivals.map((f) => f.id).toSet();
          final unique = newFestivals.where((f) => !existingIds.contains(f.id));
          _festivals.addAll(unique);
        }
        _currentPage = result.currentPage;
        _hasMoreFestivals = result.hasMore;
        _festivalsError = null;

        if (kDebugMode) {
          print('EditPost: loaded page $page — ${newFestivals.length} festivals (total ${_festivals.length}), currentPage=$_currentPage, lastPage=${result.lastPage}, hasMore=$_hasMoreFestivals');
        }
      } else {
        _festivalsError = response.message ?? 'Failed to load festivals';
      }
    } catch (e) {
      if (isDisposed) return;
      _festivalsError = _userFriendlyError(e);
      if (kDebugMode) print('EditPost: failed to load festivals page $page: $e');
    } finally {
      if (!isDisposed) {
        _festivalsLoading = false;
        _festivalsLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void loadMoreFestivals() {
    if (_festivalsLoadingMore || _festivalsLoading || !hasMoreFestivals || isSearchMode) return;
    _loadFestivalsPage(_currentPage + 1);
  }

  Future<void> retryLoadFestivals() async {
    _festivals.clear();
    _currentPage = 0;
    _hasMoreFestivals = true;
    await _loadFestivalsPage(1);
  }

  // --- Search ---

  void onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _searchQuery = '';
      _searchResults.clear();
      _isSearching = false;
      notifyListeners();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    _searchQuery = query;
    _isSearching = true;
    _festivalsError = null;
    notifyListeners();

    try {
      final response = await _festivalApiService.getFestivals(search: query);
      if (isDisposed) return;

      if (_searchQuery != query) return;

      if (response.success && response.data != null) {
        _searchResults = response.data!
            .map((json) => FestivalModel.fromApiJson(json))
            .where((f) => f.title.isNotEmpty)
            .toList();
        _festivalsError = null;
      } else {
        _searchResults.clear();
        _festivalsError = response.message ?? 'Search failed. Please try again.';
      }
    } catch (e) {
      if (isDisposed) return;
      _searchResults.clear();
      _festivalsError = _userFriendlyError(e);
      if (kDebugMode) print('EditPost: search failed for "$query": $e');
    } finally {
      if (!isDisposed) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    searchController?.clear();
    _searchDebounce?.cancel();
    _searchQuery = '';
    _searchResults.clear();
    _isSearching = false;
    _festivalsError = null;
    notifyListeners();
  }

  // --- Selection ---

  void selectFestival(FestivalModel? festival) {
    _selectedFestival = festival;
    notifyListeners();
  }

  /// Validate and return error message, or null if valid.
  String? validate() {
    if (_selectedFestival == null) {
      return 'Please select a festival before saving.';
    }
    return null;
  }

  // --- Save ---

  Future<void> save() async {
    final p = _post;
    if (p == null || p.postId == null) return;

    final validationError = validate();
    if (validationError != null) {
      _festivalsError = validationError;
      notifyListeners();
      return;
    }

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
          p.sourceCollection ?? _collectionName ?? FirestoreService.defaultPostsCollection;

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

      if (_selectedFestival != null) {
        final festivalCollectionName =
            FirestoreService.getFestivalCollectionName(
          _selectedFestival!.id,
          _selectedFestival!.title,
        );
        await _firestoreService.sharePostToFestival(
          postId: p.postId!,
          postCollection: targetCollection,
          festivalCollectionName: festivalCollectionName,
        );
        if (kDebugMode) {
          print(
              'EditPost: shared post to festival ${_selectedFestival!.title} ($festivalCollectionName)');
        }
      }

      _successMessage = AppStrings.dataUpdated;
      notifyListeners();
    }, errorMessage: 'Failed to save changes. Please try again.');
  }

  // --- Helpers ---

  String _userFriendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (msg.contains('403') || msg.contains('forbidden')) {
      return 'You don\'t have permission to perform this action.';
    }
    if (msg.contains('500') || msg.contains('server')) {
      return 'Server error. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    contentController?.dispose();
    postUrlController?.dispose();
    searchController?.dispose();
    super.dispose();
  }
}
