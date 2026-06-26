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

  test('speaks wall push up setup instructions only once before activation',
      () {
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
        'common.thang_intro',
        'wall_push_up.setup_position',
        'wall_push_up.active_intro',
      ],
    );
  });

  test('does not speak live wall push up faults before a rep finishes', () {
    final player = _FakeWallPushUpVoicePlayer();
    final coach = WallPushUpVoiceCoach(ttsService: player);
    final exercise = WallPushUp()..exerciseState = ExerciseState.activated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Arms': 'Ép khuỷu tay sát người hơn!'},
    );

    expect(player.spoken, ['Sẵn sàng', 'Hạ xuống']);
  });

  test('speaks rep count and clean cue after a good rep', () {
    final player = _FakeWallPushUpVoicePlayer();
    final coach = WallPushUpVoiceCoach(ttsService: player);
    final exercise = WallPushUp()
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = true;

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.skip(2).take(2), ['1', 'common.correct']);
  });

  test('speaks rep count and correction after a faulty rep', () {
    final player = _FakeWallPushUpVoicePlayer();
    final coach = WallPushUpVoiceCoach(ttsService: player);
    final exercise = WallPushUp()
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = false
      ..lastRepTopVoiceMessage = 'Ép khuỷu tay vào';

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Arms': 'Ép khuỷu tay sát người hơn!'},
    );
    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.skip(2).take(2), ['1', 'Ép khuỷu tay vào']);
  });

  test('speaks final rep count, clean cue, and completion', () {
    final player = _FakeWallPushUpVoicePlayer();
    final coach = WallPushUpVoiceCoach(ttsService: player);
    final exercise = WallPushUp(maxRep: 1)
      ..exerciseState = ExerciseState.completed
      ..lastRepWasClean = true;

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.spoken,
      ['1', 'common.correct', 'Hoàn thành bài tập'],
    );
  });
}
