import 'package:flutter/material.dart';

/// One-shot fade + slide for a newly arrived chat row.
///
/// Used only when the message is flagged as “new”; all other bubbles skip this widget
/// entirely so scrolling history does not create tickers/controllers per row.
class ChatMessageAppearAnimation extends StatefulWidget {
  const ChatMessageAppearAnimation({
    super.key,
    required this.alignEnd,
    required this.child,
  });

  /// Own messages slide from trailing; others from leading.
  final bool alignEnd;

  final Widget child;

  @override
  State<ChatMessageAppearAnimation> createState() =>
      _ChatMessageAppearAnimationState();
}

class _ChatMessageAppearAnimationState extends State<ChatMessageAppearAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  static const Duration _duration = Duration(milliseconds: 320);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    const curve = Curves.easeOutCubic;
    _opacity = CurvedAnimation(parent: _controller, curve: curve);
    _slide =
        Tween<Offset>(
          begin: widget.alignEnd
              ? const Offset(0.06, 0)
              : const Offset(-0.06, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}
