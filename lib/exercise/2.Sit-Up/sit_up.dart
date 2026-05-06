// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';

import 'metrics/sit_up_metric_base.dart';
import 'metrics/rom_metric.dart';
import 'metrics/jerking_metric.dart';
import 'metrics/stability_metric.dart';
import 'metrics/tempo_metric.dart';

class SitUpConfig {
  static const int MAX_REP = 15;
  static const int TIMEOUT_MS = 90000; // 90s

  static const double START_TRUNK_HORIZ_MAX = 15.0; 
  static const double START_KNEE_MIN = 70.0;
  static const double START_KNEE_MAX = 110.0; 

  static const double RISING_TRUNK_START = 15.0;
  static const double UPRIGHT_KHS_THRESHOLD = 95.0; 
  static const double LOWERING_KHS_THRESHOLD = 100.0;
  static const double LYING_TRUNK_THRESHOLD = 15.0;
}

class SitUp extends ExerciseBase {
  final int maxRep;
  SitUpState state = SitUpState.lying;
  SitUpState previousState = SitUpState.lying;

  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;

  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final RomMetric romMetric = RomMetric();
  final JerkingMetric jerkingMetric = JerkingMetric();
  final StabilityMetric stabilityMetric = StabilityMetric();
  final TempoMetric tempoMetric = TempoMetric();

  late final List<SitUpMetricBase> _metrics = [
    romMetric, jerkingMetric, stabilityMetric, tempoMetric
  ];

  final Debouncer _risingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _uprightDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lyingDebouncer = Debouncer(requiredFrames: 2);

  SitUp({this.maxRep = SitUpConfig.MAX_REP});

  @override
  String get exerciseName => 'Sit Up';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case SitUpState.lying: return 'Nằm (Chuẩn bị)';
      case SitUpState.rising: return 'Cuộn người lên';
      case SitUpState.upright: return 'Giữ!';
      case SitUpState.lowering: return 'Hạ người';
    }
  }

  // FIXED: Sửa kiểu trả về từ void thành String? để đúng với ExerciseBase
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return null; 
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final knee = landmarks[PoseLandmarkType.leftKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];
         
    if (shoulder == null || hip == null || knee == null || ankle == null) return false;
    
    double trunkHoriz = _calcHorizontalAngle(shoulder, hip);
    double kneeAngle = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    
    if (trunkHoriz > SitUpConfig.START_TRUNK_HORIZ_MAX) return false;
    if (kneeAngle < SitUpConfig.START_KNEE_MIN || kneeAngle > SitUpConfig.START_KNEE_MAX) return false;
    
    return true;
  }

  @override
  bool requestStop() => _timeoutReached || repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("rom_fails_count", romMetric.faultsCount);
    logger.pushKey("jerking_fails_count", jerkingMetric.faultsCount);
    logger.pushKey("stability_fails_count", stabilityMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushGoodRepCount();
         
    StringBuffer dump = StringBuffer();
    dump.writeln("=== DIAGNOSTIC LOG (SIT-UP) ===");
    for (var log in _diagnosticLog) {
       dump.writeln("${log['time']} | ${log['state']} | ${log['trunk'].toStringAsFixed(1)} | ${log['khs'].toStringAsFixed(1)} | ${log['ankleY'].toStringAsFixed(1)}");
    }
    logger.pushKey("diagnostic_dump", dump.toString());
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;
         
    if (now - _exerciseStartTimeMs! >= SitUpConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return;
    }

    final shoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final hip = landmarks[PoseLandmarkType.leftHip]!;
    final knee = landmarks[PoseLandmarkType.leftKnee]!;
    final ankle = landmarks[PoseLandmarkType.leftAnkle]!;
    
    scaleFactor = calculateDistance(shoulder, hip);
    double trunkHoriz = _calcHorizontalAngle(shoulder, hip);
    double kneeAngle = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double khsAngle = calculateAngleNormalized(firstPoint: knee, midPoint: hip, lastPoint: shoulder);
    
    final ctx = SitUpRepContext(
      trunkHorizontalAngle: trunkHoriz,
      hipKneeAnkleAngle: kneeAngle,
      kneeHipShoulderAngle: khsAngle,
      shoulderY: shoulder.y,
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
        'trunk': trunkHoriz,
        'khs': khsAngle,
        'ankleY': ankle.y
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(trunkHoriz, khsAngle, now);

    if (state == SitUpState.lying && previousState == SitUpState.lowering) {
      _completeRep(ctx);
      return;
    }

    if (state != SitUpState.lying) {
      for (final metric in _metrics) metric.update(ctx);
    }
         
    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double trunkHoriz, double khsAngle, int now) {
    if (_risingDebouncer.update(state == SitUpState.lying && trunkHoriz > SitUpConfig.RISING_TRUNK_START)) {
      _transitionState(SitUpState.rising, now);
    } else if (_uprightDebouncer.update(state == SitUpState.rising && khsAngle <= SitUpConfig.UPRIGHT_KHS_THRESHOLD)) {
      _transitionState(SitUpState.upright, now);
    } else if (_loweringDebouncer.update(state == SitUpState.upright && khsAngle > SitUpConfig.LOWERING_KHS_THRESHOLD)) {
      _transitionState(SitUpState.lowering, now);
    } else if (_lyingDebouncer.update((state == SitUpState.lowering || state == SitUpState.rising) && trunkHoriz < SitUpConfig.LYING_TRUNK_THRESHOLD)) {
      _transitionState(SitUpState.lying, now);
    }
  }

  void _transitionState(SitUpState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics) metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(SitUpRepContext ctx) {
    repCount++;
    romMetric.evaluateRep(ctx);
    tempoMetric.evaluateRep(ctx);
    
    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);
    
    correctForm = !allFaults.any((f) => f.affectsForm);
         
    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';
    
    logger.addRepLog(RepLog(
      correctForm: correctForm, 
      repNumber: repCount, 
      data: {
       "min_khs_angle": romMetric.minKneeHipShoulder ?? 180.0,
       "lowering_time": tempoMetric.loweringDuration ?? 0.0,
       "fault_types": allFaults.map((e) => e.type).toSet().toList()
      }
    ));
    
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