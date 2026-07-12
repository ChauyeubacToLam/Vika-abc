// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/reverse_crunch_metric_base.dart';
import 'metrics/swinging_momentum_metric.dart';
import 'metrics/pelvic_curl_metric.dart';
import 'metrics/eccentric_tempo_metric.dart';
import 'metrics/arm_position_metric.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/debouncer.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

class ReverseCrunch extends ExerciseBase with SideTrackedExerciseMixin {
  static const List<String> _voiceFaultIds = [
    'curl',
    'tempo',
    'momentum',
    'arms',
  ];

  ReverseCrunch({required this.maxRep}) : super(targetReps: maxRep);

  final int maxRep;

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
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Reverse Crunch';

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'reverse_crunch',
        faultIds: _voiceFaultIds,
        softCuePools: const {
          'tempo': ['reverse_crunch.tempo_soft'],
          'momentum': ['reverse_crunch.momentum_soft'],
        },
        reminderPools: const {
          'arms': ['reverse_crunch.arms_reminder'],
        },
        repStartPhaseKeys: const {'curling'},
        // Hesitation encouragement, not "push harder"; valid for controlled work too.
        effortPhaseKeys: const {'curling'},
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

  ReverseCrunchState crunchState = ReverseCrunchState.lying;
  ReverseCrunchState previousState = ReverseCrunchState.lying;
  int? _exerciseStartTimeMs;
  bool _isTimeout = false;
  double? _baselineTrunkKneeAngle;
  double? _baselineHipY;
  double? _minTrunkKneeAngleThisRep;
  bool _sawContractionThisRep = false;
  double _maxHipLiftThisRep = 0;
  double _maxLegAngleThisRep = 0;
  double _maxKneeAngleThisRep = 0;
  int _rejectedAttempts = 0;

  final Debouncer _curlingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _topDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lyingDebouncer = Debouncer(requiredFrames: 2);

  final SwingingMomentumMetric momentumMetric = SwingingMomentumMetric();
  final PelvicCurlMetric curlMetric = PelvicCurlMetric();
  final EccentricTempoMetric tempoMetric = EccentricTempoMetric();
  final ArmPositionMetric armMetric = ArmPositionMetric();

  late final List<ReverseCrunchMetricBase> _metrics = [
    momentumMetric,
    curlMetric,
    tempoMetric,
    armMetric
  ];

  // =========================================================================
  // FIX: THÊM CÁC OVERRIDE BẮT BUỘC TỪ ExerciseBase
  // =========================================================================
  @override
  String get currentPhaseKey => crunchState.name;

