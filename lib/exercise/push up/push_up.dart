// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'dart:io';
import 'dart:math' as math;

import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/frame_buffer.dart';

import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/exercise_logger.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/push_up_metric_base.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/depth_metric.dart';
import 'metrics/tempo_metric.dart';

// --- Config ---

class PushUpConfig {
  static const int MAX_REP = 15;

  // Top/plank fallback until the personal elbow baseline is captured.
  // Like Squat's stand-angle baseline, push-up entry/return uses the user's
  // own plank lockout angle instead of a fixed descent threshold.
  static const double PLANK_ANGLE_THRESHOLD = 160.0;
  static const double START_ELBOW_MIN = 154.0;
  static const List<double> BOTTOM_ANGLE_RANGE = [80.0, 100.0];

  // Trunk horizontal targets per facing direction (clock angle from vertical)
  static const double HORIZONTAL_CLOCK_LEFT = 90.0;
  static const double HORIZONTAL_CLOCK_RIGHT = 270.0;

  // Buffer-based motion gates, mirroring Squat's direction/ROM pattern.
  static const double ANGLE_STABLE_GATE = 2.0;
  static const double ROM_GATE = 30.0;
  static const double PLANK_RETURN_TOLERANCE = 8.0;
  static const double POSITION_STABLE_GATE_RATIO = 0.015;
  static const double POSITION_STABLE_GATE_MIN_PIXELS = 1.5;

  // High-plank setup gates.
  static const double START_TRUNK_TOLERANCE = 20.0;
  static const double START_BODY_LINE_MIN = 160.0;
  static const double START_SHOULDER_ABOVE_WRIST_RATIO = 0.25;
  static const double START_KNEE_SUPPORT_CLEARANCE_RATIO = 0.12;

  // Active anti-cheat gates. These are intentionally looser than setup so
  // normal fatigue wobble is coached by metrics instead of rejected.
  static const double ACTIVE_BODY_LINE_MIN = 150.0;
  static const double ACTIVE_SHOULDER_ABOVE_WRIST_RATIO = 0.05;
  static const double ACTIVE_KNEE_SUPPORT_CLEARANCE_RATIO = 0.05;
  static const double WRIST_Y_DRIFT_MAX_RATIO = 0.22;
  static const double WRIST_Y_DRIFT_MIN_PIXELS = 24.0;
  static const double HEEL_Y_DRIFT_MAX_RATIO = 0.28;
  static const double HEEL_Y_DRIFT_MIN_PIXELS = 30.0;
}

enum PushUpState { plank, descending, bottom, ascending }

// --- Push Up ---

class PushUp extends ExerciseBase with SideTrackedExerciseMixin {
  final int maxRep;
  PushUp({this.maxRep = PushUpConfig.MAX_REP});

  PushUpState pushUpState = PushUpState.plank;
  PushUpState previousPushUpState = PushUpState.plank;

  bool _reachedBottomThisRep = false;
  bool _repRejectedThisCycle = false;
  bool _kneeMovedThisRep = false;
  int _rejectedRepCount = 0;
  String? _repRejectReason;
  String? _repRejectType;
  String _lastPushUpEvent = 'init';
  String _lastNoCountReason = 'none';
  String _lastRejectType = 'none';
  String _lastRejectReason = 'none';
  File? _debugTraceFile;
  bool _debugTraceHeaderWritten = false;
  int _debugTraceLastWriteMs = 0;
  String _traceElbowChange = 'stable';
  String _traceEntryReady = 'no';
  String _traceBottomGate = 'no';
  String _traceReturnGate = 'no';
  String _traceKneeChange = 'stable';
  String _traceKneeMoveFromStart = 'no';
  String _traceElbowOnlyFrame = 'no';
  String _traceActiveGuard = 'ok';
  String _traceWristDrift = '';
  String _traceHeelDrift = '';

  double? _baselineElbowAngle;
  double? _baselineWristY;
  double? _baselineHeelY;
  double? _repStartKneeY;

  final Debouncer _bottomDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _plankDebouncer = Debouncer(requiredFrames: 2);
  final StickyDebouncer directionDetection = StickyDebouncer(requiredFrames: 2);

