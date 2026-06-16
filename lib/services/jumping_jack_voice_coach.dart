import '../exercise/exercise_base.dart';
import '../exercise/jumping jack/jumping_jack.dart';
import 'jumping_jack_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class JumpingJackVoicePlayer {
  Future<void> speak(String text);
  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _JumpingJackAssetVoicePlayer implements JumpingJackVoicePlayer {
  _JumpingJackAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: JumpingJackVoiceAssets.files,
              assetSourcePrefix: JumpingJackVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: JumpingJackVoiceAssets.assetBundlePrefix,
              logTag: 'JumpingJackVoice',
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

class JumpingJackVoiceCoach implements ExerciseVoiceCoach {
  JumpingJackVoiceCoach({JumpingJackVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _JumpingJackAssetVoicePlayer();

  static const int _liveFaultCooldownMs = 2500;
  static const int _postRepCueCooldownReps = 2;

  final JumpingJackVoicePlayer _voicePlayer;
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
      _speakSetup();
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

  void _speakSetup() {
    if (_didSpeakSetup) return;

    _voicePlayer.speak('jumping_jack.setup_intro');
    _voicePlayer.speak('jumping_jack.setup_position');
    _voicePlayer.speak('jumping_jack.active_intro');
    _didSpeakSetup = true;
  }

  void _speakRepOutcome(ExerciseBase exercise, int repCount) {
    _voicePlayer.speak('$repCount');

    if (exercise is JumpingJack && exercise.lastRepWasClean) {
      _voicePlayer.speak('jumping_jack.good_clean');
      return;
    }

    if (exercise is! JumpingJack) return;

    final voice = exercise.lastRepTopVoiceMessage;
    if (voice == null || voice.isEmpty) return;

    final lastRep = _lastPostRepVoiceRep[voice] ?? -99;
    if (repCount - lastRep < _postRepCueCooldownReps) return;

    _lastPostRepVoiceRep[voice] = repCount;
    _voicePlayer.speak(voice);
  }

  String? _liveFaultVoice(Map<String, String> feedback) {
    final arms = feedback['Arms'] ?? '';
    if (arms.contains('cao') || arms.contains('Duỗi')) {
      return 'Vươn tay cao hơn';
    }

    final legs = feedback['Legs'] ?? '';
    if (legs.contains('rộng')) {
      return 'Mở chân rộng hơn';
    }

    final tempo = feedback['Tempo'] ?? '';
    if (tempo.contains('Chậm') || tempo.contains('nhanh')) {
      return 'Chậm lại, giữ tư thế';
    }
    if (tempo.contains('Nhanh hơn')) {
      return 'Nhanh hơn một chút';
    }

    return null;
  }

  @override
  void dispose() {
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
