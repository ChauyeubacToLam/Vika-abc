// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';

import 'metrics/v_up_metric_base.dart';
import 'metrics/sync_elevation_metric.dart';
import 'metrics/v_shape_rom_metric.dart';
import 'metrics/jerking_metric.dart';
import 'metrics/knee_extension_metric.dart';
import 'metrics/tempo_metric.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

class VUp extends ExerciseBase with SideTrackedExerciseMixin {
  static const List<String> _voiceFaultIds = [
    'sync',
    'tempo',
    'jerking',
    'rom',
    'knee',
  ];

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => {
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder
        ),
        'wrist': (
          right: PoseLandmarkType.rightWrist,
          left: PoseLandmarkType.leftWrist
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

  final int maxRep;
  VUpState state = VUpState.lying;
  VUpState previousState = VUpState.lying;

  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;
  double? _minAngleThisRep;

  double? _baselineShoulderY;
  double? _baselineAnkleY;
  double? _baselineVAngle;
  double? _baselineWristAnkleDistance;
  bool _repReadyFromFlatBaseline = false;
  bool _sawStrictVPositionThisRep = false;
  double _maxShoulderLiftThisRep = 0;
  double _maxAnkleLiftThisRep = 0;
  double _maxTrunkAngleThisRep = 0;
  double _maxLegAngleThisRep = 0;
  double _maxWristAnkleClosureThisRep = 0;
  double? _minWristAnkleDistThisRep;

  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final SyncElevationMetric syncMetric = SyncElevationMetric();
  final VShapeRomMetric romMetric = VShapeRomMetric();
  final JerkingMetric jerkingMetric = JerkingMetric();
  final KneeExtensionMetric kneeMetric = KneeExtensionMetric();
  final TempoMetric tempoMetric = TempoMetric();

  late final List<VUpMetricBase> _metrics = [
    syncMetric,
    romMetric,
    jerkingMetric,
    kneeMetric,
    tempoMetric
  ];

  final Debouncer _readyLyingDebouncer =
      Debouncer(requiredFrames: VUpConfig.REP_READY_FRAMES);
  final Debouncer _risingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _vPositionDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _abortDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lyingDebouncer = Debouncer(requiredFrames: 2);

  VUp({required this.maxRep}) : super(targetReps: maxRep);

  @override
  String get exerciseName => 'V-Up';

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'v_up',
        faultIds: _voiceFaultIds,
        softCuePools: const {
          'sync': ['v_up.sync_soft'],
          'rom': ['v_up.rom_soft'],
        },
        reminderPools: const {
          'knee': ['v_up.knee_reminder'],
        },
        repStartPhaseKeys: const {'rising'},
        // Hesitation encouragement, not "push harder"; valid for controlled work too.
        effortPhaseKeys: const {'rising'},
        hustlePool: const ['common.push'],
        hustleFinalPool: const ['common.one_more_rep'],
      ),
      targetReps: targetReps,
      coach: VoiceCoach(
        sink: AssetVoiceSink(),
        policy: VoicePolicy(),
      ),
    );
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case VUpState.lying:
        return 'Nằm duỗi thẳng';
      case VUpState.rising:
        return 'Nâng tay và chân cùng lúc';
      case VUpState.v_position:
        return 'Giữ đỉnh chữ V';
      case VUpState.lowering:
        return 'Hạ chậm có kiểm soát';
    }
  }

  @override
  GuidanceSignal? checkSafety(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null;
  }

  @override
  void onExerciseActivated() {
    state = VUpState.lying;
    previousState = VUpState.lying;
    _resetRepAttempt(clearBaseline: true);
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final tracked = getSideTrackedLandmarks(landmarks);
    if (tracked == null) return false;

    final profile = _calculatePoseProfile(landmarks, tracked);
    return profile != null && profile.isStrictLying;
  }

  @override
  bool requestStop() => _timeoutReached || repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("max_rep", _timeoutReached ? repCount : maxRep);
    logger.pushKey("sync_fails_count", syncMetric.faultsCount);
    logger.pushKey("rom_fails_count", romMetric.faultsCount);
    logger.pushKey("jerking_fails_count", jerkingMetric.faultsCount);
    logger.pushKey("knee_fails_count", kneeMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushGoodRepCount();

    if (isDebugModeActive) {
      final dump = StringBuffer();
      dump.writeln("=== DIAGNOSTIC LOG (V-UP) ===");
      dump.writeln("Time(s) | State | V-Angle | Knee | Trunk | Leg | Ready");
      for (final log in _diagnosticLog) {
        dump.writeln(
            "${log['time']} | ${log['state']} | ${log['vAngle'].toStringAsFixed(1)} | ${log['knee'].toStringAsFixed(1)} | ${log['trunk'].toStringAsFixed(1)} | ${log['leg'].toStringAsFixed(1)} | ${log['ready']}");
      }
      logger.pushKey("diagnostic_dump", dump.toString());
    }
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    if (now - _exerciseStartTimeMs! >= VUpConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return;
    }

    final tracked = getSideTrackedLandmarks(landmarks);
    if (tracked == null) return;

    final profile = _calculatePoseProfile(landmarks, tracked);
    if (profile == null) {
      resultIssues.feedback['Error'] = 'Không nhìn rõ toàn thân';
      // Legacy UI instruction copy: Giữ vai, tay, hông, gối và cổ chân trong khung hình.
      return;
    }

    scaleFactor = profile.scaleFactor;

    final ctx = VUpRepContext(
      shoulderHipAnkleAngle: profile.vAngle,
      hipKneeAnkleAngle: profile.kneeAngle,
      wristAnkleDistance: profile.wristAnkleDistance,
      trunkHorizontalAngle: profile.trunkHorizontalAngle,
      legHorizontalAngle: profile.legHorizontalAngle,
      shoulderY: profile.shoulderY,
      ankleY: profile.ankleY,
      hipY: profile.hipY,
      scaleFactor: scaleFactor,
      shoulderLiftFromBaseline: profile.shoulderLiftFromBaseline,
      ankleLiftFromBaseline: profile.ankleLiftFromBaseline,
      wristAnkleClosureFromBaseline: profile.wristAnkleClosureFromBaseline,
      isHorizontal: profile.isHorizontal,
      bothArmsLifted: profile.bothShouldersLifted,
      bothLegsLifted: profile.bothAnklesLifted,
      isStrictLying: profile.isStrictLying,
      isStrictVPosition: profile.isStrictVPosition,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    if (isDebugModeActive &&
        (now - _lastDiagnosticTime > 500 || state != previousState)) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'vAngle': ctx.shoulderHipAnkleAngle,
        'knee': ctx.hipKneeAnkleAngle,
        'trunk': ctx.trunkHorizontalAngle,
        'leg': ctx.legHorizontalAngle,
        'ready': _repReadyFromFlatBaseline,
      });
      _lastDiagnosticTime = now;
    }

    final completedRep = _updateStateMachine(ctx);
    final metricCtx = ctx.copyWith(state: state);

    if (completedRep) {
      _completeRep(metricCtx);
      previousState = state;
      return;
    }

    if (state == VUpState.lying) {
      if (metricCtx.isStrictLying) syncMetric.update(metricCtx);
    } else {
      for (final metric in _metrics) metric.update(metricCtx);
    }

    resultIssues.setPhaseStatus(state.name, currentPhaseLabel);
  }

  bool _updateStateMachine(VUpRepContext ctx) {
    final now = ctx.frameTimestampMs;

    if (state == VUpState.lying) {
      if (ctx.isStrictLying) {
        if (_readyLyingDebouncer.update(true)) {
          _captureFlatBaseline(ctx);
        }
      } else {
        _readyLyingDebouncer.update(false);
        if (!_repReadyFromFlatBaseline &&
            ctx.shoulderHipAnkleAngle < VUpConfig.RISING_ANGLE) {
          // Legacy UI instruction copy: Nằm duỗi thẳng và giữ ổn định trước khi bắt đầu.
        }
      }
    } else {
      _readyLyingDebouncer.update(false);
    }

    if (state == VUpState.rising || state == VUpState.v_position) {
      _trackRepPeak(ctx);
    }

    final canStartRising = state == VUpState.lying &&
        _repReadyFromFlatBaseline &&
        _baselineVAngle != null &&
        !ctx.isStrictLying &&
        ctx.shoulderHipAnkleAngle <=
            _baselineVAngle! - VUpConfig.LOWERING_THRESHOLD_DIFF &&
        ctx.shoulderHipAnkleAngle < VUpConfig.RISING_ANGLE &&
        ctx.shoulderLiftFromBaseline >= VUpConfig.RISING_MIN_LIFT &&
        ctx.ankleLiftFromBaseline >= VUpConfig.RISING_MIN_LIFT &&
        ctx.hipKneeAnkleAngle >= VUpConfig.ACTIVE_KNEE_MIN;

    if (_risingDebouncer.update(canStartRising)) {
      _beginRep(ctx);
      _transitionState(VUpState.rising, now);
      return false;
    }

    final canReachTop = state == VUpState.rising && ctx.isStrictVPosition;
    if (_vPositionDebouncer.update(canReachTop)) {
      _sawStrictVPositionThisRep = true;
      _trackRepPeak(ctx);
      _transitionState(VUpState.v_position, now);
      return false;
    }

    final abortedBeforeTop = state == VUpState.rising &&
        ctx.isStrictLying &&
        _minAngleThisRep != null;
    if (_abortDebouncer.update(abortedBeforeTop)) {
      _transitionState(VUpState.lying, now);
      _rejectRepAttempt(
          'Chưa nâng đủ cả thân trên và chân nên không tính rep.');
      return false;
    }

    final canStartLowering = state == VUpState.v_position &&
        _minAngleThisRep != null &&
        ctx.shoulderHipAnkleAngle >
            _minAngleThisRep! + VUpConfig.LOWERING_THRESHOLD_DIFF;

    if (_loweringDebouncer.update(canStartLowering)) {
      _transitionState(VUpState.lowering, now);
      return false;
    }

    final returnedToFlat = state == VUpState.lowering &&
        ctx.isStrictLying &&
        ctx.shoulderHipAnkleAngle >= VUpConfig.LYING_ANGLE;

    if (_lyingDebouncer.update(returnedToFlat)) {
      _transitionState(VUpState.lying, now);
      final countable = _isRepCountable(ctx);
      _repReadyFromFlatBaseline = false;
      _readyLyingDebouncer.reset();
      if (!countable) {
        _rejectRepAttempt(
            'Rep không đủ chuỗi nằm thẳng - nâng chữ V - hạ về nằm thẳng.');
        return false;
      }
      return true;
    }

    return false;
  }

  void _captureFlatBaseline(VUpRepContext ctx) {
    _baselineShoulderY = ctx.shoulderY;
    _baselineAnkleY = ctx.ankleY;
    _baselineVAngle = ctx.shoulderHipAnkleAngle;
    _baselineWristAnkleDistance = ctx.wristAnkleDistance;
    _repReadyFromFlatBaseline = true;
    syncMetric.update(ctx.copyWith(state: VUpState.lying));
  }

  void _beginRep(VUpRepContext ctx) {
    _repReadyFromFlatBaseline = false;
    _sawStrictVPositionThisRep = false;
    _minAngleThisRep = ctx.shoulderHipAnkleAngle;
    _maxShoulderLiftThisRep = ctx.shoulderLiftFromBaseline;
    _maxAnkleLiftThisRep = ctx.ankleLiftFromBaseline;
    _maxTrunkAngleThisRep = ctx.trunkHorizontalAngle;
    _maxLegAngleThisRep = ctx.legHorizontalAngle;
    _maxWristAnkleClosureThisRep = ctx.wristAnkleClosureFromBaseline;
    _minWristAnkleDistThisRep = ctx.wristAnkleDistance;
  }

  void _trackRepPeak(VUpRepContext ctx) {
    if (_minAngleThisRep == null ||
        ctx.shoulderHipAnkleAngle < _minAngleThisRep!) {
      _minAngleThisRep = ctx.shoulderHipAnkleAngle;
    }
    if (ctx.shoulderLiftFromBaseline > _maxShoulderLiftThisRep) {
      _maxShoulderLiftThisRep = ctx.shoulderLiftFromBaseline;
    }
    if (ctx.ankleLiftFromBaseline > _maxAnkleLiftThisRep) {
      _maxAnkleLiftThisRep = ctx.ankleLiftFromBaseline;
    }
    if (ctx.trunkHorizontalAngle > _maxTrunkAngleThisRep) {
      _maxTrunkAngleThisRep = ctx.trunkHorizontalAngle;
    }
    if (ctx.legHorizontalAngle > _maxLegAngleThisRep) {
      _maxLegAngleThisRep = ctx.legHorizontalAngle;
    }
    if (ctx.wristAnkleClosureFromBaseline > _maxWristAnkleClosureThisRep) {
      _maxWristAnkleClosureThisRep = ctx.wristAnkleClosureFromBaseline;
    }
    if (_minWristAnkleDistThisRep == null ||
        ctx.wristAnkleDistance < _minWristAnkleDistThisRep!) {
      _minWristAnkleDistThisRep = ctx.wristAnkleDistance;
    }
  }

  bool _isRepCountable(VUpRepContext ctx) {
    if (!_sawStrictVPositionThisRep) return false;
    if (_minAngleThisRep == null ||
        _minAngleThisRep! > VUpConfig.V_POSITION_THRESHOLD) {
      return false;
    }
    if (_maxShoulderLiftThisRep < VUpConfig.TOP_MIN_LIFT ||
        _maxAnkleLiftThisRep < VUpConfig.TOP_MIN_LIFT) {
      return false;
    }
    if (_maxTrunkAngleThisRep < VUpConfig.TOP_TRUNK_HORIZ_MIN ||
        _maxLegAngleThisRep < VUpConfig.TOP_LEG_HORIZ_MIN) {
      return false;
    }
    final armsReachedHigh = (_minWristAnkleDistThisRep ?? double.infinity) <=
            VUpConfig.TOP_ARM_REACH_DIST_MAX ||
        _maxWristAnkleClosureThisRep >= VUpConfig.TOP_ARM_REACH_CLOSURE_MIN;
    return armsReachedHigh && ctx.isStrictLying;
  }

  void _rejectRepAttempt(String message) {
    resultIssues.feedback['Result'] = 'Không tính rep';
    _resetRepAttempt(clearBaseline: true);
    for (final metric in _metrics) metric.reset();
  }

  void _resetRepAttempt({required bool clearBaseline}) {
    _minAngleThisRep = null;
    _sawStrictVPositionThisRep = false;
    _maxShoulderLiftThisRep = 0;
    _maxAnkleLiftThisRep = 0;
    _maxTrunkAngleThisRep = 0;
    _maxLegAngleThisRep = 0;
    _maxWristAnkleClosureThisRep = 0;
    _minWristAnkleDistThisRep = null;
    _repReadyFromFlatBaseline = false;

    _readyLyingDebouncer.reset();
    _risingDebouncer.reset();
    _vPositionDebouncer.reset();
    _loweringDebouncer.reset();
    _abortDebouncer.reset();
    _lyingDebouncer.reset();

    if (clearBaseline) {
      _baselineShoulderY = null;
      _baselineAnkleY = null;
      _baselineVAngle = null;
      _baselineWristAnkleDistance = null;
    }
  }

  void _transitionState(VUpState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (final metric in _metrics)
      metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(VUpRepContext ctx) {
    romMetric.evaluateRep(ctx);
    tempoMetric.evaluateRep(ctx);

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);

    final hasDisqualifyingFault = allFaults.any((f) => f.type == 'knee');

    correctForm = !allFaults.any((f) => f.affectsForm);

    if (hasDisqualifyingFault) {
      resultIssues.feedback['Result'] = 'Không tính rep';
      correctForm = false;
    } else {
      repCount++;
      if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';
    }

    final faultAffectsForm = <String, bool>{};
    final faultPriorities = <String, int>{};
    for (final fault in allFaults) {
      faultAffectsForm[fault.type] =
          (faultAffectsForm[fault.type] ?? false) || fault.affectsForm;
      final previousPriority = faultPriorities[fault.type];
      if (previousPriority == null || fault.priority < previousPriority) {
        faultPriorities[fault.type] = fault.priority;
      }
    }

    logger
        .addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "min_v_angle": romMetric.minVAngle ?? 180.0,
      "max_shoulder_lift": _maxShoulderLiftThisRep,
      "max_ankle_lift": _maxAnkleLiftThisRep,
      "min_wrist_ankle_dist": _minWristAnkleDistThisRep ?? 999.0,
      "lowering_time": tempoMetric.loweringDuration ?? 0.0,
      "fault_types": allFaults.map((e) => e.type).toSet().toList(),
      "fault_affects_form": faultAffectsForm,
      "fault_priorities": faultPriorities,
    }));

    correctForm = true;
    _resetRepAttempt(clearBaseline: true);
    for (final metric in _metrics) {
      if (hasDisqualifyingFault) {
        metric.reset();
      } else {
        metric.resetAndCountFault();
      }
    }
  }

  _VUpPoseProfile? _calculatePoseProfile(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    Map<String, PoseLandmark> tracked,
  ) {
    final shoulder = tracked['shoulder'];
    final wrist = tracked['wrist'];
    final hip = tracked['hip'];
    final knee = tracked['knee'];
    final ankle = tracked['ankle'];

    if (shoulder == null ||
        wrist == null ||
        hip == null ||
        knee == null ||
        ankle == null) {
      return null;
    }

    if (![shoulder, wrist, hip, knee, ankle]
        .every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }

    final scale = calculateDistance(shoulder, hip);
    if (scale <= 0) return null;

    final vAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    final kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    final trunkHorizontal =
        calculateAbsoluteHorizontalAngle(point1: shoulder, point2: hip);
    final legHorizontal =
        calculateAbsoluteHorizontalAngle(point1: hip, point2: ankle);
    final wristAnkleDist = calculateDistance(wrist, ankle) / scale;

    final shoulderLiftFromBaseline = _baselineShoulderY == null
        ? 0.0
        : (_baselineShoulderY! - shoulder.y) / scale;
    final ankleLiftFromBaseline =
        _baselineAnkleY == null ? 0.0 : (_baselineAnkleY! - ankle.y) / scale;
    final wristClosureFromBaseline = _baselineWristAnkleDistance == null
        ? 0.0
        : _baselineWristAnkleDistance! - wristAnkleDist;

    final bilateral = _calculateBilateralProfile(landmarks, scale);
    if (bilateral == null) return null;

    final isStrictLying = vAngle >= VUpConfig.START_BODY_MIN &&
        kneeAngle >= VUpConfig.START_KNEE_MIN &&
        trunkHorizontal <= VUpConfig.START_TRUNK_HORIZ_MAX &&
        legHorizontal <= VUpConfig.START_LEG_HORIZ_MAX &&
        bilateral.isHorizontal &&
        wristAnkleDist >= VUpConfig.START_WRIST_ANKLE_DIST_MIN;

    final armsReachedHigh =
        wristAnkleDist <= VUpConfig.TOP_ARM_REACH_DIST_MAX ||
            wristClosureFromBaseline >= VUpConfig.TOP_ARM_REACH_CLOSURE_MIN;

    final isStrictVPosition = vAngle <= VUpConfig.V_POSITION_THRESHOLD &&
        kneeAngle >= VUpConfig.ACTIVE_KNEE_MIN &&
        trunkHorizontal >= VUpConfig.TOP_TRUNK_HORIZ_MIN &&
        legHorizontal >= VUpConfig.TOP_LEG_HORIZ_MIN &&
        shoulderLiftFromBaseline >= VUpConfig.TOP_MIN_LIFT &&
        ankleLiftFromBaseline >= VUpConfig.TOP_MIN_LIFT &&
        armsReachedHigh;

    return _VUpPoseProfile(
      vAngle: vAngle,
      kneeAngle: kneeAngle,
      wristAnkleDistance: wristAnkleDist,
      trunkHorizontalAngle: trunkHorizontal,
      legHorizontalAngle: legHorizontal,
      shoulderY: shoulder.y,
      ankleY: ankle.y,
      hipY: hip.y,
      scaleFactor: scale,
      shoulderLiftFromBaseline: shoulderLiftFromBaseline,
      ankleLiftFromBaseline: ankleLiftFromBaseline,
      wristAnkleClosureFromBaseline: wristClosureFromBaseline,
      isHorizontal: bilateral.isHorizontal,
      bothShouldersLifted: bilateral.bothShouldersLifted,
      bothAnklesLifted: bilateral.bothAnklesLifted,
      isStrictLying: isStrictLying,
      isStrictVPosition: isStrictVPosition,
    );
  }

  _BilateralVUpProfile? _calculateBilateralProfile(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    double scale,
  ) {
    final samples = <({
      PoseLandmark shoulder,
      PoseLandmark hip,
      PoseLandmark knee,
      PoseLandmark ankle,
    })>[];

    void collectSide(
      PoseLandmarkType shoulderType,
      PoseLandmarkType hipType,
      PoseLandmarkType kneeType,
      PoseLandmarkType ankleType,
    ) {
      final shoulder = landmarks[shoulderType];
      final hip = landmarks[hipType];
      final knee = landmarks[kneeType];
      final ankle = landmarks[ankleType];
      if (shoulder == null || hip == null || knee == null || ankle == null) {
        return;
      }
      if (![shoulder, hip, knee, ankle]
          .every(ExerciseBase.isLandmarkConfident)) {
        return;
      }
      samples.add((shoulder: shoulder, hip: hip, knee: knee, ankle: ankle));
    }

    collectSide(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );
    collectSide(
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    );

    if (samples.isEmpty) return null;

    final spreads = <double>[];
    final shoulderLifts = <double>[];
    final ankleLifts = <double>[];
    for (final sample in samples) {
      spreads.add((sample.shoulder.y - sample.hip.y).abs() / scale);
      spreads.add((sample.knee.y - sample.hip.y).abs() / scale);
      spreads.add((sample.ankle.y - sample.hip.y).abs() / scale);
      shoulderLifts.add((sample.hip.y - sample.shoulder.y) / scale);
      ankleLifts.add((sample.hip.y - sample.ankle.y) / scale);
    }

    final ySpread = spreads.reduce((a, b) => a > b ? a : b);
    final bestShoulderLift = shoulderLifts.reduce((a, b) => a > b ? a : b);
    final bestAnkleLift = ankleLifts.reduce((a, b) => a > b ? a : b);

    return _BilateralVUpProfile(
      isHorizontal: ySpread <= VUpConfig.START_Y_SPREAD_MAX,
      bothShouldersLifted: bestShoulderLift >= VUpConfig.TOP_MIN_LIFT,
      bothAnklesLifted: bestAnkleLift >= VUpConfig.TOP_MIN_LIFT,
    );
  }
}

