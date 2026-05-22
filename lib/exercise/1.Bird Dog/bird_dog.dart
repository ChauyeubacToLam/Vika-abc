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
  static const int MAX_REP = 24;
  static const int TIMEOUT_MS = 90000;

  static const double START_KNEE_MIN = 60;
  static const double START_KNEE_MAX = 120;
  static const double START_ARM_MIN = 60;
  static const double START_ARM_MAX = 120;
  static const double START_TRUNK_HORIZ_MAX = 15;

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

  // Biến Snapshot: Chỉ lưu tay/chân đang thao tác ở đúng đỉnh của rep
  bool? _peakLeftLeg;
  bool? _peakLeftArm;

  BirdDog({this.maxRep = BirdDogConfig.MAX_REP});

  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Bird Dog';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case BirdDogState.neutral: return 'Chuẩn bị';
      case BirdDogState.extending: return 'Đang duỗi';
      case BirdDogState.hold_extended: return 'Giữ 5s!';
      case BirdDogState.returning: return 'Thu về';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) => null;

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
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

    bool isLeftValid = checkSide(landmarks[PoseLandmarkType.leftShoulder], landmarks[PoseLandmarkType.leftHip], landmarks[PoseLandmarkType.leftKnee], landmarks[PoseLandmarkType.leftAnkle], landmarks[PoseLandmarkType.leftWrist]);
    bool isRightValid = checkSide(landmarks[PoseLandmarkType.rightShoulder], landmarks[PoseLandmarkType.rightHip], landmarks[PoseLandmarkType.rightKnee], landmarks[PoseLandmarkType.rightAnkle], landmarks[PoseLandmarkType.rightWrist]);

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
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    if (now - _exerciseStartTimeMs! >= BirdDogConfig.TIMEOUT_MS) {
      if (!_timeoutReached) {
        _timeoutReached = true;
        resultIssues.feedback['Result'] = 'Hết thời gian!';
        resultIssues.addInstruction('TIMEOUT', 'Status', 'Đang lưu kết quả...');
      }
      return;
    }

    // --- XÁC ĐỊNH CHÂN (Live Data) ---
    final leftKneeAngle = calculateAngleNormalized(firstPoint: landmarks[PoseLandmarkType.leftHip]!, midPoint: landmarks[PoseLandmarkType.leftKnee]!, lastPoint: landmarks[PoseLandmarkType.leftAnkle]!);
    final rightKneeAngle = calculateAngleNormalized(firstPoint: landmarks[PoseLandmarkType.rightHip]!, midPoint: landmarks[PoseLandmarkType.rightKnee]!, lastPoint: landmarks[PoseLandmarkType.rightAnkle]!);

    // --- XÁC ĐỊNH TAY (Live Data - Tính từ Hông lên Cổ tay để phân biệt rõ rệt) ---
    final leftArmAngle = calculateAngleNormalized(firstPoint: landmarks[PoseLandmarkType.leftHip]!, midPoint: landmarks[PoseLandmarkType.leftShoulder]!, lastPoint: landmarks[PoseLandmarkType.leftWrist]!);
    final rightArmAngle = calculateAngleNormalized(firstPoint: landmarks[PoseLandmarkType.rightHip]!, midPoint: landmarks[PoseLandmarkType.rightShoulder]!, lastPoint: landmarks[PoseLandmarkType.rightWrist]!);

    bool currentLeftLeg = leftKneeAngle > rightKneeAngle;
    bool currentLeftArm = leftArmAngle > rightArmAngle;

    double activeKneeAngle = currentLeftLeg ? leftKneeAngle : rightKneeAngle;
    double activeArmAngle = currentLeftArm ? leftArmAngle : rightArmAngle;
    double nonActiveKneeAngle = currentLeftLeg ? rightKneeAngle : leftKneeAngle;

    // --- SNAPSHOT DATA (Chỉ chốt số liệu tay chân khi đang ở đỉnh rep) ---
    if (state == BirdDogState.hold_extended) {
      _peakLeftLeg = currentLeftLeg;
      _peakLeftArm = currentLeftArm;
    }

    // --- EVALUATION DATA (Dữ liệu chống nhiễu dùng để chấm điểm) ---
    // Nếu đang thu về hoặc chốt rep, BẮT BUỘC dùng data snapshot ở đỉnh để đánh giá
    bool evalLeftLeg = (state == BirdDogState.returning || state == BirdDogState.neutral) && _peakLeftLeg != null 
        ? _peakLeftLeg! 
        : currentLeftLeg;
        
    bool evalLeftArm = (state == BirdDogState.returning || state == BirdDogState.neutral) && _peakLeftArm != null 
        ? _peakLeftArm! 
        : currentLeftArm;

    // --- FIX LỖI CHỐNG ĐẨY (PUSH-UP BLOCKER) ---
    if (nonActiveKneeAngle > 130 && state != BirdDogState.neutral) {
      _transitionState(BirdDogState.neutral, now);
      _peakLeftLeg = null; // Xóa snapshot
      _peakLeftArm = null;
      resultIssues.feedback['Error'] = 'Sai tư thế (Đang Plank)';
      resultIssues.addInstruction('BLOCK', 'Error', 'Hạ hai gối xuống sàn!');
      return;
    }

    bool isSameSide = (evalLeftLeg == evalLeftArm);

    final hip = landmarks[evalLeftLeg ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip]!;
    final ankle = landmarks[evalLeftLeg ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle]!;
    final shoulder = landmarks[evalLeftArm ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder]!;
    final wrist = landmarks[evalLeftArm ? PoseLandmarkType.leftWrist : PoseLandmarkType.rightWrist]!;
    final ear = landmarks[evalLeftArm ? PoseLandmarkType.leftEar : PoseLandmarkType.rightEar] ?? landmarks[PoseLandmarkType.leftEar]!;

    scaleFactor = calculateDistance(shoulder, hip);

    double shaAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double trunkHoriz = _calcHorizontalAngle(shoulder, hip);
    double armHoriz = _calcHorizontalAngle(shoulder, wrist);
    double legHoriz = _calcHorizontalAngle(hip, ankle);

    final ctx = BirdDogRepContext(
      activeKneeAngle: activeKneeAngle,
      nonActiveKneeAngle: nonActiveKneeAngle,
      activeArmAngle: activeArmAngle,
      shoulderHipAnkleAngle: shaAngle,
      trunkHorizontalAngle: trunkHoriz,
      activeArmHorizontalAngle: armHoriz,
      activeLegHorizontalAngle: legHoriz,
      hipY: hip.y,
      earY: ear.y,
      shoulderY: shoulder.y,
      scaleFactor: scaleFactor,
      isLeftLegActive: evalLeftLeg,
      isSameSide: isSameSide,
      state: state,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    _updateStateMachine(activeKneeAngle, activeArmAngle, now);

    // --- HIỆN ĐỒNG HỒ ĐẾM NGƯỢC 5S CHO UI ---
    if (state == BirdDogState.hold_extended && tempoMetric.holdStartMs != null) {
      double elapsed = (now - tempoMetric.holdStartMs!) / 1000.0;
      double progress = (elapsed / 5.0).clamp(0.0, 1.0);
      resultIssues.feedback['progress'] = progress.toStringAsFixed(2);
      
      if (progress < 1.0) {
        resultIssues.addInstruction('HOLD', 'Timer', 'Giữ: ${(progress * 100).toInt()}%');
      } else {
        resultIssues.addInstruction('HOLD', 'Timer', 'Tốt! Thu về');
      }
    } else {
      resultIssues.feedback['progress'] = '0.0';
    }

    if (state == BirdDogState.neutral && previousState == BirdDogState.returning) {
      _completeRep(ctx);
      previousState = BirdDogState.neutral;
      return;
    }

    if (state != BirdDogState.neutral) {
      for (final metric in _metrics) metric.update(ctx);
    }
  }

  void _updateStateMachine(double kneeAngle, double armAngle, int now) {
    if (state == BirdDogState.neutral && kneeAngle > BirdDogConfig.EXTENDING_KNEE_START) {
      _transitionState(BirdDogState.extending, now);
    } else if (_holdDebouncer.update(state == BirdDogState.extending &&
        kneeAngle > BirdDogConfig.HOLD_KNEE_THRESHOLD &&
        armAngle > BirdDogConfig.HOLD_ARM_THRESHOLD)) {
      _transitionState(BirdDogState.hold_extended, now);
    } else if (state == BirdDogState.extending && kneeAngle < BirdDogConfig.NEUTRAL_KNEE_THRESHOLD) {
      // FIX DEADLOCK: Đang giơ lên mà rớt xuống luôn thì clear về chuẩn bị
      _transitionState(BirdDogState.neutral, now);
      _peakLeftLeg = null;
      _peakLeftArm = null;
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
    if (ctx.isSameSide) {
      resultIssues.feedback['Result'] = 'Cùng tay chân (Ko đếm)';
      resultIssues.addInstruction('REJECTED', 'Error', 'Hãy đưa tay nọ chân kia!');
      _resetRepState();
      return;
    }

    if (tempoMetric.lastLegWasLeft == ctx.isLeftLegActive) {
      resultIssues.feedback['Result'] = 'Chưa đổi bên (Ko đếm)';
      resultIssues.addInstruction('REJECTED', 'Error', 'Hãy luân phiên đổi bên!');
      _resetRepState();
      return;
    }

    repCount++;
    tempoMetric.markLegUsed(ctx.isLeftLegActive);
    tempoMetric.evaluateRep(ctx);
    
    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);

    correctForm = !allFaults.any((f) => f.affectsForm);
    if (!correctForm) resultIssues.feedback['Result'] = 'Sai Form';

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "hold_time": tempoMetric.holdDuration ?? 0,
      "fault_types": allFaults.map((e) => e.type).toSet().toList()
    }));

    _resetRepState();
  }

  void _resetRepState() {
    correctForm = true;
    for (var metric in _metrics) metric.resetAndCountFault();
    // Xóa snapshot để chu trình sau nhận diện lại từ đầu
    _peakLeftLeg = null;
    _peakLeftArm = null;
  }

  double _calcHorizontalAngle(PoseLandmark p1, PoseLandmark p2) {
    double dy = (p2.y - p1.y).abs();
    double dx = (p2.x - p1.x).abs();
    if (dx == 0) return 90.0;
    return (dy / dx) * (180 / 3.14159);
  }
}