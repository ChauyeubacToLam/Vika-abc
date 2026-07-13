import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/voice/earcon_player.dart';
import 'package:vika/voice/policy_voice_coach.dart';
import 'package:vika/voice/voice_coach.dart';
import 'package:vika/voice/voice_content.dart';
import 'package:vika/voice/voice_policy.dart';
import 'package:vika/voice/voice_sink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queued countdown numeral is skipped after its earned second passes',
      () {
    final sink = _DeferredVoiceSink();
    final exercise = _HoldExercise(target: 20, maxHolds: 1);
    final coach = _coach(sink: sink);
    addTearDown(coach.dispose);

    _drive(coach, exercise, ms: 0);
    sink.clearAll();
    exercise.live = 15;
    _drive(coach, exercise, ms: 15000);
    expect(sink.pendingKeys, contains('5'));

    // Simulate a long line occupying the real FIFO. The hold advances before
    // the numeral reaches dequeue, so its policy-supplied relevance check dies.
    exercise.live = 16;
    sink.drain();
    expect(sink.played, isNot(contains('5')));
    expect(sink.skipped, contains('5'));
  });

  test('short-hold guards separate halfway, final-10, and countdown', () {
    final fifteen = _runHoldTo(target: 15, seconds: 10);
    expect(fifteen, contains('common.time.halfway'));
    expect(fifteen, isNot(contains('common.time.10s_left')));
    expect(fifteen.where(_isNumeral), isEmpty);

    final twenty = _runHoldTo(target: 20, seconds: 15);
    expect(twenty, contains('common.time.halfway'));
    expect(twenty, isNot(contains('common.time.10s_left')));
    expect(twenty, contains('5'));

    final thirty = _runHoldTo(target: 30, seconds: 20);
    expect(thirty, contains('common.time.halfway'));
    expect(thirty, contains('common.time.10s_left'));
    expect(thirty.where(_isNumeral), isEmpty);
  });

  test('every hold milestone queues exactly one forced outcome follow-up', () {
    final halfway = _runHoldTo(target: 20, seconds: 10);
    expect(halfway, hasLength(2));
    expect(halfway, contains('common.time.halfway'));

    final twoMilestones = _runHoldTo(target: 30, seconds: 20);
    expect(twoMilestones, hasLength(4));
    expect(twoMilestones, contains('common.time.halfway'));
    expect(twoMilestones, contains('common.time.10s_left'));
    expect(twoMilestones, contains('common.hold_push'));
  });

  test('hold completion tone does not duplicate on final set edge', () {
    final sink = _DeferredVoiceSink();
    final earcon = _RecordingEarconSink();
    final exercise = _HoldExercise(target: 20, maxHolds: 1)..isFinalSet = true;
    final coach = _coach(sink: sink, earcon: earcon);
    addTearDown(coach.dispose);

    _drive(coach, exercise, ms: 0);
    sink.clearAll();
    exercise
      ..repCount = 1
      ..exerciseState = ExerciseState.completed;
    _drive(coach, exercise, ms: 20000);
    expect(earcon.endToneCalls, 1);
    expect(sink.pendingKeys, contains('1'));
    expect(sink.pendingKeys, contains('common.exercise_complete'));
    expect(sink.pendingKeys, isNot(contains('common.set_complete')));
  });

  test('rest edge tones once and re-arms the existing 3 2 1 countdown', () {
    final sink = _DeferredVoiceSink();
    final earcon = _RecordingEarconSink();
    final exercise = _HoldExercise(target: 20, maxHolds: 2);
    final coach = _coach(sink: sink, earcon: earcon);
    addTearDown(coach.dispose);

    _drive(coach, exercise, ms: 0);
    sink.clearAll();

    exercise
      ..repCount = 1
      ..phase = 'resting';
    _drive(coach, exercise, ms: 20000);
    // The landed-hold registration belongs to the completion edge, before the
    // rest-end ritual. Clear it so this assertion scopes the timed edge onward.
    sink.clearAll();
    exercise
      ..phase = 'reArming'
      ..reArming = true;
    _drive(coach, exercise, ms: 25000);
    expect(earcon.restEndToneCalls, 1);
    expect(sink.pendingKeys, isEmpty);
    expect(
      exercise.isGuidanceGraceActive(GuidanceClass.bodyInFrame),
      isFalse,
    );

    exercise.reArmElapsedMs = 800;
    _drive(coach, exercise, ms: 25800);
    exercise.reArmElapsedMs = 1600;
    _drive(coach, exercise, ms: 26600);
    expect(sink.pendingKeys, ['3', '2']);

    // A pose break drops the perishable queue and the next confirmed hold
    // starts from ba again.
    exercise.reArmElapsedMs = null;
    _drive(coach, exercise, ms: 26800);
    expect(sink.pendingKeys, isEmpty);
    exercise.reArmElapsedMs = 800;
    _drive(coach, exercise, ms: 27600);
    expect(sink.pendingKeys, ['3']);

    exercise.reArmElapsedMs = 2400;
    _drive(coach, exercise, ms: 29200);
    exercise
      ..phase = 'holding'
      ..reArming = false
      ..reArmElapsedMs = null;
    _drive(coach, exercise, ms: 30000);
    expect(sink.pendingKeys, ['3', '2', '1']);
    expect(sink.pendingKeys, isNot(contains('high_plank.setup_position')));
    expect(sink.stopCalls, 0);
    expect(earcon.restEndToneCalls, 1);
  });

  test('re-arm setup signal stays quiet when fast and re-tells once when stuck',
      () async {
    final sink = _DeferredVoiceSink();
    final exercise = _HoldExercise(target: 20, maxHolds: 2);
    final coach = _coach(sink: sink);
    addTearDown(coach.dispose);

    _drive(coach, exercise, ms: 0);
    await Future<void>.delayed(Duration.zero);
    sink.clearAll();
    exercise
      ..phase = 'reArming'
      ..reArming = true;

    // A fast attempt leaves setupPosition before the delayed re-tell is due.
    for (var i = 1; i <= 50; i++) {
      exercise.publishGuidanceSignal(
        const GuidanceSignal.setupPosition(),
        publishFeedback: false,
      );
      _drive(coach, exercise, ms: i * 100);
    }
    expect(sink.pendingKeys, isEmpty);

    // The holdStill interval is a real absent edge for the setup latch.
    for (var i = 51; i <= 80; i++) {
      exercise.publishGuidanceSignal(
        const GuidanceSignal.holdStill(),
        publishFeedback: false,
      );
      _drive(coach, exercise, ms: i * 100);
    }

    // A later re-arm that stays out of position earns one delayed re-tell.
    for (var i = 81; i <= 250; i++) {
      exercise.publishGuidanceSignal(
        const GuidanceSignal.setupPosition(),
        publishFeedback: false,
      );
      _drive(coach, exercise, ms: i * 100);
    }
    expect(
      sink.pendingKeys.where((key) => key == 'high_plank.setup_position'),
      hasLength(1),
    );
  });

  test('rep-counted hold fails loud on a non-canonical phase key', () {
    final sink = _DeferredVoiceSink();
    final exercise = _HoldExercise(target: 20, maxHolds: 1)..phase = 'hovering';
    final coach = _coach(sink: sink);
    addTearDown(coach.dispose);

    expect(
      () => _drive(coach, exercise, ms: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rep-counted hold fails loud when milestone outcome pools are empty',
      () {
    final sink = _DeferredVoiceSink();
    final exercise = _HoldExercise(target: 20, maxHolds: 1);
    final coach = PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repCountedHold,
        slug: 'high_plank',
        praisePool: const <String>[],
        hustlePool: const <String>[],
      ),
      coach: VoiceCoach(sink: sink),
      earcon: _RecordingEarconSink(),
      targetReps: 1,
      countsByRepNumber: true,
    );
    addTearDown(coach.dispose);

    expect(
      () => _drive(coach, exercise, ms: 0),
      throwsA(isA<AssertionError>()),
    );
  });
}

