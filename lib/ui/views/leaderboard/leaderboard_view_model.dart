import 'package:flutter/foundation.dart';

import '../../../core/di/locator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/viewmodels/base_view_model.dart';

/// Badge labels by rank (top contributors/influencers).
String _badgeForRank(int rank) {
  switch (rank) {
    case 1:
      return 'Top Rumour Spotter';
    case 2:
      return 'Media Master';
    case 3:
      return 'Crowd Favourite';
    default:
      return 'Top Contributor';
  }
}

class LeaderboardViewModel extends BaseViewModel {
  final FirestoreService _firestore = locator<FirestoreService>();

  List<Map<String, dynamic>> _leaders = [];
  List<Map<String, dynamic>> get leaders => _leaders;

  static const int leaderboardLimit = 20;

  Future<void> loadLeaderboard() async {
    if (kDebugMode) {
      print('[Leaderboard] loadLeaderboard() started');
    }
    setBusy(true);
    try {
      final list = await _firestore.getLeaderboard(limit: leaderboardLimit);
      if (kDebugMode) {
        print('[Leaderboard] loadLeaderboard() got ${list.length} users from Firestore');
      }
      _leaders = [];
      for (var i = 0; i < list.length; i++) {
        _leaders.add({
          'rank': i + 1,
          'name': list[i]['displayName'] as String? ?? 'User',
          'userId': list[i]['userId'] as String?,
          'photoUrl': list[i]['photoUrl'] as String?,
          'badge': _badgeForRank(i + 1),
          'score': list[i]['leaderboardScore'] as double? ?? 0.0,
          'attendedFestivalsCount': list[i]['attendedFestivalsCount'] as int? ?? 0,
          'postCount': list[i]['postCount'] as int? ?? 0,
        });
      }
      if (kDebugMode) {
        print('[Leaderboard] loadLeaderboard() built _leaders.length=${_leaders.length}');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [Leaderboard] loadLeaderboard() error: $e');
        print('❌ [Leaderboard] stackTrace: $stackTrace');
      }
      _leaders = [];
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}
