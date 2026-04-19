import '../exercise/exercise_base.dart';
import '../exercise/squat/squat.dart';
import 'viettel_tts_service.dart';

class SquatVoiceCoach {
  SquatVoiceCoach({ViettelTTSService? ttsService})
      : _ttsService = ttsService ?? ViettelTTSService();

  static const int _phaseCueMinGapMs = 250;
  static const int _faultCueCooldownMs = 3000;
  static const int _postRepCueCooldownReps = 3;
  static const int _postRepRepeatSuppressMs = 1500;

  static const String _trunkPriorityCue = 'Ưỡn ngực lên';

  final ViettelTTSService _ttsService;

  String _lastPhaseKey = '';
  String? _lastPhasePhrase;
  int _lastRepCount = 0;
  int _lastPhaseCueAtMs = 0;
  bool _didAnnounceSetComplete = false;
  bool _didAnnounceReady = false;
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

      _lastPhaseKey = currentPhaseKey;
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    if (currentExerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhaseKey = currentPhaseKey;
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    if (!_didAnnounceReady) {
      _ttsService.clearQueue();
      _ttsService.speak('Sẵn sàng');
      _didAnnounceReady = true;
    }

    final phaseInstr = exercise.resultIssues.instructions[currentPhaseKey];
    final statusText = phaseInstr?['Status'];
    final phasePhrase = _phasePhraseFromStatus(statusText);
    final liveFaultVoice = _highestPriorityLiveFaultVoice(feedback);
    final canSpeakLiveFault = liveFaultVoice != null &&
        _canSpeakLiveFaultVoice(liveFaultVoice, nowMs);

    if (repIncreased) {
      _ttsService.clearPendingButKeepCurrent();
      _ttsService.speak('$repCount');
      _enqueuePostRepFeedbackIfAllowed(
        exercise: exercise,
        repCount: repCount,
        nowMs: nowMs,
      );
      _lastPhaseKey = currentPhaseKey;
      _lastPhasePhrase = phasePhrase;
      _lastRepCount = repCount;
      return;
    }

    final phaseKeyChanged = currentPhaseKey != _lastPhaseKey;
    final phraseChanged =
        phasePhrase != null && phasePhrase != _lastPhasePhrase;
    final canSpeakPhaseCue = nowMs - _lastPhaseCueAtMs >= _phaseCueMinGapMs;
    final trunkCueTakesPriority =
        liveFaultVoice == _trunkPriorityCue && canSpeakLiveFault;

    if (!trunkCueTakesPriority &&
        phasePhrase != null &&
        (phaseKeyChanged || phraseChanged) &&
        canSpeakPhaseCue) {
      _ttsService.speak(phasePhrase);
      _lastPhaseCueAtMs = nowMs;
    }

    if (liveFaultVoice != null && canSpeakLiveFault) {
      if (liveFaultVoice == _trunkPriorityCue) {
        // Let the current phrase finish, but bring chest cue to the front.
        _ttsService.clearPendingButKeepCurrent();
      }
      _lastFaultVoiceAtMs[liveFaultVoice] = nowMs;
      _ttsService.speak(liveFaultVoice);
    }

    _lastPhaseKey = currentPhaseKey;
    _lastPhasePhrase = phasePhrase;
    _lastRepCount = repCount;
  }

  void dispose() {
    _ttsService.clearQueue();
  }

  String? _phasePhraseFromStatus(String? statusText) {
    if (statusText == null || statusText.isEmpty) return null;

    if (statusText.startsWith('Hold') || statusText.contains('Giữ')) {
      return 'Giữ';
    }
    if (statusText.contains('Xuống')) {
      return 'Xuống';
    }
    if (statusText.contains('Đứng lên') || statusText.contains('Lên')) {
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
    final back = feedback['Back'] ?? '';
    if (back.contains('Chest up')) {
      return _trunkPriorityCue;
    }

    final depth = feedback['Depth'] ?? '';
    if (depth.contains('Go Lower')) {
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
