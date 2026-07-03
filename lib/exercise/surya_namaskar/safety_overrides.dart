// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import '../cobra/cobra.dart';

import 'pose_recognizers.dart';

class SuryaSafetyResult {
  const SuryaSafetyResult({
    required this.triggered,
    this.code,
    this.message,
    this.debugData = const {},
  });

  final bool triggered;
  final String? code;
  final String? message;
  final Map<String, dynamic> debugData;

  static const none = SuryaSafetyResult(triggered: false);
}

class SuryaSafetyOverrides {
  SuryaPoseId? _activePoseId;
  final Map<String, int> _unsafeFramesByCode = {};

  void resetForPose(SuryaPoseId poseId) {
    if (_activePoseId == poseId) return;
    _activePoseId = poseId;
    _unsafeFramesByCode.clear();
  }

  void clear() {
    _unsafeFramesByCode.clear();
  }

  SuryaSafetyResult evaluate({
    required SuryaPoseId poseId,
    required Map<PoseLandmarkType, PoseLandmark> landmarks,
    required CameraFacing cameraFacing,
  }) {
    resetForPose(poseId);

    switch (poseId) {
      case SuryaPoseId.hastaUttanasana:
        return _raisedArmsSafety(landmarks, cameraFacing);
      case SuryaPoseId.lowLungeRightBack:
      case SuryaPoseId.lowLungeLeftBack:
        return _lowLungeSafety(landmarks, cameraFacing);
      case SuryaPoseId.highPlankBlank:
        return _highPlankSafety(landmarks, cameraFacing);
      case SuryaPoseId.ashtangaNamaskara:
        return _ashtangaSafety(landmarks, cameraFacing);
      case SuryaPoseId.cobra:
        return _cobraSafety(landmarks, cameraFacing);
      case SuryaPoseId.downwardDog:
        return _downwardDogSafety(landmarks, cameraFacing);
      case SuryaPoseId.pranamasana:
      case SuryaPoseId.uttanasana:
        return SuryaSafetyResult.none;
    }
  }

  SuryaSafetyResult _raisedArmsSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final shoulder = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    if (shoulder == null || hip == null) return SuryaSafetyResult.none;

