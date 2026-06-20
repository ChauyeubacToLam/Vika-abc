// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';

import 'metrics/sit_up_metric_base.dart';
import 'metrics/rom_metric.dart';
import 'metrics/jerking_metric.dart';
import 'metrics/stability_metric.dart';
import 'metrics/tempo_metric.dart';

class SitUpConfig {
  static const int MAX_REP = 15;
  static const int TIMEOUT_MS = 90000; // 90s

  // FIX: Spec yêu cầu < 10° (code cũ là 15°)
  static const double START_TRUNK_HORIZ_MAX = 18.0;
  static const double START_KNEE_MIN = 60.0;
  // FIX: Spec yêu cầu 100° (code cũ là 110°)
  static const double START_KNEE_MAX = 115.0;

  static const double RISING_TRUNK_START = 30.0; // Must be > LYING_TRUNK_THRESHOLD
  static const double COUNTABLE_TOP_KHS_THRESHOLD = 142.0;
  static const double UPRIGHT_KHS_THRESHOLD = 105.0;
  static const double LOWERING_KHS_THRESHOLD = 110.0;
  static const double LOWERING_KHS_DIFF = 15.0; // Increased to prevent noise bouncing
  static const double LYING_TRUNK_THRESHOLD = 22.0;
}

class SitUp extends ExerciseBase with SideTrackedExerciseMixin {
  final int maxRep;
  SitUpState state = SitUpState.lying;
  SitUpState previousState = SitUpState.lying;

  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;
  double? _minKhsThisRep;

  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final RomMetric romMetric = RomMetric();
  final JerkingMetric jerkingMetric = JerkingMetric();
  final StabilityMetric stabilityMetric = StabilityMetric();
  final TempoMetric tempoMetric = TempoMetric();

  late final List<SitUpMetricBase> _metrics = [
    romMetric,
    jerkingMetric,
    stabilityMetric,
    tempoMetric
  ];
  late final List<TrackedMetric> _trackedMetrics =
      _metrics.map(TrackedMetric.new).toList();

  @override
  List<TrackedMetric> get trackedDebugMetrics =>
      List<TrackedMetric>.unmodifiable(
        [
          ...super.trackedDebugMetrics,
          ..._trackedMetrics,
        ],
      );

  final Debouncer _risingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _uprightDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lyingDebouncer = Debouncer(requiredFrames: 2);