class _VUpPoseProfile {
  const _VUpPoseProfile({
    required this.vAngle,
    required this.kneeAngle,
    required this.wristAnkleDistance,
    required this.trunkHorizontalAngle,
    required this.legHorizontalAngle,
    required this.shoulderY,
    required this.ankleY,
    required this.hipY,
    required this.scaleFactor,
    required this.shoulderLiftFromBaseline,
    required this.ankleLiftFromBaseline,
    required this.wristAnkleClosureFromBaseline,
    required this.isHorizontal,
    required this.bothShouldersLifted,
    required this.bothAnklesLifted,
    required this.isStrictLying,
    required this.isStrictVPosition,
  });

  final double vAngle;
  final double kneeAngle;
  final double wristAnkleDistance;
  final double trunkHorizontalAngle;
  final double legHorizontalAngle;
  final double shoulderY;
  final double ankleY;
  final double hipY;
  final double scaleFactor;
  final double shoulderLiftFromBaseline;
  final double ankleLiftFromBaseline;
  final double wristAnkleClosureFromBaseline;
  final bool isHorizontal;
  final bool bothShouldersLifted;
  final bool bothAnklesLifted;
  final bool isStrictLying;
  final bool isStrictVPosition;
}

class _BilateralVUpProfile {
  const _BilateralVUpProfile({
    required this.isHorizontal,
    required this.bothShouldersLifted,
    required this.bothAnklesLifted,
  });

  final bool isHorizontal;
  final bool bothShouldersLifted;
  final bool bothAnklesLifted;
}
