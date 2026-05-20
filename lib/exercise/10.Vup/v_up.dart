// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';

import 'metrics/v_up_metric_base.dart';
import 'metrics/sync_elevation_metric.dart';
import 'metrics/v_shape_rom_metric.dart';
import 'metrics/jerking_metric.dart';
import 'metrics/knee_extension_metric.dart';
import 'metrics/tempo_metric.dart';


class VUp extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  VUpState state = VUpState.lying;
  VUpState previousState = VUpState.lying;
  
  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;
  double? _minAngleThisRep;
  
  // DIAGNOSTIC LOG
  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final SyncElevationMetric syncMetric = SyncElevationMetric();
  final VShapeRomMetric romMetric = VShapeRomMetric();
  final JerkingMetric jerkingMetric = JerkingMetric();
  final KneeExtensionMetric kneeMetric = KneeExtensionMetric();
  final TempoMetric tempoMetric = TempoMetric();
  
  late final List<VUpMetricBase> _metrics = [
    syncMetric, romMetric, jerkingMetric, kneeMetric, tempoMetric
  ];

  final Debouncer _risingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _vPositionDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lyingDebouncer = Debouncer(requiredFrames: 2);

  VUp({this.maxRep = VUpConfig.MAX_REP});

  @override
  String get exerciseName => 'V-Up';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case VUpState.lying: return 'Nằm duỗi thẳng';
      case VUpState.rising: return 'Gập lên chữ V';
      case VUpState.v_position: return 'Đỉnh điểm!';
      case VUpState.lowering: return 'Hạ có kiểm soát';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null; // No specific safety checks yet
  }

  // NOTE UI: Cần hiển thị Pop-up Safety Gate "Có tiền sử đau thắt lưng không?" trước.
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];
    
    if (shoulder == null || hip == null || ankle == null) return false;

    double bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);

    // Người phải nằm thẳng
    if (bodyAngle < VUpConfig.START_BODY_MIN) return false;

    // Check tọa độ Y xấp xỉ nhau (Sát sàn)
    double dyShoulderHip = (shoulder.y - hip.y).abs();
    double dyAnkleHip = (ankle.y - hip.y).abs();
    double scale = calculateDistance(shoulder, hip);
    
    if (scale > 0 && (dyShoulderHip / scale > 0.2 || dyAnkleHip / scale > 0.2)) return false;

    return true; 
  }

  @override
  bool requestStop() => _timeoutReached || repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("sync_fails_count", syncMetric.faultsCount);
    logger.pushKey("rom_fails_count", romMetric.faultsCount);
    logger.pushKey("jerking_fails_count", jerkingMetric.faultsCount);
    logger.pushKey("knee_fails_count", kneeMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushGoodRepCount();
    
    StringBuffer dump = StringBuffer();
    dump.writeln("=== DIAGNOSTIC LOG (V-UP) ===");
    dump.writeln("Time(s) | State | V-Angle | Knee | Shld_Y | Ankle_Y");
    for (var log in _diagnosticLog) {
       dump.writeln("${log['time']} | ${log['state']} | ${log['vAngle'].toStringAsFixed(1)} | ${log['knee'].toStringAsFixed(1)} | ${log['shldY'].toStringAsFixed(1)} | ${log['ankleY'].toStringAsFixed(1)}");
    }
    logger.pushKey("diagnostic_dump", dump.toString());
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;
    
    if (now - _exerciseStartTimeMs! >= VUpConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return; 
    }

    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final wrist = landmarks[PoseLandmarkType.leftWrist];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final knee = landmarks[PoseLandmarkType.leftKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];

    if (shoulder == null || wrist == null || hip == null || knee == null || ankle == null) return;

    scaleFactor = calculateDistance(shoulder, hip);

    double vAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double kneeStraight = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double wristAnkleDist = scaleFactor > 0 ? calculateDistance(wrist, ankle) / scaleFactor : 0;

    if (now - _lastDiagnosticTime > 500 || state != previousState) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'vAngle': vAngle,
        'knee': kneeStraight,
        'shldY': shoulder.y,
        'ankleY': ankle.y,
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(vAngle, now);

    final ctx = VUpRepContext(
      shoulderHipAnkleAngle: vAngle,
      hipKneeAnkleAngle: kneeStraight,
      wristAnkleDistance: wristAnkleDist,
      shoulderY: shoulder.y,
      ankleY: ankle.y,
      hipY: hip.y,
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    if (state == VUpState.lying && previousState == VUpState.lowering) {
      _completeRep(ctx);
      return;
    }

    if (state != VUpState.lying) {
      for (final metric in _metrics) metric.update(ctx);
    }
    
    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double vAngle, int now) {
    if (state == VUpState.rising || state == VUpState.v_position) {
      if (_minAngleThisRep == null || vAngle < _minAngleThisRep!) {
        _minAngleThisRep = vAngle;
      }
    }

    if (_risingDebouncer.update(state == VUpState.lying && vAngle < VUpConfig.RISING_ANGLE)) {
      _transitionState(VUpState.rising, now);
      _minAngleThisRep = vAngle;
    } 
    else if (_vPositionDebouncer.update(state == VUpState.rising && vAngle <= VUpConfig.V_POSITION_THRESHOLD)) {
      _transitionState(VUpState.v_position, now);
    }
    else if (_loweringDebouncer.update((state == VUpState.v_position || state == VUpState.rising) && 
            _minAngleThisRep != null && vAngle > _minAngleThisRep! + VUpConfig.LOWERING_THRESHOLD_DIFF)) {
      _transitionState(VUpState.lowering, now);
    }
    else if (_lyingDebouncer.update(state == VUpState.lowering && vAngle > VUpConfig.LYING_ANGLE)) {
      _transitionState(VUpState.lying, now);
      _minAngleThisRep = null;
    }
  }

  void _transitionState(VUpState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics) metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(VUpRepContext ctx) {
    romMetric.evaluateRep(ctx);
    tempoMetric.evaluateRep(ctx);
    repCount++;

    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);
    correctForm = !allFaults.any((f) => f.affectsForm);
    
    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
       "min_v_angle": romMetric.minVAngle ?? 180.0,
       "lowering_time": tempoMetric.loweringDuration ?? 0.0,
       "fault_types": allFaults.map((e) => e.type).toSet().toList()
    }));

    correctForm = true;
    for (var metric in _metrics) metric.resetAndCountFault();
  }
}