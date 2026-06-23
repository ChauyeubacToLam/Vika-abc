// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'dart:math' as math;
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../../services/leg_raise_voice_coach.dart';
import '../exercise_base.dart';

import 'metrics/leg_raise_metric_base.dart';
import 'metrics/pelvic_stability_metric.dart';
import 'metrics/rom_metric.dart';
import 'metrics/knee_straightness_metric.dart';
import 'metrics/tempo_metric.dart';
import 'metrics/arm_position_metric.dart';

class LegRaise extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  LegRaiseState state = LegRaiseState.lying;
  LegRaiseState previousState = LegRaiseState.lying;
  int invalidAttemptCount = 0;
  bool lastRepWasClean = true;
  String? lastRepTopVoiceMessage;

  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;

  // DIAGNOSTIC LOG
  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final PelvicStabilityMetric pelvicMetric = PelvicStabilityMetric();
  final RomMetric romMetric = RomMetric();
  final KneeStraightnessMetric kneeMetric = KneeStraightnessMetric();
  final TempoMetric tempoMetric = TempoMetric();
  final ArmPositionMetric armMetric = ArmPositionMetric();

  late final List<LegRaiseMetricBase> _metrics = [
    pelvicMetric,
    romMetric,
    kneeMetric,
    tempoMetric,
    armMetric
  ];

  final Debouncer _raisingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _topDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lyingDebouncer = Debouncer(requiredFrames: 2);

  LegRaise({required this.maxRep});

  @override
  String get exerciseName => 'Leg Raises';

  @override
  ExerciseVoiceCoach? createVoiceCoach() => LegRaiseVoiceCoach();

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case LegRaiseState.lying:
        return 'Nằm sát sàn';
      case LegRaiseState.raising:
        return 'Đang nâng lên';
      case LegRaiseState.top:
        return 'Giữ thẳng!';
      case LegRaiseState.lowering:
        return 'Hạ chậm có kiểm soát';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return 'Hãy đặt camera ngang bên hông để theo dõi Leg Raises.';
    }

    bool sideVisible(
      PoseLandmarkType shoulder,
      PoseLandmarkType hip,
      PoseLandmarkType knee,
      PoseLandmarkType ankle,
    ) {
      final landmarks = [
        smoothedLandmarks[shoulder],
        smoothedLandmarks[hip],
        smoothedLandmarks[knee],
        smoothedLandmarks[ankle],
      ];
      return landmarks
          .every((lm) => lm != null && ExerciseBase.isLandmarkConfident(lm));
    }

    final hasLeft = sideVisible(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );
    final hasRight = sideVisible(
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    );
    if (!hasLeft && !hasRight) {
      return 'Giữ vai, hông, gối và cổ chân rõ trong khung hình.';
    }
    return null;
  }

  // NOTE UI: Cần hiển thị Pop-up Safety Gate "Có tiền sử đau thắt lưng không?" trước.
  ({
    double hipFlexion,
    double kneeStraight,
    double trunkHorizontal,
    bool isValid
  }) _calculateStrictAngles(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    double leftHipFlexion = 180.0, rightHipFlexion = 180.0;
    double leftKneeStraight = 180.0, rightKneeStraight = 180.0;
    double leftTrunk = 0.0, rightTrunk = 0.0;
    bool hasLeft = false, hasRight = false;

    if (landmarks.containsKey(PoseLandmarkType.leftShoulder) &&
        landmarks.containsKey(PoseLandmarkType.leftHip) &&
        landmarks.containsKey(PoseLandmarkType.leftKnee) &&
        landmarks.containsKey(PoseLandmarkType.leftAnkle) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.leftShoulder]!) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.leftHip]!) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.leftKnee]!) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.leftAnkle]!)) {
      leftHipFlexion = calculateAngleNormalized(
          firstPoint: landmarks[PoseLandmarkType.leftShoulder]!,
          midPoint: landmarks[PoseLandmarkType.leftHip]!,
          lastPoint: landmarks[PoseLandmarkType.leftKnee]!);
      leftKneeStraight = calculateAngleNormalized(
          firstPoint: landmarks[PoseLandmarkType.leftHip]!,
          midPoint: landmarks[PoseLandmarkType.leftKnee]!,
          lastPoint: landmarks[PoseLandmarkType.leftAnkle]!);

      double dx = (landmarks[PoseLandmarkType.leftShoulder]!.x -
              landmarks[PoseLandmarkType.leftHip]!.x)
          .abs();
      double dy = (landmarks[PoseLandmarkType.leftShoulder]!.y -
              landmarks[PoseLandmarkType.leftHip]!.y)
          .abs();
      leftTrunk = math.atan2(dy, dx) * (180.0 / math.pi);

      hasLeft = true;
    }

    if (landmarks.containsKey(PoseLandmarkType.rightShoulder) &&
        landmarks.containsKey(PoseLandmarkType.rightHip) &&
        landmarks.containsKey(PoseLandmarkType.rightKnee) &&
        landmarks.containsKey(PoseLandmarkType.rightAnkle) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.rightShoulder]!) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.rightHip]!) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.rightKnee]!) &&
        ExerciseBase.isLandmarkConfident(
            landmarks[PoseLandmarkType.rightAnkle]!)) {
      rightHipFlexion = calculateAngleNormalized(
          firstPoint: landmarks[PoseLandmarkType.rightShoulder]!,
          midPoint: landmarks[PoseLandmarkType.rightHip]!,
          lastPoint: landmarks[PoseLandmarkType.rightKnee]!);
      rightKneeStraight = calculateAngleNormalized(
          firstPoint: landmarks[PoseLandmarkType.rightHip]!,
          midPoint: landmarks[PoseLandmarkType.rightKnee]!,
          lastPoint: landmarks[PoseLandmarkType.rightAnkle]!);

      double dx = (landmarks[PoseLandmarkType.rightShoulder]!.x -
              landmarks[PoseLandmarkType.rightHip]!.x)
          .abs();
      double dy = (landmarks[PoseLandmarkType.rightShoulder]!.y -
              landmarks[PoseLandmarkType.rightHip]!.y)
          .abs();
      rightTrunk = math.atan2(dy, dx) * (180.0 / math.pi);

      hasRight = true;
    }

    double hipFlexion = 180.0;
    double kneeStraight = 180.0;
    double trunkHorizontal = 0.0;

    if (hasLeft && hasRight) {
      hipFlexion =
          leftHipFlexion > rightHipFlexion ? leftHipFlexion : rightHipFlexion;
      kneeStraight = leftKneeStraight < rightKneeStraight
          ? leftKneeStraight
          : rightKneeStraight;
      trunkHorizontal = leftTrunk < rightTrunk ? leftTrunk : rightTrunk;
    } else if (hasLeft) {
      hipFlexion = leftHipFlexion;
      kneeStraight = leftKneeStraight;
      trunkHorizontal = leftTrunk;
    } else if (hasRight) {
      hipFlexion = rightHipFlexion;
      kneeStraight = rightKneeStraight;
      trunkHorizontal = rightTrunk;
    }

    return (
      hipFlexion: hipFlexion,
      kneeStraight: kneeStraight,
      trunkHorizontal: trunkHorizontal,
      isValid: hasLeft || hasRight
    );
  }

  ({
    bool isVisible,
    bool isCorrect,
    double? minElbowAngle,
    double? maxWristHipDistanceRatio,
  }) _calculateArmPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final samples = <({double elbowAngle, double wristHipDistanceRatio})>[];

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

      samples.add((
        elbowAngle: calculateAngleNormalized(
            firstPoint: shoulder, midPoint: elbow, lastPoint: wrist),
        wristHipDistanceRatio: calculateDistance(wrist, hip) / scale,
      ));
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

    if (samples.isEmpty) {
      return (
        isVisible: false,
        isCorrect: false,
        minElbowAngle: null,
        maxWristHipDistanceRatio: null,
      );
    }

    var minElbow = samples.first.elbowAngle;
    var maxWristHip = samples.first.wristHipDistanceRatio;
    for (final sample in samples.skip(1)) {
      minElbow = math.min(minElbow, sample.elbowAngle);
      maxWristHip = math.max(maxWristHip, sample.wristHipDistanceRatio);
    }

    return (
      isVisible: true,
      isCorrect: minElbow >= LegRaiseConfig.ARM_ELBOW_STRAIGHT_MIN &&
          maxWristHip <= LegRaiseConfig.ARM_WRIST_HIP_MAX_RATIO,
      minElbowAngle: minElbow,
      maxWristHipDistanceRatio: maxWristHip,
    );
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final angles = _calculateStrictAngles(landmarks);

    if (!angles.isValid) return false;

    // Người phải duỗi thẳng trên mặt đất
    if (angles.hipFlexion < LegRaiseConfig.START_HIP_FLEXION_MIN) return false;
    if (angles.kneeStraight < LegRaiseConfig.START_KNEE_STRAIGHT_MIN)
      return false;
    if (angles.trunkHorizontal > LegRaiseConfig.MAX_TRUNK_ANGLE) return false;

    final armPosition = _calculateArmPosition(landmarks);
    if (!armPosition.isVisible) {
      resultIssues.feedback['Arms'] =
          'Giữ hai tay thẳng sát hông trong khung hình.';
      return false;
    }
    if (!armPosition.isCorrect) {
      resultIssues.feedback['Arms'] = 'Duỗi thẳng hai tay và khép sát hông.';
      return false;
    }

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
    logger.pushKey("arm_position_fails_count", armMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", _timeoutReached ? repCount : maxRep);

    if (isDebugModeActive) {
      StringBuffer dump = StringBuffer();
      dump.writeln("=== DIAGNOSTIC LOG (LEG RAISE) ===");
      dump.writeln("Time(s) | State | HipFlex | KneeAng | HipY");
      for (var log in _diagnosticLog) {
        dump.writeln(
            "${log['time']} | ${log['state']} | ${log['hipFlex'].toStringAsFixed(1)} | ${log['knee'].toStringAsFixed(1)} | ${log['hipY'].toStringAsFixed(1)}");
      }
      logger.pushKey("diagnostic_dump", dump.toString());
    }
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    if (now - _exerciseStartTimeMs! >= LegRaiseConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return;
    }

    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ??
        landmarks[PoseLandmarkType.rightShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip] ??
        landmarks[PoseLandmarkType.rightHip];
    final knee = landmarks[PoseLandmarkType.leftKnee] ??
        landmarks[PoseLandmarkType.rightKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ??
        landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null || hip == null || knee == null || ankle == null) {
      return; // Safe guard: prevent null crash when user goes out of frame
    }

    scaleFactor = calculateDistance(shoulder, hip);

    final angles = _calculateStrictAngles(landmarks);
    if (!angles.isValid) {
      resultIssues.feedback['Error'] = 'Không nhìn rõ người';
      resultIssues.addInstruction(
          'BLOCK', 'Error', 'Hãy nằm vào giữa khung hình!');
      return;
    }

    double hipFlexion = angles.hipFlexion;
    double kneeStraight = angles.kneeStraight;
    double trunkHorizontal = angles.trunkHorizontal;
    final armPosition = _calculateArmPosition(landmarks);

    final ctx = LegRaiseRepContext(
      hipFlexionAngle: hipFlexion,
      kneeStraightnessAngle: kneeStraight,
      trunkHorizontalAngle: trunkHorizontal,
      hipY: hip.y,
      ankleY: ankle.y,
      scaleFactor: scaleFactor,
      armsVisible: armPosition.isVisible,
      armStraightnessAngle: armPosition.minElbowAngle,
      wristHipDistanceRatio: armPosition.maxWristHipDistanceRatio,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    if (isDebugModeActive &&
        (now - _lastDiagnosticTime > 500 || state != previousState)) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'hipFlex': hipFlexion,
        'knee': kneeStraight,
        'hipY': hip.y
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(ctx);

    if (state != LegRaiseState.lying) {
      for (final metric in _metrics) metric.update(ctx);
    }

    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  void _updateStateMachine(LegRaiseRepContext ctx) {
    double hipFlexion = ctx.hipFlexionAngle;
    double trunkHorizontal = ctx.trunkHorizontalAngle;
    int now = ctx.frameTimestampMs;

    bool isTrunkLying = trunkHorizontal <= LegRaiseConfig.MAX_TRUNK_ANGLE;

    if (!isTrunkLying) {
      if (state != LegRaiseState.lying) {
        _transitionState(LegRaiseState.lying, now);
      }
      ctx.resultIssues.feedback['Error'] = 'Lưng không chạm sàn';
      ctx.resultIssues
          .addInstruction('BLOCK', 'Error', 'Hãy nằm sát lưng xuống sàn!');
      _raisingDebouncer.update(false); // Reset debouncer
      return;
    }

    if (state != LegRaiseState.lying &&
        ctx.kneeStraightnessAngle < LegRaiseConfig.START_KNEE_STRAIGHT_MIN) {
      ctx.resultIssues.feedback['Error'] = 'Gập gối';
      ctx.resultIssues
          .addInstruction('BLOCK', 'Error', 'Hãy duỗi thẳng chân ra!');
    }

    if (_raisingDebouncer.update(state == LegRaiseState.lying &&
        hipFlexion < LegRaiseConfig.RAISING_ANGLE)) {
      _transitionState(LegRaiseState.raising, now);
    } else if (_topDebouncer.update(state == LegRaiseState.raising &&
        hipFlexion <= LegRaiseConfig.TOP_ANGLE)) {
      _transitionState(LegRaiseState.top, now);
    } else if (_loweringDebouncer.update(state == LegRaiseState.top &&
        hipFlexion > LegRaiseConfig.LOWERING_ANGLE)) {
      _transitionState(LegRaiseState.lowering, now);
    } else if (_lyingDebouncer.update(state == LegRaiseState.lowering &&
        hipFlexion > LegRaiseConfig.LYING_ANGLE)) {
      _transitionState(LegRaiseState.lying, now);
      _completeRep(ctx);
    }
  }

  void _transitionState(LegRaiseState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics)
      metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(LegRaiseRepContext ctx) {
    romMetric.evaluateRep(ctx);
    tempoMetric.evaluateRep(ctx);

    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);
    correctForm = !allFaults.any((f) => f.affectsForm);
    lastRepWasClean = correctForm;
    lastRepTopVoiceMessage = _topVoiceMessage(allFaults);

    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';

    bool hasBlockingFormFault =
        allFaults.any((f) => f.type == 'BentKnee' || f.type == 'ArmPosition');
    if (!hasBlockingFormFault) {
      repCount++;
    } else {
      invalidAttemptCount++;
      ctx.resultIssues.feedback['Result'] = 'Không tính rep';
    }

    if (!hasBlockingFormFault) {
      logger.addRepLog(
          RepLog(correctForm: correctForm, repNumber: repCount, data: {
        "min_hip_flexion": romMetric.minHipFlexion ?? 180.0,
        "lowering_time": tempoMetric.loweringDuration ?? 0.0,
        "fault_types": allFaults.map((e) => e.type).toSet().toList()
      }));
    }

    correctForm = true;
    for (var metric in _metrics) {
      if (hasBlockingFormFault) {
        metric.reset();
      } else {
        metric.resetAndCountFault();
      }
    }
  }

  String? _topVoiceMessage(List<FaultRecord> faults) {
    final voicedFaults = faults
        .where((fault) =>
            fault.voiceMessage != null && fault.voiceMessage!.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.type.compareTo(b.type);
      });
    final rawVoice = voicedFaults.isEmpty ? null : voicedFaults.first.voiceMessage;
    return _voiceScriptMessage(rawVoice);
  }

  String? _voiceScriptMessage(String? rawVoice) {
    if (rawVoice == null || rawVoice.isEmpty) return null;
    if (rawVoice.contains('Võng lưng') || rawVoice.contains('lưng sát sàn')) {
      return 'Ép lưng dưới xuống sàn';
    }
    if (rawVoice.contains('vuông góc') || rawVoice.contains('Nâng chân')) {
      return 'Nâng và hạ chân rõ hơn';
    }
    if (rawVoice.contains('gối')) {
      return 'Duỗi thẳng đầu gối';
    }
    if (rawVoice.contains('Hạ chân') || rawVoice.contains('Từ từ')) {
      return 'Hạ chân chậm lại';
    }
    if (rawVoice.contains('tay') || rawVoice.contains('hông')) {
      return 'Duỗi tay sát hông';
    }
    return rawVoice;
  }
}
