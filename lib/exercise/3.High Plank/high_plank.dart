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

  // State Transition Thresholds
  static const double HOLDING_BODY_THRESHOLD = 165.0;
  static const double HOLDING_ARM_THRESHOLD = 160.0;
  
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

  final Debouncer _holdingDebouncer = Debouncer(requiredFrames: 4); // Cần giữ form 4 frame liên tục
  final Debouncer _droppingDebouncer = Debouncer(requiredFrames: 2);

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
    return null; // No specific safety check for this exercise yet.
  }

  // NOTE UI: Cần hiển thị Pop-up Safety Gate (Đau cổ tay/thắt lưng) trước.
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
    logger.pushKey("sagging_fails_count", saggingMetric.faultsCount);
    logger.pushKey("piked_fails_count", pikedHipMetric.faultsCount);
    logger.pushKey("elbow_fails_count", elbowMetric.faultsCount);
    logger.pushKey("total_perfect_time_ms", timerMetric.totalHoldingTimeMs);
    
    // Ghi 1 rep giả lập cho toàn bộ set để tương thích hệ thống Report
    logger.addRepLog(RepLog(correctForm: saggingMetric.faultsCount == 0, repNumber: 1, data: {
       "perfect_hold_time": timerMetric.totalHoldingTimeMs / 1000.0,
    }));
    logger.pushGoodRepCount(); // Tính là 1 rep tốt nếu không sụt hông
    
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

    final shoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final elbow = landmarks[PoseLandmarkType.leftElbow]!;
    final wrist = landmarks[PoseLandmarkType.leftWrist]!;
    final hip = landmarks[PoseLandmarkType.leftHip]!;
    final ankle = landmarks[PoseLandmarkType.leftAnkle]!;

    scaleFactor = calculateDistance(shoulder, hip);

    double bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double armAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    
    // Tính khoảng cách nội suy Y của Hông so với đường Vai-Gót
    double expectedHipY = _interpolateY(shoulder, ankle, hip.x);
    double rawDeviation = hip.y - expectedHipY;
    double hipDeviation = scaleFactor > 0 ? rawDeviation / scaleFactor : 0; // > 0: Sagging, < 0: Piked

    final ctx = HighPlankRepContext(
      shoulderHipAnkleAngle: bodyAngle,
      shoulderElbowWristAngle: armAngle,
      hipDeviation: hipDeviation,
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

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

    for (final metric in _metrics) metric.update(ctx);
    
    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double bodyAngle, double armAngle, double hipDev, int now) {
    bool isFormGood = bodyAngle >= HighPlankConfig.HOLDING_BODY_THRESHOLD && 
                      armAngle >= HighPlankConfig.HOLDING_ARM_THRESHOLD &&
                      hipDev < HighPlankConfig.DROPPING_SAG_DEVIATION;

    if (state == HighPlankState.setup || state == HighPlankState.dropping) {
      if (_holdingDebouncer.update(isFormGood)) {
        _transitionState(HighPlankState.holding, now);
      }
    } else if (state == HighPlankState.holding) {
      if (_droppingDebouncer.update(!isFormGood)) {
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
    if (p1.x == p2.x) return p1.y; // Tránh chia cho 0
    double t = (targetX - p1.x) / (p2.x - p1.x);
    return p1.y + t * (p2.y - p1.y);
  }
}