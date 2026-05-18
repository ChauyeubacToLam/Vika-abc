// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';

import 'metrics/high_plank_metric_base.dart';
import 'metrics/sagging_metric.dart';
import 'metrics/piked_hip_metric.dart';
import 'metrics/elbow_metric.dart';
import 'metrics/timer_metric.dart';

class HighPlankConfig {
  static const int TARGET_TIME_MS = 30000; // 30s form chuẩn
  static const int TIMEOUT_MS = 90000; // 90s timeout

  // Start Position (Tay duỗi, lưng thẳng)
  static const double START_ARM_MIN = 160.0;
  static const double START_BODY_MIN = 165.0;

  // State Transition Thresholds — SETUP/DROPPING -> HOLDING (ngưỡng vào, chặt hơn)
  static const double HOLDING_BODY_THRESHOLD = 165.0;
  static const double HOLDING_ARM_THRESHOLD = 160.0;
  // FIX Bug 2: Ngưỡng vào HOLDING cho sagging phải chặt hơn ngưỡng ra (0.05 < 0.08)
  // để tạo hysteresis band giống arm/body angle, tránh rung state.
  static const double HOLDING_SAG_DEVIATION = 0.05;

  // State Transition Thresholds — HOLDING -> DROPPING (ngưỡng ra, lỏng hơn = tạo hysteresis band)
  static const double DROPPING_PIKE_ANGLE = 155.0;
  static const double DROPPING_ARM_ANGLE = 150.0;
  static const double DROPPING_SAG_DEVIATION = 0.08; // Sụt hông > 8% chiều dài lưng
}

class HighPlank extends ExerciseBase {
  HighPlankState state = HighPlankState.setup;
  HighPlankState previousState = HighPlankState.setup;

  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;

  // DIAGNOSTIC LOG
  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final SaggingMetric saggingMetric = SaggingMetric();
  final PikedHipMetric pikedHipMetric = PikedHipMetric();
  final ElbowMetric elbowMetric = ElbowMetric();
  final TimerMetric timerMetric = TimerMetric();

  late final List<HighPlankMetricBase> _metrics = [
    saggingMetric, pikedHipMetric, elbowMetric, timerMetric
  ];

  final Debouncer _holdingDebouncer = Debouncer(requiredFrames: 4);
  final Debouncer _droppingDebouncer = Debouncer(requiredFrames: 2);

  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'High Plank';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case HighPlankState.setup: return 'Chuẩn bị form...';
      case HighPlankState.holding: return 'Giữ vững! Đang đếm giờ';
      case HighPlankState.dropping: return 'Mất form! Sửa lại ngay';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];

    if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null) return false;

    double armAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);

    if (armAngle < HighPlankConfig.START_ARM_MIN) return false;
    if (bodyAngle < HighPlankConfig.START_BODY_MIN) return false;

    return true;
  }

  @override
  bool requestStop() => _timeoutReached || timerMetric.totalHoldingTimeMs >= HighPlankConfig.TARGET_TIME_MS;

  @override
  void onSetComplete() {
    logger.pushKey("sagging_fails_count", saggingMetric.faults.length);
    logger.pushKey("piked_fails_count", pikedHipMetric.faults.length);
    logger.pushKey("elbow_fails_count", elbowMetric.faults.length);
    logger.pushKey("total_perfect_time_ms", timerMetric.totalHoldingTimeMs);

    logger.addRepLog(RepLog(correctForm: saggingMetric.faults.isEmpty, repNumber: 1, data: {
      "perfect_hold_time": timerMetric.totalHoldingTimeMs / 1000.0,
    }));

    if (saggingMetric.faults.isEmpty) logger.pushGoodRepCount();

    StringBuffer dump = StringBuffer();
    dump.writeln("=== DIAGNOSTIC LOG (HIGH PLANK) ===");
    dump.writeln("Time(s) | State | S-H-A | S-E-W | HipDev");
    for (var log in _diagnosticLog) {
      dump.writeln("${log['time']} | ${log['state']} | ${log['body'].toStringAsFixed(1)} | ${log['arm'].toStringAsFixed(1)} | ${log['dev'].toStringAsFixed(2)}");
    }
    logger.pushKey("diagnostic_dump", dump.toString());
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    if (now - _exerciseStartTimeMs! >= HighPlankConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return;
    }

    // FIX Bug 1: Null-check trước khi force-unwrap.
    // ML Kit có thể mất điểm neo bất kỳ lúc nào → không check = crash.
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];

    if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null) return;

    scaleFactor = calculateDistance(shoulder, hip);

    double bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double armAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);

    double expectedHipY = _interpolateY(shoulder, ankle, hip.x);
    double rawDeviation = hip.y - expectedHipY;
    double hipDeviation = scaleFactor > 0 ? rawDeviation / scaleFactor : 0;

    if (now - _lastDiagnosticTime > 500 || state != previousState) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'body': bodyAngle,
        'arm': armAngle,
        'dev': hipDeviation
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(bodyAngle, armAngle, hipDeviation, now);

    final ctx = HighPlankRepContext(
      shoulderHipAnkleAngle: bodyAngle,
      shoulderElbowWristAngle: armAngle,
      hipDeviation: hipDeviation,
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    for (final metric in _metrics) metric.update(ctx);

    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double bodyAngle, double armAngle, double hipDev, int now) {
    // FIX Bug 2: Dùng HOLDING_SAG_DEVIATION (0.05) cho ngưỡng vào — chặt hơn ngưỡng ra (0.08).
    // Trước đây cả hai đều dùng 0.08 → không có hysteresis → rung state khi hipDev dao động gần 0.08.
    bool isFormGoodToHold = bodyAngle >= HighPlankConfig.HOLDING_BODY_THRESHOLD &&
                            armAngle >= HighPlankConfig.HOLDING_ARM_THRESHOLD &&
                            hipDev < HighPlankConfig.HOLDING_SAG_DEVIATION;

    bool isFormBadToDrop = bodyAngle < HighPlankConfig.DROPPING_PIKE_ANGLE ||
                           armAngle < HighPlankConfig.DROPPING_ARM_ANGLE ||
                           hipDev >= HighPlankConfig.DROPPING_SAG_DEVIATION;

    if (state == HighPlankState.setup || state == HighPlankState.dropping) {
      if (_holdingDebouncer.update(isFormGoodToHold)) {
        _transitionState(HighPlankState.holding, now);
      }
    } else if (state == HighPlankState.holding) {
      if (_droppingDebouncer.update(isFormBadToDrop)) {
        _transitionState(HighPlankState.dropping, now);
      }
    }
  }

  void _transitionState(HighPlankState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics) metric.onStateTransition(previousState, newState, now);
  }

  double _interpolateY(PoseLandmark p1, PoseLandmark p2, double targetX) {
    if (p1.x == p2.x) return p1.y;
    double t = (targetX - p1.x) / (p2.x - p1.x);
    return p1.y + t * (p2.y - p1.y);
  }
}