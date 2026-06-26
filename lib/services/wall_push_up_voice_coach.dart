import '../exercise/exercise_base.dart';
import '../exercise/wall_push_up/wall_push_up.dart';
import 'generic_exercise_voice_assets.dart';
import 'queued_asset_voice_player.dart';
import 'wall_push_up_voice_assets.dart';

abstract class WallPushUpVoicePlayer {
  Future<void> speak(String text);
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) {
    return Future<void>.value();
  }

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

class WallPushUpVoiceCoach implements ExerciseVoiceCoach {
  WallPushUpVoiceCoach({WallPushUpVoicePlayer? ttsService})
      : _ttsService = ttsService ?? _WallPushUpAssetVoicePlayer();

  static const int _phaseCueMinGapMs = 350;

  static const List<String> _readyCountdown = ['Sẵn sàng'];
  static const String _cleanRepCue = 'common.correct';

  final WallPushUpVoicePlayer _ttsService;

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
    final repIncreased = repCount > _lastRepCount;

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _ttsService.clearPendingButKeepCurrent();
        if (repIncreased) {
          _speakRepOutcome(
            exercise: exercise,
            repCount: repCount,
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
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    final phasePhrase = _phasePhrase(exercise);
    if (!_didAnnounceReady) {
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

    if (repIncreased) {
      _ttsService.clearPendingButKeepCurrent();
      _speakRepOutcome(
        exercise: exercise,
        repCount: repCount,
        includeCount: true,
      );
      if (!exercise.requestStop()) {
        _ttsService.speak('Hạ xuống');
      }
      _lastPhasePhrase = null;
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
    _ttsService.clearPendingButKeepCurrent();
    _ttsService.dispose();
  }

  void _speakSetup(ExerciseBase exercise) {
    if (_didSpeakSetup) {
      return;
    }
    final script =
        GenericExerciseVoiceAssets.scriptForExerciseName(exercise.exerciseName);
    _ttsService.speak(exercise.setupOrientationIntroVoiceKey);
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

  bool _shouldSpeakCompletedRepCount({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    if (exercise is WallPushUp) {
      return repCount <= exercise.maxRep;
    }
    return true;
  }

  void _speakRepOutcome({
    required ExerciseBase exercise,
    required int repCount,
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
    );
  }

  void _enqueuePostRepFeedbackIfAllowed({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    if (exercise is! WallPushUp || exercise.lastRepWasClean) {
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
