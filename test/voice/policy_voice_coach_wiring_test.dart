import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/Cobra/cobra.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';
import 'package:vika/exercise/lunge/lunge.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/services/generic_exercise_voice_assets.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/voice/voice_coach.dart';
import 'package:vika/voice/policy_voice_coach.dart';
import 'package:vika/voice/voice_content.dart';
import 'package:vika/voice/voice_policy.dart';
import 'package:vika/voice/voice_sink.dart';

// Wiring tests for the voice-policy migration.
//
// These do not simulate audio playback or exercise motion. They prove the
// factory layer builds the right PolicyVoiceCoach data: modality bundle,
// legacy slug/fault key parity, squat phase cues, and shipped asset mappings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Rep-counted generic exercises should keep numeral counting and the same
  // '<slug>.<fault>' keys the legacy generic coach used.
  test('generic rep exercises use the policy coach with rep defaults', () {
    final exercise = Lunge();
    final coach = exercise.createVoiceCoach();
    addTearDown(() => coach?.dispose());

    expect(coach, isA<PolicyVoiceCoach>());

    final policyCoach = coach! as PolicyVoiceCoach;
    expect(policyCoach.script.slug, 'lunge');
    expect(policyCoach.script.countPool, VoiceDefaults.repBased.count);
    expect(policyCoach.script.hasSoftCues, isFalse);
    expect(policyCoach.countsByRepNumber, isTrue);
    expect(policyCoach.script.faultKey('depth'), 'lunge.depth');
  });

  test('glute bridge uses its pilot script and keeps hustle off', () {
    final exercise = GluteBridge(maxRep: 3);
    final coach = exercise.createVoiceCoach();
    addTearDown(() => coach?.dispose());

    expect(coach, isA<PolicyVoiceCoach>());

    final policyCoach = coach! as PolicyVoiceCoach;
    expect(policyCoach.script.slug, 'glute_bridge');
    expect(policyCoach.script.countPool, VoiceDefaults.repBased.count);
    expect(policyCoach.script.faultIds, const [
      'hip_extension',
      'hyperextension',
      'knee_angle',
      'speed_control',
      'neck_head',
    ]);
    expect(
      policyCoach.script.softPoolFor('hip_extension'),
      const ['glute_bridge.hip_extension_soft'],
    );
    expect(policyCoach.script.hustlePool, isEmpty);
    expect(policyCoach.targetReps, isNull);
  });

  // Hold exercises use the time-based bundle at factory time. The hold target
  // comes from liveHoldTargetSeconds, so this catches accidental rep-bundle use.
  test('generic hold exercises use the policy coach with time defaults', () {
    final exercise = Cobra(maxRep: 1);
    final coach = exercise.createVoiceCoach();
    addTearDown(() => coach?.dispose());

    expect(coach, isA<PolicyVoiceCoach>());

    final policyCoach = coach! as PolicyVoiceCoach;
    expect(policyCoach.script.slug, 'cobra');
    expect(policyCoach.script.countPool, VoiceDefaults.timeBased.count);
    expect(policyCoach.countsByRepNumber, isFalse);
    expect(policyCoach.script.faultKey('elbow'), 'cobra.elbow');
  });

  // Squat is the stage-3 pilot: it adds phase cues and targetReps on top of the
  // generic policy wiring, while still reusing legacy fault ids.
  test('squat uses the policy coach with phase cues and rep target', () {
    final exercise = Squat(maxRep: 15);
    final coach = exercise.createVoiceCoach();
    addTearDown(() => coach?.dispose());

    expect(coach, isA<PolicyVoiceCoach>());

    final policyCoach = coach! as PolicyVoiceCoach;
    expect(policyCoach.script.slug, 'squat');
    expect(policyCoach.script.countPool, VoiceDefaults.repBased.count);
    expect(policyCoach.script.phaseCues['descending'], 'Xuống');
    expect(policyCoach.script.phaseCues['bottom'], 'Giữ');
    expect(policyCoach.script.phaseCues['ascending'], 'Đứng lên');
    expect(policyCoach.script.faultKey('depth'), 'squat.depth');
    expect(policyCoach.targetReps, 15);
  });

  // The pilot is useful on device only if phase cues make sound. These keys are
  // phrase keys, so they must resolve through the shared asset map.
  test('squat phase cues resolve to shipped assets', () {
    expect(GenericExerciseVoiceAssets.resolveAsset('Xuống'), 'squat/xuong.wav');
    expect(GenericExerciseVoiceAssets.resolveAsset('Giữ'), 'squat/giu.wav');
    expect(
      GenericExerciseVoiceAssets.resolveAsset('Đứng lên'),
      'squat/dung_len.wav',
    );
  });

  test('rep counts speak the landed rep number, regardless of random seed', () {
    for (var seed = 1; seed <= 8; seed++) {
      final sink = _RecordingVoiceSink();
      final exercise = GluteBridge(maxRep: 3)
        ..exerciseState = ExerciseState.activated;
      final coach = PolicyVoiceCoach(
        script: VoiceScript.from(
          VoiceDefaults.repBased,
          slug: 'glute_bridge',
          faultIds: const ['hip_extension'],
        ),
        coach: VoiceCoach(
          sink: sink,
          policy: _countAlwaysPolicy(seed),
          random: Random(seed),
        ),
      );
      addTearDown(coach.dispose);

      coach.processFrame(
        exercise: exercise,
        repCount: 0,
        hasPose: true,
        feedback: const {},
      );

      for (var rep = 1; rep <= 3; rep++) {
        exercise.logger.addRepLog(
          RepLog(repNumber: rep, correctForm: true, data: const {}),
        );
        coach.processFrame(
          exercise: exercise,
          repCount: rep,
          hasPose: true,
          feedback: const {},
        );
      }

      expect(sink.keys.take(3), ['1', '2', '3']);
    }
  });

  test('glute bridge classifier routes clean, soft, and critical reps', () {
    expect(
      _spokenOutcomeKeys(
        script: _gluteBridgePilotScript(),
        repLog: RepLog(
          repNumber: 2,
          correctForm: true,
          data: const {'fault_types': []},
        ),
      ),
      const ['common.good_1'],
      reason: 'zero faults means truly clean -> praise',
    );

    expect(
      _spokenOutcomeKeys(
        script: _gluteBridgePilotScript(),
        repLog: RepLog(
          repNumber: 2,
          correctForm: true,
          data: const {
            'fault_types': ['hip_extension'],
          },
        ),
      ),
      const ['glute_bridge.hip_extension_soft'],
      reason: 'correctForm true with measured faults is non-critical -> soft',
    );

    final critical = _spokenOutcomeKeys(
      script: _gluteBridgePilotScript(),
      repLog: RepLog(
        repNumber: 2,
        correctForm: false,
        data: const {
          'fault_types': ['hip_extension'],
        },
      ),
    );
    expect(critical, const ['glute_bridge.hip_extension']);
    expect(
      critical,
      isNot(contains('glute_bridge.hip_extension_soft')),
      reason: 'critical reps must stay on the correction branch',
    );
  });

  test('scripts without soft pools keep the existing 2-way classifier', () {
    expect(
      _spokenOutcomeKeys(
        script: VoiceScript.from(
          VoiceDefaults.repBased,
          slug: 'generic',
          faultIds: const ['hip_extension'],
        ),
        repLog: RepLog(
          repNumber: 2,
          correctForm: true,
          data: const {
            'fault_types': ['hip_extension'],
          },
        ),
      ),
      const ['common.good_1'],
      reason: 'without soft content, correctForm true still falls through to '
          'the old praise path',
    );
  });
}

