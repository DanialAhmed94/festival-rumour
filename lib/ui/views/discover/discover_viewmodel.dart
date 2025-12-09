import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../festival/festival_model.dart';

class DiscoverViewModel extends BaseViewModel {
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final NavigationService _navigationService = locator<NavigationService>();
  
  String selected = AppStrings.live;
  bool _isFavorited = false;
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

  void toggleFavorite() {
    _isFavorited = !_isFavorited;
    notifyListeners();
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