  final Debouncer _activeBodyLineDebouncer = Debouncer(requiredFrames: 4);
  final Debouncer _wristDriftDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _heelDriftDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _elbowOnlyDebouncer = Debouncer(requiredFrames: 5);

  final TrunkAlignmentMetric trunkAlignmentMetric = TrunkAlignmentMetric();
  final DepthMetric depthMetric = DepthMetric();
  final TempoMetric tempoMetric = TempoMetric();

  late final List<PushUpMetricBase> _metrics = [
    trunkAlignmentMetric,
    depthMetric,
    tempoMetric,
  ];

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder,
        ),
        'elbow': (
          right: PoseLandmarkType.rightElbow,
          left: PoseLandmarkType.leftElbow,
        ),
        'wrist': (
          right: PoseLandmarkType.rightWrist,
          left: PoseLandmarkType.leftWrist,
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip,
        ),
        'knee': (
          right: PoseLandmarkType.rightKnee,
          left: PoseLandmarkType.leftKnee,
        ),
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle,
        ),
        'heel': (
          right: PoseLandmarkType.rightHeel,
          left: PoseLandmarkType.leftHeel,
        ),
        'foot': (
          right: PoseLandmarkType.rightFootIndex,
          left: PoseLandmarkType.leftFootIndex,
        ),
      };

  // --- UI Bridge ---

  @override
  String get exerciseName => 'Push Up';

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get currentPhaseKey => pushUpState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (pushUpState) {
      case PushUpState.plank:
        return 'Chuẩn bị';
      case PushUpState.descending:
        return 'Xuống';
      case PushUpState.bottom:
        return 'Giữ';
      case PushUpState.ascending:
        return 'Đẩy lên';
    }
  }

  // --- Start Position ---

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return false;

    final geometry = _calculateGeometry(lm);
    final status = _evaluatePlankGeometry(geometry);
    if (!status.valid) return false;

    // Capture once during the 3s hold-still activation window. Wrist baseline
    // stays anchored to this valid setup pose; it is not refreshed mid-set.
    _captureStartBaselines(geometry);
    return true;
  }

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey(
        "trunk_alignment_fails_count", trunkAlignmentMetric.faultsCount);
    logger.pushKey("depth_fails_count", depthMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushKey("push_up_guard_rejects_count", _rejectedRepCount);

    logger.pushMin("min_elbow_angle", "min_elbow_angle");
    logger.pushMax("elbow_rom", "max_elbow_rom");
    logger.pushMax("max_abs_trunk_deviation", "max_abs_trunk_deviation");
    logger.pushMax("max_wrist_y_drift", "max_wrist_y_drift");
    logger.pushMax("max_heel_y_drift", "max_heel_y_drift");
    logger.pushMax("knee_y_travel", "max_knee_y_travel");
    logger.pushMax("shoulder_y_travel", "max_shoulder_y_travel");
    logger.pushAverage("ascending_time", "avg_ascending_time");
    logger.pushAverage("descending_time", "avg_descending_time");
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  // --- Safety Checks ---

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Xin hãy quay nghiêng để theo dõi tư thế Push Up";
    }

    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) {
      return "⚠️ Đảm bảo vai, tay, hông, gối và bàn chân đều trong khung hình";
    }

    final allConfident = lm.values
        .every((landmark) => ExerciseBase.isLandmarkConfident(landmark));
    if (!allConfident)
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";

    return null;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Get landmarks
    final lm = getSideTrackedLandmarks(smoothedLandmarks);
    if (lm == null) return;

    // 2. Calculate geometry
    final geometry = _calculateGeometry(lm);
    scaleFactor = geometry.torsoLen;
    final now = frameTimestampMs;

    // 3. Build RepContext
    final ctx = RepContext(
      elbowAngle: geometry.elbowAngle,
      trunkDeviation: geometry.trunkDeviation,
      trunkClockAngle: geometry.trunkClockAngle,
      scaleFactor: scaleFactor,
      pushUpState: pushUpState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // 4. Debug data
    _publishCompactDebug(geometry);

    frameBuffer.addFrame(FrameSnapshot(log: {
      "elbowAngle": geometry.elbowAngle,
      "trunkDeviation": geometry.trunkDeviation,
      "trunkClockAngle": geometry.trunkClockAngle,
      "wristY": geometry.wristY,
      "shoulderY": geometry.shoulderY,
      "hipY": geometry.hipY,
      "kneeY": geometry.kneeY,
      "ankleY": geometry.ankleY,
      "heelY": geometry.heelY,
      "kneeSupportClearance": geometry.kneeSupportClearance,
      "shoulderHipKneeAngle": geometry.shoulderHipKneeAngle,
      "hipKneeAnkleAngle": geometry.hipKneeAnkleAngle,
    }, timeStamp: now));
    debugData['minElbow'] = _debugMinElbowLabel();

    final plankStatus = _evaluatePlankGeometry(geometry);
    if (pushUpState == PushUpState.plank && plankStatus.valid) {
      // Refresh only the elbow top baseline while in a clean plank. This keeps
      // ROM counting personalized like Squat's baseline, without moving the
      // wrist anti-cheat anchor captured at activation.
      _refreshPlankElbowBaseline(geometry);
    } else if (pushUpState == PushUpState.plank && !plankStatus.valid) {
      resultIssues.feedback['Setup'] = plankStatus.reason ?? 'Giữ plank chuẩn';
    }

    if (pushUpState != PushUpState.plank) {
      _updateActiveGuard(geometry);
    }

    // 5. Update state machine before checking completion.
    _updatePushUpState(geometry, now);
    _appendDebugTrace(geometry, now);

    // 6. Rep completion (return to plank)
    if (pushUpState == PushUpState.plank &&
        previousPushUpState != PushUpState.plank) {
      _completeRep(ctx);
      return;
    }

    // 7. Run all metrics
    if (pushUpState != PushUpState.plank) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    _updatePhaseInstructions();
  }

  // --- Rep Completion ---

  void _completeRep(RepContext ctx) {
    if (_repRejectedThisCycle) {
      _rejectedRepCount += 1;
      _lastNoCountReason = 'rejected:${_repRejectType ?? _lastRejectType}';
      _lastPushUpEvent = 'no-count rejected';
      debugData['fail'] = _lastNoCountReason;
      resultIssues.feedback['Result'] = 'Lần này chưa tính nhé';
      resultIssues.feedback['Form'] =
          _repRejectReason ?? 'Giữ đúng tư thế push-up đầy đủ';
      _resetRepCycle(countMetricFaults: false);
      return;
    }

    if (!_reachedBottomThisRep) {
      _lastNoCountReason = 'no bottom: min elbow ${_debugMinElbowLabel()}';
      _lastPushUpEvent = 'no-count no-bottom';
      debugData['fail'] = _lastNoCountReason;
      resultIssues.feedback['Status'] = 'Xuống thấp hơn nhé';
      _resetRepCycle(countMetricFaults: false);
      return;
    }

    repCount += 1;
    _lastNoCountReason = 'none';
    _lastPushUpEvent = 'counted rep $repCount';

    final finalState = previousPushUpState;
    depthMetric.checkRepCompletion(finalState, ctx);
    tempoMetric.evaluateRep(ctx);

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Tốt!' : 'Chỉnh tư thế';

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});

    if (tempoMetric.descentDuration != null) {
      final descent = tempoMetric.descentDuration!.toStringAsFixed(1);
      resultIssues.feedback['Tempo'] = '↓${descent}s';
      if (tempoMetric.ascentDuration != null) {
        final ascent = tempoMetric.ascentDuration!.toStringAsFixed(1);
        resultIssues.feedback['Tempo'] = '↓${descent}s ↑${ascent}s';
      }
    }

    final minElbow =
        _numFromSnapshot(frameBuffer.getPeakMin("elbowAngle"), "elbowAngle") ??
            ctx.elbowAngle;
    final topElbow = _topElbowAngle;
    final elbowRom = (topElbow - minElbow).clamp(0.0, 180.0).toDouble();

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        "min_elbow_angle": minElbow,
        "elbow_rom": elbowRom,
        "max_abs_trunk_deviation": frameBuffer.getMaxAbs("trunkDeviation"),
        "max_wrist_y_drift":
            frameBuffer.getMaxAbsFromBaseline("wristY", _baselineWristY),
        "max_heel_y_drift":
            frameBuffer.getMaxAbsFromBaseline("heelY", _baselineHeelY),
        "knee_y_travel": frameBuffer.getTravel("kneeY"),
        "shoulder_y_travel": frameBuffer.getTravel("shoulderY"),
        "hip_y_travel": frameBuffer.getTravel("hipY"),
        "ascending_time": tempoMetric.ascentDuration ?? 0.0,
        "descending_time": tempoMetric.descentDuration ?? 0.0,
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    _resetRepCycle(countMetricFaults: true);
  }

  // --- State Machine ---

  void _updatePushUpState(_PushUpGeometry geometry, int timestampMs) {
    final elbowAngle = geometry.elbowAngle;
    final angleChange =
        frameBuffer.getChange("elbowAngle", PushUpConfig.ANGLE_STABLE_GATE);
    final isBendingFrame = angleChange == ChangeState.decreasing;
    final isExtendingFrame = angleChange == ChangeState.increasing;
    // Buffer direction + ROM-from-baseline mirrors Squat:
    // stable/decreasing/increasing comes from FrameBuffer, while ROM_GATE
    // confirms the elbow has actually left the user's plank baseline.
    final elbowBendFromTop = _topElbowAngle - elbowAngle;
    final entryReady = !isExtendingFrame &&
        pushUpState == PushUpState.plank &&
        elbowBendFromTop > PushUpConfig.ROM_GATE;
    final bottomGate = elbowAngle <= PushUpConfig.BOTTOM_ANGLE_RANGE[1] &&
        pushUpState == PushUpState.descending;
    final plankReturnGate =
        elbowAngle >= _topElbowAngle - PushUpConfig.PLANK_RETURN_TOLERANCE &&
            (pushUpState == PushUpState.ascending ||
                pushUpState == PushUpState.descending) &&
            !isBendingFrame;

    debugData['gates'] =
        'E:${_debugBool(entryReady)} B:${_debugBool(bottomGate)} R:${_debugBool(plankReturnGate)}';
    _traceElbowChange = angleChange.name;
    _traceEntryReady = _debugBool(entryReady);
    _traceBottomGate = _debugBool(bottomGate);
    _traceReturnGate = _debugBool(plankReturnGate);

    if (angleChange != ChangeState.stable) {
      final isExtending = directionDetection.update(isExtendingFrame);

      if (!isExtending && entryReady) {
        // We clear the buffer on active rep start like Squat. Keep the knee
        // baseline outside the buffer so the anti-cheat still sees the body
        // moving with the elbows on the first descent frames.
        _repStartKneeY = geometry.kneeY;
        _transitionState(PushUpState.descending, timestampMs);
        frameBuffer.clear();
      } else if (isExtending && pushUpState == PushUpState.descending) {
        _transitionState(PushUpState.ascending, timestampMs);
      } else if (!isExtending && pushUpState == PushUpState.ascending) {
        _transitionState(PushUpState.descending, timestampMs);
      }
    }

    if (_bottomDebouncer.update(bottomGate)) {
      _transitionState(PushUpState.bottom, timestampMs);
    } else if (pushUpState == PushUpState.bottom && isExtendingFrame) {
      _transitionState(PushUpState.ascending, timestampMs);
    } else if (_plankDebouncer.update(plankReturnGate)) {
      _transitionState(PushUpState.plank, timestampMs);
    }
  }

  void _transitionState(PushUpState newState, int timestampMs) {
    if (newState == pushUpState) {
      return;
    }

    previousPushUpState = pushUpState;
    pushUpState = newState;
    _lastPushUpEvent =
        '${previousPushUpState.toString().split('.').last}->${newState.toString().split('.').last}';
    debugData['event'] = _lastPushUpEvent;

    if (newState == PushUpState.descending &&
        previousPushUpState == PushUpState.plank) {
      _reachedBottomThisRep = false;
      _repRejectedThisCycle = false;
      _repRejectReason = null;
      _repRejectType = null;
      _kneeMovedThisRep = false;
      _lastRejectType = 'none';
      _resetGuardDebouncers();
      resultIssues.instructions.clear();
    } else if (newState == PushUpState.bottom) {
      _reachedBottomThisRep = true;
      if (!_kneeMovedThisRep) {
        _rejectCurrentCycle(_PushUpGuardStatus.invalid(
          type: 'KneeMotion',
          reason: 'Di chuyển cả thân người, không chỉ gập khuỷu tay',
        ));
      }
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousPushUpState, newState, timestampMs);
    }
  }

  void _updatePhaseInstructions() {
    switch (pushUpState) {
      case PushUpState.plank:
        resultIssues.addInstruction('plank', 'Status', 'Xuống');
        break;
      case PushUpState.descending:
        resultIssues.addInstruction('descending', 'Status', 'Đang xuống...');
        break;
      case PushUpState.bottom:
        resultIssues.addInstruction('bottom', 'Status', 'Đẩy lên!');
        break;
      case PushUpState.ascending:
        resultIssues.addInstruction('ascending', 'Status', 'Đang đẩy lên!');
        break;
    }
  }

  void _updateActiveGuard(_PushUpGeometry geometry) {
    final positionGate = _positionGate(geometry.torsoLen);
    final kneeChange = frameBuffer.getChange("kneeY", positionGate);
    final startKneeY = _repStartKneeY;
    final kneeMovedFromStart = startKneeY != null &&
        (geometry.kneeY - startKneeY).abs() > positionGate;
    if (kneeChange != ChangeState.stable || kneeMovedFromStart) {
      _kneeMovedThisRep = true;
    }
    _traceKneeChange = kneeChange.name;
    _traceKneeMoveFromStart = _debugBool(kneeMovedFromStart);

    final activeStatus = _evaluateActiveGeometry(geometry);
    debugData['guard'] = activeStatus.valid ? 'ok' : activeStatus.type;
    _traceActiveGuard = activeStatus.valid ? 'ok' : activeStatus.type;
    if (_activeBodyLineDebouncer.update(!activeStatus.valid)) {
      _rejectCurrentCycle(activeStatus);
    }

    final wristBase = _baselineWristY;
    if (wristBase != null) {
      final wristDrift = (geometry.wristY - wristBase).abs();
      final threshold = _wristDriftThreshold(geometry.torsoLen);
      _traceWristDrift = wristDrift.toStringAsFixed(2);
      if (_wristDriftDebouncer.update(wristDrift > threshold)) {
        _rejectCurrentCycle(_PushUpGuardStatus.invalid(
          type: 'Wrist',
          reason: 'Giữ cổ tay ở cùng vị trí, không đổi sang chống tường',
        ));
      }
    }

    final heelBase = _baselineHeelY;
    if (heelBase != null) {
      final heelDrift = (geometry.heelY - heelBase).abs();
      final threshold = _heelDriftThreshold(geometry.torsoLen);
      _traceHeelDrift = heelDrift.toStringAsFixed(2);
      if (_heelDriftDebouncer.update(heelDrift > threshold)) {
        _rejectCurrentCycle(_PushUpGuardStatus.invalid(
          type: 'Heel',
          reason: 'Giữ chân ở cùng vị trí, không nâng hoặc đổi điểm chống',
        ));
      }
    }

    final elbowBendFromTop = _topElbowAngle - geometry.elbowAngle;
    final elbowOnlyFrame = elbowBendFromTop > PushUpConfig.ROM_GATE &&
        pushUpState == PushUpState.descending &&
        kneeChange == ChangeState.stable;
    _traceElbowOnlyFrame = _debugBool(elbowOnlyFrame);
    if (_elbowOnlyDebouncer.update(elbowOnlyFrame)) {
      _rejectCurrentCycle(_PushUpGuardStatus.invalid(
        type: 'KneeMotion',
        reason: 'Di chuyển cả thân người, không chỉ gập khuỷu tay',
      ));
    }
  }

  void _rejectCurrentCycle(_PushUpGuardStatus status) {
    if (!status.valid) {
      _repRejectedThisCycle = true;
      _repRejectReason ??= status.reason;
      _repRejectType ??= status.type;
      _lastRejectType = status.type;
      _lastRejectReason = status.reason ?? 'none';
      _lastPushUpEvent = 'reject ${status.type}';
      debugData['event'] = _lastPushUpEvent;
      debugData['reject'] = _repRejectType ?? _lastRejectType;
      resultIssues.feedback['Form'] = status.reason ?? 'Giữ đúng tư thế';
      resultIssues.addInstruction(
        currentPhaseKey,
        status.type,
        status.reason ?? 'Giữ đúng tư thế push-up',
      );
    }
  }

  void _resetRepCycle({required bool countMetricFaults}) {
    correctForm = true;
    pushUpState = PushUpState.plank;
    previousPushUpState = PushUpState.plank;
    _reachedBottomThisRep = false;
    _repRejectedThisCycle = false;
    _repRejectReason = null;
    _repRejectType = null;
    _kneeMovedThisRep = false;
    _repStartKneeY = null;
    _bottomDebouncer.reset();
    _plankDebouncer.reset();
    directionDetection.reset();
    _resetGuardDebouncers();
    for (final metric in _metrics) {
      if (countMetricFaults) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }
  }

  void _resetGuardDebouncers() {
    _activeBodyLineDebouncer.reset();
    _wristDriftDebouncer.reset();
    _heelDriftDebouncer.reset();
    _elbowOnlyDebouncer.reset();
  }

  void _captureStartBaselines(_PushUpGeometry geometry) {
    _refreshPlankElbowBaseline(geometry);
    _baselineWristY = geometry.wristY;
    _baselineHeelY = geometry.heelY;
  }

  void _refreshPlankElbowBaseline(_PushUpGeometry geometry) {
    _baselineElbowAngle =
        math.max(geometry.elbowAngle, PushUpConfig.PLANK_ANGLE_THRESHOLD);
  }

  double get _topElbowAngle =>
      _baselineElbowAngle ?? PushUpConfig.PLANK_ANGLE_THRESHOLD;

  _PushUpGeometry _calculateGeometry(Map<String, PoseLandmark> lm) {
    final shoulder = lm['shoulder']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;
    final heel = lm['heel']!;
    final foot = lm['foot']!;

    final torsoLen = math.max(calculateDistance(shoulder, hip), 1.0);
    final elbowAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: elbow,
      lastPoint: wrist,
    );
    final trunkClockAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    final horizontalTarget = cameraFacing == CameraFacing.right
        ? PushUpConfig.HORIZONTAL_CLOCK_RIGHT
        : PushUpConfig.HORIZONTAL_CLOCK_LEFT;
    final trunkDeviation = clockAngleDeviation(
      trunkClockAngle,
      horizontalTarget,
    );
    final shoulderHipKneeAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: hip,
      lastPoint: knee,
    );
    final hipKneeAnkleAngle = calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: ankle,
    );
    final supportY = math.min(wrist.y, math.min(heel.y, foot.y));

    return _PushUpGeometry(
      torsoLen: torsoLen,
      elbowAngle: elbowAngle,
      trunkClockAngle: trunkClockAngle,
      trunkDeviation: trunkDeviation,
      shoulderHipKneeAngle: shoulderHipKneeAngle,
      hipKneeAnkleAngle: hipKneeAnkleAngle,
      wristY: wrist.y,
      shoulderY: shoulder.y,
      hipY: hip.y,
      kneeY: knee.y,
      ankleY: ankle.y,
      heelY: heel.y,
      kneeSupportClearance: supportY - knee.y,
      hipSupportClearance: supportY - hip.y,
      shoulderAboveWrist: wrist.y - shoulder.y,
    );
  }

  _PushUpGuardStatus _evaluatePlankGeometry(_PushUpGeometry geometry) {
    if (geometry.elbowAngle < PushUpConfig.START_ELBOW_MIN) {
      return _PushUpGuardStatus.invalid(
        type: 'Setup',
        reason: 'Duỗi tay lên tư thế plank cao',
      );
    }
    final torsoLen = geometry.torsoLen;
    if (geometry.trunkDeviation.abs() > PushUpConfig.START_TRUNK_TOLERANCE) {
      return _PushUpGuardStatus.invalid(
        type: 'Setup',
        reason: 'Giữ thân người ngang như plank',
      );
    }
    if (geometry.shoulderAboveWrist <
        torsoLen * PushUpConfig.START_SHOULDER_ABOVE_WRIST_RATIO) {
      return _PushUpGuardStatus.invalid(
        type: 'Setup',
        reason: 'Vai cần ở trên cổ tay, không nằm sát sàn',
      );
    }
    if (geometry.kneeSupportClearance <
            torsoLen * PushUpConfig.START_KNEE_SUPPORT_CLEARANCE_RATIO ||
        geometry.hipSupportClearance <
            torsoLen * PushUpConfig.START_KNEE_SUPPORT_CLEARANCE_RATIO) {
      return _PushUpGuardStatus.invalid(
        type: 'Setup',
        reason: 'Nâng gối và hông khỏi sàn',
      );
    }
    if (geometry.shoulderHipKneeAngle < PushUpConfig.START_BODY_LINE_MIN ||
        geometry.hipKneeAnkleAngle < PushUpConfig.START_BODY_LINE_MIN) {
      return _PushUpGuardStatus.invalid(
        type: 'Setup',
        reason: 'Giữ vai, hông, gối, cổ chân thành một đường thẳng',
      );
    }

    return const _PushUpGuardStatus.valid();
  }

  _PushUpGuardStatus _evaluateActiveGeometry(_PushUpGeometry geometry) {
    if (geometry.shoulderHipKneeAngle < PushUpConfig.ACTIVE_BODY_LINE_MIN ||
        geometry.hipKneeAnkleAngle < PushUpConfig.ACTIVE_BODY_LINE_MIN) {
      return _PushUpGuardStatus.invalid(
        type: 'BodyLine',
        reason: 'Giữ vai, hông, gối, cổ chân thẳng hàng',
      );
    }

    return const _PushUpGuardStatus.valid();
  }

  double _positionGate(double torsoLen) => math.max(
        torsoLen * PushUpConfig.POSITION_STABLE_GATE_RATIO,
        PushUpConfig.POSITION_STABLE_GATE_MIN_PIXELS,
      );

  double _wristDriftThreshold(double torsoLen) => math.max(
        torsoLen * PushUpConfig.WRIST_Y_DRIFT_MAX_RATIO,
        PushUpConfig.WRIST_Y_DRIFT_MIN_PIXELS,
      );

  double _heelDriftThreshold(double torsoLen) => math.max(
        torsoLen * PushUpConfig.HEEL_Y_DRIFT_MAX_RATIO,
        PushUpConfig.HEEL_Y_DRIFT_MIN_PIXELS,
      );

  double? _numFromSnapshot(FrameSnapshot? snapshot, String key) {
    final value = snapshot?.log[key];
    return value?.toDouble();
  }

  String _debugBool(bool value) => value ? 'yes' : 'no';

  String _debugMinElbowLabel() {
    return _numFromSnapshot(frameBuffer.getPeakMin("elbowAngle"), "elbowAngle")
            ?.toStringAsFixed(1) ??
        'n/a';
  }

  void _publishCompactDebug(_PushUpGeometry geometry) {
    debugData
      ..clear()
      ..['state'] = currentPhaseKey
      ..['event'] = _lastPushUpEvent
      ..['fail'] = _lastNoCountReason
      ..['reject'] = _repRejectType ?? _lastRejectType
      ..['rejectReason'] = _lastRejectReason
      ..['elbow'] = geometry.elbowAngle.toStringAsFixed(1)
      ..['minElbow'] = _debugMinElbowLabel()
      ..['rom'] = (_topElbowAngle - geometry.elbowAngle).toStringAsFixed(1)
      ..['bottom'] = _debugBool(_reachedBottomThisRep)
      ..['tracePath'] = _debugTraceFile?.path ?? 'pending';
  }

  void _appendDebugTrace(_PushUpGeometry geometry, int timestampMs) {
    if (timestampMs - _debugTraceLastWriteMs < 80) return;
    _debugTraceLastWriteMs = timestampMs;

    try {
      final file = _debugTraceFile ??= _createDebugTraceFile(timestampMs);
      final buffer = StringBuffer();
      if (!_debugTraceHeaderWritten) {
        buffer.writeln(
          'timestampMs,state,previousState,event,lastNoCount,rejectType,'
          'elbowAngle,topElbow,elbowRom,minElbow,elbowChange,entryReady,'
          'bottomGate,returnGate,reachedBottom,repRejected,kneeMovedRep,'
          'kneeChange,kneeMoveFromStart,elbowOnlyFrame,activeGuard,'
          'trunkClock,trunkDev,shoulderHipKnee,hipKneeAnkle,wristY,'
          'wristDrift,heelDrift,trackedSide,frameBuffer',
        );
        _debugTraceHeaderWritten = true;
      }

      buffer.writeln([
        timestampMs,
        currentPhaseKey,
        previousPushUpState.name,
        _lastPushUpEvent,
        _lastNoCountReason,
        _repRejectType ?? _lastRejectType,
        geometry.elbowAngle.toStringAsFixed(2),
        _topElbowAngle.toStringAsFixed(2),
        (_topElbowAngle - geometry.elbowAngle).toStringAsFixed(2),
        _debugMinElbowLabel(),
        _traceElbowChange,
        _traceEntryReady,
        _traceBottomGate,
        _traceReturnGate,
        _debugBool(_reachedBottomThisRep),
        _debugBool(_repRejectedThisCycle),
        _debugBool(_kneeMovedThisRep),
        _traceKneeChange,
        _traceKneeMoveFromStart,
        _traceElbowOnlyFrame,
        _traceActiveGuard,
        geometry.trunkClockAngle.toStringAsFixed(2),
        geometry.trunkDeviation.toStringAsFixed(2),
        geometry.shoulderHipKneeAngle.toStringAsFixed(2),
        geometry.hipKneeAnkleAngle.toStringAsFixed(2),
        geometry.wristY.toStringAsFixed(2),
        _traceWristDrift,
        _traceHeelDrift,
        trackedSide?.name ?? 'none',
        frameBuffer.frameBuffer.length,
      ].map(_csvEscape).join(','));

      file.writeAsStringSync(buffer.toString(), mode: FileMode.append);
      debugData['tracePath'] = file.path;
    } catch (error) {
      debugData['tracePath'] = 'trace failed: $error';
    }
  }

  File _createDebugTraceFile(int timestampMs) {
    final directory = _debugTraceDirectory();
    directory.createSync(recursive: true);
    return File('${directory.path}/vika_push_up_debug_$timestampMs.csv');
  }

  Directory _debugTraceDirectory() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      final documents = Directory('$home/Documents');
      if (documents.existsSync()) {
        return Directory('${documents.path}/vika_debug');
      }
    }

    if (Platform.isAndroid) {
      final downloads = Directory('/sdcard/Download');
      if (downloads.existsSync()) {
        return Directory('${downloads.path}/vika_debug');
      }
    }

    return Directory('${Directory.systemTemp.path}/vika_debug');
  }

  String _csvEscape(Object? value) {
    final text = (value ?? '').toString();
    if (!text.contains(',') && !text.contains('"') && !text.contains('\n')) {
      return text;
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}

class _PushUpGeometry {
  const _PushUpGeometry({
    required this.torsoLen,
    required this.elbowAngle,
    required this.trunkClockAngle,
    required this.trunkDeviation,
    required this.shoulderHipKneeAngle,
    required this.hipKneeAnkleAngle,
    required this.wristY,
    required this.shoulderY,
    required this.hipY,
    required this.kneeY,
    required this.ankleY,
    required this.heelY,
    required this.kneeSupportClearance,
    required this.hipSupportClearance,
    required this.shoulderAboveWrist,
  });

  final double torsoLen;
  final double elbowAngle;
  final double trunkClockAngle;
  final double trunkDeviation;
  final double shoulderHipKneeAngle;
  final double hipKneeAnkleAngle;
  final double wristY;
  final double shoulderY;
  final double hipY;
  final double kneeY;
  final double ankleY;
  final double heelY;
  final double kneeSupportClearance;
  final double hipSupportClearance;
  final double shoulderAboveWrist;
}

class _PushUpGuardStatus {
  const _PushUpGuardStatus.valid()
      : valid = true,
        type = 'Guard',
        reason = null;

  const _PushUpGuardStatus.invalid({
    required this.type,
    required this.reason,
  }) : valid = false;

  final bool valid;
  final String type;
  final String? reason;
}
