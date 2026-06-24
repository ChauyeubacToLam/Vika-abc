import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/pose/vika_pose_landmark.dart';
import 'package:vika/utils/exercise_logger.dart';

import '../../utils/frame_buffer.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/pose_math_helpers.dart';
import 'metrics/knee_anchoring_metric.dart';
import 'metrics/russian_metric_base.dart';
import 'metrics/spinal_flexion_metric.dart';
import 'metrics/thoracic_rotation_metric.dart';
import 'metrics/twist_rom_metric.dart';

enum RussianTwistState { center_setup, twisting, max_point, returning }

enum TwistDirection { none, forward, backward }

class RussianTwistConfig {
  static const int MAX_REP = 20;

  /// Trunk angle (shoulder midpoint -> hip midpoint, from horizontal) must
  /// stay in [MIN, MAX] degrees so the user sits in a leaned-back V, neither
  /// upright nor collapsed. In front-view this is measured via the dy/dx of
  /// the shoulder-to-hip midline.
  static const double MIN_TRUNK_HORIZONTAL_ANGLE = 32.0;
  static const double MAX_TRUNK_HORIZONTAL_ANGLE = 72.0;

  /// Lateral wrist offset thresholds, all normalized by shoulder width so
  /// they are body-size and camera-distance independent.
  ///
  /// A wrist offset of 0.30 means the hand is 30% of shoulder-width away
  /// from the body midline — a comfortable full twist to one side.
  static const double TWIST_START_DELTA = 0.12;
  static const double GOOD_ROM_DELTA = 0.28;
  static const double CENTER_TOLERANCE = 0.06;

  /// Velocity gate for wrist-offset change detection (normalized units).
  static const double OFFSET_VELOCITY_GATE = 0.015;

  /// Minimum shoulder width (px) below which the frame is rejected as too far
  /// away / unreliable.
  static const double MIN_SHOULDER_WIDTH = 40.0;
}

