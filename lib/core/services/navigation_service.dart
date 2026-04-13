import 'package:flutter/material.dart';

class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Navigate to a new screen
  Future<T?> navigateTo<T extends Object?>(String routeName, {Object? arguments}) async {
    try {
      if (navigatorKey.currentState == null) {
        print('NavigationService: Navigator state is null');
        return null;
      }
      final result = await navigatorKey.currentState!.pushNamed<dynamic>(routeName, arguments: arguments);
      // Cast the result to the expected type
      return result as T?;
    } catch (e) {
      print('NavigationService: Error navigating to $routeName: $e');
      return null;
    }
  }

  /// Navigate to a new screen and replace current
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return navigatorKey.currentState!.pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Navigate to a new screen and clear stack
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil<T>(
      routeName,
      predicate,
      arguments: arguments,
    );
  }

  /// Pop current screen
  void pop<T extends Object?>([T? result]) {
    try {
      if (navigatorKey.currentState == null) {
        print('NavigationService: Navigator state is null');
        return;
      }
      navigatorKey.currentState!.pop<T>(result);
    } catch (e) {
      print('NavigationService: Error popping: $e');
    }
  }

  /// Pop until specific route
  void popUntil(bool Function(Route<dynamic>) predicate) {
    navigatorKey.currentState!.popUntil(predicate);
  }

  /// Check if can pop
  bool get canPop => navigatorKey.currentState!.canPop();

  /// Navigate to home and clear stack
  Future<T?> navigateToHome<T extends Object?>() {
    return pushNamedAndRemoveUntil<T>('/home', (route) => false);
  }

  /// Navigate to login and clear stack
  Future<T?> navigateToLogin<T extends Object?>() {
    return pushNamedAndRemoveUntil<T>('/welcome', (route) => false);
  }
  void showSnackbar(String message, {bool isError = false}) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}




