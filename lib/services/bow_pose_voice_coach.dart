import '../exercise/bow_pose/bow_pose.dart';
import '../exercise/exercise_base.dart';
import 'bow_pose_voice_assets.dart';
import 'generic_exercise_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class BowPoseVoicePlayer {
  Future<void> speak(String text);
  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _BowPoseAssetVoicePlayer implements BowPoseVoicePlayer {
  _BowPoseAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: {
                ...GenericExerciseVoiceAssets.commonFiles,
                ...BowPoseVoiceAssets.files,
              },
              assetSourcePrefix: BowPoseVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: BowPoseVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
              logTag: 'BowPoseVoice',
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

class BowPoseVoiceCoach implements ExerciseVoiceCoach {
  BowPoseVoiceCoach({BowPoseVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _BowPoseAssetVoicePlayer();

  static const int _liveFaultCooldownMs = 3000;
  static const int _postRepCueCooldownReps = 2;

  final BowPoseVoicePlayer _voicePlayer;
  final Map<String, int> _lastPostRepVoiceRep = {};

  int _lastRepCount = 0;
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

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _lastRepCount = repCount;
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
      _speakRepOutcome(exercise, repCount);
      _lastRepCount = repCount;
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

  void _speakRepOutcome(ExerciseBase exercise, int repCount) {
    _voicePlayer.speak('$repCount');

    if (exercise is BowPose && exercise.lastRepWasClean) {
      _voicePlayer.speak('bow_pose.hold_good');
      return;
    }

    _speakCorrection(exercise, repCount);
  }

  void _speakCorrection(ExerciseBase exercise, int repNumber) {
    if (exercise is! BowPose) return;

    final voice = exercise.lastRepTopVoiceMessage;
    if (voice == null || voice.isEmpty) return;

    final lastRep = _lastPostRepVoiceRep[voice] ?? -99;
    if (repNumber - lastRep < _postRepCueCooldownReps) return;

    _lastPostRepVoiceRep[voice] = repNumber;
    _voicePlayer.speak(voice);
  }

  String? _liveFaultVoice(Map<String, String> feedback) {
    final connection = feedback['Connection'] ?? '';
    if (connection.contains('Tuột')) return 'Nắm chân chắc hơn';

    final timer = feedback['Timer'] ?? '';
    if (timer.contains('Giữ')) return null;

    final thigh = feedback['Thigh'] ?? '';
    if (thigh.contains('Kéo đùi')) {
      return 'Nâng đùi cao hơn nếu lưng vẫn thoải mái';
    }

    final chest = feedback['Chest'] ?? '';
    if (chest.contains('Mở căng')) return 'Mở ngực thêm một chút';

    final stability = feedback['StabilityScore'] ?? '';
    if (stability.isNotEmpty && stability != 'N/A') {
      final score = int.tryParse(stability.replaceAll('%', '').trim());
      if (score != null && score < 50) return 'Giữ người yên hơn';
    }

    return null;
  }

  @override
  void dispose() {
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
