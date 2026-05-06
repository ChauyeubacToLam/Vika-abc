// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/bird_dog_metric_base.dart';
import 'metrics/lumbar_extension_metric.dart';
import 'metrics/alignment_metric.dart';
import 'metrics/trunk_stability_metric.dart';
import 'metrics/tempo_metric.dart';

class BirdDogConfig {
  static const int MAX_REP = 24; // 12 mỗi bên
  static const int TIMEOUT_MS = 90000; // 90 giây timeout

  // Start Position Limits
  static const double START_KNEE_MIN = 60;
  static const double START_KNEE_MAX = 120;
  static const double START_ARM_MIN = 60;
  static const double START_ARM_MAX = 120;
  static const double START_TRUNK_HORIZ_MAX = 15; // Cập nhật theo chuẩn < 15 độ

  // State Transition Thresholds
  static const double EXTENDING_KNEE_START = 120;
  static const double HOLD_KNEE_THRESHOLD = 160;
  static const double HOLD_ARM_THRESHOLD = 150;
  static const double RETURNING_KNEE_THRESHOLD = 150;
  static const double NEUTRAL_KNEE_THRESHOLD = 110;
}

class BirdDog extends ExerciseBase {
  final int maxRep;
  BirdDogState state = BirdDogState.neutral;
  BirdDogState previousState = BirdDogState.neutral;

  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;

  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final LumbarExtensionMetric lumbarMetric = LumbarExtensionMetric();
  final AlignmentMetric alignmentMetric = AlignmentMetric();
  final TrunkStabilityMetric trunkMetric = TrunkStabilityMetric();
  final TempoMetric tempoMetric = TempoMetric();

  late final List<BirdDogMetricBase> _metrics = [
    lumbarMetric,
    alignmentMetric,
    trunkMetric,
    tempoMetric
  ];

  final Debouncer _holdDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _returningDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _neutralDebouncer = Debouncer(requiredFrames: 3);

  BirdDog({this.maxRep = BirdDogConfig.MAX_REP});

  @override
  String get exerciseName => 'Bird Dog';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case BirdDogState.neutral:
        return 'Chuẩn bị';
      case BirdDogState.extending:
        return 'Đang duỗi';
      case BirdDogState.hold_extended:
        return 'Giữ thẳng!';
      case BirdDogState.returning:
        return 'Thu về';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return null; // Quản lý qua Safety Gate UI
  }