/// Front-view Russian Twist.
///
/// Rep counting is driven by the lateral position of the leading hand
/// relative to the body midline (midpoint of the two shoulders), normalized
/// by shoulder width. This signal stays reliable while twisting to both
/// sides because the hands remain in frame — unlike the previous side-view
/// implementation whose tracked shoulder was fully occluded when twisting
/// toward the camera's blind side, stalling the rep counter.
class RussianTwist extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
        VikaImageOrientation.portrait,
      };

  final int maxRep;
  RussianTwist({this.maxRep = RussianTwistConfig.MAX_REP});

  RussianTwistState russianState = RussianTwistState.center_setup;
  RussianTwistState previousRussianState = RussianTwistState.center_setup;
  TwistDirection currentDirection = TwistDirection.none;
  TwistDirection lastCompletedTwistDirection = TwistDirection.none;

  int _halfRepCount = 0;
  int _rejectedHalfTwists = 0;
  double? _centerOffset;
  final List<FaultRecord> _pendingFullRepFaults = [];

  static const Set<String> _blockingFaultTypes = {
    'shallow_twist',
    'knee_wobble',
    'upright_torso',
    'collapsed_torso',
  };

  final ThoracicRotationMetric thoracicMetric = ThoracicRotationMetric();
  final KneeAnchoringMetric kneeMetric = KneeAnchoringMetric();
  final TwistRomMetric twistRomMetric = TwistRomMetric();
  final SpinalFlexionMetric spinalMetric = SpinalFlexionMetric();

  late final List<RussianMetricBase> _metrics = [
    thoracicMetric,
    kneeMetric,
    twistRomMetric,
    spinalMetric,
  ];
  late final List<TrackedMetric> _trackedMetrics =
      _metrics.map(TrackedMetric.new).toList();

  @override
  List<TrackedMetric> get trackedDebugMetrics =>
      List<TrackedMetric>.unmodifiable(
        [
          ...super.trackedDebugMetrics,
          ..._trackedMetrics,
        ],
      );

  @override
  String get exerciseName => 'Russian Twist';

  @override
  String get currentPhaseKey => russianState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (russianState) {
      case RussianTwistState.center_setup:
        return 'Sẵn sàng';
      case RussianTwistState.twisting:
        return 'Vặn mình';
      case RussianTwistState.max_point:
        return 'Chạm đích';
      case RussianTwistState.returning:
        return 'Quay về';
    }
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("thoracic_fails_count", thoracicMetric.faultsCount);
    logger.pushKey("knee_wobble_fails_count", kneeMetric.faultsCount);
    logger.pushKey("rom_fails_count", twistRomMetric.faultsCount);
    logger.pushKey("rejected_attempts_count", _rejectedHalfTwists);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  // -- Safety: require a front view --

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) {
      if (cameraFacing == CameraFacing.left ||
          cameraFacing == CameraFacing.right) {
        return 'Đặt camera chính diện trước mặt, không quay nghiêng hông.';
      }
      if (cameraFacing == CameraFacing.angled) {
        return 'Xoay camera về chính diện trước mặt rồi mới tập.';
      }
      return 'Đặt camera chính diện trước mặt để AI thấy rõ hai vai và hai tay.';
    }

    final bundle = _collectFrontLandmarks(landmarks);
    if (bundle == null) {
      return 'Không nhìn thấy đủ các điểm khớp vai, hông, gối và cổ tay.';
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final bundle = _collectFrontLandmarks(landmarks);
    if (bundle == null) return false;

    final trunkAngle = _trunkHorizontalAngle(bundle);
    if (trunkAngle > RussianTwistConfig.MAX_TRUNK_HORIZONTAL_ANGLE) {
      resultIssues.feedback['System'] =
          'Ngả lưng ra sau khoảng 35-60 độ, không ngồi thẳng lưng.';
      return false;
    }
    if (trunkAngle < RussianTwistConfig.MIN_TRUNK_HORIZONTAL_ANGLE) {
      resultIssues.feedback['System'] =
          'Nâng thân lên một chút, đừng nằm quá thấp khi chuẩn bị.';
      return false;
    }

    // Hands must start roughly centered (near the body midline).
    final shoulderWidth = _shoulderWidth(bundle);
    if (shoulderWidth < RussianTwistConfig.MIN_SHOULDER_WIDTH) {
      resultIssues.feedback['System'] =
          'Lùi xa hơn một chút để AI nhìn rõ toàn thân.';
      return false;
    }

    final wristPoint = _leadingWrist(landmarks, bundle);
    final wristOffset =
        (wristPoint.x - bundle.midShoulderX) / shoulderWidth;
    if (wristOffset.abs() > RussianTwistConfig.TWIST_START_DELTA) {
      resultIssues.feedback['System'] =
          'Đưa hai tay về giữa ngực trước khi bắt đầu.';
      return false;
    }

    debugData['RussianSetup'] = {
      'cameraFacing': cameraFacing.name,
      'frontFacingRatio': frontFacingRatio.toStringAsFixed(2),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'shoulderWidth': shoulderWidth.toStringAsFixed(1),
      'wristOffset': wristOffset.toStringAsFixed(2),
    };
    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final safety = checkSafety(smoothedLandmarks);
    if (safety != null) {
      resultIssues.feedback['System'] = safety;
      return;
    }

    final bundle = _collectFrontLandmarks(smoothedLandmarks);
    if (bundle == null) return;

    final shoulderWidth = _shoulderWidth(bundle);
    if (shoulderWidth < RussianTwistConfig.MIN_SHOULDER_WIDTH) return;
    scaleFactor = shoulderWidth;

    final wristPoint = _leadingWrist(smoothedLandmarks, bundle);
    final wristOffset =
        (wristPoint.x - bundle.midShoulderX) / shoulderWidth;
    final shoulderRotationOffset =
        (bundle.midShoulderX - bundle.midHipX) / shoulderWidth;
    final trunkAngle = _trunkHorizontalAngle(bundle);

    final now = frameTimestampMs;
    frameBuffer.addFrame(FrameSnapshot(log: {
      'wristOffset': wristOffset,
    }, timeStamp: now));

    _updateStateMachine(wristOffset, now);

    final ctx = RussianRepContext(
      midShoulderX: bundle.midShoulderX,
      midShoulderY: bundle.midShoulderY,
      midHipX: bundle.midHipX,
      midHipY: bundle.midHipY,
      midKneeX: bundle.midKneeX,
      midKneeY: bundle.midKneeY,
      wristX: wristPoint.x,
      wristY: wristPoint.y,
      leftShoulderX: bundle.leftShoulder.x,
      leftShoulderY: bundle.leftShoulder.y,
      rightShoulderX: bundle.rightShoulder.x,
      rightShoulderY: bundle.rightShoulder.y,
      leftKneeX: bundle.leftKnee.x,
      leftKneeY: bundle.leftKnee.y,
      rightKneeX: bundle.rightKnee.x,
      rightKneeY: bundle.rightKnee.y,
      leftHipX: bundle.leftHip.x,
      leftHipY: bundle.leftHip.y,
      rightHipX: bundle.rightHip.x,
      rightHipY: bundle.rightHip.y,
      wristLateralOffset: wristOffset,
      shoulderRotationOffset: shoulderRotationOffset,
      kneeDriftRatio: 0.0,
      trunkHorizontalAngle: trunkAngle,
      shoulderWidth: shoulderWidth,
      state: russianState,
      direction: currentDirection,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    for (final metric in _metrics) {
      metric.update(ctx);
    }

    debugData['RussianTwistDebug'] = {
      'state': russianState.name,
      'cameraFacing': cameraFacing.name,
      'frontFacingRatio': frontFacingRatio.toStringAsFixed(2),
      'direction': currentDirection.name,
      'halfRepCount': _halfRepCount,
      'repCount': repCount,
      'rejectedHalfTwists': _rejectedHalfTwists,
      'wristOffset': wristOffset.toStringAsFixed(2),
      'shoulderRotation': shoulderRotationOffset.toStringAsFixed(2),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
    };

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (russianState == RussianTwistState.center_setup) {
      resultIssues.addInstruction('center', 'Status', 'Sẵn sàng vặn');
    } else if (russianState == RussianTwistState.twisting) {
      resultIssues.addInstruction('twisting', 'Status', 'Vặn người!');
    } else if (russianState == RussianTwistState.returning) {
      resultIssues.addInstruction('returning', 'Status', 'Quay về giữa');
    }
  }

  // -- State machine (driven by signed wrist lateral offset) --

  void _updateStateMachine(double wristOffset, int now) {
    final change = frameBuffer.getChange(
      'wristOffset',
      RussianTwistConfig.OFFSET_VELOCITY_GATE,
    );
    final center = _centerOffset ?? wristOffset;
    final delta = wristOffset - center;

    if (russianState == RussianTwistState.center_setup) {
      _centerOffset = center;
      if (delta >= RussianTwistConfig.TWIST_START_DELTA) {
        currentDirection = TwistDirection.forward;
        _transitionState(RussianTwistState.twisting, now);
      } else if (delta <= -RussianTwistConfig.TWIST_START_DELTA) {
        currentDirection = TwistDirection.backward;
        _transitionState(RussianTwistState.twisting, now);
      }
    } else if (russianState == RussianTwistState.twisting) {
      if (delta.abs() >= RussianTwistConfig.GOOD_ROM_DELTA) {
        _transitionState(RussianTwistState.max_point, now);
      } else if (_reversingFromPeak(change, delta)) {
        _transitionState(RussianTwistState.returning, now);
      }
    } else if (russianState == RussianTwistState.max_point) {
      if (_reversingFromPeak(change, delta)) {
        _transitionState(RussianTwistState.returning, now);
      }
    } else if (russianState == RussianTwistState.returning) {
      final nearCenter =
          delta.abs() <= RussianTwistConfig.CENTER_TOLERANCE;
      if (nearCenter) {
        _transitionState(RussianTwistState.center_setup, now);
        _completeHalfRep();
      }
    }
  }

  /// True when the wrist is travelling back toward center after a twist.
  bool _reversingFromPeak(ChangeState change, double delta) {
    if (delta == 0) return false;
    // Forward (positive delta) is reversing when offset is decreasing.
    // Backward (negative delta) is reversing when offset is increasing.
    if (delta > 0) {
      return change == ChangeState.decreasing;
    }
    return change == ChangeState.increasing;
  }

  void _transitionState(RussianTwistState newState, int timestampMs) {
    if (newState == russianState) return;

    previousRussianState = russianState;
    russianState = newState;

    if (newState == RussianTwistState.twisting &&
        previousRussianState == RussianTwistState.center_setup) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(
        previousRussianState,
        newState,
        currentDirection,
        timestampMs,
      );
    }
  }

  void _completeHalfRep() {
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }
    var countMetricFaults = false;

    final hasBlockingFault =
        allFaults.any((f) => _blockingFaultTypes.contains(f.type));

    if (!hasBlockingFault) {
      if (currentDirection == lastCompletedTwistDirection) {
        _rejectedHalfTwists++;
        resultIssues.feedback['Result'] = 'Không tính';
        setFeedback.add({
          false: {
            'General': {'duplicate_side': 'Vui lòng vặn luân phiên 2 hướng!'}
          }
        });
      } else {
        _halfRepCount++;
        lastCompletedTwistDirection = currentDirection;
        _pendingFullRepFaults.addAll(allFaults);

        if (_halfRepCount % 2 == 0) {
          repCount++;
          countMetricFaults = true;
          correctForm = !_pendingFullRepFaults.any((f) => f.affectsForm);
          resultIssues.feedback['Result'] =
              correctForm ? 'Tốt lắm!' : 'Chỉnh tư thế';

          final faultMap = <String, Map<String, String>>{};
          for (final fault in _pendingFullRepFaults) {
            faultMap.putIfAbsent(fault.phase, () => {});
            faultMap[fault.phase]![fault.type] = fault.message;
          }

          setFeedback.add({correctForm: faultMap});
          logger.addRepLog(RepLog(
            correctForm: correctForm,
            repNumber: repCount,
            data: {
              'fault_types':
                  _pendingFullRepFaults.map((f) => f.type).toSet().toList(),
              'half_rep_count': _halfRepCount,
            },
          ));
          _pendingFullRepFaults.clear();
        }
      }
    } else {
      _rejectedHalfTwists++;
      resultIssues.feedback['Result'] = 'Không tính';
      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        faultMap.putIfAbsent(fault.phase, () => {});
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({false: faultMap});
    }

    for (final metric in _metrics) {
      if (countMetricFaults) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }

    currentDirection = TwistDirection.none;
  }

  // -- Front-view landmark helpers --

  _FrontBundle? _collectFrontLandmarks(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null) {
      return null;
    }
    if (!ExerciseBase.isLandmarkConfident(leftShoulder) ||
        !ExerciseBase.isLandmarkConfident(rightShoulder) ||
        !ExerciseBase.isLandmarkConfident(leftHip) ||
        !ExerciseBase.isLandmarkConfident(rightHip) ||
        !ExerciseBase.isLandmarkConfident(leftKnee) ||
        !ExerciseBase.isLandmarkConfident(rightKnee)) {
      return null;
    }

    return _FrontBundle(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
      leftKnee: leftKnee,
      rightKnee: rightKnee,
    );
  }

  double _shoulderWidth(_FrontBundle bundle) {
    return calculateDistance(bundle.leftShoulder, bundle.rightShoulder);
  }

  double _trunkHorizontalAngle(_FrontBundle bundle) {
    final midShoulderY = (bundle.leftShoulder.y + bundle.rightShoulder.y) / 2;
    final midHipY = (bundle.leftHip.y + bundle.rightHip.y) / 2;
    final midShoulderX = (bundle.leftShoulder.x + bundle.rightShoulder.x) / 2;
    final midHipX = (bundle.leftHip.x + bundle.rightHip.x) / 2;

    final dy = (midShoulderY - midHipY).abs();
    final dx = (midShoulderX - midHipX).abs();
    // Angle of the shoulder->hip line from vertical. An upright torso reads
    // near 0° (shoulders directly above hips); a fully laid-back torso reads
    // near 90°. We reuse the same MIN/MAX trunk-angle config semantics, so
    // measure from vertical here.
    final fromVertical =
        math.atan2(dx, dy) * (180.0 / math.pi);
    return fromVertical;
  }

  /// Picks the more reliable wrist (highest presence/visibility/likelihood)
  /// to represent the leading hand. While twisting, the leading hand is the
  /// most stable signal and always stays in frame.
  ({double x, double y}) _leadingWrist(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    _FrontBundle bundle,
  ) {
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];

    if (leftWrist == null && rightWrist == null) {
      // Fall back to the shoulder midpoint if no wrist is visible.
      return (
        x: bundle.midShoulderX,
        y: bundle.midShoulderY,
      );
    }
    if (leftWrist == null) {
      return (x: rightWrist!.x, y: rightWrist.y);
    }
    if (rightWrist == null) {
      return (x: leftWrist.x, y: leftWrist.y);
    }

    final leftScore = _landmarkReliability(leftWrist);
    final rightScore = _landmarkReliability(rightWrist);
    final best = leftScore >= rightScore ? leftWrist : rightWrist;
    return (x: best.x, y: best.y);
  }

  double _landmarkReliability(PoseLandmark landmark) {
    return landmark.likelihood + landmark.presence + landmark.visibility;
  }
}

/// Internal helper bundling the six required bilateral landmarks for a
/// front-view frame, with precomputed midpoints.
class _FrontBundle {
  _FrontBundle({
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
    required this.leftKnee,
    required this.rightKnee,
  });

  final PoseLandmark leftShoulder;
  final PoseLandmark rightShoulder;
  final PoseLandmark leftHip;
  final PoseLandmark rightHip;
  final PoseLandmark leftKnee;
  final PoseLandmark rightKnee;

  double get midShoulderX => (leftShoulder.x + rightShoulder.x) / 2;
  double get midShoulderY => (leftShoulder.y + rightShoulder.y) / 2;
  double get midHipX => (leftHip.x + rightHip.x) / 2;
  double get midHipY => (leftHip.y + rightHip.y) / 2;
  double get midKneeX => (leftKnee.x + rightKnee.x) / 2;
  double get midKneeY => (leftKnee.y + rightKnee.y) / 2;
}
