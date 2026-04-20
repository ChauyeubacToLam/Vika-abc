import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/services/squat_voice_coach.dart';

class _FakeSquatVoicePlayer implements SquatVoicePlayer {
  final List<String> events = [];

  @override
  void clearPendingButKeepCurrent() {
    events.add('clearPendingButKeepCurrent');
  }

  @override
  void clearQueue() {
    events.add('clearQueue');
  }

  @override
  Future<void> speak(String text) async {
    events.add('speak:$text');
  }
}

void main() {
  test('Squat ready cue says "Sẵn sàng" exactly once on activation', () {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat()..exerciseState = ExerciseState.activated;

    squat.resultIssues.addInstruction(
      squat.currentPhaseKey,
      'Status',
      Squat.standingStatus,
    );

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    expect(player.events, ['clearQueue', 'speak:Sẵn sàng']);

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    expect(player.events, ['clearQueue', 'speak:Sẵn sàng']);
  });
}