List<String> _runHoldTo({required double target, required double seconds}) {
  final sink = _DeferredVoiceSink();
  final coach = _coach(sink: sink);
  final exercise = _HoldExercise(target: target, maxHolds: 1);
  _drive(coach, exercise, ms: 0);
  sink.clearAll();

  // Keep crossings realistic so each threshold gets its own frame.
  for (var second = 1.0; second <= seconds; second += 1) {
    exercise.live = second;
    _drive(coach, exercise, ms: (second * 1000).round());
  }
  final keys = List<String>.from(sink.pendingKeys);
  coach.dispose();
  return keys;
}

bool _isNumeral(String key) => const {'1', '2', '3', '4', '5'}.contains(key);

PolicyVoiceCoach _coach({
  required VoiceSink sink,
  EarconSink? earcon,
}) {
  final quietOutcomeTuning = <CueType, CueTuning>{
    ...kDefaultTuning,
    CueType.praise: const CueTuning(CueMode.variableRatio, base: 0, cap: 0),
    CueType.hustle: const CueTuning(CueMode.perishable, base: 0, cap: 0),
    CueType.criticalFault: const CueTuning(CueMode.correction, base: 0, cap: 0),
    CueType.reminder: const CueTuning(CueMode.correction, base: 0, cap: 0),
  };
  return PolicyVoiceCoach(
    script: VoiceScript.from(
      VoiceDefaults.repCountedHold,
      slug: 'high_plank',
      faultIds: const ['sagging', 'piked', 'elbow', 'wall_guard'],
      repStartPhaseKeys: const {'holding'},
    ),
    coach: VoiceCoach(
      sink: sink,
      policy: VoicePolicy(
        random: Random(1),
        tuning: quietOutcomeTuning,
      ),
      random: Random(1),
    ),
    earcon: earcon ?? _RecordingEarconSink(),
    targetReps: 1,
    countsByRepNumber: true,
  );
}

