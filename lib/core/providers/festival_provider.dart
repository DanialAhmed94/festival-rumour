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
    if (_selectedFestival?.id != festival?.id) {
      _selectedFestival = festival;
      notifyListeners();
      
      if (kDebugMode) {
        print('🎪 Selected festival: ${festival?.title ?? 'None'}');
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
    _allFestivals = List.from(festivals);
    notifyListeners();
    
    if (kDebugMode) {
      print('🎪 Updated festivals list: ${festivals.length} festivals');
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
