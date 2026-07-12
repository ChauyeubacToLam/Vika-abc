import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/1.Bird Dog/bird_dog.dart';
import 'package:vika/exercise/10.Vup/v_up.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug.dart';
import 'package:vika/exercise/13.Plank Up-Down/plank_up_down.dart';
import 'package:vika/exercise/2.Sit-Up/sit_up.dart';
import 'package:vika/exercise/4.Mountain Climber/mountain_climber.dart';
import 'package:vika/exercise/5.Superman/superman.dart';
import 'package:vika/exercise/7.Plank Shoulder Tap/plank_shoulder_tap.dart';
import 'package:vika/exercise/8.Leg Raises (Supine)/leg_raise.dart';
import 'package:vika/exercise/9.Reverse Crunch/reverse_crunch.dart';
import 'package:vika/exercise/Cobra/cobra.dart';
import 'package:vika/exercise/Jump_Squat/jump_squat.dart';
import 'package:vika/exercise/ashtanga_namaskara/ashtanga_namaskara.dart';
import 'package:vika/exercise/cossack_squat/cossack_squat.dart';
import 'package:vika/exercise/curl_up/curl_up.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/fault_record.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';
import 'package:vika/exercise/jumping jack/jumping_jack.dart';
import 'package:vika/exercise/lunge/lunge.dart';
import 'package:vika/exercise/push up/push_up.dart';
import 'package:vika/exercise/russian_twist/russian_twist.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/exercise/standing_knee_to_elbow/standing_knee_to_elbow.dart';
import 'package:vika/exercise/step_back_burpee/step_back_burpee.dart';
import 'package:vika/exercise/tricep_dip/tricep_dip.dart';
import 'package:vika/exercise/walking_lunge/walking_lunge.dart';
import 'package:vika/exercise/wall_push_up/wall_push_up.dart' hide FaultRecord;
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
    addTearDown(coach.dispose);

    expect(coach, isA<PolicyVoiceCoach>());

    final policyCoach = coach as PolicyVoiceCoach;
    expect(policyCoach.script.slug, 'lunge');
    expect(policyCoach.script.countPool, VoiceDefaults.repBased.count);
    expect(policyCoach.script.hasSoftCues, isFalse);
    expect(policyCoach.countsByRepNumber, isTrue);
    expect(policyCoach.script.faultKey('depth'), 'lunge.depth');
  });

  test('mixed rep-hold exercises explicitly keep rep voice defaults', () {
    final exercises = <ExerciseBase>[
      Superman(maxRep: 8),
      PlankUpDown(maxRep: 8),
      WalkingLunge(maxRep: 8),
    ];
    final coaches = exercises
        .map((exercise) => exercise.createVoiceCoach() as PolicyVoiceCoach)
        .toList();
    addTearDown(() {
      for (final coach in coaches) {
        coach.dispose();
      }
    });

    for (final coach in coaches) {
      expect(coach.script.countPool, VoiceDefaults.repBased.count);
      expect(coach.countsByRepNumber, isTrue);
      expect(coach.targetReps, 8);
    }
  });

  test('rep exercise fleet exposes the Tier 2 soft and reminder wiring', () {
    final cases = <({
      ExerciseBase exercise,
      Map<String, List<String>> softPools,
      Map<String, List<String>> reminderPools,
      Set<String> repStartPhaseKeys,
    })>[
      (
        exercise: Squat(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'trunk': ['squat.trunk_reminder'],
        },
        repStartPhaseKeys: const {'descending'},
      ),
      (
        exercise: PushUp(maxRep: 2),
        softPools: const {
          'depth': ['push_up.depth_soft'],
        },
        reminderPools: const {
          'sag': ['push_up.sag_reminder'],
        },
        repStartPhaseKeys: const {'descending'},
      ),
      (
        exercise: WallPushUp(maxRep: 2),
        softPools: const {
          'body_line': ['wall_push_up.body_line_soft'],
          'foot': ['wall_push_up.foot_soft'],
          'shoulder': ['wall_push_up.shoulder_soft'],
          'elbow': ['wall_push_up.elbow_soft'],
          'head': ['wall_push_up.head_soft'],
          'cervical': ['wall_push_up.cervical_soft'],
          'tempo': ['wall_push_up.tempo_soft'],
        },
        reminderPools: const {
          'body_line': ['wall_push_up.body_line_reminder'],
        },
        repStartPhaseKeys: const {'descending'},
      ),
      (
        exercise: Lunge(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'trunk': ['lunge.trunk_reminder'],
        },
        repStartPhaseKeys: const {'descending'},
      ),
      (
        exercise: WalkingLunge(maxRep: 2),
        softPools: const {
          'rear_depth': ['walking_lunge.rear_depth_soft'],
          'step_length': ['walking_lunge.step_length_soft'],
        },
        reminderPools: const {
          'torso': ['walking_lunge.torso_reminder'],
        },
        repStartPhaseKeys: const {'stepping', 'descending'},
      ),
      (
        exercise: CossackSquat(maxRep: 2),
        softPools: const {
          'depth_deep': ['cossack_squat.depth_deep_soft'],
          'torso': ['cossack_squat.torso_soft'],
        },
        reminderPools: const {
          'knee_valgus': ['cossack_squat.knee_valgus_reminder'],
        },
        repStartPhaseKeys: const {'descending'},
      ),
      (
        exercise: StandingKneeToElbow(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'core_drive': ['standing_kte.core_drive_reminder'],
        },
        repStartPhaseKeys: const {'approaching'},
      ),
      (
        exercise: TricepDip(maxRep: 2),
        softPools: const {},
        reminderPools: const {},
        repStartPhaseKeys: const {},
      ),
      (
        exercise: JumpSquat(maxRep: 2),
        softPools: const {
          'landing_depth': ['jump_squat.landing_depth_soft'],
        },
        reminderPools: const {},
        repStartPhaseKeys: const {},
      ),
      (
        exercise: StepBackBurpee(maxRep: 2),
        softPools: const {
          'squat_depth': ['step_back_burpee.squat_depth_soft'],
          'plank_extension': ['step_back_burpee.plank_extension_soft'],
        },
        reminderPools: const {},
        repStartPhaseKeys: const {},
      ),
      (
        exercise: CurlUp(maxRep: 2),
        softPools: const {
          'knee_extension': ['curl_up.knee_extension_soft'],
          'neck_pull': ['curl_up.neck_pull_soft'],
          'trunk_high': ['curl_up.trunk_high_soft'],
          'trunk_low': ['curl_up.trunk_low_soft'],
        },
        reminderPools: const {
          'neck_pull': ['curl_up.neck_pull_reminder'],
        },
        repStartPhaseKeys: const {'ascending'},
      ),
      (
        exercise: SitUp(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'jerking': ['sit_up.jerking_reminder'],
        },
        repStartPhaseKeys: const {'rising'},
      ),
      (
        exercise: VUp(maxRep: 2),
        softPools: const {
          'sync': ['v_up.sync_soft'],
          'rom': ['v_up.rom_soft'],
        },
        reminderPools: const {
          'knee': ['v_up.knee_reminder'],
        },
        repStartPhaseKeys: const {'rising'},
      ),
      (
        exercise: DeadBug(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'anti_extension': ['dead_bug.anti_extension_reminder'],
        },
        repStartPhaseKeys: const {'extending'},
      ),
      (
        exercise: BirdDog(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'lumbar': ['bird_dog.lumbar_reminder'],
        },
        repStartPhaseKeys: const {'extending'},
      ),
      (
        exercise: Superman(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'lumbar': ['superman.lumbar_reminder'],
        },
        repStartPhaseKeys: const {'lifting'},
      ),
      (
        exercise: MountainClimber(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'trunk_sag': ['mountain_climber.trunk_sag_reminder'],
        },
        repStartPhaseKeys: const {'knee_driving_in'},
      ),
      (
        exercise: ReverseCrunch(maxRep: 2),
        softPools: const {
          'tempo': ['reverse_crunch.tempo_soft'],
          'momentum': ['reverse_crunch.momentum_soft'],
        },
        reminderPools: const {
          'arms': ['reverse_crunch.arms_reminder'],
        },
        repStartPhaseKeys: const {'curling'},
      ),
      (
        exercise: PlankShoulderTap(maxRep: 2),
        softPools: const {
          'tempo': ['plank_shoulder_tap.tempo_soft'],
        },
        reminderPools: const {
          'hip_rotation': [
            'plank_shoulder_tap.hip_rotation_reminder',
          ],
        },
        repStartPhaseKeys: const {'lifting'},
      ),
      (
        exercise: LegRaise(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'pelvic': ['leg_raises.pelvic_reminder'],
        },
        repStartPhaseKeys: const {'raising'},
      ),
      (
        exercise: RussianTwist(maxRep: 2),
        softPools: const {},
        reminderPools: const {
          'knee': ['russian_twist.knee_reminder'],
        },
        repStartPhaseKeys: const {'twisting'},
      ),
      (
        exercise: JumpingJack(maxRep: 2),
        softPools: const {
          'tempo_fast': ['jumping_jack.tempo_fast_soft'],
        },
        reminderPools: const {},
        repStartPhaseKeys: const {},
      ),
      (
        exercise: AshtangaNamaskara(maxRep: 2),
        softPools: const {
          'neck': ['ashtanga_namaskara.neck_soft'],
        },
        reminderPools: const {
          'hip': ['ashtanga_namaskara.hip_reminder'],
        },
        repStartPhaseKeys: const {'recognized'},
      ),
      (
        exercise: PlankUpDown(maxRep: 2),
        softPools: const {
          'alternating': ['plank_up_down.alternating_soft'],
        },
        reminderPools: const {
          'trunk': ['plank_up_down.trunk_reminder'],
        },
        repStartPhaseKeys: const {'pushing_up'},
      ),
    ];

    for (final tier2Case in cases) {
      final coach = tier2Case.exercise.createVoiceCoach();
      expect(coach, isA<PolicyVoiceCoach>());
      final policyCoach = coach! as PolicyVoiceCoach;
      addTearDown(policyCoach.dispose);

      expect(
        policyCoach.script.softCuePools,
        tier2Case.softPools,
        reason: '${policyCoach.script.slug} soft pools',
      );
      expect(
        policyCoach.script.reminderPools,
        tier2Case.reminderPools,
        reason: '${policyCoach.script.slug} reminder pools',
      );
      expect(
        policyCoach.script.repStartPhaseKeys,
        tier2Case.repStartPhaseKeys,
        reason: '${policyCoach.script.slug} rep-start phases',
      );
      expect(
        policyCoach.script.effortPhaseKeys,
        isEmpty,
        reason: '${policyCoach.script.slug} hustle must stay off',
      );
    }
  });

  test('glute bridge uses its pilot script with hustle + reminders enabled',
      () {
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
    // Hustle enabled 07-11: generic push + target-proven final line.
    expect(policyCoach.script.hustlePool, const ['common.push']);
    expect(policyCoach.script.hustleFinalPool, const ['common.one_more_rep']);
    // Reminders enabled 07-11 (recordings landed 07-10): continuous criticals
    // only — peak faults (hip_extension, knee_angle, speed_control) stay
    // excluded by design, their rep-end line IS the instruction.
    expect(
      policyCoach.script.reminderPoolFor('hyperextension'),
      const ['glute_bridge.hyperextension_reminder'],
    );
    expect(
      policyCoach.script.reminderPoolFor('neck_head'),
      const ['glute_bridge.neck_head_reminder'],
    );
    expect(policyCoach.script.reminderPoolFor('hip_extension'), isEmpty);
    expect(policyCoach.script.repStartPhaseKeys, const {'ascending'});
    expect(policyCoach.script.effortPhaseKeys, const {'ascending'});
    // Glute bridge forwards maxRep -> targetReps (so final-rep awareness works);
    // hustle stays off via the empty hustlePool + zero tuning, not a null target.
    expect(policyCoach.targetReps, 3);
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

  test('squat uses fleet-standard silence with reminders and rep target', () {
    final exercise = Squat(maxRep: 15);
    final coach = exercise.createVoiceCoach();
    addTearDown(() => coach?.dispose());

    expect(coach, isA<PolicyVoiceCoach>());

    final policyCoach = coach! as PolicyVoiceCoach;
    expect(policyCoach.script.slug, 'squat');
    expect(policyCoach.script.countPool, VoiceDefaults.repBased.count);
    expect(policyCoach.script.phaseCues, isEmpty);
    expect(
      policyCoach.script.reminderPoolFor('trunk'),
      const ['squat.trunk_reminder'],
    );
    expect(policyCoach.script.repStartPhaseKeys, const {'descending'});
    expect(policyCoach.script.hustlePool, isEmpty);
    expect(policyCoach.script.effortPhaseKeys, isEmpty);
    expect(policyCoach.script.faultKey('depth'), 'squat.depth');
    expect(policyCoach.targetReps, 15);
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

  test('live faults fire mid-rep and are not duplicated at rep end', () async {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 3)
      ..exerciseState = ExerciseState.activated;
    final coach = PolicyVoiceCoach(
      script: _gluteBridgePilotScript(),
      coach: VoiceCoach(
        sink: sink,
        policy: _outcomeAlwaysPolicy(),
        random: _ScriptedRandom([0.99]),
      ),
      targetReps: 3,
    );
    addTearDown(coach.dispose);

    exercise.live = [
      FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
        priority: 1,
      ),
    ];
    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );
    await Future<void>.delayed(Duration.zero);

    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
          repNumber: 1,
          correctForm: false,
          data: const {
            'fault_types': ['hyperextension'],
            'fault_affects_form': {'hyperextension': true},
            'fault_priorities': {'hyperextension': 1},
          },
        ),
      );
    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(
      sink.keys.where((key) => key == 'glute_bridge.hyperextension'),
      hasLength(1),
    );
  });

  test('blocked live critical keeps first-occurrence credit next rep',
      () async {
    var now = 0;
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 3)
      ..exerciseState = ExerciseState.activated;
    final coach = PolicyVoiceCoach(
      script: _gluteBridgePilotScript(),
      coach: VoiceCoach(
        sink: sink,
        policy: VoicePolicy(
          random: _ScriptedRandom([0.99]),
          clockMs: () => now,
          tuning: {
            ...kDefaultTuning,
            CueType.count: const CueTuning(CueMode.always, base: 0.0, cap: 0.0),
            CueType.criticalFault: const CueTuning(
              CueMode.correction,
              base: 0.0,
              step: 0.0,
              cap: 0.0,
              firstOccurrenceCertain: true,
            ),
            CueType.softFault:
                const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
            CueType.praise:
                const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
            CueType.hustle:
                const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
            CueType.phase:
                const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
          },
          outcomeCollisionGapMs: 500,
          maxOutcomeCuesPerRep: 2,
        ),
        random: _ScriptedRandom([0.99]),
      ),
      targetReps: 3,
    );
    addTearDown(coach.dispose);

    exercise.live = [
      FaultRecord(
        phase: 'ascending',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
      ),
    ];
    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );
    await Future<void>.delayed(Duration.zero);

    now = 100;
    exercise.live = [
      FaultRecord(
        phase: 'descending',
        type: 'neck_head',
        message: 'Thả đầu xuống',
        affectsForm: true,
      ),
    ];
    coach.processFrame(
      exercise: exercise,
      repCount: 0,
      hasPose: true,
      feedback: const {},
    );

    expect(sink.keys, contains('glute_bridge.hyperextension'));
    expect(sink.keys, isNot(contains('glute_bridge.neck_head')));

    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
          repNumber: 1,
          correctForm: false,
          data: const {
            'fault_types': ['hyperextension', 'neck_head'],
            'fault_affects_form': {
              'hyperextension': true,
              'neck_head': true,
            },
          },
        ),
      );
    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    now = 600;
    exercise.live = [
      FaultRecord(
        phase: 'ascending',
        type: 'neck_head',
        message: 'Thả đầu xuống',
        affectsForm: true,
      ),
    ];
    coach.processFrame(
      exercise: exercise,
      repCount: 1,
      hasPose: true,
      feedback: const {},
    );

    expect(
      sink.keys.where((key) => key == 'glute_bridge.neck_head'),
      hasLength(1),
      reason: 'blocked rep-1 attempt must not turn rep 2 into persistence=1',
    );
  });

  test('reminder stays quiet on rep 1 and without a previous live sighting',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 4,
      policy: _reminderAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 0, phase: 'ascending', ms: 500);

    exercise.logger.addRepLog(
      RepLog(repNumber: 1, correctForm: true, data: const {'fault_types': []}),
    );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1500);

    expect(
      sink.keys.where((key) => key.endsWith('_reminder')),
      isEmpty,
      reason:
          'rep-start alone is not enough; the previous rep must see a live critical',
    );
  });

  test('reminder fires on bottom to ascending after previous live critical',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 4,
      policy: _reminderAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.live = [
      FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
        priority: 2,
      ),
    ];
    _driveFrame(coach, exercise, repCount: 0, phase: 'topHold', ms: 500);

    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
            repNumber: 1, correctForm: false, data: const {'fault_types': []}),
      );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1500);

    expect(
      sink.keys.where((key) => key == 'glute_bridge.hyperextension_reminder'),
      const ['glute_bridge.hyperextension_reminder'],
    );
  });

  test('reminder also fires on descending to ascending fast path', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 4,
      policy: _reminderAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.live = [
      FaultRecord(
        phase: 'descending',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
      ),
    ];
    _driveFrame(coach, exercise, repCount: 0, phase: 'descending', ms: 500);

    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
            repNumber: 1, correctForm: false, data: const {'fault_types': []}),
      );
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1000);

    expect(
      sink.keys.where((key) => key == 'glute_bridge.hyperextension_reminder'),
      const ['glute_bridge.hyperextension_reminder'],
    );
  });

  test('reminder hard-stops after a rep without that live critical', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 5)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 5,
      policy: _reminderAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.live = [
      FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
      ),
    ];
    _driveFrame(coach, exercise, repCount: 0, phase: 'topHold', ms: 500);
    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
            repNumber: 1, correctForm: false, data: const {'fault_types': []}),
      );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1500);

    exercise.logger.addRepLog(
      RepLog(repNumber: 2, correctForm: true, data: const {'fault_types': []}),
    );
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 2500);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 3000);

    expect(
      sink.keys.where((key) => key == 'glute_bridge.hyperextension_reminder'),
      hasLength(1),
      reason: 'a clean/no-live-critical rep clears eligibility and streak',
    );
  });

  test('one reminder per rep, highest-priority eligible fault wins', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 4,
      policy: _reminderAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.live = [
      FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
        priority: 5,
      ),
      FaultRecord(
        phase: 'topHold',
        type: 'neck_head',
        message: 'Thả đầu xuống',
        affectsForm: true,
        priority: 1,
      ),
    ];
    _driveFrame(coach, exercise, repCount: 0, phase: 'topHold', ms: 500);

    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
            repNumber: 1, correctForm: false, data: const {'fault_types': []}),
      );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1500);

    expect(
      sink.keys.where((key) => key.endsWith('_reminder')),
      const ['glute_bridge.neck_head_reminder'],
    );
  });

  test(
      'reminder wins the commit-edge slot over a still-live critical of the '
      'same fault (07-11 reorder)', () async {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    // Both the critical AND the reminder are deterministic-first and ENABLED,
    // so the assertion proves the reminder PREEMPTS the re-correction — not
    // that the critical happened to be disabled (as in the isolated tests).
    final policy = VoicePolicy(
      random: _ScriptedRandom([0.0]),
      tuning: {
        ...kDefaultTuning,
        CueType.count: const CueTuning(CueMode.always, base: 0.0, cap: 0.0),
        CueType.praise:
            const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
        CueType.softFault:
            const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
        CueType.criticalFault: const CueTuning(
          CueMode.correction,
          base: 1.0,
          cap: 1.0,
          firstOccurrenceCertain: true,
        ),
        CueType.reminder: const CueTuning(
          CueMode.correction,
          base: 1.0,
          cap: 1.0,
          firstOccurrenceCertain: true,
        ),
        CueType.hustle:
            const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
        CueType.phase: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
      },
      outcomeCollisionGapMs: 0,
    );
    final coach = _reminderCoach(sink: sink, targetReps: 4, policy: policy);
    addTearDown(coach.dispose);

    final neckHead = FaultRecord(
      phase: 'topHold',
      type: 'neck_head',
      message: 'Thả đầu xuống',
      affectsForm: true,
      priority: 1,
    );

    // Flush the sink's microtask-scheduled audio-end callback between frames
    // so `_outcomeAudioPending` clears — on device the audio finishes in the
    // gap between reps; the fake sink completes waitUntilIdle on a microtask.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    // Rep 0: neck_head fires critically (first occurrence) → eligible for the
    // rep-1 reminder.
    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.live = [neckHead];
    _driveFrame(coach, exercise, repCount: 0, phase: 'topHold', ms: 500);
    expect(sink.keys, contains('glute_bridge.neck_head'));
    await settle();

    // Rep 1 lands with neck_head STILL live — the continuous-fault case the
    // isolated tests skip by clearing `live`.
    exercise.logger.addRepLog(
      RepLog(repNumber: 1, correctForm: false, data: const {'fault_types': []}),
    );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    await settle();

    final before = sink.keys.length;
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1500);
    final spokenThisEdge = sink.keys.sublist(before);

    expect(spokenThisEdge, contains('glute_bridge.neck_head_reminder'),
        reason: 'the feedforward reminder claims the commit-edge slot');
    expect(spokenThisEdge, isNot(contains('glute_bridge.neck_head')),
        reason: 'the same-fault re-correction is suppressed this rep — the '
            'reminder replaces it (remind, do not re-nag). The old '
            'drain-first order spoke the critical and dropped the reminder.');
  });

  test('empty reminder pool is silent and makes no reminder policy call', () {
    final policy = _RecordingVoicePolicy(
      tuning: _reminderAdapterTuning(),
    );
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 4,
      policy: policy,
      script: _reminderScript(reminderPools: const {}),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.live = [
      FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
      ),
    ];
    _driveFrame(coach, exercise, repCount: 0, phase: 'topHold', ms: 500);
    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
            repNumber: 1, correctForm: false, data: const {'fault_types': []}),
      );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1500);

    expect(sink.keys.where((key) => key.endsWith('_reminder')), isEmpty);
    expect(policy.cueTypes, isNot(contains(CueType.reminder)));
  });

  test('reminder beats hustle on a coincident glute commit edge', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 6)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 6,
      policy: _reminderAdapterPolicy(hustleBase: 1.0),
      script: _reminderScript(hustlePool: const ['common.push']),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.logger.addRepLog(
      RepLog(repNumber: 1, correctForm: true, data: const {'fault_types': []}),
    );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2000);

    exercise.logger.addRepLog(
      RepLog(repNumber: 2, correctForm: true, data: const {'fault_types': []}),
    );
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4000);

    exercise.live = [
      FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
      ),
    ];
    _driveFrame(coach, exercise, repCount: 2, phase: 'topHold', ms: 4500);
    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
            repNumber: 3, correctForm: false, data: const {'fault_types': []}),
      );
    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 5000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 7000);

    expect(
      sink.keys.where((key) => key == 'glute_bridge.hyperextension_reminder'),
      const ['glute_bridge.hyperextension_reminder'],
    );
    expect(sink.keys, isNot(contains('common.push')));
  });

  test('reminder does not fire after the target rep has landed', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 1)
      ..exerciseState = ExerciseState.activated;
    final coach = _reminderCoach(
      sink: sink,
      targetReps: 1,
      policy: _reminderAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    exercise.live = [
      FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng',
        affectsForm: true,
      ),
    ];
    _driveFrame(coach, exercise, repCount: 0, phase: 'topHold', ms: 500);
    exercise
      ..live = const []
      ..logger.addRepLog(
        RepLog(
            repNumber: 1, correctForm: false, data: const {'fault_types': []}),
      );
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1500);

    expect(sink.keys.where((key) => key.endsWith('_reminder')), isEmpty);
  });

  test('hustle arms only after baseline and a stretched effort entry', () {
    final logs = _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 8)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 8,
      policy: _hustleAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 5000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 6100);
    _driveFrame(coach, exercise, repCount: 4, phase: 'bottom', ms: 7000);
    _driveFrame(coach, exercise, repCount: 4, phase: 'ascending', ms: 9000);

    expect(
      logs.where((line) => line.contains('[VoiceHustle] gap')),
      containsAllInOrder([
        '[VoiceHustle] gap rep=2 gapMs=1000 baselineMs=collecting armed=false',
        '[VoiceHustle] gap rep=3 gapMs=1000 baselineMs=1000 armed=false',
        '[VoiceHustle] gap rep=4 gapMs=1100 baselineMs=1000 armed=false',
        '[VoiceHustle] gap rep=5 gapMs=2000 baselineMs=1000 armed=true',
      ]),
    );
    expect(
      sink.keys.where((key) => key == 'common.push'),
      const ['common.push'],
      reason: 'only the stretched post-baseline gap should call hustle',
    );
  });

  test(
      'sub-threshold fast-path gaps are excluded from the hustle baseline '
      '(07-11)', () {
    final logs = _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 8)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 8,
      policy: _hustleAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    // A ~0ms fast-path gap (100ms < kMinArmGapMs) lands FIRST. Without the
    // guard it would be the first baseline sample and deflate the median.
    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 1100);
    // Two genuine 1000ms gaps build the baseline — untainted by the 100ms.
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 2000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 3000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 4000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 5000);
    _driveFrame(coach, exercise, repCount: 4, phase: 'bottom', ms: 6000);
    _driveFrame(coach, exercise, repCount: 4, phase: 'ascending', ms: 8000);

    expect(
      logs.where((line) => line.contains('[VoiceHustle] gap')),
      containsAllInOrder([
        // Excluded: still collecting, not counted toward the sample.
        '[VoiceHustle] gap rep=2 gapMs=100 baselineMs=collecting armed=false',
        // First REAL sample — still collecting proves the 100ms was dropped.
        '[VoiceHustle] gap rep=3 gapMs=1000 baselineMs=collecting armed=false',
        // Second real sample sets baseline=1000 (NOT median(100,1000)=550).
        '[VoiceHustle] gap rep=4 gapMs=1000 baselineMs=1000 armed=false',
        '[VoiceHustle] gap rep=5 gapMs=2000 baselineMs=1000 armed=true',
      ]),
    );
  });

  test('final rep effort entry selects the target-proven final pool', () {
    _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 4,
      policy: _hustleAdapterPolicy(
        rolls: const [0.99, 0.99, 0.0],
        hustleBase: 0.50,
      ),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 5000);

    expect(
      sink.keys,
      isNot(contains('common.one_more_rep')),
      reason: 'the scripted paired roll at rep N-1 loses',
    );

    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 7000);

    expect(
      sink.keys.where((key) => key == 'common.one_more_rep'),
      const ['common.one_more_rep'],
      reason: 'the final effort-entry fire uses hustleFinalPool',
    );
    expect(sink.keys, isNot(contains('common.push')));
  });

  test('pause-voided gap neither arms nor feeds the baseline', () {
    final logs = _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 8)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 8,
      policy: _hustleAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);

    exercise.manualPause();
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1500);
    exercise.manualResume();
    // Fast-forward past the required resume re-hold; this test owns hustle gap
    // bookkeeping, not the setup countdown contract covered below.
    exercise.exerciseState = ExerciseState.activated;
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2500);

    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 5000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 6000);
    _driveFrame(coach, exercise, repCount: 4, phase: 'bottom', ms: 7000);
    _driveFrame(coach, exercise, repCount: 4, phase: 'ascending', ms: 9000);

    expect(
      logs,
      contains('[VoiceHustle] void rep=2 reason=pause gapMs=500'),
    );
    expect(
      logs.where((line) => line.contains('[VoiceHustle] gap')),
      containsAllInOrder([
        '[VoiceHustle] gap rep=3 gapMs=1000 baselineMs=collecting armed=false',
        '[VoiceHustle] gap rep=4 gapMs=1000 baselineMs=1000 armed=false',
        '[VoiceHustle] gap rep=5 gapMs=2000 baselineMs=1000 armed=true',
      ]),
      reason: 'the paused rep-2 gap is not counted as a baseline sample',
    );
    expect(sink.keys.where((key) => key == 'common.push'), hasLength(1));
  });

  test('pose-loss voided gap neither arms nor feeds the baseline', () {
    final logs = _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 6)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 6,
      policy: _hustleAdapterPolicy(),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(
      coach,
      exercise,
      repCount: 1,
      phase: 'bottom',
      ms: 1400,
      hasPose: false,
    );
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2400);
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4000);

    expect(
      logs,
      contains('[VoiceHustle] void rep=2 reason=pose_loss gapMs=400'),
    );
    expect(
      logs.where((line) => line.contains('[VoiceHustle] gap')),
      contains(
        '[VoiceHustle] gap rep=3 gapMs=1000 baselineMs=collecting armed=false',
      ),
      reason: 'the pose-loss gap did not become baseline sample #1',
    );
    expect(sink.keys, isNot(contains('common.push')));
  });

  test('fired paired finish consumes the final effort-entry push', () async {
    final logs = _captureDebugPrintsForTest();
    final sink = _BusyRecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 4,
      policy: _hustleAdapterPolicy(hustleBase: 1.0),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    sink.finishCurrentLine();
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 5000);

    expect(
      sink.keys.where((key) => key == 'common.one_more_rep'),
      const ['common.one_more_rep'],
      reason: 'pairing fires even though the count just made the sink busy',
    );

    sink.finishCurrentLine();
    await Future<void>.delayed(Duration.zero);
    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 7000);

    expect(
      logs,
      contains('[VoiceHustle] gap rep=4 gapMs=2000 baselineMs=1000 armed=true'),
    );
    expect(
      sink.keys.where((key) => key == 'common.one_more_rep'),
      hasLength(1),
      reason: 'the consumed final push must not fire again at effort entry',
    );
  });

  test('lost paired finish leaves the final effort-entry push live', () {
    _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 4)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 4,
      policy: _hustleAdapterPolicy(
        rolls: const [0.99, 0.99, 0.0],
        hustleBase: 0.50,
      ),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 5000);

    expect(sink.keys, isNot(contains('common.one_more_rep')));

    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 7000);

    expect(
      sink.keys.where((key) => key == 'common.one_more_rep'),
      const ['common.one_more_rep'],
      reason: 'a lost paired roll does not consume the final transition',
    );
  });

  test('empty hustle pools stay silent while gap and void logs fire', () {
    final logs = _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 5)
      ..exerciseState = ExerciseState.activated;
    final coach = PolicyVoiceCoach(
      script: _gluteBridgePilotScript(),
      coach: VoiceCoach(
        sink: sink,
        policy: _hustleAdapterPolicy(hustleBase: 1.0),
        random: _ScriptedRandom([0.0]),
      ),
      targetReps: 5,
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);

    _driveFrame(
      coach,
      exercise,
      repCount: 2,
      phase: 'bottom',
      ms: 3500,
      hasPose: false,
    );
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 4500);

    _driveFrame(coach, exercise, repCount: 3, phase: 'bottom', ms: 5000);
    _driveFrame(coach, exercise, repCount: 3, phase: 'ascending', ms: 6000);
    _driveFrame(coach, exercise, repCount: 4, phase: 'bottom', ms: 7000);
    _driveFrame(coach, exercise, repCount: 4, phase: 'ascending', ms: 9000);

    expect(
      logs,
      contains('[VoiceHustle] void rep=3 reason=pose_loss gapMs=500'),
    );
    expect(
      logs,
      contains('[VoiceHustle] gap rep=5 gapMs=2000 baselineMs=1000 armed=true'),
    );
    expect(
      sink.keys.where(
        (key) => key == 'common.push' || key == 'common.one_more_rep',
      ),
      isEmpty,
      reason: 'empty pools make say(hustle) no-op while logging still runs',
    );
  });

  test('scripts without effortPhaseKeys never arm hustle', () {
    final logs = _captureDebugPrintsForTest();
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 8)
      ..exerciseState = ExerciseState.activated;
    final coach = _hustleCoach(
      sink: sink,
      targetReps: 8,
      script: _hustleScript(effortPhaseKeys: const {}),
      policy: _hustleAdapterPolicy(hustleBase: 1.0),
    );
    addTearDown(coach.dispose);

    _driveFrame(coach, exercise, repCount: 0, phase: 'bottom', ms: 0);
    _driveFrame(coach, exercise, repCount: 1, phase: 'bottom', ms: 1000);
    _driveFrame(coach, exercise, repCount: 1, phase: 'ascending', ms: 2500);
    _driveFrame(coach, exercise, repCount: 2, phase: 'bottom', ms: 3000);
    _driveFrame(coach, exercise, repCount: 2, phase: 'ascending', ms: 6000);

    expect(sink.keys, isNot(contains('common.push')));
    expect(
      logs.where((line) => line.contains('[VoiceHustle] gap')),
      isEmpty,
      reason: 'squat-style scripts do not even measure hustle gaps',
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

  test('setup safety voice assets register common keys', () {
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.side_orientation'),
      'common/side_orientation.mp3',
    );
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.body_in_frame'),
      'common/body_in_frame.mp3',
    );
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.paused'),
      'common/paused.mp3',
    );
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.resume'),
      'common/resume.mp3',
    );
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.great_1'),
      'common/great_1.mp3',
    );
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.great_2'),
      'common/great_2.mp3',
    );
  });

  test('setup safety runs before the non-activated and no-pose early return',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      startMs: 0,
      count: 29,
      hasPose: false,
    );
    expect(sink.keys, isEmpty);

    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      ms: 3500,
      hasPose: false,
    );

    expect(sink.keys, const ['common.side_orientation']);
  });

  test('phone-orientation guidance speaks the rotate prompt (07-11 ruling)',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    // Standard entry latch: silent through the enter debounce, one fire on
    // the debounced edge, silent while the condition persists.
    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.phoneLandscape(),
      startMs: 0,
      count: 29,
      hasPose: false,
    );
    expect(sink.keys, isEmpty);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.phoneLandscape(),
      startMs: 3000,
      count: 10,
      hasPose: false,
    );
    expect(sink.keys, const ['common.rotate_landscape']);
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.rotate_landscape'),
      'common/rotate_landscape.mp3',
    );
    expect(
      GenericExerciseVoiceAssets.resolveAsset('common.rotate_portrait'),
      'common/rotate_portrait.mp3',
    );
  });

  test('steady setup safety is silent while held, then recues once', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      startMs: 0,
      count: 29,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 3500,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 5000,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 13500,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 20000,
      hasPose: false,
    );

    expect(
      sink.keys,
      const ['common.body_in_frame', 'common.body_in_frame'],
    );
  });

  test('sub-debounce setup safety flicker stays silent', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrame(
      coach,
      exercise,
      signal: null,
      ms: 0,
      hasPose: false,
    );
    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      startMs: 3600,
      count: 29,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: null,
      ms: 6600,
      hasPose: false,
    );

    expect(sink.keys, isEmpty);
  });

  test('same setup safety class fires again after debounced exit and re-entry',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      startMs: 0,
      count: 29,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      ms: 3500,
      hasPose: false,
    );
    _driveGuidanceFrames(
      coach,
      exercise,
      signal: null,
      startMs: 3600,
      count: 30,
      hasPose: false,
    );
    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      startMs: 6600,
      count: 30,
      hasPose: false,
    );

    expect(
      sink.keys,
      const ['common.side_orientation', 'common.side_orientation'],
    );
  });

  test('different setup safety class drains as soon as the sink is free', () {
    final sink = _BusyRecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      startMs: 0,
      count: 29,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      ms: 3500,
      hasPose: false,
    );
    expect(sink.keys, const ['common.side_orientation']);
    expect(sink.isBusy, isTrue);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      startMs: 3600,
      count: 30,
      hasPose: false,
    );
    expect(sink.keys, const ['common.side_orientation']);

    sink.finishCurrentLine();
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 6600,
      hasPose: false,
    );

    expect(
      sink.keys,
      const ['common.side_orientation', 'common.body_in_frame'],
    );
  });

  test('pending setup safety request drops when the condition clears', () {
    final sink = _BusyRecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      startMs: 0,
      count: 29,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.turnSide(),
      ms: 3500,
      hasPose: false,
    );
    expect(sink.keys, const ['common.side_orientation']);
    expect(sink.isBusy, isTrue);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      startMs: 3600,
      count: 30,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: null,
      ms: 6600,
      hasPose: false,
    );

    sink.finishCurrentLine();
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: null,
      ms: 6700,
      hasPose: false,
    );

    expect(sink.keys, const ['common.side_orientation']);
  });

  // Grace is VOICE-ONLY: signage renders live from frame one (the UI reads the
  // raw signal), while graced-class voice waits out the fallback window (no
  // intro audio here — _safetyCoach zeroes CueType.setup, so the fixed
  // kGuidanceSignalGraceMs window from set start applies).
  test('grace fallback suppresses voice only; guidance signal stays live', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 0,
      hasPose: false,
    );
    expect(exercise.guidanceSignal?.kind, GuidanceClass.bodyInFrame,
        reason: 'the UI signal is never grace-gated');
    expect(sink.keys, isEmpty);

    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.phoneLandscape(),
      ms: 100,
      hasPose: false,
    );
    expect(
      exercise.guidanceSignal?.kind,
      GuidanceClass.phoneLandscape,
    );
    expect(sink.keys, isEmpty);

    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      startMs: 600,
      count: 29,
      hasPose: false,
    );
    expect(exercise.guidanceSignal?.kind, GuidanceClass.bodyInFrame);
    expect(sink.keys, isEmpty,
        reason: 'graced-class voice stays quiet through the fallback window');

    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: ExerciseBase.kGuidanceSignalGraceMs,
      hasPose: false,
    );

    expect(sink.keys, const ['common.body_in_frame']);
  });

  test('graced voice is quiet for the intro duration, speaks at intro end',
      () async {
    final sink = _BusyRecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink);
    addTearDown(coach.dispose);

    // Set start: the intro pair is queued and audibly playing (sink busy).
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 0,
      hasPose: false,
    );
    expect(
      sink.keys,
      const ['glute_bridge.setup_position', 'glute_bridge.active_intro'],
    );

    // The graced condition persists well past the old 3.5s tail while the
    // intro still plays: signage live, voice quiet (window pinned to the
    // intro's actual duration).
    _driveGuidanceFrames(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      startMs: 100,
      count: 50,
      hasPose: false,
    );
    expect(exercise.guidanceSignal?.kind, GuidanceClass.bodyInFrame);
    expect(sink.keys, hasLength(2),
        reason: 'no graced safety voice over the intro, however long it runs');

    // Intro audio ends → the window CLOSES (no settle tail). The persisting
    // condition speaks on the very next frame: its enter debounce accrued
    // during the intro, so the debounce is the only residual delay.
    sink.finishCurrentLine();
    await Future<void>.delayed(Duration.zero);
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.bodyInFrame(),
      ms: 5200,
      hasPose: false,
    );

    expect(
      sink.keys,
      const [
        'glute_bridge.setup_position',
        'glute_bridge.active_intro',
        'common.body_in_frame',
      ],
      reason: 'prompt fire at intro-end, not intro-end + 3.5s',
    );
  });

  test('paused is an immediate edge and does not refire while held', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.activated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.paused(),
      ms: 0,
      hasPose: false,
    );
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.paused(),
      ms: 100,
      hasPose: false,
    );

    expect(sink.keys, const ['common.paused']);
  });

  test('resume speaks once from the producer edge signal', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.activated;
    final coach = _safetyCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveGuidanceFrame(
      coach,
      exercise,
      signal: const GuidanceSignal.resume(),
      ms: 0,
    );
    _driveGuidanceFrame(coach, exercise, signal: null, ms: 100);

    expect(sink.keys, const ['common.resume']);
  });

  // --- Setup-instruction voice (per-set intro / countdown / ready / done) ---

  test('setup intro fires once per set, unconditional, and again on a new set',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 3)
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink, targetReps: 3);
    addTearDown(coach.dispose);

    // Set start with ZERO pose frames: the intro fires anyway (unconditional).
    _driveSetupFrame(coach, exercise, ms: 0, hasPose: false);
    expect(
      sink.keys,
      const ['glute_bridge.setup_position', 'glute_bridge.active_intro'],
    );

    // Further notActivated frames never repeat it.
    _driveSetupFrame(coach, exercise, ms: 100, hasPose: false);
    _driveSetupFrame(coach, exercise, ms: 200);
    expect(
      sink.keys,
      const ['glute_bridge.setup_position', 'glute_bridge.active_intro'],
    );

    // Run the set to completion, then a genuine restart (completed →
    // notActivated) re-fires the intro.
    exercise.exerciseState = ExerciseState.activated;
    _driveSetupFrame(coach, exercise, ms: 300);
    exercise.exerciseState = ExerciseState.completed;
    _driveSetupFrame(coach, exercise, ms: 400);
    exercise.exerciseState = ExerciseState.notActivated;
    _driveSetupFrame(coach, exercise, ms: 500, hasPose: false);

    expect(
      sink.keys.where((k) => k == 'glute_bridge.setup_position'),
      hasLength(2),
      reason: 'a new set re-fires the intro',
    );
    expect(
      sink.keys.where((k) => k == 'glute_bridge.active_intro'),
      hasLength(2),
    );
  });

  test('ready fires once on the activation edge; set-complete once on done',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 2)
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink, targetReps: 2);
    addTearDown(coach.dispose);

    _driveSetupFrame(coach, exercise, ms: 0, hasPose: false);
    expect(sink.keys.where((k) => k == 'common.ready'), isEmpty);

    exercise.exerciseState = ExerciseState.activated;
    _driveSetupFrame(coach, exercise, ms: 100);
    _driveSetupFrame(coach, exercise, ms: 200);
    expect(sink.keys.where((k) => k == 'common.ready'), hasLength(1));
    expect(sink.keys.where((k) => k == 'common.set_complete'), isEmpty);

    exercise.exerciseState = ExerciseState.completed;
    _driveSetupFrame(coach, exercise, ms: 300);
    _driveSetupFrame(coach, exercise, ms: 400);
    expect(sink.keys.where((k) => k == 'common.set_complete'), hasLength(1));
  });

  test('holdStill emits no instruction line (and never common.hold_still)', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink);
    addTearDown(coach.dispose);

    _driveSetupFrame(coach, exercise, ms: 0, hasPose: false);
    final afterIntro = List<String>.from(sink.keys);

    // holdStill held for many frames, no hold clock → still no line at all.
    for (var i = 1; i <= 40; i++) {
      exercise.publishGuidanceSignal(
        const GuidanceSignal.holdStill(),
        publishFeedback: false,
      );
      _driveSetupFrame(coach, exercise, ms: 100 * i);
    }

    expect(sink.keys, afterIntro,
        reason: 'holdStill is lineless — the countdown owns that state');
    expect(sink.keys, isNot(contains('common.hold_still')));
  });

  test('activation countdown counts up in order and ba lands before ready', () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 3)
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink, targetReps: 3);
    addTearDown(coach.dispose);

    _driveSetupFrame(coach, exercise, ms: 0, hasPose: false);

    // Hold progresses through the 3s window: một @≥800, hai @≥1600, ba @≥2400.
    exercise.holdElapsedOverride = 500;
    _driveSetupFrame(coach, exercise, ms: 600);
    exercise.holdElapsedOverride = 900;
    _driveSetupFrame(coach, exercise, ms: 1000);
    exercise.holdElapsedOverride = 1700;
    _driveSetupFrame(coach, exercise, ms: 1800);
    exercise.holdElapsedOverride = 2500;
    _driveSetupFrame(coach, exercise, ms: 2600);

    // Activation: the hold clock nulls, state flips; "ba" already fired.
    exercise
      ..holdElapsedOverride = null
      ..exerciseState = ExerciseState.activated;
    _driveSetupFrame(coach, exercise, ms: 3000);

    final counts =
        sink.keys.where((k) => RegExp(r'^\d+$').hasMatch(k)).toList();
    expect(counts, const ['1', '2', '3']);
    expect(
      sink.keys.indexOf('3') < sink.keys.indexOf('common.ready'),
      isTrue,
      reason: 'ba is queued before the ready cue',
    );
  });

  test('a broken hold drops pending counts and a re-hold restarts from một',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 3)
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink, targetReps: 3);
    addTearDown(coach.dispose);

    _driveSetupFrame(coach, exercise, ms: 0, hasPose: false);

    exercise.holdElapsedOverride = 900;
    _driveSetupFrame(coach, exercise, ms: 1000);
    exercise.holdElapsedOverride = 1700;
    _driveSetupFrame(coach, exercise, ms: 1800);
    expect(
      sink.keys.where((k) => RegExp(r'^\d+$').hasMatch(k)).toList(),
      const ['1', '2'],
    );

    // Hold breaks (still notActivated, clock gone): drop pending counts.
    exercise.holdElapsedOverride = null;
    _driveSetupFrame(coach, exercise, ms: 1900);
    expect(sink.clearPendingCalls, 1,
        reason: 'a broken hold drops the perishable pending count line');

    // Re-hold restarts from "một" — no stale hai/ba replays.
    exercise.holdElapsedOverride = 900;
    _driveSetupFrame(coach, exercise, ms: 2500);
    expect(
      sink.keys.where((k) => RegExp(r'^\d+$').hasMatch(k)).toList(),
      const ['1', '2', '1'],
    );
  });

  test('manual resume re-enters start gate without clearing set progress', () {
    final exercise = _VoiceTestExercise(targetReps: 5)
      ..exerciseState = ExerciseState.activated
      ..repCount = 2;

    exercise.manualPause();
    exercise.manualResume();

    expect(exercise.exerciseState, ExerciseState.notActivated);
    expect(exercise.isReactivatingAfterPause, isTrue);
    expect(exercise.repCount, 2);
  });

  test('resume re-hold repeats countdown and ready without replaying intro',
      () {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 5)
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink, targetReps: 5);
    addTearDown(coach.dispose);

    _driveSetupFrame(coach, exercise, ms: 0, hasPose: false);
    exercise.exerciseState = ExerciseState.activated;
    _driveSetupFrame(coach, exercise, ms: 100);

    exercise
      ..reactivatingAfterPauseOverride = true
      ..exerciseState = ExerciseState.notActivated;
    _driveSetupFrame(coach, exercise, ms: 200);

    exercise.holdElapsedOverride = 900;
    _driveSetupFrame(coach, exercise, ms: 1000);
    exercise.holdElapsedOverride = 1700;
    _driveSetupFrame(coach, exercise, ms: 1800);
    exercise.holdElapsedOverride = 2500;
    _driveSetupFrame(coach, exercise, ms: 2600);

    exercise
      ..reactivatingAfterPauseOverride = false
      ..holdElapsedOverride = null
      ..exerciseState = ExerciseState.activated;
    _driveSetupFrame(coach, exercise, ms: 3000);

    expect(
      sink.keys.where((k) => k == 'glute_bridge.setup_position'),
      hasLength(1),
      reason: 'resume re-hold is not a new set intro',
    );
    expect(
      sink.keys.where((k) => k == 'glute_bridge.active_intro'),
      hasLength(1),
    );
    expect(
      sink.keys.where((k) => RegExp(r'^\d+$').hasMatch(k)).toList(),
      const ['1', '2', '3'],
    );
    expect(sink.keys.where((k) => k == 'common.ready'), hasLength(2));
  });

  test('countdown terminates a still-playing intro and closes the grace', () {
    final sink = _BusyRecordingVoiceSink();
    final exercise = _VoiceTestExercise(targetReps: 3)
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink, targetReps: 3);
    addTearDown(coach.dispose);

    // Set start: the intro pair queued and audibly playing.
    _driveSetupFrame(coach, exercise, ms: 0, hasPose: false);
    expect(
      sink.keys,
      const ['glute_bridge.setup_position', 'glute_bridge.active_intro'],
    );
    expect(sink.isBusy, isTrue);

    // The user is already holding the start position: the first count fires
    // while the intro is still playing → the intro is stopped (current +
    // queued dropped, never resumes), the count speaks immediately, and
    // intro-audio-end is marked so the voice grace closes with it.
    exercise.holdElapsedOverride = 900;
    _driveSetupFrame(coach, exercise, ms: 1000);

    expect(sink.stopCalls, 1, reason: 'the still-playing intro was stopped');
    expect(sink.keys.last, '1',
        reason: 'the count speaks immediately, not stalled behind the intro');
    expect(
      exercise.isGuidanceGraceActive(GuidanceClass.bodyInFrame),
      isFalse,
      reason: 'the voice grace closes at the terminated intro-audio-end',
    );

    // The re-tell floor was stamped at the termination moment: a user who then
    // drops the hold and stays out of position earns the delayed re-tell
    // (a null floor would block it forever).
    sink.finishCurrentLine();
    exercise.holdElapsedOverride = null;
    for (var i = 1; i <= 135; i++) {
      _driveSetupRetellFrame(coach, exercise, ms: 1000 + 100 * i);
    }
    expect(
      sink.keys.where((k) => k == 'glute_bridge.setup_position'),
      hasLength(2),
      reason: 'intro line + one delayed re-tell measured from the stamp',
    );
  });

  test('stuck-user re-tell never fires while the intro audio is playing', () {
    final sink = _BusyRecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink);
    addTearDown(coach.dispose);

    // Set start: intro queued, the sink stays busy (intro never finishes here),
    // so intro-audio-end is never observed.
    _driveSetupRetellFrame(coach, exercise, ms: 0);
    expect(
      sink.keys,
      const ['glute_bridge.setup_position', 'glute_bridge.active_intro'],
    );

    // setupPosition latched and held well past the ~10s delay — no re-tell,
    // because the intro is still playing.
    for (var i = 1; i <= 200; i++) {
      _driveSetupRetellFrame(coach, exercise, ms: 100 * i);
    }
    expect(
      sink.keys.where((k) => k == 'glute_bridge.setup_position'),
      hasLength(1),
      reason: 'the re-tell must never speak over the intro audio',
    );
  });

  test('stuck-user re-tell fires once past intro-end and re-arms on re-entry',
      () async {
    final sink = _RecordingVoiceSink();
    final exercise = _VoiceTestExercise()
      ..exerciseState = ExerciseState.notActivated;
    final coach = _setupCoach(sink: sink);
    addTearDown(coach.dispose);

    // Set start: intro fires; flush the waiter so intro-audio-end is captured
    // on the next frame.
    _driveSetupRetellFrame(coach, exercise, ms: 0);
    await Future<void>.delayed(Duration.zero);

    // Latch (30-frame debounce) and hold. The re-tell must NOT fire before the
    // ~10s delay elapses (latch ~2900ms → fire ~12900ms).
    for (var i = 1; i <= 120; i++) {
      _driveSetupRetellFrame(coach, exercise, ms: 100 * i);
    }
    expect(
      sink.keys.where((k) => k == 'glute_bridge.setup_position'),
      hasLength(1),
      reason: 'before the ~10s delay only the intro line has spoken',
    );

    for (var i = 121; i <= 200; i++) {
      _driveSetupRetellFrame(coach, exercise, ms: 100 * i);
    }
    expect(
      sink.keys.where((k) => k == 'glute_bridge.setup_position'),
      hasLength(2),
      reason: 'one delayed re-tell, then silence while still latched',
    );

    // Debounced exit (setupPosition clear) then re-entry earns exactly one more.
    for (var i = 201; i <= 240; i++) {
      _driveSetupClearFrame(coach, exercise, ms: 100 * i);
    }
    for (var i = 241; i <= 440; i++) {
      _driveSetupRetellFrame(coach, exercise, ms: 100 * i);
    }
    expect(
      sink.keys.where((k) => k == 'glute_bridge.setup_position'),
      hasLength(3),
      reason: 'a genuine leave-and-return re-arms one more re-tell',
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
      // Silence the new structural setup cues (intro / ready) so this test's
      // exact key sequence stays the rep counts only.
      CueType.setup: const CueTuning(CueMode.base, base: 0.0),
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
    reminderPools: const {},
    hustlePool: const [],
    hustleFinalPool: const [],
    repStartPhaseKeys: const {'ascending'},
    effortPhaseKeys: const {'ascending'},
  );
}

VoiceScript _reminderScript({
  Map<String, List<String>> reminderPools = const {
    'hyperextension': ['glute_bridge.hyperextension_reminder'],
    'neck_head': ['glute_bridge.neck_head_reminder'],
  },
  List<String> hustlePool = const [],
  Set<String> repStartPhaseKeys = const {'ascending'},
  Set<String> effortPhaseKeys = const {'ascending'},
}) {
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
    reminderPools: reminderPools,
    hustlePool: hustlePool,
    hustleFinalPool: const [],
    repStartPhaseKeys: repStartPhaseKeys,
    effortPhaseKeys: effortPhaseKeys,
  );
}

