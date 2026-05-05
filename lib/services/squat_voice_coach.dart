import '../exercise/exercise_base.dart';
import '../exercise/squat/squat.dart';
import 'queued_asset_voice_player.dart';
import 'squat_voice_assets.dart';

abstract class SquatVoicePlayer {
  Future<void> speak(String text);
  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _SquatAssetVoicePlayer implements SquatVoicePlayer {
  _SquatAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: SquatVoiceAssets.files,
              assetSourcePrefix: SquatVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: SquatVoiceAssets.assetBundlePrefix,
              logTag: 'SquatVoice',
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

class SquatVoiceCoach implements ExerciseVoiceCoach {
  SquatVoiceCoach({SquatVoicePlayer? ttsService})
      : _ttsService = ttsService ?? _SquatAssetVoicePlayer();

  static const int _phaseCueMinGapMs = 250;
  static const int _faultCueCooldownMs = 3000;
  static const int _postRepCueCooldownReps = 2;
  static const int _postRepRepeatSuppressMs = 1500;

  static const List<String> _readyCountdown = ['3', '2', '1', 'Sẵn sàng'];
  static const String _cleanRepCue = 'tốt';
  static const String _trunkPriorityCue = 'Ưỡn ngực lên';

  final SquatVoicePlayer _ttsService;

  String? _lastPhasePhrase;
  int _lastRepCount = 0;
  int _lastPhaseCueAtMs = 0;
  bool _didAnnounceSetComplete = false;
  bool _didAnnounceReady = false;
  bool _wasTrunkFaultActive = false;
  final Map<String, int> _lastFaultVoiceAtMs = {};
  final Map<String, int> _lastPostRepVoiceRep = {};
  final Set<String> _liveFaultVoicesSpokenThisRep = {};

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
          _speakRepOutcome(
            exercise: exercise,
            repCount: repCount,
            nowMs: nowMs,
            includeCount: false,
          );
        }
        _ttsService.speak('Hoàn thành bài tập');
        _didAnnounceSetComplete = true;
      }

      _lastPhasePhrase = null;
      _wasTrunkFaultActive = false;
      _liveFaultVoicesSpokenThisRep.clear();
      _lastRepCount = repCount;
      return;
    }

    if (currentExerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhasePhrase = null;
      _wasTrunkFaultActive = false;
      if (currentExerciseState != ExerciseState.activated) {
        _liveFaultVoicesSpokenThisRep.clear();
      }
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
      _ttsService.clearQueue();
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

    final liveFaultVoice = _highestPriorityLiveFaultVoice(feedback);
    final trunkFaultActive = liveFaultVoice == _trunkPriorityCue;
    final trunkFaultJustDetected = trunkFaultActive && !_wasTrunkFaultActive;
    final liveFaultAlreadySpokenThisRep = liveFaultVoice != null &&
        _liveFaultVoicesSpokenThisRep.contains(liveFaultVoice);
    final canSpeakLiveFault = liveFaultVoice != null &&
        !liveFaultAlreadySpokenThisRep &&
        (trunkFaultJustDetected ||
            _canSpeakLiveFaultVoice(liveFaultVoice, nowMs));

    if (repIncreased) {
      _ttsService.clearPendingButKeepCurrent();
      _speakRepOutcome(
        exercise: exercise,
        repCount: repCount,
        nowMs: nowMs,
        includeCount: true,
      );
      _lastPhasePhrase = phasePhrase == 'Xuống' ? null : phasePhrase;
      _wasTrunkFaultActive = false;
      _liveFaultVoicesSpokenThisRep.clear();
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
    final suppressLiveFaultForReleaseCue = releaseCueJustUnlocked;
    final trunkCueTakesPriority = !releaseCueJustUnlocked &&
        liveFaultVoice == _trunkPriorityCue &&
        canSpeakLiveFault;

    if (!trunkCueTakesPriority &&
        phasePhrase != null &&
        phraseChanged &&
        (canSpeakPhaseCue || releaseCueJustUnlocked)) {
      if (releaseCueJustUnlocked) {
        // Release cue should jump ahead as soon as the hold is completed.
        _ttsService.clearPendingButKeepCurrent();
      }
      _ttsService.speak(phasePhrase);
      _lastPhaseCueAtMs = nowMs;
    }

    if (!suppressLiveFaultForReleaseCue &&
        liveFaultVoice != null &&
        canSpeakLiveFault) {
      if (liveFaultVoice == _trunkPriorityCue) {
        // Let the current phrase finish, but bring chest cue to the front.
        _ttsService.clearPendingButKeepCurrent();
      }
      _lastFaultVoiceAtMs[liveFaultVoice] = nowMs;
      _liveFaultVoicesSpokenThisRep.add(liveFaultVoice);
      _ttsService.speak(liveFaultVoice);
    }

    _lastPhasePhrase = phasePhrase;
    _wasTrunkFaultActive = trunkFaultActive;
    _lastRepCount = repCount;
  }

  void dispose() {
    _ttsService.clearQueue();
    _ttsService.dispose();
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

  bool _canSpeakLiveFaultVoice(String voice, int nowMs) {
    final lastSpokenAt = _lastFaultVoiceAtMs[voice] ?? 0;
    return nowMs - lastSpokenAt >= _faultCueCooldownMs;
  }

  String? _highestPriorityLiveFaultVoice(Map<String, String> feedback) {
    final back = (feedback['Back'] ?? '').toLowerCase();
    if (back.contains('chest up')) {
      return _trunkPriorityCue;
    }

    final sync = (feedback['Sync'] ?? '').toLowerCase();
    if (sync.contains('chest up')) {
      return _trunkPriorityCue;
    }

    return null;
  }

  void _speakRepOutcome({
    required ExerciseBase exercise,
    required int repCount,
    required int nowMs,
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
      nowMs: nowMs,
    );
  }

  void _enqueuePostRepFeedbackIfAllowed({
    required ExerciseBase exercise,
    required int repCount,
    required int nowMs,
  }) {
    if (exercise is! Squat || exercise.lastRepWasClean) {
      return;
    }

    final rawVoice = exercise.lastRepTopVoiceMessage;
    if (rawVoice == null || rawVoice.isEmpty) {
      return;
    }

    final voice = _postRepVoice(rawVoice);
    if (voice == null) {
      return;
    }

    final lastPostRepRep = _lastPostRepVoiceRep[voice] ?? -99;
    if (repCount - lastPostRepRep < _postRepCueCooldownReps) {
      return;
    }

    final lastLiveVoiceAt = _lastFaultVoiceAtMs[rawVoice] ?? 0;
    if (nowMs - lastLiveVoiceAt < _postRepRepeatSuppressMs) {
      return;
    }

    _lastPostRepVoiceRep[voice] = repCount;
    _ttsService.speak(voice);
  }

  String? _postRepVoice(String rawVoice) {
    final voice = rawVoice.trim();
    if (voice.isEmpty || voice == _trunkPriorityCue) {
      return null;
    }

    final lowerVoice = voice.toLowerCase();
    if (lowerVoice.startsWith('nhớ ')) {
      return lowerVoice;
    }

    return 'nhớ ${voice[0].toLowerCase()}${voice.substring(1)}';
  }
}
