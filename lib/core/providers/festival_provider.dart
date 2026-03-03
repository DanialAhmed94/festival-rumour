import 'package:flutter/foundation.dart';
import '../../ui/views/festival/festival_model.dart';

/// Provider to manage selected festival state globally
/// This allows the selected festival to be accessed from any screen
class FestivalProvider extends ChangeNotifier {
  FestivalModel? _selectedFestival;
  List<FestivalModel> _allFestivals = [];

  /// Get the currently selected festival
  FestivalModel? get selectedFestival => _selectedFestival;

  /// Get all festivals list
  List<FestivalModel> get allFestivals => List.unmodifiable(_allFestivals);

  /// Check if a festival is selected
  bool get hasSelectedFestival => _selectedFestival != null;

  /// Set the selected festival (called when user selects from slider)
  void setSelectedFestival(FestivalModel? festival) {
    if (kDebugMode) {
      print('🎪 [FestivalProvider] setSelectedFestival called: festival=${festival?.title ?? "null"}, id=${festival?.id}, current _selectedFestival?.id=${_selectedFestival?.id}');
    }
    if (_selectedFestival?.id != festival?.id) {
      _selectedFestival = festival;
      notifyListeners();
      if (kDebugMode) {
        print('🎪 [FestivalProvider] selected festival updated, _allFestivals.length=${_allFestivals.length}');
      }
    }
  }

  /// Clear the selected festival
  void clearSelectedFestival() {
    if (_selectedFestival != null) {
      _selectedFestival = null;
      notifyListeners();
      
      if (kDebugMode) {
        print('🎪 Cleared selected festival');
      }
    }
  }

  /// Set all festivals list (for reference)
  void setAllFestivals(List<FestivalModel> festivals) {
    if (kDebugMode) {
      print('🎪 [FestivalProvider] setAllFestivals called: input list length=${festivals.length}, first id=${festivals.isNotEmpty ? festivals.first.id : "n/a"}');
    }
    _allFestivals = List.from(festivals);
    notifyListeners();
    if (kDebugMode) {
      print('🎪 [FestivalProvider] _allFestivals now has ${_allFestivals.length} festivals');
    }
  }

  /// Get festival by ID
  FestivalModel? getFestivalById(int id) {
    try {
      return _allFestivals.firstWhere((festival) => festival.id == id);
    } catch (e) {
      return null;
    }
  }
}