VoicePolicy _countAlwaysPolicy(int seed) {
  return VoicePolicy(
    random: Random(seed),
    tuning: {
      ...kDefaultTuning,
      CueType.count: const CueTuning(CueMode.always, base: 1.0),
      CueType.praise: const CueTuning(CueMode.variableRatio, base: 0.0),
      CueType.hustle: const CueTuning(CueMode.perishable, base: 0.0),
      CueType.phase: const CueTuning(CueMode.perishable, base: 0.0),
    },
  );
}

VoiceScript _gluteBridgePilotScript() {
  return VoiceScript.from(
    VoiceDefaults.repBased,
    slug: 'glute_bridge',
    faultIds: const [
      'hip_extension',
      'hyperextension',
      'knee_angle',
      'speed_control',
      'neck_head',
    ],
    softCuePools: const {
      'hip_extension': ['glute_bridge.hip_extension_soft'],
      'hyperextension': ['glute_bridge.hyperextension_soft'],
      'knee_angle': ['glute_bridge.knee_angle_soft'],
      'speed_control': ['glute_bridge.speed_control_soft'],
      'neck_head': ['glute_bridge.neck_head_soft'],
    },
  );
}

List<String> _spokenOutcomeKeys({
  required VoiceScript script,
  required RepLog repLog,
}) {
  final sink = _RecordingVoiceSink();
  final exercise = GluteBridge(maxRep: 3)
    ..exerciseState = ExerciseState.activated;
  final coach = PolicyVoiceCoach(
    script: script,
    coach: VoiceCoach(
      sink: sink,
      policy: _outcomeAlwaysPolicy(),
      random: _ScriptedRandom([0.99]),
    ),
  );
  addTearDown(coach.dispose);

  exercise.logger.addRepLog(repLog);
  coach.processFrame(
    exercise: exercise,
    repCount: repLog.repNumber,
    hasPose: true,
    feedback: const {},
  );

  return sink.keys
      .where((key) => !RegExp(r'^\d+$').hasMatch(key))
      .toList(growable: false);
}

VoicePolicy _outcomeAlwaysPolicy() {
  return VoicePolicy(
    random: _ScriptedRandom([0.99, 0.0]),
    tuning: {
      ...kDefaultTuning,
      CueType.count: const CueTuning(CueMode.always, base: 0.0, cap: 0.0),
      CueType.praise: const CueTuning(
        CueMode.variableRatio,
        base: 1.0,
        cap: 1.0,
        scalePraiseByFormScore: false,
      ),
      CueType.correct: const CueTuning(
        CueMode.correction,
        base: 0.0,
        step: 0.0,
        cap: 0.0,
        firstOccurrenceCertain: true,
      ),
      CueType.soft: const CueTuning(CueMode.variableRatio, base: 1.0, cap: 1.0),
      CueType.hustle: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
      CueType.phase: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
    },
  );
}

class _ScriptedRandom implements Random {
  _ScriptedRandom(this._doubles);

  final List<double> _doubles;
  int _i = 0;

  @override
  double nextDouble() {
    if (_doubles.isEmpty) return 0.0;
    final v = _i < _doubles.length ? _doubles[_i] : _doubles.last;
    if (_i < _doubles.length) _i++;
    return v;
  }

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

class _RecordingVoiceSink implements VoiceSink {
  final List<String> keys = [];

  @override
  bool get isBusy => false;

  @override
  Future<void> playKey(String logicalKey) async {
    keys.add(logicalKey);
  }

  @override
  Future<void> waitUntilIdle() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
