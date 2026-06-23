import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/plank/plank.dart';
import 'package:vika/services/plank_voice_coach.dart';

class _FakePlankVoicePlayer implements PlankVoicePlayer {
  final List<String> spoken = [];
  int clearQueueCount = 0;
  int clearPendingCount = 0;
  bool disposed = false;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

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

  test('speaks plank setup instructions only once before activation', () {
    final player = _FakePlankVoicePlayer();
    final coach = PlankVoiceCoach(voicePlayer: player);
    final exercise = Plank(maxRep: 5)..exerciseState = ExerciseState.notActivated;

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
        'plank.setup_intro',
        'plank.setup_position',
        'plank.active_intro',
      ],
    );
  });

  test('speaks a correction when hold timer stops because form drops', () {
    final player = _FakePlankVoicePlayer();
    final coach = PlankVoiceCoach(voicePlayer: player);
    final exercise = Plank(maxRep: 5)
      ..exerciseState = ExerciseState.activated
      ..previousPlankState = PlankState.holding
      ..plankState = PlankState.setup
      ..lastHoldFaultVoiceMessage = 'Gồng cơ bụng, nâng hông lên';

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken, contains('Gồng cơ bụng, nâng hông lên'));
  });

  test('speaks hold good when a plank hold completes', () {
    final player = _FakePlankVoicePlayer();
    final coach = PlankVoiceCoach(voicePlayer: player);
    final exercise = Plank(maxRep: 5)..exerciseState = ExerciseState.activated;

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.take(1), ['plank.hold_good']);
  });
}
