import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class QueuedAssetVoicePlayer {
  QueuedAssetVoicePlayer({
    required Map<String, String> assetMap,
    required this.assetSourcePrefix,
    required this.assetBundlePrefix,
    this.logTag = 'AssetVoice',
  }) : _assetMap = Map.unmodifiable(assetMap) {
    _configFuture = _configurePlayer();
    _completionSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      debugPrint('[$logTag] completed');
      _isPlaying = false;
      if (_isClearingQueue) {
        return;
      }
      unawaited(_processQueue());
    });
  }

  final Map<String, String> _assetMap;
  final String assetSourcePrefix;
  final String assetBundlePrefix;
  final String logTag;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _queue = [];

  late final StreamSubscription<void> _completionSubscription;
  Future<void>? _configFuture;
  bool _isPlaying = false;
  bool _isClearingQueue = false;
  bool _isConfigured = false;
  bool _isDisposed = false;

  Future<void> _configurePlayer() async {
    try {
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.defaultToSpeaker},
          ),
        ),
      );
      _isConfigured = true;
    } catch (error) {
      debugPrint('[$logTag] configure failed: $error');
    }
  }

  Future<void> speak(String text) async {
    if (_isDisposed) {
      return;
    }

    final phrase = text.trim();
    if (phrase.isEmpty) {
      return;
    }

    _queue.add(phrase);
    debugPrint('[$logTag] queued: $phrase');
    if (!_isPlaying && !_isClearingQueue) {
      unawaited(_processQueue());
    }
  }

  void clearQueue() {
    unawaited(_clearQueue());
  }

  Future<void> _clearQueue() async {
    _queue.clear();
    if (_isDisposed || _isClearingQueue) {
      return;
    }

    if (!_isPlaying) {
      debugPrint('[$logTag] queue cleared (idle)');
      return;
    }

    _isClearingQueue = true;
    try {
      await _audioPlayer.stop();
    } catch (error) {
      debugPrint('[$logTag] stop failed: $error');
    } finally {
      _isPlaying = false;
      _isClearingQueue = false;
    }
    debugPrint('[$logTag] queue cleared');
  }

  void clearPendingButKeepCurrent() {
    _queue.clear();
    debugPrint('[$logTag] pending queue cleared');
  }

  Future<void> _processQueue() async {
    if (_isDisposed || _queue.isEmpty || _isPlaying || _isClearingQueue) {
      return;
    }

    _isPlaying = true;

    if (!_isConfigured && _configFuture != null) {
      await _configFuture;
    }

    final text = _queue.removeAt(0);
    try {
      final started = await _playText(text);
      if (!started) {
        _isPlaying = false;
        unawaited(_processQueue());
      }
    } catch (error) {
      debugPrint('[$logTag] process queue exception: $error');
      _isPlaying = false;
      unawaited(_processQueue());
    }
  }

  Future<bool> _playText(String text) async {
    final filename = _assetMap[text];
    if (filename == null) {
      debugPrint('[$logTag] missing asset mapping for "$text"');
      return false;
    }

    final bundlePath = '$assetBundlePrefix/$filename';
    try {
      await rootBundle.load(bundlePath);
    } catch (error) {
      debugPrint('[$logTag] missing asset "$bundlePath" for "$text": $error');
      return false;
    }

    await _audioPlayer.play(AssetSource('$assetSourcePrefix/$filename'));
    debugPrint('[$logTag] asset played: $bundlePath');
    return true;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _queue.clear();
    unawaited(_completionSubscription.cancel());
    unawaited(_audioPlayer.dispose());
  }
}
