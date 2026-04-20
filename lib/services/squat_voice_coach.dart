import '../exercise/exercise_base.dart';
import '../exercise/squat/squat.dart';
import 'viettel_tts_service.dart';

abstract class SquatVoicePlayer {
  Future<void> speak(String text);
  void clearQueue();
  void clearPendingButKeepCurrent();
}

class _ViettelSquatVoicePlayer implements SquatVoicePlayer {
  _ViettelSquatVoicePlayer({ViettelTTSService? ttsService})
      : _ttsService = ttsService ?? ViettelTTSService();

  final ViettelTTSService _ttsService;

  @override
  Future<void> speak(String text) => _ttsService.speak(text);

  @override
  void clearQueue() => _ttsService.clearQueue();

  @override
  void clearPendingButKeepCurrent() => _ttsService.clearPendingButKeepCurrent();
}

class SquatVoiceCoach {
  SquatVoiceCoach({SquatVoicePlayer? ttsService})
      : _ttsService = ttsService ?? _ViettelSquatVoicePlayer();

  static const int _phaseCueMinGapMs = 250;
  static const int _faultCueCooldownMs = 3000;
  static const int _postRepCueCooldownReps = 3;
  static const int _postRepRepeatSuppressMs = 1500;

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
      if (repIncreased) {
        _ttsService.clearPendingButKeepCurrent();
        _ttsService.speak('$repCount');
      } else if (!_didAnnounceSetComplete) {
        _ttsService.clearPendingButKeepCurrent();
      }

      if (!_didAnnounceSetComplete) {
        _ttsService.speak('Hoàn thành bài tập');
        _didAnnounceSetComplete = true;
      }

      _lastPhasePhrase = null;
      _wasTrunkFaultActive = false;
      _lastRepCount = repCount;
      return;
    }

    if (currentExerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhasePhrase = null;
      _wasTrunkFaultActive = false;
      _lastRepCount = repCount;
      return;
    }

    final phaseInstr = exercise.resultIssues.instructions[currentPhaseKey];
    final statusText = phaseInstr?['Status'];
    final phasePhrase = _effectivePhasePhrase(
      statusText,
      exercise: exercise,
    );
    var deferStandingCueUntilNextFrame = false;

    if (!_didAnnounceReady) {
      _ttsService.clearQueue();
      // Keep the activation cue stable so Squat always opens with the same phrase.
      _ttsService.speak('Sẵn sàng');
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
    final canSpeakLiveFault = liveFaultVoice != null &&
        (trunkFaultJustDetected ||
            _canSpeakLiveFaultVoice(liveFaultVoice, nowMs));

    if (repIncreased) {
      _ttsService.clearPendingButKeepCurrent();
      _ttsService.speak('$repCount');
      _enqueuePostRepFeedbackIfAllowed(
        exercise: exercise,
        repCount: repCount,
        nowMs: nowMs,
      );
      _lastPhasePhrase = phasePhrase == 'Xuống' ? null : phasePhrase;
      _wasTrunkFaultActive = trunkFaultActive;
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
      _ttsService.speak(liveFaultVoice);
    }

    _lastPhasePhrase = deferStandingCueUntilNextFrame ? null : phasePhrase;
    _wasTrunkFaultActive = trunkFaultActive;
    _lastRepCount = repCount;
  }

  void dispose() {
    _ttsService.clearQueue();
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

    final depth = (feedback['Depth'] ?? '').toLowerCase();
    if (depth.contains('go lower')) {
      return 'Thấp hơn nữa';
    }

    return null;
  }

  void _enqueuePostRepFeedbackIfAllowed({
    required ExerciseBase exercise,
    required int repCount,
    required int nowMs,
  }) {
    if (exercise is! Squat || exercise.lastRepWasClean) {
      return;
    }

    final voice = exercise.lastRepTopVoiceMessage;
    if (voice == null || voice.isEmpty) {
      return;
    }

    final lastPostRepRep = _lastPostRepVoiceRep[voice] ?? -99;
    if (repCount - lastPostRepRep < _postRepCueCooldownReps) {
      return;
    }

    final lastLiveVoiceAt = _lastFaultVoiceAtMs[voice] ?? 0;
    if (nowMs - lastLiveVoiceAt < _postRepRepeatSuppressMs) {
      return;
    }

    _lastPostRepVoiceRep[voice] = repCount;
    _ttsService.speak(voice);
  }
}
