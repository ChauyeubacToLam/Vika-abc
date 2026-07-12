// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/frame_buffer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/squat_metric_base.dart';
import 'metrics/squat_depth_metric.dart';
import 'metrics/trunk_lean_metric.dart';
import 'metrics/heel_rise_metric.dart';
import 'metrics/tempo_metric.dart';
import 'metrics/hip_shoulder_sync.dart';
import '../../services/generic_exercise_voice_assets.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

// --- Config ---

class SquatConfig {
  static const double ERROR_ALLOW = 2;
  static const int MAX_REP = 15;
  static const double SQUAT_STAND_ANGLE_THRESHOLD = 155;
  static const List<int> SQUAT_BOTTOM_ANGLE_THRESHOLD = [70, 115];
  static const double BOTTOM_RELEASE_READY_TOLERANCE_SECONDS = 0.05;
  static const double CLEAN_REP_KNEE_ANGLE = 171.2;
  static const double CLEAN_REP_KNEE_TOLERANCE = 12.0;
  static const double CLEAN_REP_BACK_ANGLE = 17.43;
  static const double CLEAN_REP_BACK_TOLERANCE = 12.0;
  static const double CLEAN_REP_TRUNK_LEAN = 17.43;
  static const double CLEAN_REP_TRUNK_LEAN_TOLERANCE = 12.0;
  static const double CLEAN_REP_HEEL_LIFT_PCT = 3.081;
  static const double CLEAN_REP_HEEL_LIFT_PCT_TOLERANCE = 8.0;
  static const double CLEAN_REP_BOTTOM_HOLD_PROGRESS_MIN = 0.80;
  static const double ANGLE_STABLE_GATE =
      2; // degrees, for FrameBuffer angle change detection
  static const double ROM_GATE =
      28; // degrees, minimum angle change to confirm direction switch from descending to ascending
}

enum SquatState { standing, descending, bottom, ascending }

// --- Squat ---
// DATA LOGGING PIPELINE:
// 1. frameBuffer (Per-Frame):
//    - kneeAngle: used for state transitions
// 2. RepLog (Per-Rep):
//    - peak_heel_distance: the max heelDistance reached in the rep
//    - peak_knee_angle: the min kneeAngle reached in the rep (deepest point)
//    - trunk_lean_at_bottom: the trunkLean at the deepest point
//    - ascending_time & descending_time: analyzed by TempoMetric
// 3. Set-Level Summaries (onSetComplete):
//    Aggregates all RepLogs from the set into final values:
//    - max_heel_distance: from the max of all peak_heel_distance
//    - min_knee_angle: from the min of all peak_knee_angle
//    - min_ascending_time: from the min of all ascending_time
//    - min_descending_time: from the min of all descending_time
//    On set complete, push:
//    - heel_fails_count: from the sum of all heel_fails_count
//    - depth_fails_count: from the sum of all depth_fails_count
//    - trunk_lean_fails_count: from the sum of all trunk_lean_fails_count
//    - tempo_fails_count: from the sum of all tempo_fails_count
//    - hip_shoulder_sync_fails_count: from the sum of all hip_shoulder_sync_fails_count

class Squat extends ExerciseBase with SideTrackedExerciseMixin {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  static const String standingStatus = 'Xuống';
  static const String descendingStatus = 'Going Down...';
  static const String ascendingStatus = 'Đứng lên';

  final int maxRep;
  SquatState squatState = SquatState.standing;
  SquatState previousSquatState = SquatState.standing;
  List<String> lastRepFaultVoiceMessages = [];
  String? lastRepTopVoiceMessage;
  int? lastRepTopVoicePriority;
  bool lastRepWasClean = true;
  bool _reachedBottomThisRep = false;
  double? _repMinKneeAngle;
  double? _repTrunkLeanAtBottom;
  double? _repMaxHeelDistance;

  Squat({this.maxRep = SquatConfig.MAX_REP}) : super(targetReps: maxRep);

  static String bottomHoldStatus(double remainingSeconds) =>
      'Hold! ${remainingSeconds.toStringAsFixed(1)}s';

  static bool isHoldStatus(String statusText) {
    return statusText.startsWith('Hold') || statusText.contains('Giữ');
  }

  static bool isReleaseStatus(String statusText) {
    return statusText.contains('Push Up Now!') ||
        statusText.contains(ascendingStatus);
  }

