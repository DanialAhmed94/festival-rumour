import 'package:flutter/material.dart';

class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothPageRoute({
    required this.page,
    RouteSettings? settings,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    settings: settings,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Use a smooth curve
      var curve = Curves.easeInOut;

      // Apply curved animation
      var curvedAnimation =
      CurvedAnimation(parent: animation, curve: curve);

      // Example: Slide from right + fade
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0), // from right
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 400), // smooth speed
  );
}
