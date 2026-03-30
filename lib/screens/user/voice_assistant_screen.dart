import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/avatar_voice_service.dart';
import '../../services/database_service.dart';
import '../../widgets/assistant_avatar_view.dart';

enum _VoiceAssistantState {
  listening,
  thinking,
  speaking,
  idle,
}

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({
    super.key,
    required this.chat,
  });

  final SupportChat chat;

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _database = DatabaseService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AvatarVoiceService _voice = AvatarVoiceService();

  late final AnimationController _pulseController;
  StreamSubscription<List<SupportMessage>>? _messageSubscription;

  bool _speechEnabled = false;
  bool _activeMode = true;
  bool _sending = false;
  String _heardText = '';
  String _assistantText = 'Hey, I am your ABZORA stylist and assistant. Ask me about orders, fits, or what to wear next.';
  String _statusText = 'Starting voice assistant...';
  String? _lastSpokenAssistantMessageId;
  _VoiceAssistantState _state = _VoiceAssistantState.idle;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    unawaited(_initVoiceMode());
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    unawaited(_speech.cancel());
    unawaited(_voice.dispose());
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initVoiceMode() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }

    _messageSubscription = _database
        .watchSupportMessages(chatId: widget.chat.id, actor: actor)
        .listen((messages) {
      if (messages.isEmpty) {
        return;
      }
      final assistantMessages = messages
          .where((message) => message.senderRole == 'assistant')
          .toList();
      if (assistantMessages.isEmpty) {
        return;
      }
      final latest = assistantMessages.last;
      if (latest.id == _lastSpokenAssistantMessageId ||
          latest.text.trim().isEmpty) {
        return;
      }
      _lastSpokenAssistantMessageId = latest.id;
      if (mounted) {
        setState(() {
          _assistantText = latest.text.trim();
        });
      }
      unawaited(_speak(latest.text.trim()));
    });

    try {
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      await _voice.initialize(
        onComplete: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _state = _VoiceAssistantState.idle;
            _statusText = 'Listening again...';
          });
          unawaited(_beginListening());
        },
        onCancel: () {},
        onError: (_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _state = _VoiceAssistantState.idle;
            _statusText = 'Voice playback failed. Listening again...';
          });
          unawaited(_beginListening());
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _speechEnabled = available;
        _statusText = available
            ? 'Listening...'
            : 'Microphone unavailable. Please enable speech permissions.';
      });
      if (available) {
        await _beginListening();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speechEnabled = false;
        _statusText = 'Could not start voice assistant.';
      });
    }
  }

  Future<void> _beginListening() async {
    if (!_activeMode || !_speechEnabled || _sending) {
      return;
    }
    await _voice.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _VoiceAssistantState.listening;
      _statusText = 'Listening...';
      _heardText = '';
    });
    await _speech.listen(
      localeId: 'en_IN',
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(minutes: 2),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _heardText = result.recognizedWords.trim();
        });
      },
    );
  }

  void _handleSpeechStatus(String status) {
    if (!mounted || !_activeMode) {
      return;
    }
    if (status == 'done' || status == 'notListening') {
      if (_heardText.trim().isEmpty) {
        setState(() {
          _state = _VoiceAssistantState.idle;
          _statusText = 'I didn’t catch that, can you repeat?';
        });
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted && _activeMode && !_sending) {
            unawaited(_beginListening());
          }
        });
        return;
      }
      unawaited(_sendHeardText());
    }
  }

  void _handleSpeechError(dynamic _) {
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _VoiceAssistantState.idle;
      _statusText = 'Couldn’t understand, please try again.';
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _activeMode && !_sending) {
        unawaited(_beginListening());
      }
    });
  }

  Future<void> _sendHeardText() async {
    final actor = context.read<AuthProvider>().user;
    final text = _heardText.trim();
    if (actor == null || text.isEmpty || _sending) {
      return;
    }
    if (text.toLowerCase() == 'stop') {
      _exitVoiceMode();
      return;
    }

    setState(() {
      _sending = true;
      _state = _VoiceAssistantState.thinking;
      _statusText = 'Thinking...';
    });

    try {
      await _database.sendSupportMessage(
        chatId: widget.chat.id,
        text: text,
        actor: actor,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _VoiceAssistantState.idle;
        _statusText = 'I hit a snag. Let’s try that again.';
      });
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _activeMode) {
          unawaited(_beginListening());
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _speak(String text) async {
    if (!_activeMode || text.trim().isEmpty) {
      return;
    }
    await _speech.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _VoiceAssistantState.speaking;
      _statusText = 'Speaking...';
    });
    await _voice.speak(text);
  }

  Future<void> _interruptAndListen() async {
    await _voice.stop();
    await _speech.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = 'Listening...';
      _state = _VoiceAssistantState.listening;
    });
    await _beginListening();
  }

  Future<void> _toggleMainAction() async {
    if (_state == _VoiceAssistantState.speaking) {
      await _interruptAndListen();
      return;
    }
    if (_state == _VoiceAssistantState.listening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _VoiceAssistantState.idle;
        _statusText = 'Voice assistant paused';
      });
      return;
    }
    await _beginListening();
  }

  void _exitVoiceMode() {
    _activeMode = false;
    unawaited(_speech.cancel());
    unawaited(_voice.stop());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = switch (_state) {
      _VoiceAssistantState.listening => const Color(0xFFD4AF37),
      _VoiceAssistantState.thinking => const Color(0xFFB88913),
      _VoiceAssistantState.speaking => const Color(0xFFE8C96A),
      _ => const Color(0xFFD8D0BE),
    };
    final scale = switch (_state) {
      _VoiceAssistantState.listening => 1.0,
      _VoiceAssistantState.thinking => 0.92,
      _VoiceAssistantState.speaking => 1.08,
      _ => 0.88,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _exitVoiceMode,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B0B0D),
                  Color(0xFF111114),
                  Color(0xFF050505),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -40,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: -60,
                  bottom: 120,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _exitVoiceMode,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Text(
                              _state.name.toUpperCase(),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Talk to ABZORA AI',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.45,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 26),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = 1 + (_pulseController.value * 0.08);
                          return Transform.scale(
                            scale: scale * pulse,
                            child: child,
                          );
                        },
                        child: AssistantAvatarView(
                          accent: accent,
                          state: switch (_state) {
                            _VoiceAssistantState.listening =>
                              AssistantAvatarState.listening,
                            _VoiceAssistantState.thinking =>
                              AssistantAvatarState.thinking,
                            _VoiceAssistantState.speaking =>
                              AssistantAvatarState.speaking,
                            _ => AssistantAvatarState.idle,
                          },
                          scale: 1,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _SubtitleCard(
                        label: 'You',
                        text: _heardText.trim().isEmpty
                            ? 'Speak naturally. I will keep listening after every reply.'
                            : _heardText.trim(),
                        accent: accent.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 12),
                      _SubtitleCard(
                        label: 'ABZORA AI',
                        text: _assistantText,
                        accent: Colors.white,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _state == _VoiceAssistantState.speaking
                            ? 'Tap the orb to interrupt and speak'
                            : 'The assistant will keep listening after each reply',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _toggleMainAction,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.34),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(
                            _state == _VoiceAssistantState.speaking
                                ? Icons.hearing_rounded
                                : _state == _VoiceAssistantState.listening
                                    ? Icons.pause_rounded
                                    : Icons.mic_rounded,
                            color: Colors.black,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Double tap anywhere to exit',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _SubtitleCard extends StatelessWidget {
  const _SubtitleCard({
    required this.label,
    required this.text,
    required this.accent,
  });

  final String label;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: text.trim().isEmpty ? 0.55 : 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                height: 1.48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