VoiceScript _hustleScript({
  Set<String> effortPhaseKeys = const {'ascending'},
  List<String> hustlePool = const ['common.push'],
  List<String> hustleFinalPool = const ['common.one_more_rep'],
}) {
  return VoiceScript.from(
    VoiceDefaults.repBased,
    slug: 'test',
    praisePool: const [],
    hustlePool: hustlePool,
    hustleFinalPool: hustleFinalPool,
    effortPhaseKeys: effortPhaseKeys,
  );
}

PolicyVoiceCoach _reminderCoach({
  required VoiceSink sink,
  required int targetReps,
  required VoicePolicy policy,
  VoiceScript? script,
}) {
  return PolicyVoiceCoach(
    script: script ?? _reminderScript(),
    coach: VoiceCoach(
      sink: sink,
      policy: policy,
      random: _ScriptedRandom([0.0]),
    ),
    targetReps: targetReps,
  );
}

PolicyVoiceCoach _hustleCoach({
  required VoiceSink sink,
  required int targetReps,
  required VoicePolicy policy,
  VoiceScript? script,
}) {
  return PolicyVoiceCoach(
    script: script ?? _hustleScript(),
    coach: VoiceCoach(
      sink: sink,
      policy: policy,
      random: _ScriptedRandom([0.0]),
    ),
    targetReps: targetReps,
  );
}

