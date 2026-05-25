import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Snackbar utility class following clean architecture principles
/// Provides centralized snackbar management for the application
class SnackbarUtil {
  /// Show a custom snackbar with full customization options
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? textColor,
    SnackBarAction? action,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textColor != null ? TextStyle(color: textColor) : null,
        ),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: behavior,
        action: action,
      ),
    );
  }

  /// Show an error snackbar with predefined styling
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  /// Show a success snackbar with predefined styling
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  /// Show a warning snackbar with predefined styling
  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  /// Show an info snackbar with predefined styling
  static void showInfoSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
    );
  }

  /// Show a development feature snackbar with predefined styling
  static void showDevelopmentSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: AppColors.onPrimary,
      textColor: Colors.white,
      behavior: SnackBarBehavior.floating,
    );
  }

  /// Show a custom snackbar with app theme colors
  static void showThemedSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? textColor,
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: backgroundColor ?? AppColors.onPrimary,
      textColor: textColor ?? Colors.white,
      behavior: SnackBarBehavior.floating,
    );
  }

  /// When only [ScaffoldMessengerState] is available (no [BuildContext]).
  static void showSnackBarMessenger(
    ScaffoldMessengerState? messenger,
    String message, {
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    Color? contentColor,
  }) {
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              contentColor != null ? TextStyle(color: contentColor) : null,
        ),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showErrorSnackBarMessenger(
    ScaffoldMessengerState? messenger,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    showSnackBarMessenger(
      messenger,
      message,
      duration: duration,
      backgroundColor: Colors.red,
      contentColor: Colors.white,
    );
  }
}
