// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import '../cobra/cobra.dart';

enum SuryaPoseId {
  pranamasana,
  hastaUttanasana,
  uttanasana,
  lowLungeRightBack,
  highPlankBlank,
  ashtangaNamaskara,
  cobra,
  downwardDog,
  lowLungeLeftBack,
}

enum SuryaBodySide { left, right }

class SuryaPoseRecognition {
  const SuryaPoseRecognition({
    required this.recognized,
    this.hint,
    this.debugData = const {},
  });

  final bool recognized;
  final String? hint;
  final Map<String, dynamic> debugData;
}

class SuryaPoseRecognizers {
  const SuryaPoseRecognizers._();

  static SuryaPoseRecognition recognize({
    required SuryaPoseId poseId,
    required Map<PoseLandmarkType, PoseLandmark> landmarks,
    required CameraFacing cameraFacing,
  }) {
    switch (poseId) {
      case SuryaPoseId.pranamasana:
        return _recognizePranamasana(landmarks, cameraFacing);
      case SuryaPoseId.hastaUttanasana:
        return _recognizeHastaUttanasana(landmarks, cameraFacing);
      case SuryaPoseId.uttanasana:
        return _recognizeUttanasana(landmarks, cameraFacing);
      case SuryaPoseId.lowLungeRightBack:
        return _recognizeLowLunge(
          landmarks,
          cameraFacing,
          expectedFrontSide: SuryaBodySide.left,
        );
      case SuryaPoseId.highPlankBlank:
        return _recognizeHighPlank(landmarks, cameraFacing);
      case SuryaPoseId.ashtangaNamaskara:
        return _recognizeAshtanga(landmarks, cameraFacing);
      case SuryaPoseId.cobra:
        return _recognizeCobra(landmarks, cameraFacing);
      case SuryaPoseId.downwardDog:
        return _recognizeDownwardDog(landmarks, cameraFacing);
      case SuryaPoseId.lowLungeLeftBack:
        return _recognizeLowLunge(
          landmarks,
          cameraFacing,
          expectedFrontSide: SuryaBodySide.right,
        );
    }
  }

  static SuryaPoseRecognition _recognizePranamasana(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveSideBody(landmarks, cameraFacing);
    if (body == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa vai và hông vào khung hình.',
      );
    }

    final scale = calculateDistance(body.shoulder, body.hip);
    if (scale < 1.0) {
      return const SuryaPoseRecognition(recognized: false);
    }

    final trunkClock = calculateVerticalAngle(
      pivot: body.hip,
      point: body.shoulder,
    );
    final upright = body.shoulder.y < body.hip.y &&
        clockAngleDeviation(trunkClock, 0.0).abs() <= 35.0;
    final shoulderEase =
        body.ear == null ? 1.0 : (body.shoulder.y - body.ear!.y).abs() / scale;
    final shouldersRelaxed = shoulderEase >= 0.25;