  static List<FaultRecord> orderedVoicedFaults(Iterable<FaultRecord> faults) {
    final voicedFaults = faults
        .where((fault) =>
            fault.voiceMessage != null && fault.voiceMessage!.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }

        final typeCompare = a.type.compareTo(b.type);
        if (typeCompare != 0) {
          return typeCompare;
        }

        return a.message.compareTo(b.message);
      });

    return voicedFaults;
  }

  static FaultRecord? topVoicedFault(Iterable<FaultRecord> faults) {
    final voicedFaults = orderedVoicedFaults(faults);
    return voicedFaults.isEmpty ? null : voicedFaults.first;
  }

  static List<String> orderedUniqueVoiceMessages(Iterable<FaultRecord> faults) {
    final orderedVoiceMessages = <String>[];
    final seenVoiceMessages = <String>{};

    for (final fault in orderedVoicedFaults(faults)) {
      final voiceMessage = fault.voiceMessage!;
      if (seenVoiceMessages.add(voiceMessage)) {
        orderedVoiceMessages.add(voiceMessage);
      }
    }

    return orderedVoiceMessages;
  }

  // Metrics
  final DepthMetric depthMetric = DepthMetric();
  final TrunkLeanMetric trunkLeanMetric = TrunkLeanMetric();
  final HeelRiseMetric heelRiseMetric = HeelRiseMetric();
  final TempoMetric tempoMetric = TempoMetric();
  final HipShoulderSyncMetric hipShoulderSyncMetric = HipShoulderSyncMetric();

  late final List<SquatMetricBase> _metrics = [
    depthMetric,
    trunkLeanMetric,
    heelRiseMetric,
    tempoMetric,
    hipShoulderSyncMetric,
  ];

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip
        ),
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder,
        ),
        'knee': (
          right: PoseLandmarkType.rightKnee,
          left: PoseLandmarkType.leftKnee
        ),
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle,
        ),
        'foot': (
          right: PoseLandmarkType.rightFootIndex,
          left: PoseLandmarkType.leftFootIndex,
        ),
        'heel': (
          right: PoseLandmarkType.rightHeel,
          left: PoseLandmarkType.leftHeel
        ),
      };

  // Debouncers for state transitions
  final Debouncer _bottomDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _standingDebouncer = Debouncer(requiredFrames: 2);
  final StickyDebouncer directionDetection = StickyDebouncer();

  // base
  double _baselineKneeAngle = SquatConfig
      .SQUAT_STAND_ANGLE_THRESHOLD; // Updated when standing still at the top to adapt to user differences and tracking noise.

  // --- UI Bridge ---

  @override
  String get exerciseName => 'Squat';

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  /// Squat pilot for the shared voice policy.
  ///
  /// The old [SquatVoiceCoach] did three jobs at once: phase cues,
  /// post-rep count/praise/correct lines, and setup/complete structure.
  /// This factory now hands the first two jobs to [PolicyVoiceCoach] while
  /// deliberately leaving setup/complete silent until the later instruction
  /// wiring stage.
  @override
  ExerciseVoiceCoach? createVoiceCoach() {
    // Reuse the legacy footprint instead of hardcoding squat's slug/fault ids.
    // That keeps fault audio keys identical: e.g. depth -> squat.depth.
    final legacy =
        GenericExerciseVoiceAssets.scriptForExerciseName(exerciseName);
    final script = VoiceScript.from(
      VoiceDefaults.repBased,
      slug: legacy.slug,
      faultIds: legacy.faultIds,
      reminderPools: const {
        'trunk': ['squat.trunk_reminder'],
      },
      hustlePool: const [],
      repStartPhaseKeys: const {'descending'},
      // No phaseCues: the new coach does NOT narrate the movement ("Xuống" /
      // "Giữ" / "Đứng lên") — that was the legacy behaviour. Silence is the
      // default; squat speaks only counts, praise, faults, and setup, like the
      // rest of the fleet (Nam, 2026-07-11).
    );
    return PolicyVoiceCoach(
      script: script,
      coach: VoiceCoach(
        sink: AssetVoiceSink(),
        policy: VoicePolicy(
          tuning: {
            ...kDefaultTuning,
            CueType.hustle:
                const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
          },
        ),
      ),
      // Final-rep awareness stays for count anchors. Hustle remains neutralized
      // by the empty pool, zero tuning, and absent effortPhaseKeys.
      targetReps: targetReps,
    );
  }

  @override
  String get currentPhaseKey => squatState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (squatState) {
      case SquatState.standing:
        return 'Đứng thẳng';
      case SquatState.descending:
        return 'Xuống';
      case SquatState.bottom:
        return 'Giữ';
      case SquatState.ascending:
        return 'Đứng lên';
    }
  }

  @override
  double? get liveHoldSeconds {
    if (squatState != SquatState.bottom) return null;
    final remaining = tempoMetric.bottomHoldRemaining(frameTimestampMs);
    if (remaining == null) return null;
    return (TempoConfig.BOTTOM_HOLD_MIN - remaining)
        .clamp(0.0, TempoConfig.BOTTOM_HOLD_MIN);
  }

  @override
  double? get liveHoldTargetSeconds => TempoConfig.BOTTOM_HOLD_MIN;

  bool get hasCompletedBottomHold {
    final holdDuration = tempoMetric.bottomHoldDuration;
    if (holdDuration != null) {
      return holdDuration >= TempoConfig.BOTTOM_HOLD_MIN;
    }

    final remaining = tempoMetric.bottomHoldRemaining(frameTimestampMs);
    return remaining != null &&
        remaining <= SquatConfig.BOTTOM_RELEASE_READY_TOLERANCE_SECONDS;
  }

  // --- Start Position ---
  // User must stand upright with straight legs to begin.

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final requiredLandmarks = getSideTrackedLandmarks(landmarks);
    if (requiredLandmarks == null) return false;

    final shoulder = requiredLandmarks['shoulder']!;
    final hip = requiredLandmarks['hip']!;
    final knee = requiredLandmarks['knee']!;
    final ankle = requiredLandmarks['ankle']!;

    // Trunk must be roughly vertical (< 25° deviation)
    double deviation = calculateVerticalAngle(pivot: hip, point: shoulder);
    if (deviation > 180) deviation = 360 - deviation;
    if (deviation > 25.0) return false;

    // Legs must be straight (knee angle > 155°)
    final kneeAngle = calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: ankle,
    );
    if (kneeAngle < _baselineKneeAngle - SquatConfig.ERROR_ALLOW) return false;
    _baselineKneeAngle = kneeAngle; // Set baseline for this user

    return true;
  }

  // --- Stop Condition & Set-Level Logging ---
  // Aggregates per-rep data into set-level summaries when exercise completes.
  @override
  void onSetComplete() {
    // Fault counts per metric
    logger.pushKey("heel_fails_count", heelRiseMetric.faultsCount);
    logger.pushKey("depth_fails_count", depthMetric.faultsCount);
    logger.pushKey("trunk_lean_fails_count", trunkLeanMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushKey(
        "hip_shoulder_sync_fails_count", hipShoulderSyncMetric.faultsCount);

    // Aggregated per-rep statsL
    logger.pushMax("peak_heel_distance", "max_heel_distance");
    logger.pushMin("peak_knee_angle", "min_knee_angle");
    logger.pushMin("ascending_time", "min_ascending_time");
    logger.pushMin("descending_time", "min_descending_time");
    logger.pushAverage("ascending_time", "avg_ascending_time");
    logger.pushAverage("descending_time", "avg_descending_time");

    // Count good reps
    logger.pushGoodRepCount();
    // Push max rep
    logger.pushKey("max_rep", maxRep);
  }

  @override
  bool requestStop() => repCount >= maxRep;

  // --- Safety Checks ---
  // Requires side-facing camera and all key landmarks visible with high confidence.

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return const GuidanceSignal.turnSide();
    }

    final requiredLandmarks = getSideTrackedLandmarks(landmarks);
    if (requiredLandmarks == null) return const GuidanceSignal.bodyInFrame();

    final allConfident = requiredLandmarks.values
        .every((lm) => ExerciseBase.isLandmarkConfident(lm));
    if (!allConfident) return const GuidanceSignal.lighting();

    return null;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Extract landmarks
    final lm = getSideTrackedLandmarks(smoothedLandmarks);
    if (lm == null) return;

    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;
    final shoulder = lm['shoulder']!;
    final foot = lm['foot']!;
    final heel = lm['heel']!;

    scaleFactor = calculateDistance(shoulder, hip);

    // 2. Calculate geometry
    final kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    final backAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    final trunkLean = convertClockAngleToTrunkLean(backAngle, cameraFacing);
    final heelDistanceToFloor = foot.y - heel.y;
    final normalizedHeelLift =
        heelDistanceToFloor / (scaleFactor == 0 ? 1 : scaleFactor);
    final now = frameTimestampMs;

    // 3. Build metric context
    final ctx = RepContext(
      kneeAngle: kneeAngle,
      trunkLean: trunkLean,
      clockAngle: backAngle,
      heelDistance: heelDistanceToFloor,
      scaleFactor: scaleFactor,
      squatState: squatState,
      frameTimestamp: now,
      kneeY: knee.y,
      hipY: hip.y,
      shoulderY: shoulder.y,
      resultIssues: resultIssues,
    );

    final debugEnabled = isDebugModeActive;
    // 4. Debug overlay
    debugData['squatState'] = squatState.name;
    debugData['previousSquatState'] = previousSquatState.name;
    debugData['reachedBottomThisRep'] = _reachedBottomThisRep;
    debugData['repCount'] = repCount;
    debugData['frameBuffer'] = frameBuffer.frameBuffer.length;
    debugData['kneeAngle'] = kneeAngle;
    debugData['backAngle'] = backAngle;
    debugData['trunkLean'] = trunkLean;
    debugData['heelDistance'] = heelDistanceToFloor;
    debugData['heelLiftPct'] = normalizedHeelLift * 100;

