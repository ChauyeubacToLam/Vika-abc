import '../exercise/exercise_base.dart';
import '../exercise/jumping jack/jumping_jack.dart';
import 'generic_exercise_voice_assets.dart';
import 'jumping_jack_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class JumpingJackVoicePlayer {
  Future<void> speak(String text);
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) {
    return Future<void>.value();
  }

  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _JumpingJackAssetVoicePlayer implements JumpingJackVoicePlayer {
  _JumpingJackAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: {
                ...GenericExerciseVoiceAssets.commonFiles,
                ...JumpingJackVoiceAssets.files,
              },
              assetSourcePrefix: JumpingJackVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: JumpingJackVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
              logTag: 'JumpingJackVoice',
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

class JumpingJackVoiceCoach implements ExerciseVoiceCoach {
  JumpingJackVoiceCoach({JumpingJackVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _JumpingJackAssetVoicePlayer();

  final JumpingJackVoicePlayer _voicePlayer;

  int _lastRepCount = 0;
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

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _lastRepCount = repCount;
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

    if (repIncreased) {
      _voicePlayer.clearPendingButKeepCurrent();
      _speakRepOutcome(exercise, repCount);
      _lastRepCount = repCount;
      return;
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

  void _speakRepOutcome(ExerciseBase exercise, int repCount) {
    _voicePlayer.speak('$repCount');

    if (exercise is JumpingJack && exercise.lastRepWasClean) {
      _voicePlayer.speak('common.correct');
      return;
    }

    if (exercise is! JumpingJack) return;

    final voice = exercise.lastRepTopVoiceMessage;
    if (voice == null || voice.isEmpty) {
      _voicePlayer.speak('common.fix_pose');
      return;
    }
    _voicePlayer.speak(voice);
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
