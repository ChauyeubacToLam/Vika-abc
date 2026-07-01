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
  void dispose() {
    events.add('dispose');
  }

  @override
  Future<void> speak(String text) async {
    events.add('speak:$text');
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final readyEvents = [
    'speak:3',
    'speak:2',
    'speak:1',
    'speak:Sẵn sàng',
    'speak:Xuống',
  ];

  test('Squat says "Sẵn sàng" then "Xuống" once on activation', () {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    expect(player.events, readyEvents);

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    expect(player.events, readyEvents);
  });

  test('Squat does not repeat "Xuống" on the next standing frame after ready',
      () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.events,
      readyEvents,
    );
  });

  test('Squat says "Xuống" again after rep count when user returns to standing',
      () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.events,
      [
        ...readyEvents,
        'clearPendingButKeepCurrent',
        'speak:1',
        'speak:common.correct',
        'speak:Xuống',
      ],
    );
  });

  test('Squat says "Đứng lên" as soon as the bottom hold is complete',
      () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    squat.tempoMetric.onStateTransition(
      SquatState.descending,
      SquatState.bottom,
      0,
    );
    squat.squatState = SquatState.bottom;
    squat.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(650);
    squat.resultIssues.instructions.clear();
    squat.resultIssues.addInstruction(
      squat.currentPhaseKey,
      'Status',
      Squat.ascendingStatus,
    );

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.events,
      [
        ...readyEvents,
        'clearPendingButKeepCurrent',
        'speak:Đứng lên',
      ],
    );
  });

  test(
      'Squat still says "Đứng lên" when hold is complete even if status text is stale',
      () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    squat.tempoMetric.onStateTransition(
      SquatState.descending,
      SquatState.bottom,
      0,
    );
    squat.squatState = SquatState.bottom;
    squat.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(650);
    squat.resultIssues.instructions.clear();
    squat.resultIssues.addInstruction(
      squat.currentPhaseKey,
      'Status',
      Squat.bottomHoldStatus(0.1),
    );

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.events,
      [
        ...readyEvents,
        'clearPendingButKeepCurrent',
        'speak:Đứng lên',
      ],
    );
  });

  test('Squat does not say "Đứng lên" when the user starts ascending too early',
      () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    squat.tempoMetric.onStateTransition(
      SquatState.descending,
      SquatState.bottom,
      0,
    );
    squat.tempoMetric.onStateTransition(
      SquatState.bottom,
      SquatState.ascending,
      300,
    );
    squat.squatState = SquatState.ascending;
    squat.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(300);
    squat.resultIssues.instructions.clear();
    squat.resultIssues.addInstruction(
      squat.currentPhaseKey,
      'Status',
      Squat.ascendingStatus,
    );

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.events,
      [
        ...readyEvents,
      ],
    );
  });

  test('Squat does not speak live trunk or depth correction during a rep',
      () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {
        'Back': 'Chest up!',
        'Depth': 'Go Lower',
      },
    );

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {},
    );

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {
        'Sync': 'Drive chest up!',
      },
    );

    expect(
      player.events,
      readyEvents,
    );
  });

  test('Squat does not speak live depth correction during a rep', () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {
        'Depth': 'Go Lower',
      },
    );

    expect(player.events, readyEvents);
  });

  test('Squat prefixes post-rep cues after every faulty rep', () {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    squat
      ..lastRepWasClean = false
      ..lastRepTopVoiceMessage = 'Giữ gót chân';

    coach.processFrame(
      exercise: squat,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    coach.processFrame(
      exercise: squat,
      repCount: 2,
      hasPose: true,
      feedback: const {},
    );

    coach.processFrame(
      exercise: squat,
      repCount: 3,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.events,
      [
        ...readyEvents,
        'clearPendingButKeepCurrent',
        'speak:1',
        'speak:nhớ giữ gót chân',
        'clearPendingButKeepCurrent',
        'speak:2',
        'speak:nhớ giữ gót chân',
        'clearPendingButKeepCurrent',
        'speak:3',
        'speak:nhớ giữ gót chân',
      ],
    );
  });

  test('Squat does not count a new rep after the set is completed', () {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15);

    coach.processFrame(
      exercise: squat,
      repCount: 5,
      hasPose: false,
      feedback: const {},
    );

    squat.exerciseState = ExerciseState.completed;
    coach.processFrame(
      exercise: squat,
      repCount: 6,
      hasPose: true,
      feedback: const {},
    );

    expect(
      player.events,
      [
        'clearPendingButKeepCurrent',
        'speak:Hoàn thành bài tập',
      ],
    );
    expect(player.events, isNot(contains('speak:6')));
  });

  test(
      'Squat lets the bottom release cue win over "Ưỡn ngực lên" once hold is complete',
      () async {
    final player = _FakeSquatVoicePlayer();
    final coach = SquatVoiceCoach(ttsService: player);
    final squat = Squat(maxRep: 15)..exerciseState = ExerciseState.activated;

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

    squat.tempoMetric.onStateTransition(
      SquatState.descending,
      SquatState.bottom,
      0,
    );
    squat.squatState = SquatState.bottom;
    squat.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(650);
    squat.resultIssues.instructions.clear();
    squat.resultIssues.addInstruction(
      squat.currentPhaseKey,
      'Status',
      Squat.bottomHoldStatus(0.1),
    );

    await Future<void>.delayed(const Duration(milliseconds: 275));

    coach.processFrame(
      exercise: squat,
      repCount: squat.repCount,
      hasPose: true,
      feedback: const {
        'Back': 'Chest up!',
      },
    );

    expect(
      player.events,
      [
        ...readyEvents,
        'clearPendingButKeepCurrent',
        'speak:Đứng lên',
      ],
    );
  });
}
