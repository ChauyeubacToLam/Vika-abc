import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/jumping jack/jumping_jack.dart';
import 'package:vika/services/jumping_jack_voice_coach.dart';

class _FakeJumpingJackVoicePlayer implements JumpingJackVoicePlayer {
  final List<String> spoken = [];
  int clearQueueCount = 0;
  int clearPendingCount = 0;
  bool disposed = false;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) async {}

  @override
  void clearQueue() {
    clearQueueCount++;
    spoken.clear();
  }

  @override
  void clearPendingButKeepCurrent() {
    clearPendingCount++;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speaks jumping jack setup instructions only once before activation',
      () {
    final player = _FakeJumpingJackVoicePlayer();
    final coach = JumpingJackVoiceCoach(voicePlayer: player);
    final exercise = JumpingJack(maxRep: 30)..exerciseState = ExerciseState.notActivated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: false,
      feedback: const {},
    );
    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.spoken,
      [
        'common.thang_intro',
        'jumping_jack.setup_position',
        'jumping_jack.active_intro',
      ],
    );
  });

  test('speaks rep count and clean cue after a good rep', () {
    final player = _FakeJumpingJackVoicePlayer();
    final coach = JumpingJackVoiceCoach(voicePlayer: player);
    final exercise = JumpingJack(maxRep: 30)
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = true;

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.skip(1).take(2), ['1', 'common.correct']);
  });

  test('speaks rep count and correction after a faulty rep', () {
    final player = _FakeJumpingJackVoicePlayer();
    final coach = JumpingJackVoiceCoach(voicePlayer: player);
    final exercise = JumpingJack(maxRep: 30)
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = false
      ..lastRepTopVoiceMessage = 'Mở chân rộng hơn';

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.skip(1).take(2), ['1', 'Mở chân rộng hơn']);
  });

  test('does not speak live arm correction during open phase feedback', () {
    final player = _FakeJumpingJackVoicePlayer();
    final coach = JumpingJackVoiceCoach(voicePlayer: player);
    final exercise = JumpingJack(maxRep: 30)..exerciseState = ExerciseState.activated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Arms': 'Vươn tay cao hơn!'},
    );

    expect(player.spoken, ['Sẵn sàng']);
  });
}
