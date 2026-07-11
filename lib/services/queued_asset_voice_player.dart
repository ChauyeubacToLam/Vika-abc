import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class QueuedAssetVoicePlayer {
  QueuedAssetVoicePlayer({
    required Map<String, String> assetMap,
    required this.assetSourcePrefix,
    required this.assetBundlePrefix,
    this.assetResolver,
    this.logTag = 'AssetVoice',
  }) : _assetMap = Map.unmodifiable(assetMap) {
    _configFuture = _configurePlayer();
    _completionSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (_isDisposed) {
        return;
      }
      debugPrint('[$logTag] completed');
      _isPlaying = false;
      if (_isClearingQueue) {
        return;
      }
      unawaited(_processQueue());
      _notifyIdleWaitersIfNeeded();
    });
  }

  final Map<String, String> _assetMap;
  final String assetSourcePrefix;
  final String assetBundlePrefix;
  final String? Function(String text)? assetResolver;
  final String logTag;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _queue = [];
  final List<Completer<void>> _idleWaiters = [];

  late final StreamSubscription<void> _completionSubscription;
  Future<void>? _configFuture;
  bool _isPlaying = false;
  bool _isClearingQueue = false;
  bool _isConfigured = false;
  bool _isDisposed = false;

  bool get _isIdle => !_isPlaying && !_isClearingQueue && _queue.isEmpty;

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
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.duckOthers},
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

  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (_isDisposed || _isIdle) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _idleWaiters.add(completer);
    final future = completer.future;
    if (timeout == Duration.zero) {
      return future;
    }
    return future.timeout(timeout, onTimeout: () {});
  }

  void clearQueue() {
    unawaited(_clearQueue());
  }

  Future<void> _clearQueue() async {
    _queue.clear();
    if (_isDisposed || _isClearingQueue) {
      _notifyIdleWaitersIfNeeded();
      return;
    }

    if (!_isPlaying) {
      debugPrint('[$logTag] queue cleared (idle)');
      _notifyIdleWaitersIfNeeded();
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
    _notifyIdleWaitersIfNeeded();
    // Re-kick the pump: a speak() that arrived during the await above saw
    // _isClearingQueue true and enqueued WITHOUT kicking (its
    // `!_isPlaying && !_isClearingQueue` guard), so its line would otherwise
    // sit silent until the next speak(). _processQueue's own entry guards
    // make this a no-op when nothing is pending — FIFO semantics unchanged.
    unawaited(_processQueue());
  }

  void clearPendingButKeepCurrent() {
    _queue.clear();
    debugPrint('[$logTag] pending queue cleared');
    _notifyIdleWaitersIfNeeded();
  }

  Future<void> _processQueue() async {
    if (_isDisposed || _queue.isEmpty || _isPlaying || _isClearingQueue) {
      _notifyIdleWaitersIfNeeded();
      return;
    }

    _isPlaying = true;

    if (!_isConfigured && _configFuture != null) {
      await _configFuture;
      if (_isDisposed) {
        _isPlaying = false;
        _notifyIdleWaitersIfNeeded();
        return;
      }
    }

    final text = _queue.removeAt(0);
    try {
      final started = await _playText(text);
      if (!started) {
        _isPlaying = false;
        _notifyIdleWaitersIfNeeded();
        unawaited(_processQueue());
      }
    } catch (error) {
      debugPrint('[$logTag] process queue exception: $error');
      _isPlaying = false;
      _notifyIdleWaitersIfNeeded();
      unawaited(_processQueue());
    }
  }

  Future<bool> _playText(String text) async {
    if (_isDisposed) {
      return false;
    }

    final filename = _assetMap[text] ?? assetResolver?.call(text);
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

    if (_isDisposed) {
      return false;
    }
    await _audioPlayer.play(AssetSource('$assetSourcePrefix/$filename'));
    if (_isDisposed) {
      return false;
    }
    debugPrint('[$logTag] asset played: $bundlePath');
    return true;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _isPlaying = false;
    _isClearingQueue = false;
    _queue.clear();
    _completeIdleWaiters();
    unawaited(_completionSubscription.cancel());
    unawaited(_disposePlayer());
  }

  void _notifyIdleWaitersIfNeeded() {
    if (_isIdle) {
      _completeIdleWaiters();
    }
  }

  void _completeIdleWaiters() {
    if (_idleWaiters.isEmpty) {
      return;
    }
    final waiters = List<Completer<void>>.from(_idleWaiters);
    _idleWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
  }

  Future<void> _disposePlayer() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _audioPlayer.dispose();
    } catch (_) {}
  }
}
