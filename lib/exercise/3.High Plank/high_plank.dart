// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../hold/rep_counted_hold_exercise.dart';
import 'metrics/high_plank_metric_base.dart';
import 'metrics/sagging_metric.dart';
import 'metrics/piked_hip_metric.dart';
import 'metrics/elbow_metric.dart';

class HighPlankConfig {
  // Start Position (Tay duỗi, lưng thẳng, gối thẳng)
  static const double START_ARM_MIN = 140.0;
  static const double START_BODY_MIN = 150.0;
  static const double START_KNEE_MIN = 135.0;
  static const double FLOOR_CONTACT_Y_TOLERANCE = 0.55;
  static const double WRIST_BELOW_SHOULDER_MIN = 0.35;
  static const double ANKLE_BELOW_HIP_MIN = 0.06;

  // State Transition Thresholds
  // SETUP/DROPPING -> HOLDING (ngưỡng vào, chuẩn)
  static const double HOLDING_BODY_THRESHOLD = 150.0;
  static const double HOLDING_ARM_THRESHOLD = 140.0;
  static const double HOLDING_KNEE_THRESHOLD = 135.0;
  static const double HOLDING_SAG_DEVIATION = 0.12;

  // State Transition Thresholds
  // HOLDING -> DROPPING (ngưỡng ra, lỏng hơn = tạo hysteresis band)
  static const double DROPPING_PIKE_ANGLE = 140.0;
  static const double DROPPING_ARM_ANGLE = 130.0;
  static const double DROPPING_KNEE_ANGLE = 125.0; // Gối cong quá
  static const double DROPPING_SAG_DEVIATION = 0.18; // Sụp hông > 12% chiều dài

  // Outer anti-cheat ring. These are deliberately much looser than the form
  // thresholds above: ordinary form faults stay coachable inside the hold.
  static const double OUTER_ENTRY_BODY_MIN = 115.0;
  static const double OUTER_ENTRY_ARM_MIN = 100.0;
  static const double OUTER_ENTRY_KNEE_MIN = 100.0;
  static const double OUTER_ENTRY_SAG_MAX = 0.38;
  static const double OUTER_ENTRY_TORSO_TILT_MAX = 40.0;
  static const double OUTER_EXIT_BODY_MIN = 105.0;
  static const double OUTER_EXIT_ARM_MIN = 90.0;
  static const double OUTER_EXIT_KNEE_MIN = 90.0;
  static const double OUTER_EXIT_SAG_MAX = 0.45;
  static const double OUTER_EXIT_TORSO_TILT_MAX = 55.0;
}

class _HighPlankPoseFrame {
  const _HighPlankPoseFrame({
    required this.bodyAngle,
    required this.armAngle,
    required this.hipDeviation,
  });

  final double bodyAngle;
  final double armAngle;
  final double hipDeviation;
}

class HighPlank extends RepCountedHoldExercise {
  HighPlank({
    required super.maxHolds,
    required super.holdSeconds,
  });

  int? _exerciseStartTimeMs;
  _HighPlankPoseFrame? _sampledFrame;

  // DIAGNOSTIC LOG
  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final SaggingMetric saggingMetric = SaggingMetric();
  final PikedHipMetric pikedHipMetric = PikedHipMetric();
  final ElbowMetric elbowMetric = ElbowMetric();

  late final List<HighPlankMetricBase> _metrics = [
    saggingMetric,
    pikedHipMetric,
    elbowMetric,
  ];

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'High Plank';

  @override
  int get holdingDebounceFrames => 4;

  @override
  int get droppingDebounceFrames => 2;

  // Compatibility surface for the existing High Plank tests and metrics.
  HighPlankState get state => phase;
  HighPlankState get previousState => previousPhase;

