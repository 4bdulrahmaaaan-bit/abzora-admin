import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_config.dart';

enum AssistantAvatarState {
  listening,
  thinking,
  speaking,
  idle,
}

class AssistantAvatarView extends StatefulWidget {
  const AssistantAvatarView({
    super.key,
    required this.state,
    required this.accent,
    required this.scale,
  });

  final AssistantAvatarState state;
  final Color accent;
  final double scale;

  @override
  State<AssistantAvatarView> createState() => _AssistantAvatarViewState();
}

class _AssistantAvatarViewState extends State<AssistantAvatarView> {
  WebViewController? _controller;

  bool get _useWebAvatar => AppConfig.hasReadyPlayerMeAvatar;

  @override
  void initState() {
    super.initState();
    if (_useWebAvatar) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(AppConfig.readyPlayerMeAvatarUrl));
    }
  }

  @override
  void didUpdateWidget(covariant AssistantAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && oldWidget.state != widget.state) {
      _pushAvatarStateToWeb(widget.state);
    }
  }

  Future<void> _pushAvatarStateToWeb(AssistantAvatarState state) async {
    try {
      await _controller?.runJavaScript(
        "window.postMessage({ type: 'abzoraAvatarState', state: '${state.name}' }, '*');",
      );
    } catch (_) {
      // If the embedded avatar page does not support state hooks yet,
      // keep the surrounding UI as the visible feedback layer.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: widget.scale,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: _useWebAvatar && _controller != null
          ? _webAvatar()
          : _fallbackOrb(),
    );
  }

  Widget _webAvatar() {
    return Container(
      width: 268,
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.accent.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.20),
            blurRadius: 36,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _controller!)),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: _WaveBarOverlay(
                accent: widget.accent,
                state: widget.state,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackOrb() {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            widget.accent.withValues(alpha: 0.96),
            widget.accent.withValues(alpha: 0.34),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.34),
            blurRadius: 42,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 142,
          height: 142,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.74),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                switch (widget.state) {
                  AssistantAvatarState.listening =>
                    Icons.multitrack_audio_rounded,
                  AssistantAvatarState.thinking =>
                    Icons.auto_awesome_rounded,
                  AssistantAvatarState.speaking =>
                    Icons.graphic_eq_rounded,
                  _ => Icons.self_improvement_rounded,
                },
                size: 38,
                color: Colors.white,
              ),
              const SizedBox(height: 14),
              _WaveBarOverlay(
                accent: Colors.white,
                state: widget.state,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveBarOverlay extends StatelessWidget {
  const _WaveBarOverlay({
    required this.accent,
    required this.state,
  });

  final Color accent;
  final AssistantAvatarState state;

  @override
  Widget build(BuildContext context) {
    final waveHeights = switch (state) {
      AssistantAvatarState.listening => [26.0, 38.0, 52.0, 38.0, 26.0],
      AssistantAvatarState.thinking => [18.0, 24.0, 30.0, 24.0, 18.0],
      AssistantAvatarState.speaking => [34.0, 54.0, 70.0, 54.0, 34.0],
      _ => [14.0, 18.0, 22.0, 18.0, 14.0],
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: waveHeights
          .map(
            (height) => Container(
              width: 6,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          )
          .toList(),
    );
  }
}