PolicyVoiceCoach _safetyCoach({
  required VoiceSink sink,
  VoiceScript? script,
}) {
  return PolicyVoiceCoach(
    script: script ??
        VoiceScript.from(
          VoiceDefaults.repBased,
          slug: 'glute_bridge',
          faultIds: const [],
        ),
    coach: VoiceCoach(
      sink: sink,
      policy: _safetyOnlyPolicy(),
      random: _ScriptedRandom([0.0]),
    ),
  );
}

// Setup-instruction coach: leaves CueType.setup at its default (base 1.0) and
// safety at always, and zeroes every other cue so ONLY the structural setup
// lines (intro / countdown / ready / set-complete) and the stuck-user re-tell
// can speak.
PolicyVoiceCoach _setupCoach({
  required VoiceSink sink,
  int? targetReps,
  VoiceScript? script,
}) {
  return PolicyVoiceCoach(
    script: script ??
        VoiceScript.from(
          VoiceDefaults.repBased,
          slug: 'glute_bridge',
          faultIds: const [],
        ),
    coach: VoiceCoach(
      sink: sink,
      policy: _setupOnlyPolicy(),
      random: _ScriptedRandom([0.0]),
    ),
    targetReps: targetReps,
  );
}

VoicePolicy _setupOnlyPolicy() {
  return VoicePolicy(
    random: _ScriptedRandom([0.0]),
    tuning: {
      ...kDefaultTuning,
      CueType.count: const CueTuning(CueMode.always, base: 0.0, cap: 0.0),
      CueType.praise:
          const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
      CueType.criticalFault:
          const CueTuning(CueMode.correction, base: 0.0, cap: 0.0),
      CueType.softFault:
          const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
      CueType.reminder:
          const CueTuning(CueMode.correction, base: 0.0, cap: 0.0),
      CueType.hustle: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
      CueType.phase: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
      // CueType.setup left at default base 1.0; CueType.safety at default always.
    },
    outcomeCollisionGapMs: 0,
  );
}

