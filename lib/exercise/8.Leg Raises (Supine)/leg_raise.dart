// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';

import 'metrics/leg_raise_metric_base.dart';
import 'metrics/pelvic_stability_metric.dart';
import 'metrics/rom_metric.dart';
import 'metrics/knee_straightness_metric.dart';
import 'metrics/tempo_metric.dart';

class LegRaiseConfig {
  static const int MAX_REP = 12; // Beginner/Conservative
  static const int TIMEOUT_MS = 90000; // 90s
  
  // Start Position Limits
  static const double START_HIP_FLEXION_MIN = 165.0; // Gần 180 độ
  static const double START_KNEE_STRAIGHT_MIN = 160.0; // Phải duỗi gối

  // State Transition Thresholds
  static const double RAISING_ANGLE = 170.0;
  static const double TOP_ANGLE = 100.0; // Vai-Hông-Gối <= 100 độ
  static const double LOWERING_ANGLE = 105.0;
  static const double LYING_ANGLE = 165.0;
}

class LegRaise extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  LegRaiseState state = LegRaiseState.lying;
  LegRaiseState previousState = LegRaiseState.lying;
  
  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;
  
  // DIAGNOSTIC LOG
  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;
  
  final PelvicStabilityMetric pelvicMetric = PelvicStabilityMetric();
  final RomMetric romMetric = RomMetric();
  final KneeStraightnessMetric kneeMetric = KneeStraightnessMetric();
  final TempoMetric tempoMetric = TempoMetric();
  
  late final List<LegRaiseMetricBase> _metrics = [
    pelvicMetric, romMetric, kneeMetric, tempoMetric
  ];

  final Debouncer _raisingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _topDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lyingDebouncer = Debouncer(requiredFrames: 2);

  LegRaise({this.maxRep = LegRaiseConfig.MAX_REP});

  @override
  String get exerciseName => 'Leg Raises';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case LegRaiseState.lying: return 'Nằm sát sàn';
      case LegRaiseState.raising: return 'Đang nâng lên';
      case LegRaiseState.top: return 'Giữ thẳng!';
      case LegRaiseState.lowering: return 'Hạ chậm có kiểm soát';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null; // No specific safety check for this exercise yet.
  }

  // NOTE UI: Cần hiển thị Pop-up Safety Gate "Có tiền sử đau thắt lưng không?" trước.
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final knee = landmarks[PoseLandmarkType.leftKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];
    
    if (shoulder == null || hip == null || knee == null || ankle == null) return false;

    double hipFlexion = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    double kneeStraight = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);

    // Người phải duỗi thẳng trên mặt đất
    if (hipFlexion < LegRaiseConfig.START_HIP_FLEXION_MIN) return false;
    if (kneeStraight < LegRaiseConfig.START_KNEE_STRAIGHT_MIN) return false;

    return true; 
  }

  @override
  bool requestStop() => _timeoutReached || repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("pelvic_fails_count", pelvicMetric.faultsCount);
    logger.pushKey("rom_fails_count", romMetric.faultsCount);
    logger.pushKey("knee_fails_count", kneeMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushGoodRepCount();
    
    StringBuffer dump = StringBuffer();
    dump.writeln("=== DIAGNOSTIC LOG (LEG RAISE) ===");
    dump.writeln("Time(s) | State | HipFlex | KneeAng | HipY");
    for (var log in _diagnosticLog) {
       dump.writeln("${log['time']} | ${log['state']} | ${log['hipFlex'].toStringAsFixed(1)} | ${log['knee'].toStringAsFixed(1)} | ${log['hipY'].toStringAsFixed(1)}");
    }
    logger.pushKey("diagnostic_dump", dump.toString());
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;
    
    if (now - _exerciseStartTimeMs! >= LegRaiseConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return; 
    }

    final shoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final hip = landmarks[PoseLandmarkType.leftHip]!;
    final knee = landmarks[PoseLandmarkType.leftKnee]!;
    final ankle = landmarks[PoseLandmarkType.leftAnkle]!;

    scaleFactor = calculateDistance(shoulder, hip);

    double hipFlexion = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    double kneeStraight = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);

    final ctx = LegRaiseRepContext(
      hipFlexionAngle: hipFlexion,
      kneeStraightnessAngle: kneeStraight,
      hipY: hip.y,
      ankleY: ankle.y,
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    if (now - _lastDiagnosticTime > 500 || state != previousState) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'hipFlex': hipFlexion,
        'knee': kneeStraight,
        'hipY': hip.y
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(hipFlexion, now);

    if (state == LegRaiseState.lying && previousState == LegRaiseState.lowering) {
      _completeRep(ctx);
      return;
    }

    if (state != LegRaiseState.lying) {
      for (final metric in _metrics) metric.update(ctx);
    }
    
    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double hipFlexion, int now) {
    if (_raisingDebouncer.update(state == LegRaiseState.lying && hipFlexion < LegRaiseConfig.RAISING_ANGLE)) {
      _transitionState(LegRaiseState.raising, now);
    } 
    else if (_topDebouncer.update(state == LegRaiseState.raising && hipFlexion <= LegRaiseConfig.TOP_ANGLE)) {
      _transitionState(LegRaiseState.top, now);
    }
    else if (_loweringDebouncer.update(state == LegRaiseState.top && hipFlexion > LegRaiseConfig.LOWERING_ANGLE)) {
      _transitionState(LegRaiseState.lowering, now);
    }
    else if (_lyingDebouncer.update(state == LegRaiseState.lowering && hipFlexion > LegRaiseConfig.LYING_ANGLE)) {
      _transitionState(LegRaiseState.lying, now);
    }
  }

  void _transitionState(LegRaiseState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics) metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(LegRaiseRepContext ctx) {
    repCount++;
    romMetric.evaluateRep(ctx);
    tempoMetric.evaluateRep(ctx);

    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);
    correctForm = !allFaults.any((f) => f.affectsForm);
    
    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
       "min_hip_flexion": romMetric.minHipFlexion ?? 180.0,
       "lowering_time": tempoMetric.loweringDuration ?? 0.0,
       "fault_types": allFaults.map((e) => e.type).toSet().toList()
    }));

    correctForm = true;
    for (var metric in _metrics) metric.resetAndCountFault();
  }
}