    final trunkClock = calculateVerticalAngle(pivot: hip, point: shoulder);
    final backLean = _backLeanFromVertical(trunkClock, cameraFacing);
    final unsafe = backLean > 15.0;
    return _debounced(
      code: 'raised_arms_lumbar_backbend',
      unsafe: unsafe,
      message: 'Cẩn thận lưng dưới, ngả nhẹ thôi.',
      debugData: {'suryaSafetyRaisedBackLean': backLean.toStringAsFixed(1)},
    );
  }

  SuryaSafetyResult _lowLungeSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final lunge = _resolveLunge(landmarks, cameraFacing);
    if (lunge == null) return SuryaSafetyResult.none;

    final scale = calculateDistance(lunge.frontShoulder, lunge.frontHip);
    if (scale < 1.0) return SuryaSafetyResult.none;

    final offset =
        ((lunge.frontKnee.x - lunge.frontAnkle.x) * lunge.direction) / scale;
    final unsafe = offset > 0.8;
    return _debounced(
      code: 'low_lunge_knee_travel',
      unsafe: unsafe,
      message: 'Cẩn thận đầu gối, đẩy hông ra sau một chút.',
      debugData: {'suryaSafetyKneeTravel': offset.toStringAsFixed(3)},
    );
  }

  SuryaSafetyResult _ashtangaSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveFloorBody(landmarks, cameraFacing);
    if (body == null) return SuryaSafetyResult.none;

    final scale = calculateDistance(body.shoulder, body.hip);
    if (scale < 1.0) return SuryaSafetyResult.none;

    final hipRatio = (body.shoulder.y - body.hip.y) / scale;
    final unsafe = hipRatio < 0.15;
    return _debounced(
      code: 'ashtanga_hip_collapse',
      unsafe: unsafe,
      message: 'Đẩy hông lên cao, đừng sụp hông xuống ngang vai.',
      debugData: {'suryaSafetyAshtangaHipRatio': hipRatio.toStringAsFixed(3)},
    );
  }

  SuryaSafetyResult _highPlankSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveFloorBody(landmarks, cameraFacing, requireWrist: true);
    if (body == null) return SuryaSafetyResult.none;

    final bodyLine = calculateAngleNormalized(
      firstPoint: body.shoulder,
      midPoint: body.hip,
      lastPoint: body.ankle,
    );
    final unsafe = bodyLine < 145.0;
    return _debounced(
      code: 'high_plank_body_line',
      unsafe: unsafe,
      message: 'Giữ vai, hông và gót chân trên một đường thẳng.',
      debugData: {'suryaSafetyHighPlankBodyLine': bodyLine.toStringAsFixed(1)},
    );
  }

  SuryaSafetyResult _cobraSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveFloorBody(
      landmarks,
      cameraFacing,
      requireElbow: true,
      requireWrist: true,
    );
    if (body == null) return SuryaSafetyResult.none;

    final trunkClock = calculateVerticalAngle(
      pivot: body.hip,
      point: body.shoulder,
    );
    final horizontalTarget = cameraFacing == CameraFacing.right
        ? CobraConfig.HORIZONTAL_CLOCK_RIGHT
        : CobraConfig.HORIZONTAL_CLOCK_LEFT;
    final elevation = clockAngleDeviation(trunkClock, horizontalTarget).abs();
    final elbowAngle = calculateAngle(
      firstPoint: body.shoulder,
      midPoint: body.elbow!,
      lastPoint: body.wrist!,
    );

    final overextended = elevation > CobraConfig.COBRA_OVEREXTENSION_MAX;
    final elbowsLocked = elbowAngle > CobraConfig.COBRA_ELBOW_LOCKOUT_MIN;
    final unsafe = overextended || elbowsLocked;
    final message = elbowsLocked
        ? 'Giữ khuỷu tay gập nhẹ, đừng đẩy thành upward dog.'
        : 'Cẩn thận lưng dưới, nâng ngực nhẹ hơn.';

    return _debounced(
      code: elbowsLocked ? 'cobra_elbow_locked' : 'cobra_lumbar_overextension',
      unsafe: unsafe,
      message: message,
      debugData: {
        'suryaSafetyCobraElevation': elevation.toStringAsFixed(1),
        'suryaSafetyCobraElbow': elbowAngle.toStringAsFixed(1),
      },
    );
  }

  SuryaSafetyResult _downwardDogSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveFloorBody(landmarks, cameraFacing, requireWrist: true);
    if (body == null) return SuryaSafetyResult.none;

    final spineAngle = calculateAngleNormalized(
      firstPoint: body.wrist!,
      midPoint: body.shoulder,
      lastPoint: body.hip,
    );
    final unsafe = spineAngle < 145.0;
    return _debounced(
      code: 'downward_dog_spine_round',
      unsafe: unsafe,
      message: 'Gập gối nếu cần, giữ lưng dài hơn.',
      debugData: {'suryaSafetyDownDogSpine': spineAngle.toStringAsFixed(1)},
    );
  }

  SuryaSafetyResult _debounced({
    required String code,
    required bool unsafe,
    required String message,
    required Map<String, dynamic> debugData,
  }) {
    if (!unsafe) {
      _unsafeFramesByCode[code] = 0;
      return SuryaSafetyResult(triggered: false, debugData: debugData);
    }

    final frames = (_unsafeFramesByCode[code] ?? 0) + 1;
    _unsafeFramesByCode[code] = frames;
    return SuryaSafetyResult(
      triggered: frames >= 3,
      code: code,
      message: message,
      debugData: debugData,
    );
  }

  _FloorBody? _resolveFloorBody(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing, {
    bool requireElbow = false,
    bool requireWrist = false,
  }) {
    final shoulder = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    final knee = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
    );
    final ankle = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightAnkle,
      leftType: PoseLandmarkType.leftAnkle,
    );
    final elbow = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightElbow,
      leftType: PoseLandmarkType.leftElbow,
    );
    final wrist = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightWrist,
      leftType: PoseLandmarkType.leftWrist,
    );

    if (shoulder == null || hip == null || knee == null || ankle == null) {
      return null;
    }
    if (requireElbow && elbow == null) return null;
    if (requireWrist && wrist == null) return null;

    return _FloorBody(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
      elbow: elbow,
      wrist: wrist,
    );
  }

  _LungeBody? _resolveLunge(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftHip == null ||
        leftKnee == null ||
        leftAnkle == null ||
        leftShoulder == null ||
        rightHip == null ||
        rightKnee == null ||
        rightAnkle == null ||
        rightShoulder == null) return null;

    final leftIsFront = cameraFacing == CameraFacing.right
        ? leftAnkle.x < rightAnkle.x
        : leftAnkle.x > rightAnkle.x;

    return _LungeBody(
      direction: leftIsFront
          ? (leftAnkle.x - rightAnkle.x).sign
          : (rightAnkle.x - leftAnkle.x).sign,
      frontShoulder: leftIsFront ? leftShoulder : rightShoulder,
      frontHip: leftIsFront ? leftHip : rightHip,
      frontKnee: leftIsFront ? leftKnee : rightKnee,
      frontAnkle: leftIsFront ? leftAnkle : rightAnkle,
    );
  }

  PoseLandmark? _sideLandmark(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing, {
    required PoseLandmarkType rightType,
    required PoseLandmarkType leftType,
  }) {
    if (cameraFacing == CameraFacing.right) return landmarks[rightType];
    return landmarks[leftType];
  }

  double _backLeanFromVertical(
    double trunkClockAngle,
    CameraFacing cameraFacing,
  ) {
    final diff = clockAngleDeviation(trunkClockAngle, 0.0);
    return cameraFacing == CameraFacing.right ? -diff : diff;
  }
}

class _FloorBody {
  const _FloorBody({
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
    this.elbow,
    this.wrist,
  });

  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark knee;
  final PoseLandmark ankle;
  final PoseLandmark? elbow;
  final PoseLandmark? wrist;
}

class _LungeBody {
  const _LungeBody({
    required this.direction,
    required this.frontShoulder,
    required this.frontHip,
    required this.frontKnee,
    required this.frontAnkle,
  });

  final double direction;
  final PoseLandmark frontShoulder;
  final PoseLandmark frontHip;
  final PoseLandmark frontKnee;
  final PoseLandmark frontAnkle;
}
