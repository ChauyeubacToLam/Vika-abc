import '../exercise/exercise_base.dart';
import '../exercise/plank/plank.dart';
import 'generic_exercise_voice_assets.dart';
import 'plank_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class PlankVoicePlayer {
  Future<void> speak(String text);
  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _PlankAssetVoicePlayer implements PlankVoicePlayer {
  _PlankAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: {
                ...GenericExerciseVoiceAssets.commonFiles,
                ...PlankVoiceAssets.files,
              },
              assetSourcePrefix: PlankVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: PlankVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
              logTag: 'PlankVoice',
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

class PlankVoiceCoach implements ExerciseVoiceCoach {
  PlankVoiceCoach({PlankVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _PlankAssetVoicePlayer();

  static const int _faultCueCooldownMs = 2500;

  final PlankVoicePlayer _voicePlayer;

  int _lastRepCount = 0;
  int _lastFaultCueAtMs = 0;
  bool _didSpeakSetup = false;
  bool _didAnnounceReady = false;
  bool _didAnnounceSetComplete = false;
  String? _lastFaultVoice;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repIncreased = repCount > _lastRepCount;

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _voicePlayer.clearQueue();
        if (repIncreased) {
          _voicePlayer.speak('plank.hold_good');
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
      _voicePlayer.clearQueue();
      _voicePlayer.speak('Sẵn sàng');
      _didAnnounceReady = true;
    }

    if (repIncreased) {
      _voicePlayer.clearQueue();
      _voicePlayer.speak('plank.hold_good');
      _lastRepCount = repCount;
      return;
    }

    final faultVoice = _faultVoice(exercise, feedback);
    final holdStopped = exercise is Plank &&
        exercise.previousPlankState == PlankState.holding &&
        exercise.plankState == PlankState.setup;
    final shouldSpeakFault = faultVoice != null &&
        holdStopped &&
        (faultVoice != _lastFaultVoice ||
            nowMs - _lastFaultCueAtMs >= _faultCueCooldownMs);

    if (shouldSpeakFault) {
      _lastFaultVoice = faultVoice;
      _lastFaultCueAtMs = nowMs;
      _voicePlayer.clearPendingButKeepCurrent();
      _voicePlayer.speak(faultVoice);
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

  String? _faultVoice(
    ExerciseBase exercise,
    Map<String, String> feedback,
  ) {
    if (exercise is Plank) {
      final latestHoldBreak = exercise.lastHoldFaultVoiceMessage;
      if (latestHoldBreak != null && latestHoldBreak.isNotEmpty) {
        return latestHoldBreak;
      }
    }

    final arms = feedback['Arms'] ?? '';
    if (arms.contains('cẳng tay')) return 'Chống bằng cẳng tay';

    final body = feedback['Body'] ?? '';
    if (body.contains('thẳng')) return 'Giữ thân người thẳng';

    final knees = feedback['Knees'] ?? '';
    if (knees.contains('gối')) return 'Thẳng đầu gối ra';

    final back = feedback['Back'] ?? '';
    if (back.contains('võng') || back.contains('bụng')) {
      return 'Gồng cơ bụng, nâng hông lên';
    }
    if (back.contains('cao hông') || back.contains('Hông quá cao')) {
      return 'Hạ hông xuống, giữ thân thẳng';
    }

    final neck = feedback['Neck'] ?? '';
    if (neck.contains('cúi') || neck.contains('ngẩng')) {
      return 'Giữ cổ thẳng, nhìn xuống nhẹ';
    }

    return null;
  }

  @override
  void dispose() {
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
