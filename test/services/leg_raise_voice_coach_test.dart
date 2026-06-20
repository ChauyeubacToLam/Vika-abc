import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/8.Leg Raises (Supine)/leg_raise.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/services/leg_raise_voice_coach.dart';

class _FakeLegRaiseVoicePlayer implements LegRaiseVoicePlayer {
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

  test('speaks leg raises setup instructions only once before activation', () {
    final player = _FakeLegRaiseVoicePlayer();
    final coach = LegRaiseVoiceCoach(voicePlayer: player);
    final exercise = LegRaise()..exerciseState = ExerciseState.notActivated;

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
        'leg_raises.setup_position',
        'leg_raises.active_intro',
      ],
    );
  });

  test('speaks rep count and clean cue after a good rep', () {
    final player = _FakeLegRaiseVoicePlayer();
    final coach = LegRaiseVoiceCoach(voicePlayer: player);
    final exercise = LegRaise()
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = true;

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.take(2), ['1', 'leg_raises.good_clean']);
  });

  test('speaks rep count and correction after a faulty counted rep', () {
    final player = _FakeLegRaiseVoicePlayer();
    final coach = LegRaiseVoiceCoach(voicePlayer: player);
    final exercise = LegRaise()
      ..exerciseState = ExerciseState.activated
      ..lastRepWasClean = false
      ..lastRepTopVoiceMessage = 'Hạ chân chậm lại';

    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.take(2), ['1', 'Hạ chân chậm lại']);
  });

  test('speaks no-count and correction after a blocked attempt', () {
    final player = _FakeLegRaiseVoicePlayer();
    final coach = LegRaiseVoiceCoach(voicePlayer: player);
    final exercise = LegRaise()
      ..exerciseState = ExerciseState.activated
      ..invalidAttemptCount = 1
      ..lastRepWasClean = false
      ..lastRepTopVoiceMessage = 'Duỗi thẳng đầu gối';

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );

    expect(player.spoken.take(2), ['Lần này chưa tính', 'Duỗi thẳng đầu gối']);
  });

  test('speaks live setup correction from feedback', () {
    final player = _FakeLegRaiseVoicePlayer();
    final coach = LegRaiseVoiceCoach(voicePlayer: player);
    final exercise = LegRaise()..exerciseState = ExerciseState.activated;

    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {'Arms': 'Duỗi thẳng hai tay, khép sát hông.'},
    );

    expect(player.spoken, contains('Duỗi tay sát hông'));
  });
}
