import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedWishlistButton extends StatefulWidget {
  const AnimatedWishlistButton({
    super.key,
    required this.isSelected,
    required this.onTap,
    this.isLoading = false,
    this.size = 36,
    this.iconSize = 19,
    this.selectedColor = const Color(0xFFE64553),
    this.unselectedColor = const Color(0xFF2D2D2D),
    this.backgroundColor = const Color(0xF0FFFFFF),
  });

  final bool isSelected;
  final bool isLoading;
  final Future<void> Function() onTap;
  final double size;
  final double iconSize;
  final Color selectedColor;
  final Color unselectedColor;
  final Color backgroundColor;

  @override
  State<AnimatedWishlistButton> createState() => _AnimatedWishlistButtonState();
}

class _AnimatedWishlistButtonState extends State<AnimatedWishlistButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.isLoading) {
      return;
    }
    HapticFeedback.selectionClick();
    _controller.forward(from: 0);
    await widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        customBorder: const CircleBorder(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: child,
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        widget.isSelected
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey<bool>(widget.isSelected),
                        color: widget.isSelected
                            ? widget.selectedColor
                            : widget.unselectedColor,
                        size: widget.iconSize,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