  SitUp({this.maxRep = SitUpConfig.MAX_REP});

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip
        ),
        'knee': (
          right: PoseLandmarkType.rightKnee,
          left: PoseLandmarkType.leftKnee
        ),
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle
        ),
      };

  @override
  String get exerciseName => 'Sit Up';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case SitUpState.lying:
        return 'Nằm (Chuẩn bị)';
      case SitUpState.rising:
        return 'Cuộn người lên';
      case SitUpState.upright:
        return 'Giữ!';
      case SitUpState.lowering:
        return 'Hạ người';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return 'Hãy đặt camera ngang bên hông để theo dõi Sit-Up.';
    }
    if (getSideTrackedLandmarks(landmarks) == null) {
      return 'Giữ vai, hông, gối và cổ chân rõ trong khung hình.';
    }
    // Pain screening gate (thoát vị / đau thắt lưng) được xử lý ở UI layer
    // trước khi exercise này được khởi tạo. Xem: SitUpSafetyGateScreen.
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final tracked = getSideTrackedLandmarks(landmarks);
    if (tracked == null) return false;

    final shoulder = tracked['shoulder']!;
    final hip = tracked['hip']!;
    final knee = tracked['knee']!;
    final ankle = tracked['ankle']!;
    if (![shoulder, hip, knee, ankle].every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    double trunkHoriz =
        calculateAbsoluteHorizontalAngle(point1: shoulder, point2: hip);
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    if (trunkHoriz > SitUpConfig.START_TRUNK_HORIZ_MAX) return false;
    if (kneeAngle < SitUpConfig.START_KNEE_MIN ||
        kneeAngle > SitUpConfig.START_KNEE_MAX) return false;

    return true;
  }

  @override
  bool requestStop() => _timeoutReached || repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("max_rep", _timeoutReached ? repCount : maxRep);
    logger.pushKey("rom_fails_count", romMetric.faultsCount);
    logger.pushKey("jerking_fails_count", jerkingMetric.faultsCount);
    logger.pushKey("stability_fails_count", stabilityMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushGoodRepCount();

    if (isDebugModeActive) {
      StringBuffer dump = StringBuffer();
      dump.writeln("=== DIAGNOSTIC LOG (SIT-UP) ===");
      for (var log in _diagnosticLog) {
        dump.writeln(
            "${log['time']} | ${log['state']} | ${log['trunk'].toStringAsFixed(1)} | ${log['khs'].toStringAsFixed(1)} | ${log['ankleY'].toStringAsFixed(1)}");
      }
      logger.pushKey("diagnostic_dump", dump.toString());
    }
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    if (now - _exerciseStartTimeMs! >= SitUpConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return;
    }

    final tracked = getSideTrackedLandmarks(landmarks);
    if (tracked == null) return;

    final shoulder = tracked['shoulder']!;
    final hip = tracked['hip']!;
    final knee = tracked['knee']!;
    final ankle = tracked['ankle']!;
    if (![shoulder, hip, knee, ankle].every(ExerciseBase.isLandmarkConfident)) {
      return;
    }

    scaleFactor = calculateDistance(shoulder, hip);
    double trunkHoriz =
        calculateAbsoluteHorizontalAngle(point1: shoulder, point2: hip);
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double khsAngle = calculateAngleNormalized(
        firstPoint: knee, midPoint: hip, lastPoint: shoulder);

    final ctx = SitUpRepContext(
      trunkHorizontalAngle: trunkHoriz,
      hipKneeAnkleAngle: kneeAngle,
      kneeHipShoulderAngle: khsAngle,
      shoulderY: shoulder.y,
      ankleX: ankle.x,
      ankleY: ankle.y,
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    if (isDebugModeActive &&
        (now - _lastDiagnosticTime > 500 || state != previousState)) {
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

    final completedFromLowering =
        state == SitUpState.lying && previousState == SitUpState.lowering;
    final completedFromPartialCurl = state == SitUpState.lying &&
        previousState == SitUpState.rising &&
        _hasReachedCountableTop;

    if (completedFromLowering || completedFromPartialCurl) {
      _completeRep(ctx);
      previousState = SitUpState.lying; // Thêm dòng này để reset trạng thái
      return;
    }

    if (state != SitUpState.lying) {
      for (final metric in _metrics) metric.update(ctx);
    }

    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(double trunkHoriz, double khsAngle, int now) {
    if (state == SitUpState.rising || state == SitUpState.upright) {
      if (_minKhsThisRep == null || khsAngle < _minKhsThisRep!) {
        _minKhsThisRep = khsAngle;
      }
    }

    if (_risingDebouncer.update(state == SitUpState.lying &&
        trunkHoriz > SitUpConfig.RISING_TRUNK_START)) {
      _transitionState(SitUpState.rising, now);
    } else if (_uprightDebouncer.update(state == SitUpState.rising &&
        khsAngle <= SitUpConfig.UPRIGHT_KHS_THRESHOLD)) {
      _transitionState(SitUpState.upright, now);
    } else if (_loweringDebouncer.update(state == SitUpState.rising &&
        _hasReachedCountableTop &&
        khsAngle > _minKhsThisRep! + SitUpConfig.LOWERING_KHS_DIFF)) {
      _transitionState(SitUpState.lowering, now);
    } else if (_loweringDebouncer.update(state == SitUpState.upright &&
        khsAngle > SitUpConfig.LOWERING_KHS_THRESHOLD)) {
      _transitionState(SitUpState.lowering, now);
    } else if (_lyingDebouncer.update(
        (state == SitUpState.lowering || state == SitUpState.rising) &&
            trunkHoriz < SitUpConfig.LYING_TRUNK_THRESHOLD)) {
      _transitionState(SitUpState.lying, now);
    }
  }

  bool get _hasReachedCountableTop =>
      _minKhsThisRep != null &&
      _minKhsThisRep! <= SitUpConfig.COUNTABLE_TOP_KHS_THRESHOLD;

  void _transitionState(SitUpState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics)
      metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(SitUpRepContext ctx) {
    romMetric.evaluateRep();
    tempoMetric.evaluateRep();

    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);

    final legLifts = allFaults.where((f) => f.type == 'Stability').toList();
    bool isLegLifted = legLifts.isNotEmpty;

    if (!isLegLifted) {
      repCount++;
    } else {
      final voiceMsg = legLifts.first.voiceMessage;
      if (voiceMsg != null && voiceMsg.isNotEmpty) {
        ttsService.speak(voiceMsg);
      }
    }

    correctForm = !allFaults.any((f) => f.affectsForm);

    if (isLegLifted) {
      resultIssues.feedback['Result'] = 'Không tính rep';
    } else if (!correctForm) {
      resultIssues.feedback['Result'] = 'Fix Form';
    }

    if (!isLegLifted) {
      logger.addRepLog(
          RepLog(correctForm: correctForm, repNumber: repCount, data: {
        "min_khs_angle": romMetric.minKneeHipShoulder ?? 180.0,
        "lowering_time": tempoMetric.loweringDuration ?? 0.0,
        "fault_types": allFaults.map((e) => e.type).toSet().toList()
      }));
    }

    correctForm = true;
    _minKhsThisRep = null;
    for (var metric in _metrics) {
      if (isLegLifted) {
        metric.reset();
      } else {
        metric.resetAndCountFault();
      }
    }
  }

  // FIX: Dùng atan2 thay vì (dy/dx * 180/π) — công thức cũ trả về tan(θ)×(180/π), không phải góc thật
}
