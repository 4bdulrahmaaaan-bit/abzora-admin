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
    this.backgroundColor,
    this.usePremiumIntentAnimation = false,
  });

  final bool isSelected;
  final bool isLoading;
  final Future<void> Function() onTap;
  final double size;
  final double iconSize;
  final Color selectedColor;
  final Color unselectedColor;
  final Color? backgroundColor;
  final bool usePremiumIntentAnimation;

  @override
  State<AnimatedWishlistButton> createState() => _AnimatedWishlistButtonState();
}

class _AnimatedWishlistButtonState extends State<AnimatedWishlistButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _scale;
  late final Animation<double> _pulseScale;
  bool _intentActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.usePremiumIntentAnimation ? 200 : 280,
      ),
    );
    _scale = widget.usePremiumIntentAnimation
        ? TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 1,
                end: 1.2,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
              weight: 58,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 1.2,
                end: 1,
              ).chain(CurveTween(curve: Curves.easeInOut)),
              weight: 42,
            ),
          ]).animate(_controller)
        : TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 1,
                end: 1.3,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
              weight: 45,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 1.3,
                end: 0.98,
              ).chain(CurveTween(curve: Curves.easeInOut)),
              weight: 20,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 0.98,
                end: 1,
              ).chain(CurveTween(curve: Curves.easeOutBack)),
              weight: 35,
            ),
          ]).animate(_controller);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.98,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(covariant AnimatedWishlistButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSelected && widget.isSelected) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.isLoading) {
      return;
    }
    HapticFeedback.selectionClick();
    if (widget.usePremiumIntentAnimation) {
      setState(() => _intentActive = true);
    }
    _controller.forward(from: 0);
    if (widget.usePremiumIntentAnimation) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await widget.onTap();
    if (mounted && widget.usePremiumIntentAnimation) {
      setState(() => _intentActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intentProgress = _controller.value;
    final showIntentGold = widget.usePremiumIntentAnimation && _intentActive;
    final iconColor = widget.isSelected
        ? widget.selectedColor
        : showIntentGold
        ? Color.lerp(
            widget.unselectedColor,
            const Color(0xFFC6A769),
            Curves.easeOut.transform(intentProgress),
          )
        : widget.unselectedColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        customBorder: const CircleBorder(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_scale, _pulseScale]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value * _pulseScale.value,
              child: child,
            );
          },
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.usePremiumIntentAnimation && _intentActive)
                  IgnorePointer(
                    child: Transform.scale(
                      scale: 0.8 + (intentProgress * 0.8),
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC6A769).withValues(
                                alpha: (0.22 * (1 - intentProgress)).clamp(
                                  0,
                                  1,
                                ),
                              ),
                              blurRadius: 14 + (10 * intentProgress),
                              spreadRadius: 1 + (4 * intentProgress),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (widget.backgroundColor != null)
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: Icon(
                        widget.isSelected
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey<bool>(widget.isSelected),
                        color: iconColor,
                        size: widget.iconSize,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