void _driveSetupFrame(
  PolicyVoiceCoach coach,
  _VoiceTestExercise exercise, {
  required int ms,
  bool hasPose = true,
}) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  coach.processFrame(
    exercise: exercise,
    repCount: exercise.repCount,
    hasPose: hasPose,
    feedback: const {},
  );
}

void _driveSetupRetellFrame(
  PolicyVoiceCoach coach,
  _VoiceTestExercise exercise, {
  required int ms,
}) {
  exercise
    ..frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms)
    ..publishGuidanceSignal(
      const GuidanceSignal.setupPosition(),
      publishFeedback: false,
    );
  coach.processFrame(
    exercise: exercise,
    repCount: exercise.repCount,
    hasPose: false,
    feedback: const {},
  );
}

void _driveSetupClearFrame(
  PolicyVoiceCoach coach,
  _VoiceTestExercise exercise, {
  required int ms,
}) {
  exercise
    ..frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms)
    ..clearGuidanceSignal(clearFeedback: true);
  coach.processFrame(
    exercise: exercise,
    repCount: exercise.repCount,
    hasPose: false,
    feedback: const {},
  );
}

Map<CueType, CueTuning> _reminderAdapterTuning({
  double reminderBase = 1.0,
  double reminderStep = 0.0,
  double reminderCap = 1.0,
  double hustleBase = 0.0,
}) {
  return {
    ...kDefaultTuning,
    CueType.count: const CueTuning(CueMode.always, base: 0.0, cap: 0.0),
    CueType.praise: const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
    CueType.criticalFault: const CueTuning(
      CueMode.correction,
      base: 0.0,
      cap: 0.0,
      firstOccurrenceCertain: false,
    ),
    CueType.softFault:
        const CueTuning(CueMode.variableRatio, base: 0.0, cap: 0.0),
    CueType.reminder: CueTuning(
      CueMode.correction,
      base: reminderBase,
      step: reminderStep,
      cap: reminderCap,
      firstOccurrenceCertain: true,
    ),
    CueType.hustle: CueTuning(
      CueMode.perishable,
      base: hustleBase,
      cap: hustleBase,
    ),
    CueType.phase: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
  };
}

