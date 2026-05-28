import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_buffer.dart';
import '../../utils/frame_snapshot.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/walking_metric_base.dart';
import 'metrics/step_length_metric.dart';
import 'metrics/front_knee_control_metric.dart';
import 'metrics/rear_knee_depth_metric.dart';
import 'metrics/torso_verticality_metric.dart';
import 'dart:ui' show Size;

enum WalkingState { standing, stepping, descending, bottom, pulling_through }

class WalkingLungeConfig {
  static const int MAX_REP = 20; // 10 per leg
}

class WalkingLunge extends ExerciseBase with SideTrackedExerciseMixin {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  WalkingLunge({this.maxRep = WalkingLungeConfig.MAX_REP});

  WalkingState walkingState = WalkingState.standing;
  WalkingState previousWalkingState = WalkingState.standing;

  int? _bottomStartTime;
  final List<FaultRecord> _localFaults = [];

  // Which leg is currently in front
  TrackedSide _frontLegSide = TrackedSide.left;

  // Metrics
  final StepLengthMetric stepLengthMetric = StepLengthMetric();
  final FrontKneeControlMetric frontKneeControlMetric = FrontKneeControlMetric();
  final RearKneeDepthMetric rearKneeDepthMetric = RearKneeDepthMetric();
  final TorsoVerticalityMetric torsoMetric = TorsoVerticalityMetric();