@override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Hàm phụ check góc cho từng bên
    bool checkSide(PoseLandmark? shoulder, PoseLandmark? hip, PoseLandmark? knee, PoseLandmark? ankle, PoseLandmark? wrist) {
      if (shoulder == null || hip == null || knee == null || ankle == null || wrist == null) return false;

      double kneeAngle = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);
      double armAngle = calculateAngleNormalized(firstPoint: hip, midPoint: shoulder, lastPoint: wrist);
      double trunkHoriz = _calcHorizontalAngle(shoulder, hip);

      if (kneeAngle < BirdDogConfig.START_KNEE_MIN || kneeAngle > BirdDogConfig.START_KNEE_MAX) return false;
      if (armAngle < BirdDogConfig.START_ARM_MIN || armAngle > BirdDogConfig.START_ARM_MAX) return false; 
      if (trunkHoriz > BirdDogConfig.START_TRUNK_HORIZ_MAX) return false;

      return true;
    }

    // Kiểm tra bên trái
    bool isLeftValid = checkSide(
      landmarks[PoseLandmarkType.leftShoulder], landmarks[PoseLandmarkType.leftHip],
      landmarks[PoseLandmarkType.leftKnee], landmarks[PoseLandmarkType.leftAnkle], landmarks[PoseLandmarkType.leftWrist]
    );

    // Kiểm tra bên phải
    bool isRightValid = checkSide(
      landmarks[PoseLandmarkType.rightShoulder], landmarks[PoseLandmarkType.rightHip],
      landmarks[PoseLandmarkType.rightKnee], landmarks[PoseLandmarkType.rightAnkle], landmarks[PoseLandmarkType.rightWrist]
    );

    // Chỉ cần 1 trong 2 bên hướng về camera và chuẩn form là OK!
    return isLeftValid || isRightValid;
  }

  @override
  bool requestStop() {
    if (_timeoutReached) return true;
    return repCount >= maxRep;
  }

  @override
  void onSetComplete() {
    logger.pushKey("lumbar_fails_count", lumbarMetric.faultsCount);
    logger.pushKey("alignment_fails_count", alignmentMetric.faultsCount);
    logger.pushKey("trunk_fails_count", trunkMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushGoodRepCount();

    StringBuffer dump = StringBuffer();
    dump.writeln("=== DIAGNOSTIC LOG (BIRD DOG) ===");
    dump.writeln("Time(s) | State | Knee | Arm | S-H-A (Võng) | HipY");
    for (var log in _diagnosticLog) {
      dump.writeln("${log['time']} | ${log['state']} | ${log['knee'].toStringAsFixed(1)} | ${log['arm'].toStringAsFixed(1)} | ${log['sha'].toStringAsFixed(1)} | ${log['hipY'].toStringAsFixed(1)}");
    }
    logger.pushKey("diagnostic_dump", dump.toString());
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

if (now - _exerciseStartTimeMs! >= BirdDogConfig.TIMEOUT_MS) {
      if (!_timeoutReached) {
        _timeoutReached = true;
        // Bơm data vào resultIssues để ép giao diện UI (Flutter) nhận diện sự thay đổi và setState
        resultIssues.feedback['Result'] = 'Hết thời gian!';
        resultIssues.addInstruction('TIMEOUT', 'Status', 'Đang lưu kết quả...');
      }
      return;
    }

    final leftKneeAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.leftHip]!,
        midPoint: landmarks[PoseLandmarkType.leftKnee]!,
        lastPoint: landmarks[PoseLandmarkType.leftAnkle]!);
    final rightKneeAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.rightHip]!,
        midPoint: landmarks[PoseLandmarkType.rightKnee]!,
        lastPoint: landmarks[PoseLandmarkType.rightAnkle]!);
    
    // Xác định bên đang hoạt động (dựa trên chân duỗi)
    bool useLeftLeg = leftKneeAngle > rightKneeAngle;

    // LẤY ĐIỂM CHÂN (Cùng bên đang duỗi) - Bỏ biến knee vì không xài đến
    final hip = landmarks[useLeftLeg ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip]!;
    final ankle = landmarks[useLeftLeg ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle]!;
    
    // LẤY ĐIỂM TAY ĐỐI DIỆN (Contralateral Tracking)
    final shoulder = landmarks[useLeftLeg ? PoseLandmarkType.rightShoulder : PoseLandmarkType.leftShoulder]!;
    final elbow = landmarks[useLeftLeg ? PoseLandmarkType.rightElbow : PoseLandmarkType.leftElbow]!;
    final wrist = landmarks[useLeftLeg ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist]!;
    
    scaleFactor = calculateDistance(shoulder, hip);

    double activeKneeAngle = useLeftLeg ? leftKneeAngle : rightKneeAngle;
    double activeArmAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double shaAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    
    double trunkHoriz = _calcHorizontalAngle(shoulder, hip);
    double armHoriz = _calcHorizontalAngle(shoulder, wrist);
    double legHoriz = _calcHorizontalAngle(hip, ankle);

    final ctx = BirdDogRepContext(
      activeKneeAngle: activeKneeAngle,
      activeArmAngle: activeArmAngle,
      shoulderHipAnkleAngle: shaAngle,
      trunkHorizontalAngle: trunkHoriz,
      activeArmHorizontalAngle: armHoriz,
      activeLegHorizontalAngle: legHoriz,
      hipY: hip.y,
      scaleFactor: scaleFactor,
      isLeftLegActive: useLeftLeg, // Cờ kiểm tra luân phiên
      state: state,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    if (now - _lastDiagnosticTime > 500 || state != previousState) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'knee': activeKneeAngle,
        'arm': activeArmAngle,
        'sha': shaAngle,
        'hipY': hip.y
      });
      _lastDiagnosticTime = now;
    }

_updateStateMachine(activeKneeAngle, activeArmAngle, now);

    if (state == BirdDogState.neutral && previousState == BirdDogState.returning) {
      _completeRep(ctx);
      previousState = BirdDogState.neutral; // <--- THÊM DÒNG NÀY ĐỂ RESET STATE
      return;
    }

    if (state != BirdDogState.neutral) {
      for (final metric in _metrics) metric.update(ctx);
    }

    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double kneeAngle, double armAngle, int now) {
    if (state == BirdDogState.neutral && kneeAngle > BirdDogConfig.EXTENDING_KNEE_START) {
      _transitionState(BirdDogState.extending, now);
    } else if (_holdDebouncer.update(state == BirdDogState.extending &&
        kneeAngle > BirdDogConfig.HOLD_KNEE_THRESHOLD &&
        armAngle > BirdDogConfig.HOLD_ARM_THRESHOLD)) {
      _transitionState(BirdDogState.hold_extended, now);
    } else if (_returningDebouncer.update(state == BirdDogState.hold_extended &&
        kneeAngle < BirdDogConfig.RETURNING_KNEE_THRESHOLD)) {
      _transitionState(BirdDogState.returning, now);
    } else if (_neutralDebouncer.update(state == BirdDogState.returning &&
        kneeAngle < BirdDogConfig.NEUTRAL_KNEE_THRESHOLD)) {
      _transitionState(BirdDogState.neutral, now);
    }
  }

  void _transitionState(BirdDogState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics) metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(BirdDogRepContext ctx) {
    repCount++;
    tempoMetric.evaluateRep(ctx);
    
    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);

    correctForm = !allFaults.any((f) => f.affectsForm);
    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "hold_time": tempoMetric.holdDuration ?? 0,
      "fault_types": allFaults.map((e) => e.type).toSet().toList()
    }));

    correctForm = true;
    for (var metric in _metrics) metric.resetAndCountFault();
  }

  double _calcHorizontalAngle(PoseLandmark p1, PoseLandmark p2) {
    double dy = (p2.y - p1.y).abs();
    double dx = (p2.x - p1.x).abs();
    if (dx == 0) return 90.0;
    return (dy / dx) * (180 / 3.14159);
  }
}