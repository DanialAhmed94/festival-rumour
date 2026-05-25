/// Swipe-hint Lottie on the festival carousel: at most once per **app process**
/// ([FestivalSwipeHintSession] resets on cold start).
///
/// The carousel uses large initial page indices (see [FestivalViewModel.loadFestivals]),
/// while [PageView] prefetches neighbours — the first mounted child used to steal the hint
/// even when off-center. Consumers must tie the hint to the **centered** page instead.
abstract final class FestivalSwipeHintSession {
  static bool _hintConsumedThisLaunch = false;

  /// Whether this app launch already showed/reserved the swipe hint.
  static bool get hintConsumedForLaunch => _hintConsumedThisLaunch;

  /// Call when the centered slide commits to hosting the swipe hint ([FestivalCard] init).
  static void consumeHintSlotForLaunch() {
    _hintConsumedThisLaunch = true;
  }
}
