import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../models/festival_navigation_gate_outcome.dart';
import '../utils/snackbar_util.dart';

/// Signup-with-phone route name — keep aligned with [AppRoutes.signup] in app_router.dart.
const String festivalGateSignupRoute = '/signup';

/// Shared outcome handling after [ProfileReadinessService.evaluateFestivalNavbarGate].
Future<void> applyFestivalNavbarGateOutcome(
  BuildContext context,
  FestivalNavigationGateOutcome outcome, {
  required VoidCallback onAuthenticatedNavigate,
}) async {
  if (!context.mounted) return;

  switch (outcome) {
    case FestivalNavigationGateOutcome.authenticatedPhoneReady:
      onAuthenticatedNavigate();
      return;
    case FestivalNavigationGateOutcome.needsPhoneEnrollment:
      await Navigator.of(context).pushNamed(
        festivalGateSignupRoute,
        arguments: true,
      );
      return;
    case FestivalNavigationGateOutcome.firestoreUnavailable:
      SnackbarUtil.showErrorSnackBar(
        context,
        AppStrings.couldNotLoadProfileTryAgain,
      );
      return;
    case FestivalNavigationGateOutcome.authTransientlyNull:
      SnackbarUtil.showWarningSnackBar(
        context,
        AppStrings.sessionNotReadyYetTryAgain,
      );
      return;
  }
}