VoicePolicy _reminderAdapterPolicy({
  List<double> rolls = const [0.0],
  double reminderBase = 1.0,
  double reminderStep = 0.0,
  double reminderCap = 1.0,
  double hustleBase = 0.0,
}) {
  return VoicePolicy(
    random: _ScriptedRandom(rolls),
    tuning: _reminderAdapterTuning(
      reminderBase: reminderBase,
      reminderStep: reminderStep,
      reminderCap: reminderCap,
      hustleBase: hustleBase,
    ),
    outcomeCollisionGapMs: 0,
  );
}

VoicePolicy _hustleAdapterPolicy({
  List<double> rolls = const [0.0],
  double hustleBase = 1.0,
  double hustleStep = 0.0,
  double hustleCap = 1.0,
}) {
  return VoicePolicy(
    random: _ScriptedRandom(rolls),
    tuning: {
      ...kDefaultTuning,
      CueType.count: const CueTuning(CueMode.always, base: 0.0, cap: 0.0),
      CueType.praise: const CueTuning(CueMode.variableRatio, base: 0.0),
      CueType.criticalFault: const CueTuning(CueMode.correction, base: 0.0),
      CueType.softFault: const CueTuning(CueMode.variableRatio, base: 0.0),
      CueType.hustle: CueTuning(
        CueMode.perishable,
        base: hustleBase,
        step: hustleStep,
        cap: hustleCap,
      ),
      CueType.phase: const CueTuning(CueMode.perishable, base: 0.0),
    },
    outcomeCollisionGapMs: 0,
  );
}