  @override
  String get currentPhaseLabel {
    switch (phase) {
      case HighPlankState.setup:
        return 'Chuẩn bị form...';
      case HighPlankState.holding:
        return 'Giữ vững! Đang đếm giờ';
      case HighPlankState.dropping:
        return 'Mất form! Sửa lại ngay';
      case HighPlankState.resting:
        return 'Nghỉ';
      case HighPlankState.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  List<FaultRecord> get liveFaults {
    if (phase == HoldPhase.holding) {
      return <FaultRecord>[
        if (saggingMetric.isFaultingNow)
          FaultRecord(
            phase: phase.name,
            type: 'sagging',
            message: 'Võng lưng',
            affectsForm: true,
            priority: 0,
          ),
        if (elbowMetric.isFaultingNow)
          FaultRecord(
            phase: phase.name,
            type: 'elbow',
            message: 'Khuỷu tay bị gập',
            affectsForm: true,
            priority: 1,
          ),
        if (pikedHipMetric.isFaultingNow)
          FaultRecord(
            phase: phase.name,
            type: 'piked',
            message: 'Hông nâng quá cao',
            affectsForm: true,
            priority: 2,
          ),
      ];
    }
    final breakId = outerBreakFaultId;
    if (phase != HoldPhase.dropping || breakId == null) {
      return const <FaultRecord>[];
    }
    return <FaultRecord>[
      FaultRecord(
        phase: phase.name,
        type: breakId,
        message: 'Mất tư thế plank',
        affectsForm: true,
        priority: 0,
      ),
    ];
  }

  @override
  GuidanceSignal? checkSafety(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      interruptReArm();
      return const GuidanceSignal.turnSide();
    }
    final lm = _getLandmarks(smoothedLandmarks);
    if (lm == null || !lm.values.every(ExerciseBase.isLandmarkConfident)) {
      interruptActiveHold('wall_guard');
      interruptReArm();
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  Map<String, PoseLandmark>? _getLandmarks(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    bool hasLeft = lm.containsKey(PoseLandmarkType.leftShoulder) &&
        lm.containsKey(PoseLandmarkType.leftHip) &&
        lm.containsKey(PoseLandmarkType.leftAnkle) &&
        lm.containsKey(PoseLandmarkType.leftElbow) &&
        lm.containsKey(PoseLandmarkType.leftWrist) &&
        lm.containsKey(PoseLandmarkType.leftKnee);

    bool hasRight = lm.containsKey(PoseLandmarkType.rightShoulder) &&
        lm.containsKey(PoseLandmarkType.rightHip) &&
        lm.containsKey(PoseLandmarkType.rightAnkle) &&
        lm.containsKey(PoseLandmarkType.rightElbow) &&
        lm.containsKey(PoseLandmarkType.rightWrist) &&
        lm.containsKey(PoseLandmarkType.rightKnee);

    if (!hasLeft && !hasRight) return null;

    double leftScore = 0;
    if (hasLeft) {
      leftScore = lm[PoseLandmarkType.leftShoulder]!.likelihood +
          lm[PoseLandmarkType.leftHip]!.likelihood +
          lm[PoseLandmarkType.leftAnkle]!.likelihood;
    }
    double rightScore = 0;
    if (hasRight) {
      rightScore = lm[PoseLandmarkType.rightShoulder]!.likelihood +
          lm[PoseLandmarkType.rightHip]!.likelihood +
          lm[PoseLandmarkType.rightAnkle]!.likelihood;
    }

    if (hasLeft && leftScore >= rightScore) {
      return {
        'shoulder': lm[PoseLandmarkType.leftShoulder]!,
        'elbow': lm[PoseLandmarkType.leftElbow]!,
        'wrist': lm[PoseLandmarkType.leftWrist]!,
        'hip': lm[PoseLandmarkType.leftHip]!,
        'knee': lm[PoseLandmarkType.leftKnee]!,
        'ankle': lm[PoseLandmarkType.leftAnkle]!,
      };
    } else {
      return {
        'shoulder': lm[PoseLandmarkType.rightShoulder]!,
        'elbow': lm[PoseLandmarkType.rightElbow]!,
        'wrist': lm[PoseLandmarkType.rightWrist]!,
        'hip': lm[PoseLandmarkType.rightHip]!,
        'knee': lm[PoseLandmarkType.rightKnee]!,
        'ankle': lm[PoseLandmarkType.rightAnkle]!,
      };
    }
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final shoulder = lm['shoulder']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;

    // FIX 1: Đảm bảo camera đã nhận diện rõ ràng toàn bộ cơ thể (không bị che lấp chân/hông dẫn đến nội suy sai)
    if (![shoulder, elbow, wrist, hip, knee, ankle]
        .every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    // Cơ thể nằm ngang (khoảng cách X lớn hơn Y)
    double dx = (shoulder.x - ankle.x).abs();
    double dy = (shoulder.y - ankle.y).abs();
    bool isHorizontal = dx > dy * 1.2;
    if (!isHorizontal) return false;

    // Khoảng cách thân
    double torso = calculateDistance(shoulder, hip);
    if (torso == 0) torso = 1;

    // CHỐNG NGOẠI SUY VÀ NẰM BẸP TRÊN SÀN:
    // Cổ tay phải nằm DƯỚI vai một khoảng đáng kể (trục Y hướng xuống nên Y cổ tay > Y vai)
    // Chứng tỏ tay đang chống đẩy thân người lên khỏi mặt đất
    double armVerticalLift = wrist.y - shoulder.y;
    if (armVerticalLift < torso * 0.45) {
      return false;
    }

    if (!_hasFloorSupport(
      shoulder: shoulder,
      wrist: wrist,
      hip: hip,
      ankle: ankle,
      torso: torso,
    )) {
      resultIssues.feedback['System'] =
          'Hãy chống tay trên sàn, không tập plank trên tường.';
      return false;
    }

    double armAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    // FIX 2: Đo góc giữa cánh tay và thân người để tránh trường hợp nằm duỗi thẳng trên sàn (Superman pose)
    double armBodyAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: shoulder, lastPoint: wrist);

    if (armAngle < HighPlankConfig.START_ARM_MIN) return false;
    if (bodyAngle < HighPlankConfig.START_BODY_MIN) return false;
    if (kneeAngle < HighPlankConfig.START_KNEE_MIN) return false;

    // Trong Plank, cánh tay chống đẩy cơ thể lên nên sẽ tạo góc với lưng, không được duỗi song song với cơ thể
    if (armBodyAngle < 40.0 || armBodyAngle > 140.0) return false;

    return true;
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    // Target denominator for scoring, not elapsed hold time.
    logger.pushKey("total_seconds", targetSeconds);
    logger.pushKey("good_seconds", clampedGoodHoldSeconds(targetSeconds));
    logger.pushKey("max_rep", maxHolds);
    logger.pushKey("sagging_seconds", faultHoldSecondsFor('sagging_seconds'));
    logger.pushKey("piked_seconds", faultHoldSecondsFor('piked_seconds'));
    logger.pushKey("elbow_seconds", faultHoldSecondsFor('elbow_seconds'));
    logger.pushKey(
      "total_perfect_time_ms",
      completedHoldingTimeMs + currentPartialHoldingTimeMs,
    );

    logger.pushGoodRepCount();

    if (isDebugModeActive) {
      StringBuffer dump = StringBuffer();
      dump.writeln("=== DIAGNOSTIC LOG (HIGH PLANK) ===");
      dump.writeln("Time(s) | State | S-H-A | S-E-W | HipDev | TorsoTiltDeg");
      for (var log in _diagnosticLog) {
        dump.writeln(
            "${log['time']} | ${log['state']} | ${log['body'].toStringAsFixed(1)} | ${log['arm'].toStringAsFixed(1)} | ${log['dev'].toStringAsFixed(2)} | ${log['torso_tilt'].toStringAsFixed(1)}");
      }
      logger.pushKey("diagnostic_dump", dump.toString());
    }
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'sagging_seconds',
        'piked_seconds',
        'elbow_seconds',
      };

  @override
  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    final lm = _getLandmarks(landmarks);
    if (lm == null) return null;

    final shoulder = lm['shoulder']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;

    // Bổ sung chặn rác dữ liệu: Nếu đang tập mà có vật cản che khuất tay/chân/hông thì tạm bỏ qua frame này
    if (![shoulder, elbow, wrist, hip, knee, ankle]
        .every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }

    scaleFactor = calculateDistance(shoulder, hip);
    if (!_hasFloorSupport(
      shoulder: shoulder,
      wrist: wrist,
      hip: hip,
      ankle: ankle,
      torso: scaleFactor == 0 ? 1 : scaleFactor,
    )) {
      resultIssues.feedback['System'] =
          'Hãy chống tay trên sàn, không tập plank trên tường.';
      interruptActiveHold('wall_guard');
      interruptReArm();
      publishReArmGuidance();
      return null;
    }
    double bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double armAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    final torsoTiltDeg = math.atan2(
          (shoulder.y - hip.y).abs(),
          (shoulder.x - hip.x).abs(),
        ) *
        180 /
        math.pi;

    double expectedHipY = _interpolateY(shoulder, ankle, hip.x);
    double rawDeviation = hip.y - expectedHipY;
    double hipDeviation = scaleFactor > 0 ? rawDeviation / scaleFactor : 0;

    if (isDebugModeActive &&
        (now - _lastDiagnosticTime > 500 || state != previousState)) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'body': bodyAngle,
        'arm': armAngle,
        'dev': hipDeviation,
        'torso_tilt': torsoTiltDeg,
      });
      _lastDiagnosticTime = now;
    }

