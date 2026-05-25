import 'dart:async';

/// Limits concurrent **network** [VideoPlayerController.initialize] calls in feed lists
/// so decode/bandwidth does not spike when many video cells appear (Phase 5).
final class FeedVideoInitBudget {
  FeedVideoInitBudget._();

  static const int maxConcurrent = 2;
  static int _active = 0;
  static final List<Completer<void>> _queue = [];

  static Future<void> acquire() async {
    while (_active >= maxConcurrent) {
      final c = Completer<void>();
      _queue.add(c);
      await c.future;
    }
    _active++;
  }

  static void release() {
    if (_active <= 0) return;
    _active--;
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    }
  }
}
