import '../exercise/8.Leg Raises (Supine)/leg_raise.dart';
import '../exercise/exercise_base.dart';
import 'generic_exercise_voice_assets.dart';
import 'leg_raise_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class LegRaiseVoicePlayer {
  Future<void> speak(String text);
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) {
    return Future<void>.value();
  }

  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _LegRaiseAssetVoicePlayer implements LegRaiseVoicePlayer {
  _LegRaiseAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: {
                ...GenericExerciseVoiceAssets.commonFiles,
                ...LegRaiseVoiceAssets.files,
              },
              assetSourcePrefix: LegRaiseVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: LegRaiseVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
              logTag: 'LegRaiseVoice',
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

class LegRaiseVoiceCoach implements ExerciseVoiceCoach {
  LegRaiseVoiceCoach({LegRaiseVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _LegRaiseAssetVoicePlayer();

  final LegRaiseVoicePlayer _voicePlayer;

  int _lastRepCount = 0;
  int _lastInvalidAttemptCount = 0;
  bool _didSpeakSetup = false;
  bool _didAnnounceReady = false;
  bool _didAnnounceSetComplete = false;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final repIncreased = repCount > _lastRepCount;
    final invalidAttemptIncreased = exercise is LegRaise &&
        exercise.invalidAttemptCount > _lastInvalidAttemptCount;

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _syncCounters(exercise, repCount);
      return;
    }

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _voicePlayer.clearPendingButKeepCurrent();
        if (repIncreased) {
          _speakRepOutcome(exercise, repCount);
        }
        _voicePlayer.speak('Hoàn thành bài tập');
        _didAnnounceSetComplete = true;
      }
      _syncCounters(exercise, repCount);
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _syncCounters(exercise, repCount);
      return;
    }

    if (!_didAnnounceReady) {
      _voicePlayer.speak('Sẵn sàng');
      _didAnnounceReady = true;
    }

    if (repIncreased) {
      _voicePlayer.clearPendingButKeepCurrent();
      _speakRepOutcome(exercise, repCount);
      _syncCounters(exercise, repCount);
      return;
    }

    if (invalidAttemptIncreased) {
      _voicePlayer.clearPendingButKeepCurrent();
      _voicePlayer.speak('Lần này chưa tính');
      _speakCorrection(exercise, repCount + 1);
      _syncCounters(exercise, repCount);
      return;
    }

    _syncCounters(exercise, repCount);
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

  void _speakRepOutcome(ExerciseBase exercise, int repCount) {
    _voicePlayer.speak('$repCount');

    if (exercise is LegRaise && exercise.lastRepWasClean) {
      _voicePlayer.speak('common.correct');
      return;
    }

    _speakCorrection(exercise, repCount);
  }

  void _speakCorrection(ExerciseBase exercise, int repNumber) {
    if (exercise is! LegRaise) return;

    final voice = exercise.lastRepTopVoiceMessage;
    if (voice == null || voice.isEmpty) {
      _voicePlayer.speak('common.fix_pose');
      return;
    }
    _voicePlayer.speak(voice);
  }

  void _syncCounters(ExerciseBase exercise, int repCount) {
    _lastRepCount = repCount;
    if (exercise is LegRaise) {
      _lastInvalidAttemptCount = exercise.invalidAttemptCount;
    }
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