VoicePolicy _safetyOnlyPolicy() {
  return VoicePolicy(
    random: _ScriptedRandom([0.0]),
    tuning: {
      ...kDefaultTuning,
      CueType.count: const CueTuning(CueMode.always, base: 0.0, cap: 0.0),
      CueType.praise: const CueTuning(CueMode.variableRatio, base: 0.0),
      CueType.criticalFault: const CueTuning(CueMode.correction, base: 0.0),
      CueType.softFault: const CueTuning(CueMode.variableRatio, base: 0.0),
      CueType.reminder: const CueTuning(CueMode.correction, base: 0.0),
      CueType.hustle: const CueTuning(CueMode.perishable, base: 0.0),
      CueType.phase: const CueTuning(CueMode.perishable, base: 0.0),
      CueType.safety: const CueTuning(CueMode.always),
      // Silence the intro so the safety-channel assertions stay unpolluted.
      CueType.setup: const CueTuning(CueMode.base, base: 0.0),
    },
    outcomeCollisionGapMs: 0,
  );
}

void _driveGuidanceFrames(
  PolicyVoiceCoach coach,
  _VoiceTestExercise exercise, {
  required GuidanceSignal? signal,
  required int startMs,
  required int count,
  bool hasPose = true,
  int stepMs = 100,
}) {
  for (var i = 0; i < count; i++) {
    _driveGuidanceFrame(
      coach,
      exercise,
      signal: signal,
      ms: startMs + i * stepMs,
      hasPose: hasPose,
    );
  }
}