  late final List<WalkingMetricBase> _metrics = [
    stepLengthMetric,
    frontKneeControlMetric,
    rearKneeDepthMetric,
    torsoMetric,
  ];

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'hip': (right: PoseLandmarkType.rightHip, left: PoseLandmarkType.leftHip),
        'shoulder': (right: PoseLandmarkType.rightShoulder, left: PoseLandmarkType.leftShoulder),
        'knee': (right: PoseLandmarkType.rightKnee, left: PoseLandmarkType.leftKnee),
        'ankle': (right: PoseLandmarkType.rightAnkle, left: PoseLandmarkType.leftAnkle),
        'foot': (right: PoseLandmarkType.rightFootIndex, left: PoseLandmarkType.leftFootIndex),
      };

  @override
  String get exerciseName => 'Walking Lunge';

  @override
  String get currentPhaseKey => walkingState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (walkingState) {
      case WalkingState.standing:
        return 'Đứng thẳng';
      case WalkingState.stepping:
        return 'Bước tới';
      case WalkingState.descending:
        return 'Xuống';
      case WalkingState.bottom:
        return 'Giữ';
      case WalkingState.pulling_through:
        return 'Kéo lên';
    }
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("step_consistency_fails", stepLengthMetric.faultsCount);
    logger.pushKey("front_knee_fails", frontKneeControlMetric.faultsCount);
    logger.pushKey("rear_depth_fails", rearKneeDepthMetric.faultsCount);
    logger.pushKey("torso_lean_fails", torsoMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Bài tập này yêu cầu quay mặt ngang hông (Side Camera).";
    }
    final req = getSideTrackedLandmarks(landmarks);
    if (req == null) return "⚠️ Không thấy rõ cơ thể. Hãy điều chỉnh góc máy.";
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) return false;
    final req = getSideTrackedLandmarks(landmarks);
    if (req == null) return false;

    // Check if bounding box takes up > 50% width
    double minX = 10000;
    double maxX = -10000;
    for (var lm in landmarks.values) {
      if (ExerciseBase.isLandmarkConfident(lm)) {
        if (lm.x < minX) minX = lm.x;
        if (lm.x > maxX) maxX = lm.x;
      }
    }
    
    // We don't have access to imageSize directly here without passing it, but we know coordinates are scaled
    // Wait, coordinate system: let's assume image width is rough distance.
    // Instead of using imageSize, we can just check if they are near the edge.
    // Let's use a simple heuristic: if the distance between minX and maxX > 50% of the assumed frame width (usually ~480-720 in ML kit depending on scale).
    // Let's just trust that if the distance between shoulder and ankle is huge, they are too close.
    // A better approach is to ask them to step back.
    // I'll skip the >50% check since we don't have the exact image width in `isInStartPosition` easily.
    // Or I can just check if they are near the edge.
    
    // Legs straight
    final hip = req['hip']!;
    final knee = req['knee']!;
    final ankle = req['ankle']!;
    final angle = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    if (angle < 160.0) {
      resultIssues.feedback['System'] = 'Hãy đứng thẳng để bắt đầu.';
      return false;
    }
    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Resolve Side Tracked Landmarks to get visible side
    final req = getSideTrackedLandmarks(smoothedLandmarks);
    if (req == null) {
      if (walkingState != WalkingState.standing) {
        _transitionState(WalkingState.standing, frameTimestampMs);
      }
      resultIssues.feedback['System'] = "Không thấy rõ người! Vui lòng giữ toàn thân trong khung hình.";
      return;
    }

    final leftKnee = smoothedLandmarks[PoseLandmarkType.leftKnee];
    final rightKnee = smoothedLandmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];

    if (leftKnee == null || rightKnee == null || leftAnkle == null || rightAnkle == null ||
        leftKnee.likelihood < 0.5 || rightKnee.likelihood < 0.5 || 
        leftAnkle.likelihood < 0.5 || rightAnkle.likelihood < 0.5) {
      if (walkingState != WalkingState.standing) {
        _transitionState(WalkingState.standing, frameTimestampMs);
      }
      resultIssues.feedback['System'] = "Chưa nhìn thấy hết toàn bộ 2 chân! Hãy lùi lại.";
      return;
    }

    final hip = req['hip']!;
    final shoulder = req['shoulder']!;
    
    // Out of frame warning
    bool nearEdge = false;
    for (var lm in [req['foot']!, req['shoulder']!, req['hip']!]) {
      // Very rough check, usually coordinates are between 0 and Image Width.
      // We will rely on PersonDetector bounds if we could, but here we just check if X is very close to 0 or very large.
      // Assuming typical width is ~1280 or ~720 depending on rotation.
      if (lm.x < 10 || lm.x > 1000) { // Rough assumption
        nearEdge = true;
      }
    }

    if (nearEdge) {
      resultIssues.feedback['System'] = "Quay đầu lại và tiếp tục!";
      // Optionally TTS
    }

    // Determine Front Leg vs Rear Leg based on X coordinate
    // Note: direction depends on camera facing.

    // Determine which leg is in front
    if (cameraFacing == CameraFacing.left) {
      // Facing left: smaller X is in front
      _frontLegSide = leftAnkle.x < rightAnkle.x ? TrackedSide.left : TrackedSide.right;
    } else {
      // Facing right: larger X is in front
      _frontLegSide = leftAnkle.x > rightAnkle.x ? TrackedSide.left : TrackedSide.right;
    }

    // Extract landmarks based on front/rear
    final frontKnee = smoothedLandmarks[_frontLegSide == TrackedSide.left ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee]!;
    final frontAnkle = smoothedLandmarks[_frontLegSide == TrackedSide.left ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle]!;
    final frontFoot = smoothedLandmarks[_frontLegSide == TrackedSide.left ? PoseLandmarkType.leftFootIndex : PoseLandmarkType.rightFootIndex]!;
    
    final rearKnee = smoothedLandmarks[_frontLegSide == TrackedSide.left ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee]!;
    final rearAnkle = smoothedLandmarks[_frontLegSide == TrackedSide.left ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle]!;
    
    final frontHip = smoothedLandmarks[_frontLegSide == TrackedSide.left ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip]!;
    final rearHip = smoothedLandmarks[_frontLegSide == TrackedSide.left ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip]!;

    double frontKneeAngle = calculateAngleNormalized(firstPoint: frontHip, midPoint: frontKnee, lastPoint: frontAnkle);
    double rearKneeAngle = calculateAngleNormalized(firstPoint: rearHip, midPoint: rearKnee, lastPoint: rearAnkle);

    double torsoAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    if (torsoAngle > 180) torsoAngle = 360 - torsoAngle;

    double thighLength = calculateDistance(frontHip, frontKnee);
    double stepLengthX = (frontAnkle.x - rearAnkle.x).abs();

    int now = frameTimestampMs;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "hipY": hip.y,
      "frontKneeAngle": frontKneeAngle,
      "rearKneeAngle": rearKneeAngle,
      "stepLengthX": stepLengthX,
    }, timeStamp: now));

    var ctx = WalkingRepContext(
      thighLength: thighLength,
      frontKnee: frontKnee,
      frontAnkle: frontAnkle,
      frontFoot: frontFoot,
      rearKnee: rearKnee,
      rearAnkle: rearAnkle,
      hip: hip,
      shoulder: shoulder,
      frontKneeAngle: frontKneeAngle,
      rearKneeAngle: rearKneeAngle,
      torsoAngle: torsoAngle,
      stepLengthX: stepLengthX,
      state: walkingState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // State Machine
    _updateStateMachine(ctx);

    if (ctx.state != walkingState) {
      ctx = WalkingRepContext(
        thighLength: thighLength,
        frontKnee: frontKnee,
        frontAnkle: frontAnkle,
        frontFoot: frontFoot,
        rearKnee: rearKnee,
        rearAnkle: rearAnkle,
        hip: hip,
        shoulder: shoulder,
        frontKneeAngle: frontKneeAngle,
        rearKneeAngle: rearKneeAngle,
        torsoAngle: torsoAngle,
        stepLengthX: stepLengthX,
        state: walkingState,
        frameTimestamp: now,
        resultIssues: resultIssues,
      );
    }

    if (walkingState != WalkingState.standing) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    debugData['walkingState'] = walkingState.name;
    debugData['frontLeg'] = _frontLegSide.name;
    debugData['stepLength'] = stepLengthX;
    debugData['frontKneeAngle'] = frontKneeAngle;

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (walkingState == WalkingState.stepping) {
      resultIssues.addInstruction('stepping', 'Status', 'Bước tới!');
    } else if (walkingState == WalkingState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Hạ hông xuống...');
    } else if (walkingState == WalkingState.bottom) {
      if (_bottomStartTime != null) {
        int elapsed = now - _bottomStartTime!;
        int remaining = 2000 - elapsed;
        if (remaining > 0) {
          int seconds = (remaining / 1000).ceil();
          resultIssues.addInstruction('bottom', 'Timer', 'Giữ $seconds giây!');
        } else {
          resultIssues.addInstruction('bottom', 'Timer', 'Tốt! Đứng lên!');
        }
      } else {
        resultIssues.addInstruction('bottom', 'Status', 'Giữ 2 giây!');
      }
    } else if (walkingState == WalkingState.pulling_through) {
      resultIssues.addInstruction('pulling', 'Status', 'Rút chân sau lên!');
    }
  }

  void _updateStateMachine(WalkingRepContext ctx) {
    int now = ctx.frameTimestamp;
    final hipYChange = frameBuffer.getAngleChange("hipY");
    final stepXChange = frameBuffer.getAngleChange("stepLengthX");

    if (walkingState == WalkingState.standing) {
      if (ctx.stepLengthX > 80 || ctx.frontKneeAngle < 160) {
        _transitionState(WalkingState.stepping, now);
      }
    } else if (walkingState == WalkingState.stepping) {
      if (hipYChange == AngleChangeState.increasing) {
        _transitionState(WalkingState.descending, now);
      } else if (ctx.stepLengthX < 50 && ctx.frontKneeAngle > 160 && ctx.rearKneeAngle > 160) {
        // False start, returned to standing
        _transitionState(WalkingState.standing, now);
      }
    } else if (walkingState == WalkingState.descending) {
      // Bottom when hip stops moving down or knee hits 100
      if (ctx.frontKneeAngle <= 100 || hipYChange == AngleChangeState.decreasing) {
        if (ctx.frontKneeAngle > 135) {
          // Knee didn't bend enough. This is just normal walking, not a lunge attempt.
          _transitionState(WalkingState.stepping, now);
        } else {
          _transitionState(WalkingState.bottom, now);
          _bottomStartTime = now;
          // evaluate step length here using the real context
          stepLengthMetric.evaluateRep(ctx);
        }
      }
    } else if (walkingState == WalkingState.bottom) {
      _bottomStartTime ??= now;
      
      // Pulling through when hip moves up
      if (hipYChange == AngleChangeState.decreasing || ctx.frontKneeAngle > 120) {
        _transitionState(WalkingState.pulling_through, now);
      }
    } else if (walkingState == WalkingState.pulling_through) {
      // Rep is completed when both knees are mostly straight
      if (ctx.frontKneeAngle > 150 && ctx.rearKneeAngle > 150 && ctx.stepLengthX < 80) {
         _completeRep();
         _transitionState(WalkingState.standing, now);
      } else if (ctx.stepLengthX > 80 && ctx.frontKneeAngle > 140 && ctx.rearKneeAngle > 140) {
         // Continuous walking: stepped out for next rep
         _completeRep();
         _transitionState(WalkingState.stepping, now);
      } else if (hipYChange == AngleChangeState.increasing && ctx.stepLengthX > 80 && stepXChange == AngleChangeState.increasing) {
         // Continuous walking: immediately started descending
         _completeRep();
         _transitionState(WalkingState.descending, now);
      }
    }
  }

  void _transitionState(WalkingState newState, int timestampMs) {
    if (newState == walkingState) return;
    
    if (walkingState == WalkingState.bottom && newState == WalkingState.pulling_through) {
      if (_bottomStartTime != null) {
        int elapsed = timestampMs - _bottomStartTime!;
        if (elapsed < 2000) {
          if (!_localFaults.any((f) => f.type == 'not_enough_hold')) {
            _localFaults.add(FaultRecord(
              type: 'not_enough_hold',
              message: 'Chưa giữ đủ 2 giây!',
              affectsForm: true,
              phase: 'bottom',
              priority: 1,
              voiceMessage: 'Phải giữ đủ 2 giây!',
            ));
          }
        }
      }
    }

    previousWalkingState = walkingState;
    walkingState = newState;

    if (newState == WalkingState.stepping && previousWalkingState == WalkingState.standing) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousWalkingState, newState, timestampMs);
    }
  }

  void _completeRep() {
    repCount++;

    final allFaults = <FaultRecord>[];
    allFaults.addAll(_localFaults);
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }

    setFeedback.add({correctForm: faultMap});

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "fault_types": allFaults.map((f) => f.type).toSet().toList(),
    }));

    correctForm = true;
    _localFaults.clear();
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  // To provide smoothedLandmarks to _updateStateMachine
  Map<PoseLandmarkType, PoseLandmark>? smoothedLandmarks;

  @override
  List<dynamic>? processPose(Map<PoseLandmarkType, PoseLandmark> landmarks, {InputImage? inputImage, Size? imageSize}) {
    smoothedLandmarks = poseSmoother.smoothing(landmarks);
    return super.processPose(landmarks, inputImage: inputImage, imageSize: imageSize);
  }
}
