import '../exercise/exercise_base.dart';
import 'viettel_tts_service.dart';

class SquatVoiceCoach {
  SquatVoiceCoach({ViettelTTSService? ttsService})
      : _ttsService = ttsService ?? ViettelTTSService();

  static const int _phaseCueMinGapMs = 250;
  static const int _faultCueCooldownMs = 3000;

  final ViettelTTSService _ttsService;

  String _lastPhaseKey = '';
  String? _lastPhasePhrase;
  int _lastRepCount = 0;
  int _lastPhaseCueAtMs = 0;
  bool _didAnnounceSetComplete = false;
  bool _didAnnounceReady = false;
  final Map<String, int> _lastFaultVoiceAtMs = {};

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

    if (repIncreased) {
      _ttsService.clearPendingButKeepCurrent();
      _ttsService.speak('$repCount');
      _lastPhaseKey = currentPhaseKey;
      _lastPhasePhrase = phasePhrase;
      _lastRepCount = repCount;
      return;
    }

    final phaseKeyChanged = currentPhaseKey != _lastPhaseKey;
    final phraseChanged =
        phasePhrase != null && phasePhrase != _lastPhasePhrase;
    final canSpeakPhaseCue = nowMs - _lastPhaseCueAtMs >= _phaseCueMinGapMs;

    if (phasePhrase != null &&
        (phaseKeyChanged || phraseChanged) &&
        canSpeakPhaseCue) {
      _ttsService.speak(phasePhrase);
      _lastPhaseCueAtMs = nowMs;
    }

    final liveFaultVoices = _liveFaultVoicesFromFeedback(feedback);
    for (final voice in liveFaultVoices) {
      final lastSpokenAt = _lastFaultVoiceAtMs[voice] ?? 0;
      if (nowMs - lastSpokenAt < _faultCueCooldownMs) continue;
      _lastFaultVoiceAtMs[voice] = nowMs;
      _ttsService.speak(voice);
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

  List<String> _liveFaultVoicesFromFeedback(Map<String, String> feedback) {
    final voices = <String>[];

    final depth = feedback['Depth'] ?? '';
    if (depth.contains('Go Lower')) {
      voices.add('Thấp hơn nữa');
    }

    final back = feedback['Back'] ?? '';
    if (back.contains('Chest up')) {
      voices.add('Ưỡn ngực lên');
    }

    return voices;
  }
}