void _driveGuidanceFrame(
  PolicyVoiceCoach coach,
  _VoiceTestExercise exercise, {
  required GuidanceSignal? signal,
  required int ms,
  bool hasPose = true,
}) {
  exercise
    ..frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms)
    ..phase = 'bottom';
  if (signal == null) {
    exercise.clearGuidanceSignal(clearFeedback: true);
  } else {
    exercise.publishGuidanceSignal(signal, publishFeedback: false);
  }
  coach.processFrame(
    exercise: exercise,
    repCount: exercise.repCount,
    hasPose: hasPose,
    feedback: const {},
  );
}

void _driveFrame(
  PolicyVoiceCoach coach,
  _VoiceTestExercise exercise, {
  required int repCount,
  required String phase,
  required int ms,
  bool hasPose = true,
}) {
  exercise
    ..phase = phase
    ..frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  coach.processFrame(
    exercise: exercise,
    repCount: repCount,
    hasPose: hasPose,
    feedback: const {},
  );
}

List<String> _captureDebugPrintsForTest() {
  final logs = <String>[];
  final previous = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) logs.add(message);
  };
  addTearDown(() {
    debugPrint = previous;
  });
  return logs;
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
      CueType.criticalFault: const CueTuning(
        CueMode.correction,
        base: 0.0,
        step: 0.0,
        cap: 0.0,
        firstOccurrenceCertain: true,
      ),
      CueType.softFault:
          const CueTuning(CueMode.variableRatio, base: 1.0, cap: 1.0),
      CueType.hustle: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
      CueType.phase: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
      // Silence intro / ready so _spokenOutcomeKeys sees only the outcome cue.
      CueType.setup: const CueTuning(CueMode.base, base: 0.0, cap: 0.0),
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

