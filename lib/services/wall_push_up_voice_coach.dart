import '../exercise/exercise_base.dart';
import '../exercise/wall_push_up/wall_push_up.dart';
import 'generic_exercise_voice_assets.dart';
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
              assetMap: {
                ...GenericExerciseVoiceAssets.commonFiles,
                ...WallPushUpVoiceAssets.files,
              },
              assetSourcePrefix: WallPushUpVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: WallPushUpVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
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

  static const List<String> _readyCountdown = ['Sẵn sàng'];
  static const String _cleanRepCue = 'wall_push_up.good_clean';

  final WallPushUpVoicePlayer _ttsService;

  String? _lastPhasePhrase;
  int _lastRepCount = 0;
  int _lastPhaseCueAtMs = 0;
  bool _didAnnounceSetComplete = false;
  bool _didAnnounceReady = false;
  bool _didSpeakSetup = false;
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
        _ttsService.clearQueue();
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

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _liveFaultVoicesSpokenThisRep.clear();
      _lastPhasePhrase = null;
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
      _ttsService.clearQueue();
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

  void _speakSetup(ExerciseBase exercise) {
    if (_didSpeakSetup) {
      return;
    }
    final script =
        GenericExerciseVoiceAssets.scriptForExerciseName(exercise.exerciseName);
    _ttsService.speak(script.setupIntroKey);
    _ttsService.speak(script.cueKey('setup_position'));
    _ttsService.speak(script.cueKey('active_intro'));
    _didSpeakSetup = true;
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
    if (form.contains('Wall Push Up')) return 'Đứng nghiêng vào tường';

    final body = feedback['Body'] ?? '';
    if (body.contains('Giữ vai') || body.contains('lệch')) {
      return 'Giữ thân thẳng';
    }

    final arms = feedback['Arms'] ?? '';
    if (arms.contains('Ép khuỷu') || arms.contains('Khuỷu tay')) {
      return 'Ép khuỷu tay vào';
    }

    final shoulders = feedback['Shoulders'] ?? '';
    if (shoulders.contains('Hạ vai') || shoulders.contains('nhún')) {
      return 'Hạ vai xuống';
    }

    final neck = feedback['Neck'] ?? '';
    if (neck.contains('Giữ cổ') || neck.contains('ngửa')) {
      return 'Giữ cổ thẳng';
    }

    final head = feedback['Head'] ?? '';
    if (head.contains('Kéo cằm') || head.contains('Đầu')) {
      return 'Kéo cằm về';
    }

    final feet = feedback['Feet'] ?? '';
    if (feet.contains('Kiễng gót')) return 'Kiễng gót chân lên';
    if (feet.contains('Giữ chân') || feet.contains('Chân hơi')) {
      return 'Giữ chân cố định';
    }

    final wall = feedback['Wall'] ?? '';
    if (wall.contains('Tay bị') || wall.contains('giữ tay')) {
      return 'Chống tay vào tường';
    }

    final tempo = feedback['Tempo'] ?? '';
    if (tempo.contains('Hạ chậm')) return 'Chậm lại';

    final setup = feedback['Setup'] ?? '';
    if (setup.contains('tay ngang vai') ||
        setup.contains('tường') ||
        setup.contains('nghiêng người')) {
      return 'Đứng nghiêng vào tường';
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

    _lastPostRepVoiceRep[voice] = repCount;
    _ttsService.speak(voice);
  }

  String? _postRepVoice(String rawVoice) {
    return switch (rawVoice.trim()) {
      'Giữ thân thẳng' => 'Giữ thân thẳng',
      'Ép khuỷu tay vào' => 'Ép khuỷu tay vào',
      'Chậm lại' => 'Chậm lại',
      'Hạ vai xuống' => 'Hạ vai xuống',
      'Kéo cằm về' => 'Kéo cằm về',
      'Xuống thấp hơn' => 'Xuống thấp hơn',
      'Giữ cổ thẳng' => 'Giữ cổ thẳng',
      'Giữ chân cố định' => 'Giữ chân cố định',
      'Kiễng gót chân lên' => 'Kiễng gót chân lên',
      'Chống tay vào tường' => 'Chống tay vào tường',
      'Đứng nghiêng vào tường' => 'Đứng nghiêng vào tường',
      _ => null,
    };
  }
}
