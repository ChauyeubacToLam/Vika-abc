import '../exercise/8.Leg Raises (Supine)/leg_raise.dart';
import '../exercise/exercise_base.dart';
import 'generic_exercise_voice_assets.dart';
import 'leg_raise_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class LegRaiseVoicePlayer {
  Future<void> speak(String text);
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
  void clearQueue() => _player.clearQueue();

  @override
  void clearPendingButKeepCurrent() => _player.clearPendingButKeepCurrent();

  @override
  void dispose() => _player.dispose();
}

class LegRaiseVoiceCoach implements ExerciseVoiceCoach {
  LegRaiseVoiceCoach({LegRaiseVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _LegRaiseAssetVoicePlayer();

  static const int _liveFaultCooldownMs = 2500;
  static const int _postRepCueCooldownReps = 2;

  final LegRaiseVoicePlayer _voicePlayer;
  final Map<String, int> _lastPostRepVoiceRep = {};

  int _lastRepCount = 0;
  int _lastInvalidAttemptCount = 0;
  int _lastLiveFaultAtMs = 0;
  bool _didSpeakSetup = false;
  bool _didAnnounceReady = false;
  bool _didAnnounceSetComplete = false;
  String? _lastLiveFaultVoice;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
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
        _voicePlayer.clearQueue();
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
      _voicePlayer.clearQueue();
      _voicePlayer.speak('Sẵn sàng');
      _didAnnounceReady = true;
    }

    if (repIncreased) {
      _voicePlayer.clearQueue();
      _speakRepOutcome(exercise, repCount);
      _syncCounters(exercise, repCount);
      _lastLiveFaultVoice = null;
      return;
    }

    if (invalidAttemptIncreased) {
      _voicePlayer.clearQueue();
      _voicePlayer.speak('Lần này chưa tính');
      _speakCorrection(exercise, repCount + 1);
      _syncCounters(exercise, repCount);
      _lastLiveFaultVoice = null;
      return;
    }

    final liveFaultVoice = _liveFaultVoice(feedback);
    if (liveFaultVoice != null &&
        (liveFaultVoice != _lastLiveFaultVoice ||
            nowMs - _lastLiveFaultAtMs >= _liveFaultCooldownMs)) {
      _lastLiveFaultVoice = liveFaultVoice;
      _lastLiveFaultAtMs = nowMs;
      _voicePlayer.clearPendingButKeepCurrent();
      _voicePlayer.speak(liveFaultVoice);
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
      _voicePlayer.speak('leg_raises.good_clean');
      return;
    }

    _speakCorrection(exercise, repCount);
  }

  void _speakCorrection(ExerciseBase exercise, int repNumber) {
    if (exercise is! LegRaise) return;

    final voice = exercise.lastRepTopVoiceMessage;
    if (voice == null || voice.isEmpty) return;

    final lastRep = _lastPostRepVoiceRep[voice] ?? -99;
    if (repNumber - lastRep < _postRepCueCooldownReps) return;

    _lastPostRepVoiceRep[voice] = repNumber;
    _voicePlayer.speak(voice);
  }

  String? _liveFaultVoice(Map<String, String> feedback) {
    final error = feedback['Error'] ?? '';
    if (error.contains('Gập gối')) return 'Duỗi thẳng đầu gối';
    if (error.contains('Lưng')) return 'Ép lưng dưới xuống sàn';

    final arms = feedback['Arms'] ?? '';
    if (arms.contains('tay') || arms.contains('hông')) {
      return 'Duỗi tay sát hông';
    }

    return null;
  }

  void _syncCounters(ExerciseBase exercise, int repCount) {
    _lastRepCount = repCount;
    if (exercise is LegRaise) {
      _lastInvalidAttemptCount = exercise.invalidAttemptCount;
    }
  }

  @override
  void dispose() {
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