class _RecordingVoicePolicy extends VoicePolicy {
  _RecordingVoicePolicy({required super.tuning})
      : super(
          random: _ScriptedRandom([0.0]),
          outcomeCollisionGapMs: 0,
        );

  final List<CueType> cueTypes = [];

  @override
  bool decide(CueType type, CueContext ctx) {
    cueTypes.add(type);
    return super.decide(type, ctx);
  }
}

class _RecordingVoiceSink implements VoiceSink {
  final List<String> keys = [];
  int clearPendingCalls = 0;

  @override
  bool get isBusy => false;

  @override
  Future<void> playKey(String logicalKey) async {
    keys.add(logicalKey);
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) async {}

  @override
  void clearPending() {
    clearPendingCalls++;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class _BusyRecordingVoiceSink implements VoiceSink {
  final List<String> keys = [];
  int clearPendingCalls = 0;
  int stopCalls = 0;
  Completer<void>? _idleCompleter;
  bool _busy = false;

  @override
  bool get isBusy => _busy;

  @override
  Future<void> playKey(String logicalKey) async {
    keys.add(logicalKey);
    _busy = true;
    _idleCompleter ??= Completer<void>();
  }

  void finishCurrentLine() {
    _busy = false;
    final completer = _idleCompleter;
    _idleCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _idleCompleter?.future ?? Future<void>.value();
  }

  @override
  void clearPending() {
    clearPendingCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    finishCurrentLine();
  }

  @override
  void dispose() {
    finishCurrentLine();
  }
}

class _VoiceTestExercise extends ExerciseBase {
  _VoiceTestExercise({super.targetReps});

  List<FaultRecord> live = const [];
  String phase = 'bottom';
  bool reactivatingAfterPauseOverride = false;

  /// Test-driven activation-hold clock. The real getter reads the private
  /// `_holdStillStartedAt` the state machine drives; overriding it lets a test
  /// exercise the voiced countdown without standing up the pose pipeline.
  int? holdElapsedOverride;

  @override
  int? get holdStillElapsedMs => holdElapsedOverride;

  @override
  bool get isReactivatingAfterPause =>
      reactivatingAfterPauseOverride || super.isReactivatingAfterPause;

  @override
  List<FaultRecord> get liveFaults => live;

  @override
  String get exerciseName => 'Glute Bridge';

  @override
  String get currentPhaseKey => phase;

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
