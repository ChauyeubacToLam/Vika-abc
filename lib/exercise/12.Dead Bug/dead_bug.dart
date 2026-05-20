// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';

import 'metrics/dead_bug_metric_base.dart';
import 'metrics/anti_extension_metric.dart';
import 'metrics/coordination_metric.dart';
import 'metrics/stable_limbs_metric.dart';
import 'metrics/tempo_metric.dart';

class DeadBugConfig {
  static const int MAX_REP = 20; // 10 rep mỗi bên
  static const int TIMEOUT_MS = 90000; // 90s timeout
  
  // Start Position (Tay chân dựng thẳng vuông góc sàn)
  static const double START_ANGLE_MIN = 70.0;
  static const double START_ANGLE_MAX = 110.0;

  // State Transition Thresholds (Dựa vào góc mở của chi đang hạ xuống)
  static const double EXTENDING_THRESHOLD = 120.0;
  static const double HOLD_THRESHOLD = 160.0; // Gần sát sàn
  static const double RETURNING_THRESHOLD = 150.0;
  static const double SETUP_THRESHOLD = 110.0;
}

class DeadBug extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  DeadBugState state = DeadBugState.setup;
  DeadBugState previousState = DeadBugState.setup;
  
  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;
  
  // DIAGNOSTIC LOG
  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;
  
  final AntiExtensionMetric antiExtensionMetric = AntiExtensionMetric();
  final CoordinationMetric coordinationMetric = CoordinationMetric();
  final StableLimbsMetric stableLimbsMetric = StableLimbsMetric();
  final TempoMetric tempoMetric = TempoMetric();
  
  late final List<DeadBugMetricBase> _metrics = [
    antiExtensionMetric, coordinationMetric, stableLimbsMetric, tempoMetric
  ];

  final Debouncer _extendingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _holdDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _returningDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _setupDebouncer = Debouncer(requiredFrames: 2);

  DeadBug({this.maxRep = DeadBugConfig.MAX_REP});

  @override
  String get exerciseName => 'Dead Bug';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case DeadBugState.setup: return 'Chuẩn bị (Góc 90 độ)';
      case DeadBugState.extending: return 'Từ từ duỗi tay/chân';
      case DeadBugState.hold: return 'Giữ tĩnh!';
      case DeadBugState.returning: return 'Thu về';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null; // No specific safety checks yet
  }

  // NOTE UI: Cần hiển thị Pop-up Safety Gate "Đau thắt lưng cấp tính không?" trước.
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final lHip = landmarks[PoseLandmarkType.leftHip];
    final rHip = landmarks[PoseLandmarkType.rightHip];
    final lWrist = landmarks[PoseLandmarkType.leftWrist];
    final rWrist = landmarks[PoseLandmarkType.rightWrist];
    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];
    
    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null ||
        lWrist == null || rWrist == null || lKnee == null || rKnee == null) return false;

    double lArm = calculateAngleNormalized(firstPoint: lHip, midPoint: lShoulder, lastPoint: lWrist);
    double rArm = calculateAngleNormalized(firstPoint: rHip, midPoint: rShoulder, lastPoint: rWrist);
    double lLeg = calculateAngleNormalized(firstPoint: lShoulder, midPoint: lHip, lastPoint: lKnee);
    double rLeg = calculateAngleNormalized(firstPoint: rShoulder, midPoint: rHip, lastPoint: rKnee);

    double avgArm = (lArm + rArm) / 2;
    double avgLeg = (lLeg + rLeg) / 2;

    if (avgArm < DeadBugConfig.START_ANGLE_MIN || avgArm > DeadBugConfig.START_ANGLE_MAX) return false;
    if (avgLeg < DeadBugConfig.START_ANGLE_MIN || avgLeg > DeadBugConfig.START_ANGLE_MAX) return false;

    return true; 
  }

  @override
  bool requestStop() => _timeoutReached || repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("anti_extension_fails_count", antiExtensionMetric.faultsCount);
    logger.pushKey("coordination_fails_count", coordinationMetric.faultsCount);
    logger.pushKey("stable_limbs_fails_count", stableLimbsMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushGoodRepCount();
    
    StringBuffer dump = StringBuffer();
    dump.writeln("=== DIAGNOSTIC LOG (DEAD BUG) ===");
    dump.writeln("Time | State | MaxExt | L_Arm | R_Arm | L_Hip | R_Hip | HipY");
    for (var log in _diagnosticLog) {
       dump.writeln("${log['time']} | ${log['state']} | ${log['max'].toStringAsFixed(0)} | ${log['la'].toStringAsFixed(0)} | ${log['ra'].toStringAsFixed(0)} | ${log['lh'].toStringAsFixed(0)} | ${log['rh'].toStringAsFixed(0)} | ${log['hipY'].toStringAsFixed(1)}");
    }
    logger.pushKey("diagnostic_dump", dump.toString());
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;
    
    if (now - _exerciseStartTimeMs! >= DeadBugConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return; 
    }

    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final lHip = landmarks[PoseLandmarkType.leftHip];
    final rHip = landmarks[PoseLandmarkType.rightHip];
    
    final lWrist = landmarks[PoseLandmarkType.leftWrist];
    final rWrist = landmarks[PoseLandmarkType.rightWrist];
    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];

    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null ||
        lWrist == null || rWrist == null || lKnee == null || rKnee == null) return;

    // Chuẩn hóa chiều dài lưng
    scaleFactor = calculateDistance(lShoulder, lHip);

    // Tính toán góc 4 chi
    double lArmAng = calculateAngleNormalized(firstPoint: lHip, midPoint: lShoulder, lastPoint: lWrist);
    double rArmAng = calculateAngleNormalized(firstPoint: rHip, midPoint: rShoulder, lastPoint: rWrist);
    double lHipAng = calculateAngleNormalized(firstPoint: lShoulder, midPoint: lHip, lastPoint: lKnee);
    double rHipAng = calculateAngleNormalized(firstPoint: rShoulder, midPoint: rHip, lastPoint: rKnee);

    double maxExt = [lArmAng, rArmAng, lHipAng, rHipAng].reduce((a, b) => a > b ? a : b);

    if (now - _lastDiagnosticTime > 500 || state != previousState) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'max': maxExt,
        'la': lArmAng, 'ra': rArmAng,
        'lh': lHipAng, 'rh': rHipAng,
        'hipY': lHip.y
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(maxExt, now);

    final ctx = DeadBugRepContext(
      leftArmAngle: lArmAng,
      rightArmAngle: rArmAng,
      leftHipAngle: lHipAng,
      rightHipAngle: rHipAng,
      hipY: lHip.y,
      shoulderY: lShoulder.y,
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    if (state == DeadBugState.setup && previousState == DeadBugState.returning) {
      _completeRep(ctx);
      return;
    }

    if (state != DeadBugState.setup) {
      for (final metric in _metrics) metric.update(ctx);
    }
    
    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double maxAngle, int now) {
    if (_extendingDebouncer.update(state == DeadBugState.setup && maxAngle > DeadBugConfig.EXTENDING_THRESHOLD)) {
      _transitionState(DeadBugState.extending, now);
    } 
    else if (_holdDebouncer.update(state == DeadBugState.extending && maxAngle > DeadBugConfig.HOLD_THRESHOLD)) {
      _transitionState(DeadBugState.hold, now);
    }
    else if (_returningDebouncer.update(state == DeadBugState.hold && maxAngle < DeadBugConfig.RETURNING_THRESHOLD)) {
      _transitionState(DeadBugState.returning, now);
    }
    else if (_setupDebouncer.update(state == DeadBugState.returning && maxAngle < DeadBugConfig.SETUP_THRESHOLD)) {
      _transitionState(DeadBugState.setup, now);
    }
  }

  void _transitionState(DeadBugState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics) metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(DeadBugRepContext ctx) {
    previousState = DeadBugState.setup;
    repCount++;
    tempoMetric.evaluateRep(ctx);

    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);
    correctForm = !allFaults.any((f) => f.affectsForm);
    
    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
       "extending_time": tempoMetric.extendingDuration ?? 0.0,
       "fault_types": allFaults.map((e) => e.type).toSet().toList()
    }));

    correctForm = true;
    for (var metric in _metrics) metric.resetAndCountFault();
  }
}