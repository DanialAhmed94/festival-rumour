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
import '../../../core/providers/festival_provider.dart';
import '../festival/festival_model.dart';

class DiscoverViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();
  final NavigationService _navigationService = locator<NavigationService>();
  final NetworkService _networkService = locator<NetworkService>();
  
  String selected = AppStrings.live;
  bool _isFavorited = false;
  bool _isLoadingFavorite = false; // Prevent multiple simultaneous loads
  bool _hasLoadedFavorite = false; // Track if we've already loaded favorite status
  String searchQuery = ''; // Search query
  late FocusNode searchFocusNode; // Search field focus node
  final TextEditingController searchController = TextEditingController();
  
  List<FestivalModel> _filteredFestivals = [];

  bool get isFavorited => _isFavorited;
  String get currentSearchQuery => searchQuery;
  List<FestivalModel> get filteredFestivals => _filteredFestivals;
  bool get hasSearchResults => searchQuery.isNotEmpty && _filteredFestivals.isNotEmpty;

  DiscoverViewModel() {
    searchFocusNode = FocusNode();
    // Note: Search query updates will be handled in the view where we have access to context
  }

  @override
  void onDispose() {
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
        // Add to favorites - arrayUnion automatically prevents duplicates
        await _firestoreService.addFavoriteFestival(userId, selectedFestival.id);
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

    try {
      setBusy(true);

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

      // Navigate to chat list view (without chatRoomId argument)
      // This will show the chat list where user can select the chat room
      _navigationService.navigateTo(
        AppRoutes.chatRoom,
        // Don't pass chatRoomId - let user select from list
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error creating/navigating to chat room: $e');
      }
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
    } finally {
      setBusy(false);
    }
  }

  void onBottomNavTap(int index) {
    // Navigate between tabs
  }

  // Search methods
  void setSearchQuery(String query, BuildContext context) {
    searchQuery = query;
    _filterFestivals(context);
    notifyListeners();
  }
  
  /// Filter festivals based on search query using festivals from FestivalProvider
  void _filterFestivals(BuildContext context) {
    if (searchQuery.isEmpty) {
      _filteredFestivals = [];
      return;
    }
    
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final allFestivals = festivalProvider.allFestivals;
    
    final query = searchQuery.toLowerCase().trim();
    _filteredFestivals = allFestivals.where((festival) {
      final title = festival.title.toLowerCase();
      final location = festival.location.toLowerCase();
      return title.contains(query) || location.contains(query);
    }).toList();
    
    // Limit to 10 results for better UX
    if (_filteredFestivals.length > 10) {
      _filteredFestivals = _filteredFestivals.take(10).toList();
    }
  }
  
  /// Select a festival from search results
  void selectFestival(BuildContext context, FestivalModel festival) {
    // Update FestivalProvider
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festivalProvider.setSelectedFestival(festival);
    
    // Clear search
    clearSearch(context);
    
    // Unfocus search field
    unfocusSearch();
    
    if (kDebugMode) {
      print('✅ Selected festival: ${festival.title}');
    }
  }

  void clearSearch(BuildContext context) {
    searchQuery = '';
    searchController.clear();
    _filteredFestivals = [];
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