  @override
  String get currentPhaseLabel {
    switch (crunchState) {
      case ReverseCrunchState.lying:
        return 'Nằm chuẩn bị';
      case ReverseCrunchState.curling:
        return 'Cuộn lên';
      case ReverseCrunchState.top:
        return 'Đỉnh';
      case ReverseCrunchState.lowering:
        return 'Hạ xuống';
    }
  }

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    crunchState = ReverseCrunchState.lying;
    previousState = ReverseCrunchState.lying;
    _resetRepAttempt(clearBaseline: true);
    for (final metric in _metrics) metric.reset();
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return const GuidanceSignal.turnSide();
    }
    if (getSideTrackedLandmarks(landmarks) == null) {
      return const GuidanceSignal.bodyInFrame();
    }
    if (cameraFacing == CameraFacing.front) {
      return const GuidanceSignal.turnSide();
    }
    return null;
  }
  // =========================================================================

  ({
    bool isVisible,
    bool isCorrect,
    double? minElbowAngle,
    double? maxWristHipDistanceRatio,
  }) _calculateArmPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    double? minElbow;
    double? maxWristHip;

    void collectArm(
      PoseLandmarkType shoulderType,
      PoseLandmarkType hipType,
      PoseLandmarkType elbowType,
      PoseLandmarkType wristType,
    ) {
      final shoulder = landmarks[shoulderType];
      final hip = landmarks[hipType];
      final elbow = landmarks[elbowType];
      final wrist = landmarks[wristType];
      if (shoulder == null || hip == null || elbow == null || wrist == null) {
        return;
      }
      if (![shoulder, hip, elbow, wrist]
          .every(ExerciseBase.isLandmarkConfident)) {
        return;
      }

      final scale = calculateDistance(shoulder, hip);
      if (scale <= 1e-6) return;

      final elbowAngle = calculateAngleNormalized(
          firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
      final wristHipDistanceRatio = calculateDistance(wrist, hip) / scale;

      minElbow =
          minElbow == null || elbowAngle < minElbow! ? elbowAngle : minElbow;
      maxWristHip = maxWristHip == null || wristHipDistanceRatio > maxWristHip!
          ? wristHipDistanceRatio
          : maxWristHip;
    }

    collectArm(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );
    collectArm(
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    );

    if (minElbow == null || maxWristHip == null) {
      return (
        isVisible: false,
        isCorrect: false,
        minElbowAngle: null,
        maxWristHipDistanceRatio: null,
      );
    }

    return (
      isVisible: true,
      isCorrect: minElbow! >= ReverseCrunchConfig.ARM_ELBOW_STRAIGHT_MIN &&
          maxWristHip! <= ReverseCrunchConfig.ARM_WRIST_HIP_MAX_RATIO,
      minElbowAngle: minElbow,
      maxWristHipDistanceRatio: maxWristHip,
    );
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final profile = _calculatePoseProfile(lm);

    debugData['Setup_Diagnostic'] = {
      'kneeAngle': profile.kneeAngle.toStringAsFixed(1),
      'trunkHorizontal': profile.trunkHorizontalAngle.toStringAsFixed(1),
      'thighHorizontal': profile.thighHorizontalAngle.toStringAsFixed(1),
      'shinHorizontal': profile.shinHorizontalAngle.toStringAsFixed(1),
      'isGuideStart': profile.isSetupPosition,
    };

    if (!profile.isSetupPosition) return false;

    final armPosition = _calculateArmPosition(landmarks);
    if (armPosition.isVisible && !armPosition.isCorrect) {
      resultIssues.feedback['Arms'] = 'Duỗi thẳng hai tay và khép sát hông.';
    } else if (!armPosition.isVisible) {
      resultIssues.feedback['Arms'] =
          'Nếu thấy được tay, hãy duỗi sát bên hông.';
    }

    return true;
  }

  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null &&
        (frameTimestampMs - _exerciseStartTimeMs!) >
            ReverseCrunchConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= maxRep;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;
    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) return;

    final profile = _calculatePoseProfile(lm);

    if (crunchState == ReverseCrunchState.lying && profile.isSetupPosition) {
      _captureBaseline(profile);
    }

    // Dùng FrameBuffer để tính vận tốc cuộn (TrunkKneeAngle)
    frameBuffer.addFrame(FrameSnapshot(
        log: {"trunkKneeAngle": profile.trunkKneeAngle}, timeStamp: now));
    double trunkKneeVelocity = _calculateVelocityFromBuffer("trunkKneeAngle");

    debugData['Diagnostic_Table'] = {
      'State': crunchState.name,
      'Time_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'TrunkKneeAngle': profile.trunkKneeAngle.toStringAsFixed(1),
      'KneeAngle': profile.kneeAngle.toStringAsFixed(1),
      'LegAngle': profile.legHorizontalAngle.toStringAsFixed(1),
      'HipLift': profile.hipLiftNormalized.toStringAsFixed(2),
      'TrunkKneeVel': trunkKneeVelocity.toStringAsFixed(2),
      'Hip_Y': lm['hip']!.y.toStringAsFixed(1),
    };
    final armPosition = _calculateArmPosition(landmarks);

    final ctx = RepContext(
      state: crunchState,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      trunkKneeAngle: profile.trunkKneeAngle,
      kneeAngle: profile.kneeAngle,
      thighHorizontalAngle: profile.thighHorizontalAngle,
      shinHorizontalAngle: profile.shinHorizontalAngle,
      legHorizontalAngle: profile.legHorizontalAngle,
      hipY: profile.hipY,
      hipLiftNormalized: profile.hipLiftNormalized,
      trunkKneeVelocity: trunkKneeVelocity,
      isSetupPosition: profile.isSetupPosition,
      isContractionPosition: profile.isContractionPosition,
      isLegThrustPeak: profile.isLegThrustPeak,
      armsVisible: armPosition.isVisible,
      armStraightnessAngle: armPosition.minElbowAngle,
      wristHipDistanceRatio: armPosition.maxWristHipDistanceRatio,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);
    final metricCtx = ctx.copyWith(state: crunchState);
    for (final metric in _metrics) {
      metric.update(metricCtx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(RepContext ctx) {
    if (_baselineTrunkKneeAngle == null) return;

    if (crunchState == ReverseCrunchState.curling ||
        crunchState == ReverseCrunchState.top) {
      _trackRepPeak(ctx);
      if (ctx.isContractionPosition) _sawContractionThisRep = true;
    }

    final startedCurl = ctx.trunkKneeAngle <=
            _baselineTrunkKneeAngle! -
                ReverseCrunchConfig.LIFT_START_ANGLE_DROP ||
        ctx.hipLiftNormalized >=
            ReverseCrunchConfig.LIFT_START_HIP_LIFT_NORMALIZED;

    if (_curlingDebouncer.update(crunchState == ReverseCrunchState.lying &&
        !ctx.isSetupPosition &&
        startedCurl)) {
      _transitionState(ReverseCrunchState.curling, ctx.frameTimestamp);
      _minTrunkKneeAngleThisRep = ctx.trunkKneeAngle;
      _trackRepPeak(ctx);
      if (ctx.isContractionPosition) _sawContractionThisRep = true;
    } else if (_topDebouncer.update(
        crunchState == ReverseCrunchState.curling && _sawContractionThisRep)) {
      _trackRepPeak(ctx);
      _transitionState(ReverseCrunchState.top, ctx.frameTimestamp);
    } else if (_loweringDebouncer.update(
        crunchState == ReverseCrunchState.top &&
            (ctx.isSetupPosition ||
                ctx.hipLiftNormalized <=
                    _maxHipLiftThisRep -
                        ReverseCrunchConfig.HIP_LIFT_EXIT_DROP_NORMALIZED ||
                (_minTrunkKneeAngleThisRep != null &&
                    ctx.trunkKneeAngle >=
                        _minTrunkKneeAngleThisRep! +
                            ReverseCrunchConfig.RETURN_ANGLE_RISE)))) {
      _transitionState(ReverseCrunchState.lowering, ctx.frameTimestamp);
    } else if (_lyingDebouncer.update(
        crunchState == ReverseCrunchState.curling && ctx.isSetupPosition)) {
      if (_isRepCountable) {
        _completeRep(ctx);
      } else {
        _rejectRepAttempt(
            ctx, 'Hãy cuộn gối về ngực và nhấc hông khỏi mặt sàn.');
      }
    } else if (_lyingDebouncer.update(
        crunchState == ReverseCrunchState.lowering && ctx.isSetupPosition)) {
      _completeRep(ctx);
      _minTrunkKneeAngleThisRep = null;
    }
  }

  void _transitionState(ReverseCrunchState newState, int timestampMs) {
    if (newState == crunchState) return;
    previousState = crunchState;
    crunchState = newState;
    if (newState == ReverseCrunchState.lying) {
      _resetRepAttempt(clearBaseline: true);
    }
    for (final metric in _metrics)
      metric.onStateTransition(previousState, newState, timestampMs);
  }

  void _captureBaseline(_ReverseCrunchPoseProfile profile) {
    _baselineTrunkKneeAngle = profile.trunkKneeAngle;
    _baselineHipY = profile.hipY;
  }

  void _trackRepPeak(RepContext ctx) {
    if (_minTrunkKneeAngleThisRep == null ||
        ctx.trunkKneeAngle < _minTrunkKneeAngleThisRep!) {
      _minTrunkKneeAngleThisRep = ctx.trunkKneeAngle;
    }
    if (ctx.hipLiftNormalized > _maxHipLiftThisRep) {
      _maxHipLiftThisRep = ctx.hipLiftNormalized;
    }
    if (ctx.legHorizontalAngle > _maxLegAngleThisRep) {
      _maxLegAngleThisRep = ctx.legHorizontalAngle;
    }
    if (ctx.kneeAngle > _maxKneeAngleThisRep) {
      _maxKneeAngleThisRep = ctx.kneeAngle;
    }
  }

  bool get _isRepCountable =>
      _sawContractionThisRep &&
      _maxHipLiftThisRep >= ReverseCrunchConfig.HIP_LIFT_MIN_NORMALIZED;

  void _rejectRepAttempt(RepContext ctx, String message) {
    _rejectedAttempts++;
    resultIssues.feedback['Result'] = 'Không tính rep';
    _transitionState(ReverseCrunchState.lying, ctx.frameTimestamp);
    for (final metric in _metrics) metric.reset();
  }

  void _resetRepAttempt({required bool clearBaseline}) {
    _minTrunkKneeAngleThisRep = null;
    _sawContractionThisRep = false;
    _maxHipLiftThisRep = 0;
    _maxLegAngleThisRep = 0;
    _maxKneeAngleThisRep = 0;
    _curlingDebouncer.reset();
    _topDebouncer.reset();
    _loweringDebouncer.reset();
    _lyingDebouncer.reset();
    if (clearBaseline) {
      _baselineTrunkKneeAngle = null;
      _baselineHipY = null;
    }
  }

  void _completeRep(RepContext ctx) {
    if (!_isRepCountable) {
      _rejectRepAttempt(ctx, 'Hãy cuộn gối về ngực và nhấc hông khỏi mặt sàn.');
      return;
    }

    for (final metric in _metrics) metric.evaluateRepEnd(ctx);
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);

    correctForm = !allFaults.any((f) => f.affectsForm);

    repCount++;
    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';
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
    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        "fault_types": allFaults.map((e) => e.type).toSet().toList(),
        "fault_affects_form": faultAffectsForm,
        "fault_priorities": faultPriorities,
      },
    ));

    _transitionState(ReverseCrunchState.lying, ctx.frameTimestamp);
    for (final metric in _metrics) metric.resetAndCountFault();
  }

  double _calculateVelocityFromBuffer(String key) {
    if (frameBuffer.frameBuffer.length < 3) return 0;
    var last = frameBuffer.frameBuffer.last;
    var first = frameBuffer.frameBuffer.first;
    double dAngle =
        (last.log[key] as num).toDouble() - (first.log[key] as num).toDouble();
    double dt = (last.timeStamp - first.timeStamp) / 1000.0;
    return dt == 0 ? 0 : dAngle / dt; // degrees per second
  }

  _ReverseCrunchPoseProfile _calculatePoseProfile(
      Map<String, PoseLandmark> lm) {
    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;
    final scale = calculateDistance(shoulder, hip);

    final trunkKneeAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    final kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    final trunkHorizontalAngle =
        calculateAbsoluteHorizontalAngle(point1: shoulder, point2: hip);
    final thighHorizontalAngle =
        calculateAbsoluteHorizontalAngle(point1: hip, point2: knee);
    final shinHorizontalAngle =
        calculateAbsoluteHorizontalAngle(point1: knee, point2: ankle);
    final legHorizontalAngle =
        calculateAbsoluteHorizontalAngle(point1: hip, point2: ankle);
    final hipLiftNormalized =
        scale <= 1e-6 ? 0.0 : ((_baselineHipY ?? hip.y) - hip.y) / scale;
    final trunkKneeDrop = _baselineTrunkKneeAngle == null
        ? 0.0
        : _baselineTrunkKneeAngle! - trunkKneeAngle;

    final isSetupPosition = kneeAngle >=
            ReverseCrunchConfig.SETUP_KNEE_ANGLE_RANGE[0] &&
        kneeAngle <= ReverseCrunchConfig.SETUP_KNEE_ANGLE_RANGE[1] &&
        trunkHorizontalAngle <=
            ReverseCrunchConfig.SETUP_TRUNK_HORIZONTAL_MAX &&
        thighHorizontalAngle >= ReverseCrunchConfig.SETUP_THIGH_VERTICAL_MIN &&
        shinHorizontalAngle <= ReverseCrunchConfig.SETUP_SHIN_HORIZONTAL_MAX;

    final isContractionPosition =
        trunkKneeDrop >= ReverseCrunchConfig.PELVIC_CURL_ANGLE_MIN_DROP &&
            hipLiftNormalized >= ReverseCrunchConfig.HIP_LIFT_MIN_NORMALIZED;

    final isLegThrustPeak =
        kneeAngle >= ReverseCrunchConfig.PEAK_KNEE_EXTENSION_MIN &&
            legHorizontalAngle >= ReverseCrunchConfig.PEAK_LEG_VERTICAL_MIN &&
            hipLiftNormalized >= ReverseCrunchConfig.HIP_LIFT_MIN_NORMALIZED;

    return _ReverseCrunchPoseProfile(
      trunkKneeAngle: trunkKneeAngle,
      kneeAngle: kneeAngle,
      trunkHorizontalAngle: trunkHorizontalAngle,
      thighHorizontalAngle: thighHorizontalAngle,
      shinHorizontalAngle: shinHorizontalAngle,
      legHorizontalAngle: legHorizontalAngle,
      hipY: hip.y,
      hipLiftNormalized: hipLiftNormalized,
      isSetupPosition: isSetupPosition,
      isContractionPosition: isContractionPosition,
      isLegThrustPeak: isLegThrustPeak,
    );
  }

  Map<String, PoseLandmark>? _getLandmarks(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    return getSideTrackedLandmarks(lm);
  }

  @override
  void onSetComplete() {
    logger.pushKey("timeout", _isTimeout);
    logger.pushKey("max_rep", maxRep);
    logger.pushKey("momentum_fails_count", momentumMetric.faultsCount);
    logger.pushKey("curl_fails_count", curlMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushKey("arm_position_fails_count", armMetric.faultsCount);
    logger.pushKey("rejected_attempts_count", _rejectedAttempts);
    logger.pushGoodRepCount();
  }
}

class _ReverseCrunchPoseProfile {
  const _ReverseCrunchPoseProfile({
    required this.trunkKneeAngle,
    required this.kneeAngle,
    required this.trunkHorizontalAngle,
    required this.thighHorizontalAngle,
    required this.shinHorizontalAngle,
    required this.legHorizontalAngle,
    required this.hipY,
    required this.hipLiftNormalized,
    required this.isSetupPosition,
    required this.isContractionPosition,
    required this.isLegThrustPeak,
  });

  final double trunkKneeAngle;
  final double kneeAngle;
  final double trunkHorizontalAngle;
  final double thighHorizontalAngle;
  final double shinHorizontalAngle;
  final double legHorizontalAngle;
  final double hipY;
  final double hipLiftNormalized;
  final bool isSetupPosition;
  final bool isContractionPosition;
  final bool isLegThrustPeak;
}