// 4.5 Sync baseline to depth metric for debug threshold
    depthMetric.baselineAngle = _baselineKneeAngle;
    // 5. Buffer frame & update state machine
    frameBuffer.addFrame(FrameSnapshot(log: {
      "kneeAngle": kneeAngle,
      "trunkLean": trunkLean,
      "heelDistance": heelDistanceToFloor,
    }, timeStamp: now));

    _updateStateBuffer(kneeAngle, now);

    // 6. Handle rep completion immediately when the return-to-standing is detected.
    if (squatState == SquatState.standing &&
        previousSquatState != SquatState.standing) {
      _completeRep(ctx);
      return;
    }

    // 7. Run all metrics (skip standing phase)
    if (squatState != SquatState.standing) {
      _updateRepPeaks(ctx);
      for (var i = 0; i < _metrics.length; i++) {
        _metrics[i].update(ctx);
      }
    }

    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    // 8. Phase-specific UI status
    _updatePhaseInstructions(now);
  }

  // --- Rep Completion ---

  void _completeRep(RepContext ctx) {
    final finalState = previousSquatState;
    final reachedBottom = _reachedBottomThisRep;

    if (previousSquatState != SquatState.descending) {
      repCount += 1;

      // Evaluate final metrics for this rep
      depthMetric.checkRepCompletion(
        finalState: finalState,
        reachedBottom: reachedBottom,
        ctx: ctx,
      );
      tempoMetric.evaluateRep(ctx);

      // Collect faults from all metrics
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      final calibratedCleanRep =
          _matchesCalibratedCleanRep(ctx, reachedBottom: reachedBottom);
      if (calibratedCleanRep) {
        allFaults.clear();
        resultIssues.feedback.clear();
        resultIssues.phaseStatus.clear();
        resultIssues.setPhaseStatus('standing', standingStatus);
      }

      // Determine rep quality
      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';

      // Build fault map grouped by phase
      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        faultMap.putIfAbsent(fault.phase, () => {});
        faultMap[fault.phase]![fault.type] = fault.message;
      }

      final topVoicedFault = Squat.topVoicedFault(allFaults);
      lastRepFaultVoiceMessages = Squat.orderedUniqueVoiceMessages(allFaults);
      lastRepTopVoiceMessage = topVoicedFault?.voiceMessage;
      lastRepTopVoicePriority = topVoicedFault?.priority;
      lastRepWasClean = correctForm;

      setFeedback.add({correctForm: faultMap});

      // Update debug data with metric outputs
      if (isDebugModeActive) {
        for (final metric in _metrics) {
          debugData.addAll(metric.debugData);
        }
      }

      // Tempo feedback for UI
      if (tempoMetric.descentDuration != null) {
        final descent = tempoMetric.descentDuration!.toStringAsFixed(1);
        resultIssues.feedback['Tempo'] = '↓${descent}s';
        if (tempoMetric.ascentDuration != null) {
          final ascent = tempoMetric.ascentDuration!.toStringAsFixed(1);
          resultIssues.feedback['Tempo'] = '↓${descent}s ↑${ascent}s';
        }
      }

      final faultAffectsForm = <String, bool>{};
      final faultPriorities = <String, int>{};
      for (final fault in allFaults) {
        faultAffectsForm[fault.type] =
            (faultAffectsForm[fault.type] ?? false) || fault.affectsForm;
        final previousPriority = faultPriorities[fault.type];
        if (previousPriority == null || fault.priority < previousPriority) {
          faultPriorities[fault.type] = fault.priority;
        }
      }

      // Log per-rep data
      logger.addRepLog(
          RepLog(correctForm: correctForm, repNumber: repCount, data: {
        "peak_heel_distance": _repMaxHeelDistance ?? 0,
        "peak_knee_angle": _repMinKneeAngle ?? 0,
        "trunk_lean_at_bottom": _repTrunkLeanAtBottom ?? 0,
        "ascending_time": tempoMetric.ascentDuration ?? 0.0,
        "descending_time": tempoMetric.descentDuration ?? 0.0,
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
        "fault_affects_form": faultAffectsForm,
        "fault_priorities": faultPriorities,
      }));
      for (final metric in _metrics) {
        if (calibratedCleanRep) {
          metric.reset();
        } else {
          metric.resetAndCountFault();
        }
      }
    } else {
      resultIssues.feedback['Status'] = 'Xuống thấp hơn nhé';
      for (final metric in _metrics) {
        metric.reset();
      }
    }

    // Reset for next rep
    correctForm = true;
    _reachedBottomThisRep = false;
    _resetRepPeaks();
    previousSquatState = SquatState.standing;
  }

  void _updateRepPeaks(RepContext ctx) {
    // Correlated capture: trunk lean must stay paired with the deepest knee frame.
    if (_repMinKneeAngle == null || ctx.kneeAngle < _repMinKneeAngle!) {
      _repMinKneeAngle = ctx.kneeAngle;
      _repTrunkLeanAtBottom = ctx.trunkLean;
    }

    if (_repMaxHeelDistance == null ||
        ctx.heelDistance > _repMaxHeelDistance!) {
      _repMaxHeelDistance = ctx.heelDistance;
    }
  }

  void _resetRepPeaks() {
    _repMinKneeAngle = null;
    _repTrunkLeanAtBottom = null;
    _repMaxHeelDistance = null;
  }

  bool _matchesCalibratedCleanRep(
    RepContext ctx, {
    required bool reachedBottom,
  }) {
    final safeScaleFactor = ctx.scaleFactor == null || ctx.scaleFactor == 0
        ? 1.0
        : ctx.scaleFactor!;
    final heelLiftPct = (ctx.heelDistance / safeScaleFactor) * 100;
    final backDeviation = _verticalDeviation(ctx.clockAngle);
    final holdProgress = tempoMetric.bottomHoldProgress(ctx.frameTimestamp) ??
        (hasCompletedBottomHold ? 1.0 : 0.0);

    final isMatch = reachedBottom &&
        holdProgress >= SquatConfig.CLEAN_REP_BOTTOM_HOLD_PROGRESS_MIN &&
        _within(
          ctx.kneeAngle,
          SquatConfig.CLEAN_REP_KNEE_ANGLE,
          SquatConfig.CLEAN_REP_KNEE_TOLERANCE,
        ) &&
        _within(
          backDeviation,
          SquatConfig.CLEAN_REP_BACK_ANGLE,
          SquatConfig.CLEAN_REP_BACK_TOLERANCE,
        ) &&
        _within(
          ctx.trunkLean,
          SquatConfig.CLEAN_REP_TRUNK_LEAN,
          SquatConfig.CLEAN_REP_TRUNK_LEAN_TOLERANCE,
        ) &&
        _within(
          heelLiftPct,
          SquatConfig.CLEAN_REP_HEEL_LIFT_PCT,
          SquatConfig.CLEAN_REP_HEEL_LIFT_PCT_TOLERANCE,
        );

    debugData['calibratedCleanRep'] = isMatch;
    debugData['calibratedKneeDelta'] =
        ctx.kneeAngle - SquatConfig.CLEAN_REP_KNEE_ANGLE;
    debugData['calibratedBackDelta'] =
        backDeviation - SquatConfig.CLEAN_REP_BACK_ANGLE;
    debugData['calibratedTrunkDelta'] =
        ctx.trunkLean - SquatConfig.CLEAN_REP_TRUNK_LEAN;
    debugData['calibratedHeelLiftPctDelta'] =
        heelLiftPct - SquatConfig.CLEAN_REP_HEEL_LIFT_PCT;
    debugData['calibratedBottomHoldProgress'] = holdProgress;

    return isMatch;
  }

  static bool _within(double value, double target, double tolerance) {
    return (value - target).abs() <= tolerance;
  }

  static double _verticalDeviation(double clockAngle) {
    final normalized = clockAngle.abs() % 360;
    return normalized > 180 ? 360 - normalized : normalized;
  }

  // --- Phase Instructions ---

  void _updatePhaseInstructions(int now) {
    switch (squatState) {
      case SquatState.standing:
        // Anticipatory cue: while standing, guide user to start the next rep.
        resultIssues.setPhaseStatus('standing', standingStatus);
        break;
      case SquatState.descending:
        // Keep the on-screen cue aligned with the current motion.
        // Voice should only say "Giữ" after the user actually reaches bottom.
        resultIssues.setPhaseStatus('descending', descendingStatus);
        break;
      case SquatState.bottom:
        final remaining = tempoMetric.bottomHoldRemaining(now);
        final progress = tempoMetric.bottomHoldProgress(now);
        if (!hasCompletedBottomHold && remaining != null) {
          resultIssues.setPhaseStatus('bottom', bottomHoldStatus(remaining));
        } else {
          // Anticipatory cue: when hold is complete, tell user to go up.
          resultIssues.setPhaseStatus('bottom', ascendingStatus);
        }
        if (progress != null) debugData['bottomHoldProgress'] = progress;
        break;
      case SquatState.ascending:
        // The ascent cue should stay consistent with the main voice flow.
        resultIssues.setPhaseStatus('ascending', ascendingStatus);
        break;
    }
  }

  // --- State Machine (buffer-based) ---
  // Uses frame buffer angle change direction + debouncers for robust transitions.

  void _updateStateBuffer(double kneeAngle, int timestampMs) {
    final angleChange =
        frameBuffer.getChange("kneeAngle", SquatConfig.ANGLE_STABLE_GATE);
    final isDescendingFrame = angleChange == ChangeState.decreasing;
    final isAscendingFrame = angleChange == ChangeState.increasing;
    double kneeAngleChangeFromBaseline = _baselineKneeAngle - kneeAngle;
    // debugData['kneeAngleChangeFromBaseline'] = kneeAngleChangeFromBaseline;

    // Direction-based transitions
    if (angleChange != ChangeState.stable) {
      final isIncreasing = directionDetection.update(isAscendingFrame);

      if (!isIncreasing &&
          squatState == SquatState.standing &&
          kneeAngleChangeFromBaseline > SquatConfig.ROM_GATE) {
        _transitionState(SquatState.descending, timestampMs);
        frameBuffer.clear();
      } else if (isIncreasing && squatState == SquatState.descending) {
        _transitionState(SquatState.ascending, timestampMs);
      }
    }

    if (squatState == SquatState.bottom) {
      if (isAscendingFrame) {
        _transitionState(SquatState.ascending, timestampMs);
      }
    }

    // Debounced threshold transitions
    if (_bottomDebouncer.update(
        kneeAngle <= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1] &&
            squatState == SquatState.descending)) {
      _transitionState(SquatState.bottom, timestampMs);
    } else if (_standingDebouncer.update(kneeAngle > _baselineKneeAngle &&
        (squatState == SquatState.ascending ||
            squatState == SquatState.descending) &&
        !isDescendingFrame)) {
      _transitionState(SquatState.standing, timestampMs);
    }
  }

  void _transitionState(SquatState newState, int timestampMs) {
    if (newState == squatState) {
      return;
    }

    previousSquatState = squatState;
    squatState = newState;

    if (newState == SquatState.descending) {
      _reachedBottomThisRep = false;
      resultIssues.phaseStatus.clear();
    } else if (newState == SquatState.bottom) {
      _reachedBottomThisRep = true;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousSquatState, newState, timestampMs);
    }
  }
}
