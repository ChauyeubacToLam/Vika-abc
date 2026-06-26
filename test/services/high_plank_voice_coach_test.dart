import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/3.High Plank/high_plank.dart';
import 'package:vika/exercise/3.High Plank/metrics/high_plank_metric_base.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/services/high_plank_voice_coach.dart';

class _FakeHighPlankVoicePlayer implements HighPlankVoicePlayer {
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

  test('speaks high plank setup instructions only once before activation', () {
    final player = _FakeHighPlankVoicePlayer();
    final coach = HighPlankVoiceCoach(voicePlayer: player);
    final exercise =
        HighPlank(maxSeconds: 30)..exerciseState = ExerciseState.notActivated;

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
        'common.ngang_intro',
        'high_plank.setup_position',
        'high_plank.active_intro',
      ],
    );
  });

  test('speaks a correction when hold timer stops because form drops', () {
    final player = _FakeHighPlankVoicePlayer();
    final coach = HighPlankVoiceCoach(voicePlayer: player);
    final exercise = HighPlank(maxSeconds: 10)
      ..exerciseState = ExerciseState.activated
      ..state = HighPlankState.dropping
      ..lastHoldFaultVoiceMessage = 'Siết chặt bụng, nâng hông lên một chút';

    coach.processFrame(
      exercise: exercise,
      repCount: 4,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.spoken,
      contains('Siết chặt bụng, nâng hông lên một chút'),
    );
  });

  test('speaks hold good once when ten second target is reached', () {
    final player = _FakeHighPlankVoicePlayer();
    final coach = HighPlankVoiceCoach(voicePlayer: player);
    final exercise = HighPlank(maxSeconds: 10)
      ..exerciseState = ExerciseState.activated;

    exercise.timerMetric.totalHoldingTimeMs = 10000;

    coach.processFrame(
      exercise: exercise,
      repCount: 10,
      hasPose: true,
      feedback: const {},
    );
    coach.processFrame(
      exercise: exercise,
      repCount: 10,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.spoken.where((text) => text == 'common.correct'),
      hasLength(1),
    );
  });
}
