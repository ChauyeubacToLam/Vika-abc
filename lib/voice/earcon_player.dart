import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

abstract class EarconSink {
  Future<void> endTone();
  Future<void> restEndTone();
  void dispose();
}

/// Independent non-verbal state channel. It intentionally owns a second
/// AudioPlayer so the end tone can overlap queued speech at the hold/set edge.
class EarconPlayer implements EarconSink {
  EarconPlayer({AudioPlayer? player}) : _player = player;

  static const String _endBundlePath = 'assets/audio/common/end_tone.mp3';
  static const String _endSourcePath = 'audio/common/end_tone.mp3';
  static const String _restEndBundlePath =
      'assets/audio/common/rest_end_tone.mp3';
  static const String _restEndSourcePath = 'audio/common/rest_end_tone.mp3';

  AudioPlayer? _player;
  Future<void>? _configuration;
  final Set<String> _verifiedAssets = <String>{};
  bool _disposed = false;

  Future<void> _configure(AudioPlayer player) async {
    try {
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.65);
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            // The voice player owns transient focus. The tone must not steal
            // it and pause/duck speech from the same app.
            audioFocus: AndroidAudioFocus.none,
          ),
          // iOS audio context is process-global in audioplayers. Match the
          // voice player's category/options so this player never changes the
          // shared session underneath it.
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );
    } catch (error) {
      debugPrint('[Earcon] configure failed: $error');
    }
  }

  @override
  Future<void> endTone() => _play(
        bundlePath: _endBundlePath,
        sourcePath: _endSourcePath,
        label: 'end tone',
      );

  @override
  Future<void> restEndTone() => _play(
        bundlePath: _restEndBundlePath,
        sourcePath: _restEndSourcePath,
        label: 'rest-end tone',
      );

  Future<void> _play({
    required String bundlePath,
    required String sourcePath,
    required String label,
  }) async {
    if (_disposed) return;
    final player = _player ??= AudioPlayer();
    await (_configuration ??= _configure(player));
    if (_disposed) return;
    try {
      if (!_verifiedAssets.contains(bundlePath)) {
        await rootBundle.load(bundlePath);
        _verifiedAssets.add(bundlePath);
      }
      await player.play(AssetSource(sourcePath));
      debugPrint('[Earcon] $label played');
    } catch (error) {
      debugPrint('[Earcon] $label failed: $error');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final player = _player;
    if (player != null) unawaited(player.dispose());
  }
}
