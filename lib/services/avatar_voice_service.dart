import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

class AvatarVoiceService {
  AvatarVoiceService({
    FlutterTts? tts,
    AudioPlayer? audioPlayer,
  })  : _tts = tts ?? FlutterTts(),
        _audioPlayer = audioPlayer ?? AudioPlayer();

  final FlutterTts _tts;
  final AudioPlayer _audioPlayer;

  VoidCallback? _onComplete;
  VoidCallback? _onCancel;
  void Function(String message)? _onError;

  Future<void> initialize({
    required VoidCallback onComplete,
    required VoidCallback onCancel,
    required void Function(String message) onError,
  }) async {
    _onComplete = onComplete;
    _onCancel = onCancel;
    _onError = onError;

    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _onComplete?.call();
    });
    _tts.setCancelHandler(() {
      _onCancel?.call();
    });
    _tts.setErrorHandler((message) {
      _onError?.call(message ?? 'Voice playback failed.');
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _onComplete?.call();
    });
  }

  Future<void> stop() async {
    await _tts.stop();
    await _audioPlayer.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await stop();
    if (AppConfig.hasElevenLabsConfig) {
      try {
        final audioBytes = await _synthesizeWithElevenLabs(trimmed);
        if (audioBytes != null) {
          await _audioPlayer.play(BytesSource(audioBytes));
          return;
        }
      } catch (error) {
        _onError?.call(error.toString());
      }
    }
    await _tts.speak(trimmed);
  }

  Future<Uint8List?> _synthesizeWithElevenLabs(String text) async {
    final uri = Uri.parse(
      '${AppConfig.elevenLabsEndpoint}/${AppConfig.elevenLabsVoiceId}',
    );
    final response = await http.post(
      uri,
      headers: {
        'xi-api-key': AppConfig.elevenLabsApiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: '''
{
  "text": ${_jsonString(text)},
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.45,
    "similarity_boost": 0.82,
    "style": 0.35,
    "use_speaker_boost": true
  }
}
''',
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return response.bodyBytes;
  }

  String _jsonString(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    return '"$escaped"';
  }
}

typedef VoidCallback = void Function();