void _drive(PolicyVoiceCoach coach, _HoldExercise exercise, {required int ms}) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  coach.processFrame(
    exercise: exercise,
    repCount: exercise.repCount,
    hasPose: true,
    feedback: const {},
  );
}

class _HoldExercise extends ExerciseBase {
  _HoldExercise({required this.target, required int maxHolds})
      : super(targetReps: maxHolds, targetSeconds: target.round()) {
    exerciseState = ExerciseState.activated;
  }

  final double target;
  double live = 0;
  String phase = 'holding';
  bool reArming = false;
  int? reArmElapsedMs;

  @override
  bool get usesRepCountedHolds => true;

  @override
  bool get isReArmingHold => reArming;

  @override
  int? get holdStillElapsedMs =>
      reArming ? reArmElapsedMs : super.holdStillElapsedMs;

  @override
  double? get liveHoldSeconds => phase == 'holding' ? live : null;

  @override
  double? get liveHoldTargetSeconds => target;

  @override
  String get exerciseName => 'High Plank';

  @override
  String get currentPhaseKey => phase;

  @override
  String get currentPhaseLabel => phase;

  @override
  GuidanceSignal? checkSafety(
          Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) =>
      null;

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {}

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) =>
      false;

  @override
  void onSetComplete() {}

  @override
  bool requestStop() => false;
}

class _DeferredVoiceSink implements VoiceSink {
  final List<_PendingCue> _pending = [];
  final List<String> played = [];
  final List<String> skipped = [];
  int stopCalls = 0;

  List<String> get pendingKeys => _pending.map((cue) => cue.key).toList();

  @override
  bool get isBusy => false;

  @override
  Future<void> playKey(
    String logicalKey, {
    bool Function()? isStillRelevant,
  }) async {
    _pending.add(_PendingCue(logicalKey, isStillRelevant));
  }

  void drain() {
    for (final cue in List<_PendingCue>.from(_pending)) {
      if (cue.isStillRelevant?.call() ?? true) {
        played.add(cue.key);
      } else {
        skipped.add(cue.key);
      }
    }
    _pending.clear();
  }

  void clearAll() {
    _pending.clear();
    played.clear();
    skipped.clear();
  }

  @override
  Future<void> waitUntilIdle(
      {Duration timeout = const Duration(seconds: 4)}) async {}

  @override
  void clearPending() => _pending.clear();

  @override
  Future<void> stop() async {
    stopCalls++;
    _pending.clear();
  }

  @override
  void dispose() {}
}

class _PendingCue {
  const _PendingCue(this.key, this.isStillRelevant);

  final String key;
  final bool Function()? isStillRelevant;
}

class _RecordingEarconSink implements EarconSink {
  int endToneCalls = 0;
  int restEndToneCalls = 0;

  @override
  Future<void> endTone() async {
    endToneCalls++;
  }

  @override
  Future<void> restEndTone() async {
    restEndToneCalls++;
  }

  @override
  void dispose() {}
}
