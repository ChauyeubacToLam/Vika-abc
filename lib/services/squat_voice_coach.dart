import '../exercise/exercise_base.dart';
import '../exercise/squat/squat.dart';
import 'generic_exercise_voice_assets.dart';
import 'queued_asset_voice_player.dart';
import 'squat_voice_assets.dart';

abstract class SquatVoicePlayer {
  Future<void> speak(String text);
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) {
    return Future<void>.value();
  }

  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _SquatAssetVoicePlayer implements SquatVoicePlayer {
  _SquatAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: {
                ...GenericExerciseVoiceAssets.commonFiles,
                for (final entry in SquatVoiceAssets.files.entries)
                  entry.key: 'squat/${entry.value}',
              },
              assetSourcePrefix: GenericExerciseVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: GenericExerciseVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
              logTag: 'SquatVoice',
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

class SquatVoiceCoach implements ExerciseVoiceCoach {
  SquatVoiceCoach({SquatVoicePlayer? ttsService})
      : _ttsService = ttsService ?? _SquatAssetVoicePlayer();

  static const int _phaseCueMinGapMs = 250;

  static const List<String> _readyCountdown = ['3', '2', '1', 'Sẵn sàng'];
  static const String _cleanRepCue = 'common.correct';
  static const String _trunkPriorityCue = 'Ưỡn ngực lên';

  final SquatVoicePlayer _ttsService;

  String? _lastPhasePhrase;
  int _lastRepCount = 0;
  int _lastPhaseCueAtMs = 0;
  bool _didAnnounceSetComplete = false;
  bool _didAnnounceReady = false;
  bool _didSpeakSetup = false;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentExerciseState = exercise.exerciseState;
    final currentPhaseKey = exercise.currentPhaseKey;
    final repIncreased = repCount > _lastRepCount;

    if (currentExerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _ttsService.clearPendingButKeepCurrent();
        if (repIncreased) {
          if (_hasRepLog(exercise, repCount)) {
            _speakRepOutcome(
              exercise: exercise,
              repCount: repCount,
              includeCount: true,
            );
          }
        }
        _ttsService.speak('Hoàn thành bài tập');
        _didAnnounceSetComplete = true;
      }

      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    if (currentExerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    if (currentExerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    final phaseInstr = exercise.resultIssues.instructions[currentPhaseKey];
    final statusText = phaseInstr?['Status'];
    final phasePhrase = _effectivePhasePhrase(
      statusText,
      exercise: exercise,
    );
    if (!_didAnnounceReady) {
      for (final phrase in _readyCountdown) {
        _ttsService.speak(phrase);
      }
      _didAnnounceReady = true;
      if (phasePhrase != null) {
        if (phasePhrase == 'Xuống') {
          _ttsService.speak(phasePhrase);
        }
        _lastPhasePhrase = phasePhrase;
        _lastPhaseCueAtMs = nowMs;
      }
    }

    if (repIncreased) {
      _ttsService.clearPendingButKeepCurrent();
      _speakRepOutcome(
        exercise: exercise,
        repCount: repCount,
        includeCount: true,
      );
      _lastPhasePhrase = phasePhrase == 'Xuống' ? null : phasePhrase;
      _lastRepCount = repCount;
      return;
    }

    final phraseChanged =
        phasePhrase != null && phasePhrase != _lastPhasePhrase;
    final canSpeakPhaseCue = nowMs - _lastPhaseCueAtMs >= _phaseCueMinGapMs;
    final releaseCueJustUnlocked = _isBottomReleaseCue(
          phasePhrase,
          exercise: exercise,
        ) &&
        phraseChanged;

    if (phasePhrase != null &&
        phraseChanged &&
        (canSpeakPhaseCue || releaseCueJustUnlocked)) {
      if (releaseCueJustUnlocked) {
        // Release cue should jump ahead as soon as the hold is completed.
        _ttsService.clearPendingButKeepCurrent();
      }
      _ttsService.speak(phasePhrase);
      _lastPhaseCueAtMs = nowMs;
    }

    _lastPhasePhrase = phasePhrase;
    _lastRepCount = repCount;
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _ttsService.waitUntilIdle(timeout: timeout);
  }

  @override
  void dispose() {
    _ttsService.clearQueue();
    _ttsService.dispose();
  }

  void _speakSetup(ExerciseBase exercise) {
    if (_didSpeakSetup) return;

    final script =
        GenericExerciseVoiceAssets.scriptForExerciseName(exercise.exerciseName);
    _ttsService.speak(exercise.setupOrientationIntroVoiceKey);
    _ttsService.speak(script.cueKey('setup_position'));
    _ttsService.speak(script.cueKey('active_intro'));
    _didSpeakSetup = true;
  }

  String? _effectivePhasePhrase(
    String? statusText, {
    required ExerciseBase exercise,
  }) {
    final derivedReleasePhrase = _derivedBottomReleasePhrase(exercise);
    if (derivedReleasePhrase != null) {
      return derivedReleasePhrase;
    }
    return _phasePhraseFromStatus(statusText, exercise: exercise);
  }

  String? _derivedBottomReleasePhrase(ExerciseBase exercise) {
    if (exercise is! Squat) {
      return null;
    }
    if (exercise.squatState == SquatState.bottom &&
        exercise.hasCompletedBottomHold) {
      return 'Đứng lên';
    }
    return null;
  }

  bool _isBottomReleaseCue(
    String? phasePhrase, {
    required ExerciseBase exercise,
  }) {
    return phasePhrase == 'Đứng lên' &&
        exercise is Squat &&
        exercise.squatState == SquatState.bottom &&
        exercise.hasCompletedBottomHold;
  }

  String? _phasePhraseFromStatus(
    String? statusText, {
    required ExerciseBase exercise,
  }) {
    if (statusText == null || statusText.isEmpty) return null;

    if (Squat.isHoldStatus(statusText)) {
      return 'Giữ';
    }
    if (statusText.contains('Xuống')) {
      return 'Xuống';
    }
    if (Squat.isReleaseStatus(statusText) || statusText.contains('Lên')) {
      if (exercise is Squat && !exercise.hasCompletedBottomHold) {
        return null;
      }
      return 'Đứng lên';
    }
    if (statusText.contains('Đứng thẳng')) {
      return 'Đứng thẳng';
    }

    return null;
  }

  void _speakRepOutcome({
    required ExerciseBase exercise,
    required int repCount,
    required bool includeCount,
  }) {
    if (includeCount) {
      _ttsService.speak('$repCount');
    }

    if (exercise is Squat && exercise.lastRepWasClean) {
      _ttsService.speak(_cleanRepCue);
      return;
    }

    _enqueuePostRepFeedbackIfAllowed(
      exercise: exercise,
      repCount: repCount,
    );
  }

  void _enqueuePostRepFeedbackIfAllowed({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    if (exercise is! Squat || exercise.lastRepWasClean) {
      return;
    }

    final rawVoice = exercise.lastRepTopVoiceMessage;
    if (rawVoice == null || rawVoice.isEmpty) {
      _ttsService.speak('common.fix_pose');
      return;
    }

    final voice = _postRepVoice(rawVoice);
    if (voice == null) {
      _ttsService.speak('common.fix_pose');
      return;
    }

    _ttsService.speak(voice);
  }

  bool _hasRepLog(ExerciseBase exercise, int repCount) {
    return exercise.logger.repLogs.any((log) => log.repNumber == repCount);
  }

  String? _postRepVoice(String rawVoice) {
    final voice = rawVoice.trim();
    if (voice.isEmpty) {
      return null;
    }
    if (voice == _trunkPriorityCue) return voice;

    final lowerVoice = voice.toLowerCase();
    if (lowerVoice.startsWith('nhớ ')) {
      return lowerVoice;
    }

    return 'nhớ ${voice[0].toLowerCase()}${voice.substring(1)}';
  }
}
