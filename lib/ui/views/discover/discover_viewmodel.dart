import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/api/festival_api_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../festival/festival_model.dart';

class DiscoverViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final NavigationService _navigationService = locator<NavigationService>();
  final NetworkService _networkService = locator<NetworkService>();
  final FestivalApiService _festivalApiService = locator<FestivalApiService>();
  final GeocodingService _geocodingService = locator<GeocodingService>();

  String selected = AppStrings.live;
  bool _isFavorited = false;
  bool _isLoadingFavorite = false; // Prevent multiple simultaneous loads
  bool _hasLoadedFavorite = false; // Track if we've already loaded favorite status
  String searchQuery = ''; // Search query
  late FocusNode searchFocusNode; // Search field focus node
  final TextEditingController searchController = TextEditingController();

  final List<FestivalModel> _searchResults = []; // API search results
  bool _isSearching = false;
  String? _searchError;
  Timer? _searchDebounce;

  bool get isFavorited => _isFavorited;
  String get currentSearchQuery => searchQuery;
  List<FestivalModel> get filteredFestivals => _searchResults;
  bool get hasSearchResults => searchQuery.isNotEmpty && _searchResults.isNotEmpty;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  DiscoverViewModel() {
    searchFocusNode = FocusNode();
  }

  @override
  void onDispose() {
    _searchDebounce?.cancel();
    searchFocusNode.dispose();
    searchController.dispose();
    super.onDispose();
  }

  void select(String category) {
    selected = category;
    notifyListeners();
  }

  /// Load favorite status for the current festival from Firebase
  /// Checks internet connection and shows appropriate snackbars
  Future<void> loadFavoriteStatus(BuildContext context) async {
    // CRITICAL: Check flags FIRST to prevent multiple calls
    if (_hasLoadedFavorite || _isLoadingFavorite) {
      if (kDebugMode) {
        print('⏳ Favorite status already loaded or loading, skipping duplicate call...');
      }
      return;
    }

    _isLoadingFavorite = true;
    final userId = _authService.userUid;
    if (userId == null) {
      if (kDebugMode) {
        print('⚠️ User not logged in, cannot load favorite status');
      }
      _isFavorited = false;
      notifyListeners();
      return;
    }

    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;
    
    if (selectedFestival == null) {
      _isFavorited = false;
      notifyListeners();
      return;
    }

    // Check internet connection first
    bool hasInternet = false;
    try {
      hasInternet = await _networkService.hasInternetConnection().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking internet connection: $e');
      }
      hasInternet = false;
    }

    // If no internet, show snackbar and set default state
    if (!hasInternet) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Cannot load favorite status.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      _isFavorited = false;
      _hasLoadedFavorite = true; // Mark as attempted
      _isLoadingFavorite = false;
      notifyListeners();
      return;
    }

    try {
      final isFavorited = await _firestoreService.isFestivalFavorited(
        userId,
        selectedFestival.id,
      );
      _isFavorited = isFavorited;
      _hasLoadedFavorite = true; // Mark as loaded
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Loaded favorite status for festival ${selectedFestival.id}: $isFavorited');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading favorite status: $e');
      }
      _isFavorited = false;
      _hasLoadedFavorite = true; // Mark as attempted even on error
      notifyListeners();
      
      // Show error snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load favorite status: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isLoadingFavorite = false;
    }
  }

  /// Toggle favorite status and save to Firebase
  /// Checks internet connection and prevents duplicate additions
  Future<void> toggleFavorite(BuildContext context) async {
    final userId = _authService.userUid;
    if (userId == null) {
      if (kDebugMode) {
        print('⚠️ User not logged in, cannot toggle favorite');
      }
      return;
    }

    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;
    
    if (selectedFestival == null) {
      if (kDebugMode) {
        print('⚠️ No festival selected, cannot toggle favorite');
      }
      return;
    }

    // Check internet connection first
    bool hasInternet = false;
    try {
      hasInternet = await _networkService.hasInternetConnection().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking internet connection: $e');
      }
      hasInternet = false;
    }

    // If no internet, show snackbar and return
    if (!hasInternet) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Cannot update favorite status.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final oldFavoriteStatus = _isFavorited;
    final newFavoriteStatus = !_isFavorited;

    try {
      if (newFavoriteStatus) {
        // Add to favorites with full festival data so profile can read from Firebase
        await _firestoreService.addFavoriteFestival(userId, selectedFestival.toMap());
      } else {
        // Remove from favorites
        await _firestoreService.removeFavoriteFestival(userId, selectedFestival.id);
      }

      _isFavorited = newFavoriteStatus;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ${newFavoriteStatus ? "Added" : "Removed"} festival ${selectedFestival.id} ${newFavoriteStatus ? "to" : "from"} favorites');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling favorite: $e');
      }
      // Revert the UI state on error
      _isFavorited = oldFavoriteStatus;
      notifyListeners();
      rethrow;
    }
  }

  void goToRumors(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.rumors,
    );
  }

  /// Navigate to chat rooms - creates public chat room if it doesn't exist
  Future<void> goToChatRooms(BuildContext context) async {
    // Get selected festival from provider
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;

    if (selectedFestival == null) {
      if (kDebugMode) {
        print('⚠️ No festival selected, cannot create chat room');
      }
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a festival first'),
        ),
      );
      return;
    }

    // Navigate immediately for instant response
    _navigationService.navigateTo(
      AppRoutes.chatRoom,
      // Don't pass chatRoomId - let user select from list
    );

    // Create chat room in background (non-blocking)
    // This allows the screen to open instantly while chat room is being created
    _ensureChatRoomExists(selectedFestival).catchError((e) {
      if (kDebugMode) {
        print('❌ Error creating chat room in background: $e');
      }
      // Error is handled silently - user can still use the chat screen
    });
  }

  /// Ensure chat room exists - runs in background after navigation
  Future<void> _ensureChatRoomExists(FestivalModel selectedFestival) async {
    try {
      // Generate chat room ID
      final chatRoomId = FirestoreService.getFestivalChatRoomId(
        selectedFestival.id,
        selectedFestival.title,
      );

      if (kDebugMode) {
        print('🎪 Checking chat room: $chatRoomId');
      }

      // Check if chat room exists
      final exists = await _firestoreService.checkChatRoomExists(chatRoomId);

      if (!exists) {
        if (kDebugMode) {
          print('📝 Chat room does not exist, creating new one...');
        }

        // Get all user IDs with appIdentifier = 'festivalrumor'
        final memberIds = await _firestoreService.getAllFestivalRumorUserIds();

        if (memberIds.isEmpty) {
          if (kDebugMode) {
            print('⚠️ No users found with appIdentifier=festivalrumor');
          }
        }

        // Create the chat room
        await _firestoreService.createPublicChatRoom(
          chatRoomId: chatRoomId,
          festivalName: selectedFestival.title,
          festivalId: selectedFestival.id,
          memberIds: memberIds,
        );

        if (kDebugMode) {
          print('✅ Created public chat room: $chatRoomId');
        }
      } else {
        if (kDebugMode) {
          print('✅ Chat room already exists: $chatRoomId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring chat room exists: $e');
      }
      rethrow;
    }
  }

  void onBottomNavTap(int index) {
    // Navigate between tabs
  }

  // Search methods (API-based, debounced)
  void setSearchQuery(String query, BuildContext context) {
    searchQuery = query;
    if (query.isEmpty) {
      _searchResults.clear();
      _isSearching = false;
      _searchError = null;
      _searchDebounce?.cancel();
      _searchDebounce = null;
      notifyListeners();
      return;
    }
    _searchError = null;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
    notifyListeners();
  }

  Future<void> _performSearch(String query) async {
    if (query != searchQuery || isDisposed) return;
    _isSearching = true;
    _searchError = null;
    notifyListeners();
    try {
      final response = await _festivalApiService.getFestivals(search: query);
      if (query != searchQuery || isDisposed) return;
      if (response.success && response.data != null) {
        final parsed = <FestivalModel>[];
        for (var festivalData in response.data!) {
          try {
            parsed.add(FestivalModel.fromApiJson(festivalData));
          } catch (e) {
            if (kDebugMode) {
              print('🎪 [DiscoverViewModel] Error parsing search festival: $e');
            }
          }
        }
        final withLocation = await _convertCoordinatesForFestivalList(parsed);
        if (query != searchQuery || isDisposed) return;
        _searchResults
          ..clear()
          ..addAll(withLocation);
        _searchError = null;
      } else {
        _searchResults.clear();
        if (query == searchQuery && !isDisposed) {
          _searchError = response.message ??
              'Something went wrong. Please try again.';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎪 [DiscoverViewModel] Search API error: $e');
      }
      if (!isDisposed && query == searchQuery) {
        _searchResults.clear();
        _searchError = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Something went wrong. Please check your connection and try again.';
      }
    } finally {
      if (!isDisposed) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<List<FestivalModel>> _convertCoordinatesForFestivalList(
    List<FestivalModel> list,
  ) async {
    final updated = <FestivalModel>[];
    for (var festival in list) {
      if (festival.latitude != null && festival.longitude != null) {
        try {
          final location = await _geocodingService.getLocationFromCoordinates(
            festival.latitude,
            festival.longitude,
          );
          updated.add(festival.copyWith(location: location));
        } catch (e) {
          if (kDebugMode) {
            print(
              'Error converting coordinates for festival ${festival.id}: $e',
            );
          }
          updated.add(festival);
        }
      } else {
        updated.add(festival);
      }
    }
    return updated;
  }

  void retrySearch() {
    if (searchQuery.isEmpty) return;
    _searchError = null;
    _performSearch(searchQuery);
  }

  /// Select a festival from search results
  void selectFestival(BuildContext context, FestivalModel festival) {
    if (kDebugMode) {
      print('🔍 [Discover] selectFestival: "${festival.title}" id=${festival.id}');
    }
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.setSelectedFestival(festival);
    clearSearch(context);
    unfocusSearch();
    if (kDebugMode) {
      print('🔍 [Discover] selectFestival done, provider updated');
    }
  }

  void clearSearch(BuildContext context) {
    searchQuery = '';
    searchController.clear();
    _searchResults.clear();
    _isSearching = false;
    _searchError = null;
    _searchDebounce?.cancel();
    _searchDebounce = null;
    notifyListeners();
  }

  void unfocusSearch() {
    if (isDisposed) return;
    
    try {
      searchFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) print('Error unfocusing search: $e');
    }
  }
}
