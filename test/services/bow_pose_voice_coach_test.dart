import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/bow_pose/bow_pose.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/services/bow_pose_voice_coach.dart';

class _FakeBowPoseVoicePlayer implements BowPoseVoicePlayer {
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

  test('speaks bow pose setup instructions only once before activation', () {
    final player = _FakeBowPoseVoicePlayer();
    final coach = BowPoseVoiceCoach(voicePlayer: player);
    final exercise = BowPose()..exerciseState = ExerciseState.notActivated;

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
        'bow_pose.setup_intro',
        'bow_pose.setup_position',
        'bow_pose.active_intro',
      ],
    );
  });

  test('speaks rep count and good hold cue after a clean rep', () {
    final player = _FakeBowPoseVoicePlayer();
    final coach = BowPoseVoiceCoach(voicePlayer: player);
    final exercise = BowPose()
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = true;

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.take(2), ['1', 'bow_pose.hold_good']);
  });

  test('speaks rep count and correction after a faulty counted rep', () {
    final player = _FakeBowPoseVoicePlayer();
    final coach = BowPoseVoiceCoach(voicePlayer: player);
    final exercise = BowPose()
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = false
      ..lastRepTopVoiceMessage = 'Mở ngực thêm một chút';

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.take(2), ['1', 'Mở ngực thêm một chút']);
  });

  test('speaks live correction from bow pose feedback', () {
    final player = _FakeBowPoseVoicePlayer();
    final coach = BowPoseVoiceCoach(voicePlayer: player);
    final exercise = BowPose()..exerciseState = ExerciseState.activated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Connection': 'Tuột tay rồi!'},
    );

    expect(player.spoken, contains('Nắm chân chắc hơn'));
  });
}