    _sampledFrame = _HighPlankPoseFrame(
      bodyAngle: bodyAngle,
      armAngle: armAngle,
      hipDeviation: hipDeviation,
    );

    return HoldPoseSample(
      insideOuterEntry: bodyAngle >= HighPlankConfig.OUTER_ENTRY_BODY_MIN &&
          armAngle >= HighPlankConfig.OUTER_ENTRY_ARM_MIN &&
          kneeAngle >= HighPlankConfig.OUTER_ENTRY_KNEE_MIN &&
          hipDeviation < HighPlankConfig.OUTER_ENTRY_SAG_MAX &&
          torsoTiltDeg <= HighPlankConfig.OUTER_ENTRY_TORSO_TILT_MAX,
      outsideOuterExit: bodyAngle < HighPlankConfig.OUTER_EXIT_BODY_MIN ||
          armAngle < HighPlankConfig.OUTER_EXIT_ARM_MIN ||
          kneeAngle < HighPlankConfig.OUTER_EXIT_KNEE_MIN ||
          hipDeviation >= HighPlankConfig.OUTER_EXIT_SAG_MAX ||
          torsoTiltDeg > HighPlankConfig.OUTER_EXIT_TORSO_TILT_MAX,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final sample = _sampledFrame!;
    final ctx = HighPlankRepContext(
      shoulderHipAnkleAngle: sample.bodyAngle,
      shoulderElbowWristAngle: sample.armAngle,
      hipDeviation: sample.hipDeviation,
      scaleFactor: scaleFactor,
      state: phase,
      frameTimestampMs: frameTimestampMs,
      resultIssues: resultIssues,
    );

    for (final metric in _metrics) metric.update(ctx);
    return <String, bool>{
      'sagging_seconds': saggingMetric.isFaultingNow,
      'piked_seconds': pikedHipMetric.isFaultingNow,
      'elbow_seconds': elbowMetric.isFaultingNow,
    };
  }

