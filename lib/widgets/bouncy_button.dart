import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'abzio_motion.dart';

class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleLowerBound;

  const BouncyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleLowerBound = 0.94,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AbzioMotion.fast,
      reverseDuration: AbzioMotion.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleLowerBound).animate(
      CurvedAnimation(parent: _controller, curve: AbzioMotion.curve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) {
      return;
    }
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) {
      return;
    }
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed == null ? null : _onTapDown,
      onTapUp: widget.onPressed == null ? null : _onTapUp,
      onTapCancel: widget.onPressed == null ? null : _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
