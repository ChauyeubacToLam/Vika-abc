import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/wall_push_up/wall_push_up.dart';
import 'package:vika/services/wall_push_up_voice_coach.dart';

class _FakeWallPushUpVoicePlayer implements WallPushUpVoicePlayer {
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

  test('speaks wall push up setup instructions only once before activation', () {
    final player = _FakeWallPushUpVoicePlayer();
    final coach = WallPushUpVoiceCoach(ttsService: player);
    final exercise = WallPushUp()..exerciseState = ExerciseState.notActivated;

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
        'wall_push_up.setup_intro',
        'wall_push_up.setup_position',
        'wall_push_up.active_intro',
      ],
    );
  });

  test('maps live wall push up faults to bundled voice cues', () {
    final player = _FakeWallPushUpVoicePlayer();
    final coach = WallPushUpVoiceCoach(ttsService: player);
    final exercise = WallPushUp()..exerciseState = ExerciseState.activated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Arms': 'Ép khuỷu tay sát người hơn!'},
    );

    expect(player.spoken, contains('Ép khuỷu tay vào'));
  });
}