  @override
  Map<String, FaultRecord> snapshotHoldFaults() => <String, FaultRecord>{
        if (saggingMetric.faults.isNotEmpty)
          'sagging': saggingMetric.faults.first,
        if (elbowMetric.faults.isNotEmpty) 'elbow': elbowMetric.faults.first,
        if (pikedHipMetric.faults.isNotEmpty)
          'piked': pikedHipMetric.faults.first,
      };

  @override
  void resetFormMetrics({required bool countFaults}) {
    for (final metric in _metrics) {
      if (countFaults) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }
  }

  @override
  void onHoldPhaseChanged(
    HoldPhase previous,
    HoldPhase next,
    int nowMs,
  ) {
    for (final metric in _metrics) {
      metric.onStateTransition(previous, next, nowMs);
    }
  }

  @override
  Map<String, dynamic> holdRepLogExtras() => const <String, dynamic>{
        'fault_priorities': <String, int>{
          'sagging': 0,
          'elbow': 1,
          'piked': 2,
        },
      };

  @override
  void onHoldSetReset() {
    _exerciseStartTimeMs = null;
    _sampledFrame = null;
    _diagnosticLog.clear();
    _lastDiagnosticTime = 0;
  }

  double _interpolateY(PoseLandmark p1, PoseLandmark p2, double targetX) {
    if (p1.x == p2.x) return p1.y;
    double t = (targetX - p1.x) / (p2.x - p1.x);
    return p1.y + t * (p2.y - p1.y);
  }

  bool _hasFloorSupport({
    required PoseLandmark shoulder,
    required PoseLandmark wrist,
    required PoseLandmark hip,
    required PoseLandmark ankle,
    required double torso,
  }) {
    final safeTorso = torso <= 0 ? 1.0 : torso;
    final wristAnkleYGap = (wrist.y - ankle.y).abs() / safeTorso;
    final wristBelowShoulder = (wrist.y - shoulder.y) / safeTorso;
    final ankleBelowHip = (ankle.y - hip.y) / safeTorso;

    return wristAnkleYGap <= HighPlankConfig.FLOOR_CONTACT_Y_TOLERANCE &&
        wristBelowShoulder >= HighPlankConfig.WRIST_BELOW_SHOULDER_MIN &&
        ankleBelowHip >= HighPlankConfig.ANKLE_BELOW_HIP_MIN;
  }
}
