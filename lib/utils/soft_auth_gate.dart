import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../widgets/tap_scale.dart';

enum AuthPromptStyle { softSheet, fullScreen }

enum AuthPromptTrigger { wishlist, cart, tryOn, orders }

class AuthPromptProductPreview {
  const AuthPromptProductPreview({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;
}

class _AuthPromptCopy {
  const _AuthPromptCopy({
    required this.title,
    required this.subtitle,
    required this.cta,
  });

  final String title;
  final String subtitle;
  final String cta;
}

class SoftAuthGate {
  const SoftAuthGate._();

  static bool _authFlowInProgress = false;
  static _PendingAuthIntent? _pendingIntent;
  static AuthPromptTrigger? get pendingActionType => _pendingIntent?.type;
  static String? get pendingProductId => _pendingIntent?.productId;

  static Future<bool> ensureAuthenticated(
    BuildContext context, {
    required String intentLabel,
    AuthPromptTrigger trigger = AuthPromptTrigger.cart,
    String? productId,
    AuthPromptProductPreview? productPreview,
    AuthPromptStyle promptStyle = AuthPromptStyle.softSheet,
    bool allowSkip = true,
  }) async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    if (auth.isAuthenticated) {
      return true;
    }
    if (_authFlowInProgress) {
      return false;
    }

    _authFlowInProgress = true;
    _pendingIntent = _PendingAuthIntent(type: trigger, productId: productId);
    try {
      while (navigator.mounted && !auth.isAuthenticated) {
        final sheetHostContext = navigator.context;
        final continueToLogin = await showModalBottomSheet<bool>(
          // ignore: use_build_context_synchronously
          context: sheetHostContext,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.38),
          isDismissible: allowSkip,
          enableDrag: allowSkip,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) {
            return _PremiumLoginBottomSheet(
              trigger: trigger,
              productPreview: productPreview,
              allowSkip: allowSkip,
              intentLabel: intentLabel,
              emphasizeIntent: promptStyle == AuthPromptStyle.fullScreen,
            );
          },
        );

        if (!navigator.mounted) {
          return false;
        }
        if (continueToLogin != true) {
          _pendingIntent = null;
          return false;
        }

        await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(
              mode: AbzioAppMode.customer,
              deferredAction: true,
            ),
          ),
        );
      }
      _pendingIntent = null;
      return auth.isAuthenticated;
    } finally {
      _authFlowInProgress = false;
    }
  }
}

class _PendingAuthIntent {
  const _PendingAuthIntent({
    required this.type,
    this.productId,
  });

  final AuthPromptTrigger type;
  final String? productId;
}

class _PremiumLoginBottomSheet extends StatefulWidget {
  const _PremiumLoginBottomSheet({
    required this.trigger,
    required this.productPreview,
    required this.allowSkip,
    required this.intentLabel,
    required this.emphasizeIntent,
  });

  final AuthPromptTrigger trigger;
  final AuthPromptProductPreview? productPreview;
  final bool allowSkip;
  final String intentLabel;
  final bool emphasizeIntent;

  @override
  State<_PremiumLoginBottomSheet> createState() =>
      _PremiumLoginBottomSheetState();
}

class _PremiumLoginBottomSheetState extends State<_PremiumLoginBottomSheet>
    with SingleTickerProviderStateMixin {
  static const _ctaColor = Color(0xFFC6A769);
  late final AnimationController _entranceController;
  late final Animation<double> _translateY;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final curve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _translateY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 28, end: -4),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -4, end: 0),
        weight: 30,
      ),
    ]).animate(curve);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.985, end: 1.012),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.012, end: 1),
        weight: 35,
      ),
    ]).animate(curve);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  _AuthPromptCopy get _copy {
    switch (widget.trigger) {
      case AuthPromptTrigger.wishlist:
        return const _AuthPromptCopy(
          title: 'Save this to your Wishlist',
          subtitle: 'Access it anytime',
          cta: 'Save & Continue',
        );
      case AuthPromptTrigger.cart:
        return const _AuthPromptCopy(
          title: 'Continue to Checkout',
          subtitle: 'Login to complete your purchase',
          cta: 'Continue Securely',
        );
      case AuthPromptTrigger.tryOn:
        return const _AuthPromptCopy(
          title: 'Try Before You Buy',
          subtitle: 'See how it fits on you',
          cta: 'Start Try-On',
        );
      case AuthPromptTrigger.orders:
        return const _AuthPromptCopy(
          title: 'Track Your Orders',
          subtitle: 'View status and delivery updates',
          cta: 'View Orders',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final textTheme = Theme.of(context).textTheme;
    final hasPreview =
        widget.productPreview != null &&
        widget.productPreview!.name.trim().isNotEmpty;

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5F2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7D2C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                copy.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF111111),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                copy.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B6B6B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.emphasizeIntent) ...[
                const SizedBox(height: 10),
                Text(
                  widget.intentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8A8A8A),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.25,
                  ),
                ),
              ],
              if (hasPreview) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _PreviewImage(imageUrl: widget.productPreview?.imageUrl),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.productPreview!.name.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF111111),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TapScale(
                scale: 0.97,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(true);
                },
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ctaColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      copy.cta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Opacity(
                  opacity: widget.allowSkip ? 0.65 : 0.35,
                  child: TextButton(
                    onPressed: widget.allowSkip
                        ? () => Navigator.of(context).pop(false)
                        : null,
                    child: Text(
                      'Skip for now',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;
    if (!hasImage) {
      return Container(
        width: 56,
        height: 56,
        color: const Color(0xFFECE8DF),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 18,
          color: Color(0xFF8A8A8A),
        ),
      );
    }
    return Image.network(
      imageUrl!,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 56,
          height: 56,
          color: const Color(0xFFECE8DF),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 18,
            color: Color(0xFF8A8A8A),
          ),
        );
      },
    );
  }
}
