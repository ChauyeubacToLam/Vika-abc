import '../exercise/3.High Plank/high_plank.dart';
import '../exercise/3.High Plank/metrics/high_plank_metric_base.dart';
import '../exercise/exercise_base.dart';
import 'generic_exercise_voice_assets.dart';
import 'high_plank_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class HighPlankVoicePlayer {
  Future<void> speak(String text);
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) {
    return Future<void>.value();
  }

  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _HighPlankAssetVoicePlayer implements HighPlankVoicePlayer {
  _HighPlankAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: {
                ...GenericExerciseVoiceAssets.commonFiles,
                ...HighPlankVoiceAssets.files,
              },
              assetSourcePrefix: HighPlankVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: HighPlankVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
              logTag: 'HighPlankVoice',
            );

  final QueuedAssetVoicePlayer _player;

  @override
  Future<void> speak(String text) => _player.speak(text);

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) =>
      _player.waitUntilIdle(timeout: timeout);

  @override
  void clearQueue() => _player.clearQueue();

  @override
  void clearPendingButKeepCurrent() => _player.clearPendingButKeepCurrent();

  @override
  void dispose() => _player.dispose();
}

class HighPlankVoiceCoach implements ExerciseVoiceCoach {
  HighPlankVoiceCoach({HighPlankVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _HighPlankAssetVoicePlayer();

  static const int _faultCueCooldownMs = 2500;

  final HighPlankVoicePlayer _voicePlayer;

  int _lastRepCount = 0;
  int _lastFaultCueAtMs = 0;
  bool _didSpeakSetup = false;
  bool _didAnnounceReady = false;
  bool _didSpeakHoldGood = false;
  bool _didAnnounceSetComplete = false;
  String? _lastFaultVoice;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _voicePlayer.clearPendingButKeepCurrent();
        _speakHoldGoodIfTargetReached(exercise);
        _voicePlayer.speak('Hoàn thành bài tập');
        _didAnnounceSetComplete = true;
      }
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastRepCount = repCount;
      return;
    }

    if (!_didAnnounceReady) {
      _voicePlayer.speak('Sẵn sàng');
      _didAnnounceReady = true;
    }

    _speakHoldGoodIfTargetReached(exercise);

    final countStopped = repCount <= _lastRepCount;
    final holdJustStopped =
        exercise is HighPlank && exercise.state == HighPlankState.dropping;
    final rawFaultVoice = _faultVoice(exercise, feedback);
    final faultVoice =
        rawFaultVoice ?? (holdJustStopped ? 'common.fix_pose' : null);
    final shouldSpeakFault = faultVoice != null &&
        (countStopped || holdJustStopped) &&
        !_didSpeakHoldGood &&
        (faultVoice != _lastFaultVoice ||
            nowMs - _lastFaultCueAtMs >= _faultCueCooldownMs);

    if (shouldSpeakFault) {
      _lastFaultVoice = faultVoice;
      _lastFaultCueAtMs = nowMs;
      _voicePlayer.clearPendingButKeepCurrent();
      _voicePlayer.speak(faultVoice);
    }

    _lastRepCount = repCount;
  }

  void _speakSetup(ExerciseBase exercise) {
    if (_didSpeakSetup) return;

    final script =
        GenericExerciseVoiceAssets.scriptForExerciseName(exercise.exerciseName);
    _voicePlayer.speak(exercise.setupOrientationIntroVoiceKey);
    _voicePlayer.speak(script.cueKey('setup_position'));
    _voicePlayer.speak(script.cueKey('active_intro'));
    _didSpeakSetup = true;
  }

  void _speakHoldGoodIfTargetReached(ExerciseBase exercise) {
    if (_didSpeakHoldGood || exercise is! HighPlank) return;

    if (exercise.timerMetric.totalHoldingTimeMs >= exercise.maxSeconds * 1000) {
      _voicePlayer.clearPendingButKeepCurrent();
      _voicePlayer.speak('common.correct');
      _didSpeakHoldGood = true;
    }
  }

  String? _faultVoice(
    ExerciseBase exercise,
    Map<String, String> feedback,
  ) {
    if (exercise is HighPlank) {
      final latestHoldBreak = exercise.lastHoldFaultVoiceMessage;
      if (latestHoldBreak != null && latestHoldBreak.isNotEmpty) {
        return latestHoldBreak;
      }

      if (exercise.saggingMetric.isFaultingNow) {
        return 'Siết chặt bụng, nâng hông lên một chút';
      }
      if (exercise.elbowMetric.isFaultingNow) {
        return 'Duỗi thẳng cánh tay ra';
      }
      if (exercise.pikedHipMetric.isFaultingNow) {
        return 'Hạ thấp mông xuống bằng với vai';
      }
    }

    final system = feedback['System'] ?? '';
    if (system.contains('không tập plank trên tường')) {
      return 'Giữ người thẳng trên sàn';
    }

    final core = feedback['Core'] ?? '';
    if (core.contains('Võng')) {
      return 'Siết chặt bụng, nâng hông lên một chút';
    }

    return null;
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _voicePlayer.waitUntilIdle(timeout: timeout);
  }

  @override
  void dispose() {
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