    return SuryaPoseRecognition(
      recognized: upright && shouldersRelaxed,
      hint: upright ? 'Thả lỏng vai xuống.' : 'Đứng thẳng người hơn.',
      debugData: {
        'suryaPrayerUpright': upright,
        'suryaPrayerShoulderEase': shoulderEase.toStringAsFixed(2),
      },
    );
  }

  static SuryaPoseRecognition _recognizeHastaUttanasana(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveSideBody(
      landmarks,
      cameraFacing,
      requireElbow: true,
      requireWrist: true,
    );
    if (body == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa vai, hông, khuỷu tay và cổ tay vào khung hình.',
      );
    }

    final trunkClock = calculateVerticalAngle(
      pivot: body.hip,
      point: body.shoulder,
    );
    final backLean = _backLeanFromVertical(trunkClock, cameraFacing);
    final wristAboveShoulder = body.wrist!.y < body.shoulder.y;
    final elbowAngle = calculateAngle(
      firstPoint: body.shoulder,
      midPoint: body.elbow!,
      lastPoint: body.wrist!,
    );
    final armsLong = elbowAngle >= 120.0;
    final trunkOk = body.shoulder.y < body.hip.y && backLean <= 22.0;

    return SuryaPoseRecognition(
      recognized: wristAboveShoulder && armsLong && trunkOk,
      hint: wristAboveShoulder
          ? 'Ngả nhẹ thôi, giữ bụng dưới chắc.'
          : 'Vươn tay lên cao qua đầu.',
      debugData: {
        'suryaRaisedArmsBackLean': backLean.toStringAsFixed(1),
        'suryaRaisedArmsElbow': elbowAngle.toStringAsFixed(1),
      },
    );
  }

  static SuryaPoseRecognition _recognizeUttanasana(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveSideBody(landmarks, cameraFacing, requireWrist: true);
    if (body == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa vai, hông và tay vào khung hình.',
      );
    }

    final scale = calculateDistance(body.shoulder, body.hip);
    if (scale < 1.0) return const SuryaPoseRecognition(recognized: false);

    final trunkClock = calculateVerticalAngle(
      pivot: body.hip,
      point: body.shoulder,
    );
    final forwardLean = convertClockAngleToTrunkLean(trunkClock, cameraFacing);
    final folded = forwardLean >= 45.0 || body.shoulder.y > body.hip.y;
    final handLow = body.wrist == null || body.wrist!.y >= body.hip.y - scale;

    return SuryaPoseRecognition(
      recognized: folded && handLow,
      hint: folded
          ? 'Gập gối nếu cần để giữ lưng dài.'
          : 'Gập người từ khớp hông về phía trước.',
      debugData: {
        'suryaUttanasanaForwardLean': forwardLean.toStringAsFixed(1),
        'suryaUttanasanaFolded': folded,
      },
    );
  }

  static SuryaPoseRecognition _recognizeLowLunge(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing, {
    required SuryaBodySide expectedFrontSide,
  }) {
    final lunge = _resolveLunge(landmarks, cameraFacing);
    if (lunge == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa hai chân, hông và vai vào khung hình.',
      );
    }

    final scale = calculateDistance(lunge.frontShoulder, lunge.frontHip);
    if (scale < 1.0) return const SuryaPoseRecognition(recognized: false);

    final stanceRatio = (lunge.frontAnkle.x - lunge.backAnkle.x).abs() / scale;
    final frontKneeAngle = calculateAngle(
      firstPoint: lunge.frontHip,
      midPoint: lunge.frontKnee,
      lastPoint: lunge.frontAnkle,
    );
    final sideMatches = lunge.frontSide == expectedFrontSide;
    final lungeShape = stanceRatio > 0.50 && frontKneeAngle < 170.0;

    return SuryaPoseRecognition(
      recognized: lungeShape && sideMatches,
      hint: sideMatches
          ? 'Hạ hông xuống nhẹ, nâng ngực.'
          : 'Đổi đúng chân cho nhịp lunge này.',
      debugData: {
        'suryaLungeFrontSide': lunge.frontSide.name,
        'suryaLungeExpectedFront': expectedFrontSide.name,
        'suryaLungeStance': stanceRatio.toStringAsFixed(2),
        'suryaLungeFrontKnee': frontKneeAngle.toStringAsFixed(1),
      },
    );
  }

  static SuryaPoseRecognition _recognizeAshtanga(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveFloorBody(landmarks, cameraFacing);
    if (body == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa vai, hông, gối và cổ chân vào khung hình.',
      );
    }

    final scale = calculateDistance(body.shoulder, body.hip);
    if (scale < 1.0) return const SuryaPoseRecognition(recognized: false);

    final shoulderHipDelta = body.shoulder.y - body.hip.y;
    final hipPositionRatio = shoulderHipDelta / scale;
    final kneesGrounded = (body.knee.y - body.ankle.y).abs() / scale <= 1.0;
    final chestLow = shoulderHipDelta / scale >= 0.05;

    return SuryaPoseRecognition(
      recognized: kneesGrounded && hipPositionRatio >= 0.12 && chestLow,
      hint: 'Hạ gối, ngực, cằm và giữ hông cao.',
      debugData: {
        'suryaAshtangaHipRatio': hipPositionRatio.toStringAsFixed(3),
        'suryaAshtangaKneesGrounded': kneesGrounded,
        'suryaAshtangaChestLow': chestLow,
      },
    );
  }

  static SuryaPoseRecognition _recognizeHighPlank(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveFloorBody(
      landmarks,
      cameraFacing,
      requireWrist: true,
    );
    if (body == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa cổ tay, vai, hông, gối và cổ chân vào khung hình.',
      );
    }

    final scale = calculateDistance(body.shoulder, body.hip);
    if (scale < 1.0) return const SuryaPoseRecognition(recognized: false);

    final bodyLine = calculateAngleNormalized(
      firstPoint: body.shoulder,
      midPoint: body.hip,
      lastPoint: body.ankle,
    );
    final wristShoulderOffset = (body.wrist!.x - body.shoulder.x).abs() / scale;
    final hipShoulderLevel = (body.hip.y - body.shoulder.y).abs() / scale;
    final plankShape = bodyLine >= 150.0 && hipShoulderLevel <= 1.0;
    final handStacked = wristShoulderOffset <= 1.2;

    return SuryaPoseRecognition(
      recognized: plankShape && handStacked,
      hint: plankShape
          ? 'Giữ vai trên cổ tay, siết bụng nhẹ.'
          : 'Duỗi người thành một đường thẳng từ vai đến gót.',
      debugData: {
        'suryaHighPlankBodyLine': bodyLine.toStringAsFixed(1),
        'suryaHighPlankWristOffset': wristShoulderOffset.toStringAsFixed(2),
        'suryaHighPlankHipLevel': hipShoulderLevel.toStringAsFixed(2),
      },
    );
  }

  static SuryaPoseRecognition _recognizeCobra(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveSideBody(landmarks, cameraFacing);
    if (body == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa vai và hông vào khung hình.',
      );
    }

    final scale = calculateDistance(body.shoulder, body.hip);
    if (scale < 1.0) return const SuryaPoseRecognition(recognized: false);

    final trunkClock = calculateVerticalAngle(
      pivot: body.hip,
      point: body.shoulder,
    );
    final horizontalTarget = cameraFacing == CameraFacing.right
        ? CobraConfig.HORIZONTAL_CLOCK_RIGHT
        : CobraConfig.HORIZONTAL_CLOCK_LEFT;
    final elevation = clockAngleDeviation(trunkClock, horizontalTarget).abs();
    final chestLifted = _isStandaloneCobraPosition(trunkClock, cameraFacing);
    final elbowAngle = body.elbow == null || body.wrist == null
        ? null
        : calculateAngle(
            firstPoint: body.shoulder,
            midPoint: body.elbow!,
            lastPoint: body.wrist!,
          );

    return SuryaPoseRecognition(
      recognized: chestLifted,
      hint: 'Trượt ngực lên, khuỷu tay vẫn gập nhẹ.',
      debugData: {
        'suryaCobraElevation': elevation.toStringAsFixed(1),
        'suryaCobraMinElevation': CobraConfig.COBRA_MIN_ELEVATION,
        if (elbowAngle != null)
          'suryaCobraElbow': elbowAngle.toStringAsFixed(1),
      },
    );
  }

  static bool _isStandaloneCobraPosition(
    double trunkClockAngle,
    CameraFacing cameraFacing,
  ) {
    if (cameraFacing == CameraFacing.right) {
      return trunkClockAngle <
          (CobraConfig.HORIZONTAL_CLOCK_RIGHT -
              CobraConfig.COBRA_MIN_ELEVATION);
    }
    if (cameraFacing == CameraFacing.left) {
      return trunkClockAngle >
          (CobraConfig.HORIZONTAL_CLOCK_LEFT + CobraConfig.COBRA_MIN_ELEVATION);
    }
    return false;
  }

  static SuryaPoseRecognition _recognizeDownwardDog(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    final body = _resolveFloorBody(
      landmarks,
      cameraFacing,
      requireWrist: true,
      requireEar: true,
    );
    if (body == null) {
      return const SuryaPoseRecognition(
        recognized: false,
        hint: 'Đưa cổ tay, vai, hông, gối và cổ chân vào khung hình.',
      );
    }

    final spineAngle = calculateAngleNormalized(
      firstPoint: body.wrist!,
      midPoint: body.shoulder,
      lastPoint: body.hip,
    );
    final apexAngle = calculateAngleNormalized(
      firstPoint: body.shoulder,
      midPoint: body.hip,
      lastPoint: body.ankle,
    );
    final hipsHigh = body.hip.y < body.shoulder.y || body.hip.y < body.knee.y;
    final grounded = body.wrist!.y > body.hip.y && body.ankle.y > body.hip.y;

    return SuryaPoseRecognition(
      recognized: hipsHigh && grounded && spineAngle >= 110.0,
      hint: 'Đẩy hông lên cao và kéo dài lưng.',
      debugData: {
        'suryaDownDogSpine': spineAngle.toStringAsFixed(1),
        'suryaDownDogApex': apexAngle.toStringAsFixed(1),
        'suryaDownDogHipsHigh': hipsHigh,
      },
    );
  }

  static _SideBody? _resolveSideBody(
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
    final ear = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    if (shoulder == null || hip == null) return null;
    if (requireElbow && elbow == null) return null;
    if (requireWrist && wrist == null) return null;

    return _SideBody(
      shoulder: shoulder,
      hip: hip,
      elbow: elbow,
      wrist: wrist,
      ear: ear,
    );
  }

  static _FloorBody? _resolveFloorBody(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing, {
    bool requireElbow = false,
    bool requireWrist = false,
    bool requireEar = false,
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
    final ear = _sideLandmark(
      landmarks,
      cameraFacing,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    if (shoulder == null || hip == null || knee == null || ankle == null) {
      return null;
    }
    if (requireElbow && elbow == null) return null;
    if (requireWrist && wrist == null) return null;
    if (requireEar && ear == null) return null;

    return _FloorBody(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
      elbow: elbow,
      wrist: wrist,
      ear: ear,
    );
  }

  static _LungeBody? _resolveLunge(
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
      frontSide: leftIsFront ? SuryaBodySide.left : SuryaBodySide.right,
      direction: leftIsFront
          ? (leftAnkle.x - rightAnkle.x).sign
          : (rightAnkle.x - leftAnkle.x).sign,
      frontShoulder: leftIsFront ? leftShoulder : rightShoulder,
      frontHip: leftIsFront ? leftHip : rightHip,
      frontKnee: leftIsFront ? leftKnee : rightKnee,
      frontAnkle: leftIsFront ? leftAnkle : rightAnkle,
      backAnkle: leftIsFront ? rightAnkle : leftAnkle,
    );
  }

  static PoseLandmark? _sideLandmark(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing, {
    required PoseLandmarkType rightType,
    required PoseLandmarkType leftType,
  }) {
    if (cameraFacing == CameraFacing.right) return landmarks[rightType];
    return landmarks[leftType];
  }

  static double _backLeanFromVertical(
    double trunkClockAngle,
    CameraFacing cameraFacing,
  ) {
    final diff = clockAngleDeviation(trunkClockAngle, 0.0);
    return cameraFacing == CameraFacing.right ? -diff : diff;
  }
}

class _SideBody {
  const _SideBody({
    required this.shoulder,
    required this.hip,
    this.elbow,
    this.wrist,
    this.ear,
  });

  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark? elbow;
  final PoseLandmark? wrist;
  final PoseLandmark? ear;
}

class _FloorBody {
  const _FloorBody({
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
    this.elbow,
    this.wrist,
    this.ear,
  });

  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark knee;
  final PoseLandmark ankle;
  final PoseLandmark? elbow;
  final PoseLandmark? wrist;
  final PoseLandmark? ear;
}

class _LungeBody {
  const _LungeBody({
    required this.frontSide,
    required this.direction,
    required this.frontShoulder,
    required this.frontHip,
    required this.frontKnee,
    required this.frontAnkle,
    required this.backAnkle,
  });

  final SuryaBodySide frontSide;
  final double direction;
  final PoseLandmark frontShoulder;
  final PoseLandmark frontHip;
  final PoseLandmark frontKnee;
  final PoseLandmark frontAnkle;
  final PoseLandmark backAnkle;
}
