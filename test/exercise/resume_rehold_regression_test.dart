// Regression suite for the resume-re-hold routing (decisions.md 07-10
// "Resume requires the start-position hold again" + the 07-11 loop fix).
//
// THE BUG THIS PINS DOWN: processPose called _beginPauseReactivationIfNeeded()
// unconditionally every frame, demoting ANY activated exercise back to
// notActivated — activate → demote → re-hold → "một, hai, ba" → activate →
// demote… an infinite countdown loop on device. The demote must run ONLY on
// the gate's one-frame resume edge (manual or auto).

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/fault_record.dart';
import 'package:vika/exercise/presence_gate.dart';
import 'package:vika/utils/person_detector.dart';

class _FakePresenceSource implements PosePresenceSource {
  @override
  bool personDetected = true;
  @override
  double presenceScore = 1.0;

  @override
  Future<bool> detect([Object? _]) async => personDetected;

  @override
  Future<void> triggerCheck({String reason = 'unknown'}) async {}

  @override
  Future<void> useActivatedCadence() async {}

  @override
  Future<void> usePausedCadence() async {}

  @override
  Future<void> close() async {}
}

class _ReholdTestExercise extends ExerciseBase {
  _ReholdTestExercise({super.gate}) : super(targetReps: 3);

  @override
  List<FaultRecord> get liveFaults => const [];

  @override
  String get exerciseName => 'Rehold Test';

  @override
  String get currentPhaseKey => 'bottom';

  @override
  String get currentPhaseLabel => 'Test';

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

PoseLandmark _landmark(PoseLandmarkType type) {
  return PoseLandmark(type: type, x: 200, y: 400, z: 0, likelihood: 0.99);
}

Map<PoseLandmarkType, PoseLandmark> _allLandmarks() {
  return {for (final t in PoseLandmarkType.values) t: _landmark(t)};
}

_ReholdTestExercise _activatedExercise() {
  final exercise = _ReholdTestExercise(
    gate: PresenceGate(detector: _FakePresenceSource()),
  )..exerciseState = ExerciseState.activated;
  return exercise;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('activated exercise is never demoted without a resume edge '
      '(the 07-11 infinite 3-2-1 loop)', () {
    final exercise = _activatedExercise();

    for (var i = 0; i < 5; i++) {
      exercise.processPose(_allLandmarks());
      expect(exercise.exerciseState, ExerciseState.activated,
          reason: 'frame $i must not demote an activated exercise');
      expect(exercise.isReactivatingAfterPause, isFalse);
    }
  });

  test('manual pause + resume demands exactly ONE re-hold, then stays', () {
    final exercise = _activatedExercise();

    exercise.manualPause();
    exercise.processPose(_allLandmarks());
    expect(exercise.exerciseState, ExerciseState.activated,
        reason: 'pausing alone never demotes — only the resume does');

    exercise.manualResume();
    expect(exercise.exerciseState, ExerciseState.notActivated,
        reason: 'manual resume routes back through the start-position hold');
    expect(exercise.isReactivatingAfterPause, isTrue);

    // The gate's pending resume edge is consumed on the next frame — it must
    // not demote again or double-fire anything.
    exercise.processPose(_allLandmarks());
    expect(exercise.exerciseState, ExerciseState.notActivated);
    expect(exercise.isReactivatingAfterPause, isTrue);

    // Re-hold completes (simulated): the machine must STAY activated on
    // subsequent frames — no loop back to the countdown.
    exercise.exerciseState = ExerciseState.activated;
    for (var i = 0; i < 5; i++) {
      exercise.processPose(_allLandmarks());
      expect(exercise.exerciseState, ExerciseState.activated,
          reason: 'no second demote without a new resume edge (frame $i)');
    }
  });

  test('a resume edge landing on a NO-POSE frame still demands the re-hold',
      () {
    final source = _FakePresenceSource();
    final gate = PresenceGate(detector: source);
    final exercise = _ReholdTestExercise(gate: gate)
      ..exerciseState = ExerciseState.activated;

    // Auto-resume shape: the gate resumes on its own edge while ML Kit has no
    // skeleton yet (segmentation sees the person before pose does). Simulate
    // via the gate's manual edge, consumed by a no-pose frame.
    gate.manualPause();
    exercise.processNoPoseFrame();
    expect(exercise.exerciseState, ExerciseState.activated);

    gate.manualResume(DateTime.now());
    exercise.processNoPoseFrame();
    expect(exercise.exerciseState, ExerciseState.notActivated,
        reason: 'the one-frame resume edge must not be eaten by the '
            'no-pose path');
    expect(exercise.isReactivatingAfterPause, isTrue);
  });
}
