import '../exercise/exercise_base.dart';
import '../exercise/wall_push_up/wall_push_up.dart';
import 'queued_asset_voice_player.dart';
import 'wall_push_up_voice_assets.dart';

abstract class WallPushUpVoicePlayer {
  Future<void> speak(String text);
  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _WallPushUpAssetVoicePlayer implements WallPushUpVoicePlayer {
  _WallPushUpAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: WallPushUpVoiceAssets.files,
              assetSourcePrefix: WallPushUpVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: WallPushUpVoiceAssets.assetBundlePrefix,
              logTag: 'WallPushUpVoice',
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

class WallPushUpVoiceCoach implements ExerciseVoiceCoach {
  WallPushUpVoiceCoach({WallPushUpVoicePlayer? ttsService})
      : _ttsService = ttsService ?? _WallPushUpAssetVoicePlayer();

  static const int _phaseCueMinGapMs = 350;
  static const int _faultCueCooldownMs = 3000;
  static const int _postRepCueCooldownReps = 2;
  static const int _postRepRepeatSuppressMs = 1500;

  static const List<String> _readyCountdown = ['Sẵn sàng'];
  static const String _cleanRepCue = 'tốt';

  final WallPushUpVoicePlayer _ttsService;

  String? _lastPhasePhrase;
  int _lastRepCount = 0;
  int _lastPhaseCueAtMs = 0;
  bool _didAnnounceSetComplete = false;
  bool _didAnnounceReady = false;
  final Map<String, int> _lastFaultVoiceAtMs = {};
  final Map<String, int> _lastPostRepVoiceRep = {};
  final Set<String> _liveFaultVoicesSpokenThisRep = {};

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repIncreased = repCount > _lastRepCount;

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _ttsService.clearPendingButKeepCurrent();
        if (repIncreased) {
          _speakRepOutcome(
            exercise: exercise,
            repCount: repCount,
            nowMs: nowMs,
            includeCount: _shouldSpeakCompletedRepCount(
              exercise: exercise,
              repCount: repCount,
            ),
          );
        }
        _ttsService.speak('Hoàn thành bài tập');
        _didAnnounceSetComplete = true;
      }
      _lastPhasePhrase = null;
      _liveFaultVoicesSpokenThisRep.clear();
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhasePhrase = null;
      if (exercise.exerciseState != ExerciseState.activated) {
        _liveFaultVoicesSpokenThisRep.clear();
      }
      _lastRepCount = repCount;
      return;
    }

    final phasePhrase = _phasePhrase(exercise);
    if (!_didAnnounceReady) {
      _ttsService.clearQueue();
      for (final phrase in _readyCountdown) {
        _ttsService.speak(phrase);
      }
      if (phasePhrase != null) {
        _ttsService.speak(phasePhrase);
      }
      _didAnnounceReady = true;
      _lastPhasePhrase = phasePhrase;
      _lastPhaseCueAtMs = nowMs;
    }

    final liveFaultVoice = _highestPriorityLiveFaultVoice(feedback);
    final liveFaultAlreadySpokenThisRep = liveFaultVoice != null &&
        _liveFaultVoicesSpokenThisRep.contains(liveFaultVoice);
    final canSpeakLiveFault = liveFaultVoice != null &&
        !liveFaultAlreadySpokenThisRep &&
        _canSpeakLiveFaultVoice(liveFaultVoice, nowMs);

    if (repIncreased) {
      _ttsService.clearPendingButKeepCurrent();
      _speakRepOutcome(
        exercise: exercise,
        repCount: repCount,
        nowMs: nowMs,
        includeCount: true,
      );
      if (!exercise.requestStop()) {
        _ttsService.speak('Hạ xuống');
      }
      _lastPhasePhrase = null;
      _liveFaultVoicesSpokenThisRep.clear();
      _lastRepCount = repCount;
      return;
    }

    final phraseChanged =
        phasePhrase != null && phasePhrase != _lastPhasePhrase;
    final canSpeakPhaseCue = nowMs - _lastPhaseCueAtMs >= _phaseCueMinGapMs;
    if (phasePhrase != null && phraseChanged && canSpeakPhaseCue) {
      _ttsService.speak(phasePhrase);
      _lastPhasePhrase = phasePhrase;
      _lastPhaseCueAtMs = nowMs;
    }

    if (liveFaultVoice != null && canSpeakLiveFault) {
      _lastFaultVoiceAtMs[liveFaultVoice] = nowMs;
      _liveFaultVoicesSpokenThisRep.add(liveFaultVoice);
      _ttsService.speak(liveFaultVoice);
    }

    _lastRepCount = repCount;
  }

  @override
  void dispose() {
    _ttsService.clearQueue();
    _ttsService.dispose();
  }

  String? _phasePhrase(ExerciseBase exercise) {
    if (exercise is! WallPushUp) {
      return null;
    }

    switch (exercise.wallPushUpState) {
      case WallPushUpState.standing:
        return 'Hạ xuống';
      case WallPushUpState.bottom:
      case WallPushUpState.ascending:
        return 'Đẩy ra';
      case WallPushUpState.descending:
        return null;
    }
  }

  bool _canSpeakLiveFaultVoice(String voice, int nowMs) {
    final lastSpokenAt = _lastFaultVoiceAtMs[voice] ?? 0;
    return nowMs - lastSpokenAt >= _faultCueCooldownMs;
  }

  bool _shouldSpeakCompletedRepCount({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    if (exercise is WallPushUp) {
      return repCount <= exercise.maxRep;
    }
    return true;
  }

  String? _highestPriorityLiveFaultVoice(Map<String, String> feedback) {
    final form = feedback['Form'] ?? '';
    if (form.contains('Chưa xuống đủ sâu')) return 'Xuống thấp hơn';
    if (form.contains('Vai, hông') || form.contains('thẳng hàng')) {
      return 'Giữ thân thẳng';
    }

    final body = feedback['Body'] ?? '';
    if (body.contains('Giữ vai') || body.contains('lệch')) {
      return 'Giữ thân thẳng';
    }

    final shoulders = feedback['Shoulders'] ?? '';
    if (shoulders.contains('Hạ vai') || shoulders.contains('nhún')) {
      return 'Hạ vai xuống';
    }

    final head = feedback['Head'] ?? '';
    if (head.contains('Kéo cằm') || head.contains('Đầu')) {
      return 'Kéo cằm về';
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

    if (exercise is WallPushUp && exercise.lastRepWasClean) {
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
    if (exercise is! WallPushUp || exercise.lastRepWasClean) {
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
    return switch (rawVoice.trim()) {
      'Giữ thân thẳng' => 'nhớ giữ thân thẳng',
      'Ép khuỷu tay vào' => 'nhớ ép khuỷu tay',
      'Chậm lại' => 'nhớ chậm lại',
      _ => null,
    };
  }
}
