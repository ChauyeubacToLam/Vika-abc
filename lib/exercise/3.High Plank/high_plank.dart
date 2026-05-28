// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../../pose/vika_image_orientation.dart';
import '../exercise_base.dart';
import 'metrics/high_plank_metric_base.dart';
import 'metrics/sagging_metric.dart';
import 'metrics/piked_hip_metric.dart';
import 'metrics/elbow_metric.dart';
import 'metrics/timer_metric.dart';

class HighPlankConfig {
  static const int TARGET_TIME_MS = 30000; // 30s form chuẩn
  static const int TIMEOUT_MS = 90000; // 90s timeout

  // Start Position (Tay duỗi, lưng thẳng, gối thẳng)
  static const double START_ARM_MIN = 150.0;
  static const double START_BODY_MIN = 160.0;
  static const double START_KNEE_MIN = 145.0;

  // State Transition Thresholds
  // SETUP/DROPPING -> HOLDING (ngưỡng vào, chuẩn)
  static const double HOLDING_BODY_THRESHOLD = 160.0;
  static const double HOLDING_ARM_THRESHOLD = 150.0;
  static const double HOLDING_KNEE_THRESHOLD = 145.0;
  static const double HOLDING_SAG_DEVIATION = 0.08;

  // State Transition Thresholds
  // HOLDING -> DROPPING (ngưỡng ra, lỏng hơn = tạo hysteresis band)
  static const double DROPPING_PIKE_ANGLE = 150.0;
  static const double DROPPING_ARM_ANGLE = 140.0;
  static const double DROPPING_KNEE_ANGLE = 135.0; // Gối cong quá
  static const double DROPPING_SAG_DEVIATION = 0.12; // Sụp hông > 12% chiều dài
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

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> lm) {
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
    if (shoulder.likelihood < 0.6 || elbow.likelihood < 0.6 || wrist.likelihood < 0.6 ||
        hip.likelihood < 0.6 || knee.likelihood < 0.6 || ankle.likelihood < 0.6) {
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

    double armAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double kneeAngle = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    
    // FIX 2: Đo góc giữa cánh tay và thân người để tránh trường hợp nằm duỗi thẳng trên sàn (Superman pose)
    double armBodyAngle = calculateAngleNormalized(firstPoint: hip, midPoint: shoulder, lastPoint: wrist);

    if (armAngle < HighPlankConfig.START_ARM_MIN) return false;
    if (bodyAngle < HighPlankConfig.START_BODY_MIN) return false;
    if (kneeAngle < HighPlankConfig.START_KNEE_MIN) return false;

    // Trong Plank, cánh tay chống đẩy cơ thể lên nên sẽ tạo góc với lưng, không được duỗi song song với cơ thể
    if (armBodyAngle < 40.0 || armBodyAngle > 140.0) return false;

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

    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    final shoulder = lm['shoulder']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;

    // Bổ sung chặn rác dữ liệu: Nếu đang tập mà có vật cản che khuất tay/chân/hông thì tạm bỏ qua frame này
    if (shoulder.likelihood < 0.5 || elbow.likelihood < 0.5 || wrist.likelihood < 0.5 ||
        hip.likelihood < 0.5 || knee.likelihood < 0.5 || ankle.likelihood < 0.5) {
      return;
    }

    scaleFactor = calculateDistance(shoulder, hip);
    double bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double armAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double kneeAngle = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);

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

    _updateStateMachine(bodyAngle, armAngle, hipDeviation, kneeAngle, now);

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

    repCount = timerMetric.totalHoldingTimeMs ~/ 1000;

    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double bodyAngle, double armAngle, double hipDev, double kneeAngle, int now) {
    bool isFormGoodToHold = bodyAngle >= HighPlankConfig.HOLDING_BODY_THRESHOLD &&
                            armAngle >= HighPlankConfig.HOLDING_ARM_THRESHOLD &&
                            kneeAngle >= HighPlankConfig.HOLDING_KNEE_THRESHOLD &&
                            hipDev < HighPlankConfig.HOLDING_SAG_DEVIATION;

    bool isFormBadToDrop = bodyAngle < HighPlankConfig.DROPPING_PIKE_ANGLE ||
                           armAngle < HighPlankConfig.DROPPING_ARM_ANGLE ||
                           kneeAngle < HighPlankConfig.DROPPING_KNEE_ANGLE ||
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