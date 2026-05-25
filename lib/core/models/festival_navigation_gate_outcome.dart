/// Result of [ProfileReadinessService.evaluateFestivalNavbarGate].
enum FestivalNavigationGateOutcome {
  /// Phone confirmed (cache or Firestore). Safe to navigate to NavBar / main app hub.
  authenticatedPhoneReady,

  /// Authoritative read says user needs phone/signup verification (signup route with fromFestival).
  needsPhoneEnrollment,

  /// Firestore read threw (timeout / unavailable). Do **not** treat as missing phone — show retry.
  firestoreUnavailable,

  /// Auth user still null after stabilization + bounded retry — show retry/wait UX.
  authTransientlyNull,
}
