// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/pose/vika_pose_landmark.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';
import '../cobra/cobra.dart';
import 'pose_recognizers.dart';
import 'safety_overrides.dart';

class SuryaNamaskarConfig {
  static const int defaultRounds = 1;
  static const int defaultPoseDurationMs = 5000;
  static const int ashtangaDurationMs = 5000;
  static const int recognitionGraceMs = 300;
  static const int poseRecognitionFramesRequired = 6;
  static const int cobraRecognitionFramesRequired = 2;
  static const int maxSafetyTriggersPerRound = 3;
  static const double startPresenceMin = 0.45;
  static const double startVisibilityMin = 0.20;
  static const double startArmVerticalMaxDeviation = 85.0;
  static const double startElbowStraightMin = 105.0;
}

enum SuryaPoseRuntimePhase { waiting, holding }

enum SuryaNamaskarLeadLeg { right, left }

class SuryaNamaskarStep {
  const SuryaNamaskarStep({
    required this.number,
    required this.poseId,
    required this.phaseKey,
    required this.labelVi,
    required this.shortName,
    required this.breath,
    required this.voiceCue,
    this.durationMs = SuryaNamaskarConfig.defaultPoseDurationMs,
    this.isBlank = false,
  });

  final int number;
  final SuryaPoseId poseId;
  final String phaseKey;
  final String labelVi;
  final String shortName;
  final String breath;
  final String voiceCue;
  final int durationMs;
  final bool isBlank;
}

class SuryaNamaskarExercise extends ExerciseBase {
  SuryaNamaskarExercise({
    required int maxRounds,
    this.leadLeg = SuryaNamaskarLeadLeg.right,
  })  : maxRounds = maxRounds < 1 ? 1 : maxRounds,
        _steps = _buildSteps(leadLeg);

  final int maxRounds;
  final SuryaNamaskarLeadLeg leadLeg;

  final List<SuryaNamaskarStep> _steps;

  static List<SuryaNamaskarStep> _buildSteps(SuryaNamaskarLeadLeg leadLeg) {
    final isRightLead = leadLeg == SuryaNamaskarLeadLeg.right;
    return [
      SuryaNamaskarStep(
        number: 1,
        poseId: SuryaPoseId.pranamasana,
        phaseKey: 'surya_pose_1',
        labelVi: 'Tư thế Cầu nguyện',
        shortName: 'Cầu nguyện',
        breath: 'Thở ra',
        voiceCue: 'Đứng thẳng, chắp tay trước ngực. Thở ra một hơi.',
      ),
      SuryaNamaskarStep(
        number: 2,
        poseId: SuryaPoseId.hastaUttanasana,
        phaseKey: 'surya_pose_2',
        labelVi: 'Tư thế Vươn tay',
        shortName: 'Vươn tay',
        breath: 'Hít vào',
        voiceCue: 'Hít vào, vươn tay lên cao, ngả nhẹ.',
      ),
      SuryaNamaskarStep(
        number: 3,
        poseId: SuryaPoseId.uttanasana,
        phaseKey: 'surya_pose_3',
        labelVi: 'Tư thế Gập người',
        shortName: 'Gập người',
        breath: 'Thở ra',
        voiceCue: 'Thở ra, gập người về trước. Gập gối nếu cần.',
      ),
      SuryaNamaskarStep(
        number: 4,
        poseId: isRightLead
            ? SuryaPoseId.lowLungeRightBack
            : SuryaPoseId.lowLungeLeftBack,
        phaseKey: 'surya_pose_4',
        labelVi: isRightLead
            ? 'Tư thế Kỵ sĩ - chân phải sau'
            : 'Tư thế Kỵ sĩ - chân trái sau',
        shortName: isRightLead ? 'Kỵ sĩ phải' : 'Kỵ sĩ trái',
        breath: 'Hít vào',
        voiceCue: isRightLead
            ? 'Hít vào, bước chân phải ra sau, gối phải xuống sàn.'
            : 'Hít vào, bước chân trái ra sau, gối trái xuống sàn.',
      ),
      SuryaNamaskarStep(
        number: 5,
        poseId: SuryaPoseId.highPlankBlank,
        phaseKey: 'surya_pose_5',
        labelVi: 'Tư thế Tấm ván cao',
        shortName: 'Plank cao',
        breath: 'Giữ hơi',
        voiceCue: 'Bước về tấm ván cao, vai trên cổ tay và thân người thẳng.',
      ),
      SuryaNamaskarStep(
        number: 6,
        poseId: SuryaPoseId.ashtangaNamaskara,
        phaseKey: 'surya_pose_6',
        labelVi: 'Tư thế 8 điểm chạm',
        shortName: '8 điểm chạm',
        breath: 'Thở ra',
        voiceCue: 'Thở ra, hạ gối, ngực, cằm. Hông giữ cao.',
        durationMs: SuryaNamaskarConfig.ashtangaDurationMs,
      ),
      SuryaNamaskarStep(
        number: 7,
        poseId: SuryaPoseId.cobra,
        phaseKey: 'surya_pose_7',
        labelVi: 'Tư thế Rắn hổ mang',
        shortName: 'Rắn hổ mang',
        breath: 'Hít vào',
        voiceCue: 'Hít vào, trượt ngực lên thành rắn hổ mang. Ngả nhẹ thôi.',
      ),
      SuryaNamaskarStep(
        number: 8,
        poseId: SuryaPoseId.downwardDog,
        phaseKey: 'surya_pose_8',
        labelVi: 'Tư thế Chó cúi mặt',
        shortName: 'Chó cúi mặt',
        breath: 'Thở ra',
        voiceCue: 'Thở ra, đẩy hông lên cao thành chó cúi mặt.',
      ),
      SuryaNamaskarStep(
        number: 9,
        poseId: isRightLead
            ? SuryaPoseId.lowLungeLeftBack
            : SuryaPoseId.lowLungeRightBack,
        phaseKey: 'surya_pose_9',
        labelVi: isRightLead
            ? 'Tư thế Kỵ sĩ - chân phải lên trước'
            : 'Tư thế Kỵ sĩ - chân trái lên trước',
        shortName: isRightLead ? 'Kỵ sĩ phải' : 'Kỵ sĩ trái',
        breath: 'Hít vào',
        voiceCue: isRightLead
            ? 'Hít vào, bước chân phải lên trước, gối trái xuống sàn.'
            : 'Hít vào, bước chân trái lên trước, gối phải xuống sàn.',
      ),
      SuryaNamaskarStep(
        number: 10,
        poseId: SuryaPoseId.uttanasana,
        phaseKey: 'surya_pose_10',
        labelVi: 'Tư thế Gập người',
        shortName: 'Gập người',
        breath: 'Thở ra',
        voiceCue: isRightLead
            ? 'Thở ra, bước chân trái lên, gập người về trước.'
            : 'Thở ra, bước chân phải lên, gập người về trước.',
      ),
      SuryaNamaskarStep(
        number: 11,
        poseId: SuryaPoseId.hastaUttanasana,
        phaseKey: 'surya_pose_11',
        labelVi: 'Tư thế Vươn tay',
        shortName: 'Vươn tay',
        breath: 'Hít vào',
        voiceCue: 'Hít vào, đứng dậy, vươn tay lên cao, ngả nhẹ.',
      ),
      SuryaNamaskarStep(
        number: 12,
        poseId: SuryaPoseId.pranamasana,
        phaseKey: 'surya_pose_12',
        labelVi: 'Tư thế Cầu nguyện',
        shortName: 'Cầu nguyện',
        breath: 'Thở ra',
        voiceCue: 'Thở ra, chắp tay trước ngực. Hoàn thành vòng.',
      ),
    ];
  }

  final SuryaSafetyOverrides _safetyOverrides = SuryaSafetyOverrides();
  final Set<int> _recognizedPoseNumbers = {};
  final Set<int> _missedPoseNumbers = {};
  final Set<int> _blankPoseNumbers = {};
  final List<int> _poseDurationsMs = [];

  int _poseIndex = -1;
  SuryaPoseRuntimePhase _posePhase = SuryaPoseRuntimePhase.waiting;
  int? _poseStartedMs;
  int _poseHoldAccumulatedMs = 0;
  int? _lastHoldTickMs;
  int? _pauseStartedMs;
  int? _roundStartedMs;
  int _poseRecognitionFrames = 0;
  int _roundSafetyTriggers = 0;
  int _setSafetyTriggers = 0;
  bool _setComplete = false;
  String? _lastSafetyCode;

  @override
  String get exerciseName => 'Surya Namaskar';

  @override
  ExerciseVoiceCoach? createVoiceCoach() => null;

  bool get usesSegmentationPersonGate => false;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get currentPhaseKey {
    if (_setComplete) return 'completed';
    if (_poseIndex < 0 || _poseIndex >= _steps.length) return 'idle';
    return _steps[_poseIndex].phaseKey;
  }

  @override
  String get currentPhaseLabel {
    if (_setComplete) return 'Hoàn thành';
    if (_poseIndex < 0 || _poseIndex >= _steps.length) {
      return 'Giơ hai tay thẳng lên trời';
    }
    final step = _steps[_poseIndex];
    if (_posePhase == SuryaPoseRuntimePhase.waiting) {
      return 'Vào ${step.shortName}';
    }
    return '${step.number}/12 · ${step.shortName}';
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final visibility = _strictStartVisibilityGate(landmarks);
    debugData.addAll(visibility.debugData);
    if (!visibility.ready) return false;

    final raisedArms = _strictRaisedArmsStart(landmarks);
    debugData.addAll(raisedArms.debugData);
    return raisedArms.ready;
  }

  @override
  void onExerciseActivated() {
    _startRound(frameTimestampMs);
  }

  @override
  bool requestStop() => _setComplete;

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return const GuidanceSignal.turnSide();
    }

    if (exerciseState == ExerciseState.notActivated) {
      final visibility = _strictStartVisibilityGate(landmarks);
      debugData.addAll(visibility.debugData);
      if (!visibility.ready) {
        return const GuidanceSignal.bodyInFrame();
      }
    }

    final hasCoreLandmarks = landmarks[PoseLandmarkType.leftShoulder] != null &&
        landmarks[PoseLandmarkType.rightShoulder] != null &&
        landmarks[PoseLandmarkType.leftHip] != null &&
        landmarks[PoseLandmarkType.rightHip] != null;
    if (!hasCoreLandmarks) {
      return const GuidanceSignal.bodyInFrame();
    }

    return null;
  }

  _StartGateResult _strictStartVisibilityGate(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final missing = <String>[];
    final occluded = <String>[];
    const requiredStartLandmarks = <PoseLandmarkType>[
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    for (final type in requiredStartLandmarks) {
      final landmark = landmarks[type];
      if (landmark == null) {
        missing.add(type.name);
        continue;
      }

      final visibleEnough =
          landmark.presence >= SuryaNamaskarConfig.startPresenceMin &&
              landmark.visibility >= SuryaNamaskarConfig.startVisibilityMin &&
              landmark.likelihood >= SuryaNamaskarConfig.startVisibilityMin;
      if (!visibleEnough) {
        occluded.add(type.name);
      }
    }
    if (!_hasVisibleStartChinProxy(landmarks)) {
      missing.add('chin');
    }

    return _StartGateResult(
      ready: missing.isEmpty && occluded.isEmpty,
      debugData: {
        'suryaStartMissingLandmarks': missing.length,
        'suryaStartOccludedLandmarks': occluded.length,
        if (missing.isNotEmpty) 'suryaStartFirstMissing': missing.first,
        if (occluded.isNotEmpty) 'suryaStartFirstOccluded': occluded.first,
      },
    );
  }

  bool _hasVisibleStartChinProxy(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    return _isStartLandmarkVisible(landmarks[PoseLandmarkType.leftMouth]) ||
        _isStartLandmarkVisible(landmarks[PoseLandmarkType.rightMouth]) ||
        _isStartLandmarkVisible(landmarks[PoseLandmarkType.nose]);
  }

  bool _isStartLandmarkVisible(PoseLandmark? landmark) {
    if (landmark == null) return false;
    return landmark.presence >= SuryaNamaskarConfig.startPresenceMin &&
        landmark.visibility >= SuryaNamaskarConfig.startVisibilityMin &&
        landmark.likelihood >= SuryaNamaskarConfig.startVisibilityMin;
  }

  _StartGateResult _strictRaisedArmsStart(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null) {
      return const _StartGateResult(ready: false);
    }

    final leftElbowAngle = calculateAngle(
      firstPoint: leftShoulder,
      midPoint: leftElbow,
      lastPoint: leftWrist,
    );
    final rightElbowAngle = calculateAngle(
      firstPoint: rightShoulder,
      midPoint: rightElbow,
      lastPoint: rightWrist,
    );
    final leftArmClock = calculateVerticalAngle(
      pivot: leftShoulder,
      point: leftWrist,
    );
    final rightArmClock = calculateVerticalAngle(
      pivot: rightShoulder,
      point: rightWrist,
    );
    final leftArmVertical = clockAngleDeviation(leftArmClock, 0.0).abs();
    final rightArmVertical = clockAngleDeviation(rightArmClock, 0.0).abs();
    final leftTorso = calculateDistance(leftShoulder, leftHip);
    final rightTorso = calculateDistance(rightShoulder, rightHip);
    final leftWristRaised = leftWrist.y < leftShoulder.y + leftTorso * 0.15;
    final rightWristRaised = rightWrist.y < rightShoulder.y + rightTorso * 0.15;
    final shouldersAboveHips =
        leftShoulder.y < leftHip.y && rightShoulder.y < rightHip.y;

    final elbowsOpenEnough =
        leftElbowAngle >= SuryaNamaskarConfig.startElbowStraightMin &&
            rightElbowAngle >= SuryaNamaskarConfig.startElbowStraightMin;
    final armsRaisedEnough = leftArmVertical <=
            SuryaNamaskarConfig.startArmVerticalMaxDeviation &&
        rightArmVertical <= SuryaNamaskarConfig.startArmVerticalMaxDeviation;

    return _StartGateResult(
      ready: leftWristRaised &&
          rightWristRaised &&
          shouldersAboveHips &&
          elbowsOpenEnough &&
          armsRaisedEnough,
      debugData: {
        'suryaStartLeftWristRaised': leftWristRaised,
        'suryaStartRightWristRaised': rightWristRaised,
        'suryaStartShouldersAboveHips': shouldersAboveHips,
        'suryaStartLeftElbow': leftElbowAngle.toStringAsFixed(1),
        'suryaStartRightElbow': rightElbowAngle.toStringAsFixed(1),
        'suryaStartLeftArmVertical': leftArmVertical.toStringAsFixed(1),
        'suryaStartRightArmVertical': rightArmVertical.toStringAsFixed(1),
      },
    );
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (_setComplete) return;
    if (_poseIndex < 0) _startRound(frameTimestampMs);
    if (_poseIndex >= _steps.length) return;

    resultIssues.phaseStatus.clear();

    final step = _steps[_poseIndex];
    final nowMs = frameTimestampMs;
    final startedMs = _poseStartedMs ?? nowMs;
    final elapsedSinceEntryMs = nowMs - startedMs;

    if (step.isBlank) {
      _blankPoseNumbers.add(step.number);
      if (_posePhase == SuryaPoseRuntimePhase.waiting) {
        _startPoseHold(step, nowMs, announce: false);
      }
      _tickPoseHold(isStillRecognized: true, timestampMs: nowMs);
      _updateFlowInstructions(
        step: step,
        elapsedSinceEntryMs: elapsedSinceEntryMs,
        recognized: true,
        hint: 'High Plank đang để trống, flow vẫn tiếp tục.',
      );
      _maybeCompleteHoldingPose(step, nowMs);
      _populateDebug(step, elapsedSinceEntryMs);
      return;
    }

    final safety = _safetyOverrides.evaluate(
      poseId: step.poseId,
      landmarks: smoothedLandmarks,
      cameraFacing: cameraFacing,
    );
    debugData.addAll(safety.debugData);
    if (safety.triggered) {
      _handleSafetyTrigger(safety, nowMs);
      _updateFlowInstructions(
        step: step,
        elapsedSinceEntryMs: elapsedSinceEntryMs,
        recognized: _recognizedPoseNumbers.contains(step.number),
        hint: safety.message,
      );
      _populateDebug(step, elapsedSinceEntryMs);
      return;
    }
    _lastSafetyCode = null;

    final recognition = SuryaPoseRecognizers.recognize(
      poseId: step.poseId,
      landmarks: smoothedLandmarks,
      cameraFacing: cameraFacing,
    );
    debugData.addAll(recognition.debugData);

    if (_posePhase == SuryaPoseRuntimePhase.waiting) {
      final canRecognize =
          elapsedSinceEntryMs >= SuryaNamaskarConfig.recognitionGraceMs;
      if (canRecognize && recognition.recognized) {
        _poseRecognitionFrames += 1;
        if (_poseRecognitionFrames >= _recognitionFramesRequired(step)) {
          _startPoseHold(step, nowMs);
        }
      } else {
        _poseRecognitionFrames = 0;
      }
    } else {
      final isStillRecognized = recognition.recognized ||
          _continuesStandaloneCobraHold(step, smoothedLandmarks);
      _tickPoseHold(
        isStillRecognized: isStillRecognized,
        timestampMs: nowMs,
      );
    }

    final effectiveRecognized = _posePhase == SuryaPoseRuntimePhase.holding
        ? recognition.recognized ||
            _continuesStandaloneCobraHold(step, smoothedLandmarks)
        : recognition.recognized;

    _updateFlowInstructions(
      step: step,
      elapsedSinceEntryMs: elapsedSinceEntryMs,
      recognized: _recognizedPoseNumbers.contains(step.number),
      hint: _posePhase == SuryaPoseRuntimePhase.holding && !effectiveRecognized
          ? 'Giữ lại đúng tư thế để AI tiếp tục đếm.'
          : recognition.hint,
    );
    _maybeCompleteHoldingPose(step, nowMs);
    _populateDebug(step, elapsedSinceEntryMs);
  }

  int _recognitionFramesRequired(SuryaNamaskarStep step) {
    return step.poseId == SuryaPoseId.cobra
        ? SuryaNamaskarConfig.cobraRecognitionFramesRequired
        : SuryaNamaskarConfig.poseRecognitionFramesRequired;
  }

  bool _continuesStandaloneCobraHold(
    SuryaNamaskarStep step,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    if (step.poseId != SuryaPoseId.cobra ||
        _posePhase != SuryaPoseRuntimePhase.holding) {
      return false;
    }

    final shoulder = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    if (shoulder == null || hip == null) return false;

    final trunkClock = calculateVerticalAngle(pivot: hip, point: shoulder);
    final horizontalTarget = cameraFacing == CameraFacing.right
        ? CobraConfig.HORIZONTAL_CLOCK_RIGHT
        : CobraConfig.HORIZONTAL_CLOCK_LEFT;
    final trunkDeviation = clockAngleDeviation(trunkClock, horizontalTarget);
    final stillInCobraHold =
        trunkDeviation.abs() >= CobraConfig.PRONE_TOLERANCE;
    debugData['suryaCobraHoldContinuation'] = stillInCobraHold;
    debugData['suryaCobraHoldDeviation'] = trunkDeviation.toStringAsFixed(1);
    return stillInCobraHold;
  }

  @override
  void manualPause() {
    _pauseStartedMs ??= DateTime.now().millisecondsSinceEpoch;
    super.manualPause();
  }

  @override
  void manualResume() {
    final pauseStarted = _pauseStartedMs;
    if (pauseStarted != null && _poseStartedMs != null) {
      final pauseDurationMs =
          DateTime.now().millisecondsSinceEpoch - pauseStarted;
      _poseStartedMs = _poseStartedMs! + pauseDurationMs;
    }
    _pauseStartedMs = null;
    _lastHoldTickMs = DateTime.now().millisecondsSinceEpoch;
    _lastSafetyCode = null;
    _safetyOverrides.clear();
    super.manualResume();
  }

  @override
  void onSetComplete() {
    logger.pushGoodRepCount();
    logger.pushKey('max_rounds', maxRounds);
    logger.pushKey('max_rep', maxRounds);
    logger.pushKey('total_safety_triggers', _setSafetyTriggers);
    logger.pushAverage('recognized_poses', 'avg_recognized_poses');
    logger.pushAverage('missed_poses', 'avg_missed_poses');
    logger.pushAverage(
        'smoothness_variance_ms2', 'avg_smoothness_variance_ms2');
  }

  void _startRound(int timestampMs) {
    _recognizedPoseNumbers.clear();
    _missedPoseNumbers.clear();
    _blankPoseNumbers.clear();
    _poseDurationsMs.clear();
    _roundSafetyTriggers = 0;
    _lastSafetyCode = null;
    _roundStartedMs = timestampMs;
    _enterPose(0, timestampMs);
  }

  void _enterPose(
    int index,
    int timestampMs, {
    bool announce = true,
  }) {
    _poseIndex = index;
    _posePhase = SuryaPoseRuntimePhase.waiting;
    _poseStartedMs = timestampMs;
    _poseHoldAccumulatedMs = 0;
    _lastHoldTickMs = null;
    _poseRecognitionFrames = 0;
    final step = _steps[_poseIndex];
    _safetyOverrides.resetForPose(step.poseId);
    if (announce) _speakPoseCue(step);
  }

  void _speakPoseCue(SuryaNamaskarStep step) {
    ttsService.clearQueue();
    ttsService.speak(step.voiceCue);
  }

  void _startPoseHold(
    SuryaNamaskarStep step,
    int timestampMs, {
    bool announce = true,
  }) {
    if (_posePhase == SuryaPoseRuntimePhase.holding) return;
    _posePhase = SuryaPoseRuntimePhase.holding;
    _poseHoldAccumulatedMs = 0;
    _lastHoldTickMs = timestampMs;
    if (step.isBlank) {
      _blankPoseNumbers.add(step.number);
    } else {
      _recognizedPoseNumbers.add(step.number);
    }

    if (announce) {
      ttsService.clearPendingButKeepCurrent();
      ttsService.speak(
        'Đúng tư thế. Giữ ${(step.durationMs / 1000).round()} giây.',
      );
    }
  }

  void _tickPoseHold({
    required bool isStillRecognized,
    required int timestampMs,
  }) {
    final lastTick = _lastHoldTickMs ?? timestampMs;
    final deltaMs = timestampMs - lastTick;
    if (isStillRecognized && deltaMs > 0) {
      _poseHoldAccumulatedMs += deltaMs.clamp(0, 250);
    }
    _lastHoldTickMs = timestampMs;
  }

  void _maybeCompleteHoldingPose(SuryaNamaskarStep step, int timestampMs) {
    if (_posePhase != SuryaPoseRuntimePhase.holding) return;
    if (_poseHoldAccumulatedMs < step.durationMs) return;

    _poseDurationsMs.add(timestampMs - (_poseStartedMs ?? timestampMs));

    final nextIndex = _poseIndex + 1;
    if (nextIndex >= _steps.length) {
      _completeRound(timestampMs);
      return;
    }

    final nextStep = _steps[nextIndex];
    _speakPoseCompletion(step, nextStep);
    _enterPose(nextIndex, timestampMs, announce: false);
  }

  void _speakPoseCompletion(
    SuryaNamaskarStep completed,
    SuryaNamaskarStep next,
  ) {
    ttsService.clearPendingButKeepCurrent();
    ttsService.speak('Hoàn thành ${completed.shortName}.');
    ttsService.speak('Tiếp theo ${next.shortName}.');
    ttsService.speak(next.voiceCue);
  }

  void _handleSafetyTrigger(SuryaSafetyResult safety, int timestampMs) {
    if (_lastSafetyCode == safety.code) return;

    _lastSafetyCode = safety.code;
    _roundSafetyTriggers += 1;
    _setSafetyTriggers += 1;

    final message = safety.message ?? 'Cẩn thận, dừng lại và ổn định tư thế.';
    resultIssues.feedback['System'] = '⚠️ $message';
    ttsService.clearQueue();
    ttsService.speak(message);

    if (_roundSafetyTriggers >= SuryaNamaskarConfig.maxSafetyTriggersPerRound) {
      ttsService.speak('Bài sẽ chờ bạn chỉnh lại tư thế, không tự kết thúc.');
    }
  }

  void _completeRound(int timestampMs) {
    final checkablePoseCount = _steps.where((step) => !step.isBlank).length;
    final recognizedCount = _recognizedPoseNumbers.length;
    _missedPoseNumbers
      ..clear()
      ..addAll(
        _steps
            .where((step) =>
                !step.isBlank && !_recognizedPoseNumbers.contains(step.number))
            .map((step) => step.number),
      );
    final missedCount = _missedPoseNumbers.length;
    final roundDurationMs = timestampMs - (_roundStartedMs ?? timestampMs);
    final smoothnessVariance = _variance(_poseDurationsMs);

    correctForm = _roundSafetyTriggers == 0 && missedCount == 0;
    repCount += 1;

    logger.addRepLog(
      RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          'recognized_poses': recognizedCount,
          'checkable_poses': checkablePoseCount,
          'missed_poses': missedCount,
          'blank_poses': _blankPoseNumbers.length,
          'safety_triggers': _roundSafetyTriggers,
          'smoothness_variance_ms2': smoothnessVariance,
          'duration_ms': roundDurationMs,
        },
      ),
    );

    setFeedback.add({
      correctForm: {
        'flow': {
          'recognized': '$recognizedCount/$checkablePoseCount',
          'missed': '$missedCount',
          'blank': '${_blankPoseNumbers.length}',
          'safety': '$_roundSafetyTriggers',
        },
      },
    });

    resultIssues.feedback['Result'] = correctForm
        ? 'Hoàn thành vòng Chào Mặt Trời'
        : 'Hoàn thành vòng, cần chậm và an toàn hơn';

    if (repCount >= maxRounds) {
      _setComplete = true;
      ttsService.clearQueue();
      ttsService.speak('Hoàn thành bài tập');
      return;
    }

    _startRound(timestampMs);
  }

  void _updateFlowInstructions({
    required SuryaNamaskarStep step,
    required int elapsedSinceEntryMs,
    required bool recognized,
    String? hint,
  }) {
    final isHolding = _posePhase == SuryaPoseRuntimePhase.holding;
    final progress = isHolding
        ? (_poseHoldAccumulatedMs / step.durationMs).clamp(0.0, 1.0).toDouble()
        : (_poseRecognitionFrames / _recognitionFramesRequired(step))
            .clamp(0.0, 1.0)
            .toDouble();
    final remainingSec = isHolding
        ? ((step.durationMs - _poseHoldAccumulatedMs)
                .clamp(0, step.durationMs)) /
            1000.0
        : null;
    final status = isHolding
        ? 'Giữ! ${remainingSec!.toStringAsFixed(1)}s · ${step.number}/12'
        : 'Vào ${step.shortName} · ${step.number}/12';

    resultIssues.setPhaseStatus(step.phaseKey, status);

    resultIssues.feedback['Flow'] =
        '${step.number}/12 · ${step.shortName} · ${step.breath}';
    resultIssues.feedback['Recognized'] =
        recognized ? 'Đã nhận tư thế, đang đếm' : 'Chờ vào đúng tư thế';

    debugData['holdProgress'] = progress;
    debugData['bottomHoldProgress'] = progress;
  }

  void _populateDebug(SuryaNamaskarStep step, int elapsedMs) {
    debugData['suryaPoseIndex'] = step.number;
    debugData['suryaPoseName'] = step.shortName;
    debugData['suryaPosePhase'] = _posePhase.name;
    debugData['suryaPoseElapsedMs'] = elapsedMs;
    debugData['suryaPoseHoldMs'] = _poseHoldAccumulatedMs;
    debugData['suryaPoseRecognitionFrames'] = _poseRecognitionFrames;
    debugData['suryaRecognizedCount'] = _recognizedPoseNumbers.length;
    debugData['suryaMissedCount'] = _missedPoseNumbers.length;
    debugData['suryaBlankCount'] = _blankPoseNumbers.length;
    debugData['suryaRoundSafetyTriggers'] = _roundSafetyTriggers;
    debugData['suryaMaxRounds'] = maxRounds;
  }

  double _variance(List<int> values) {
    if (values.length < 2) return 0.0;
    final average = values.reduce((a, b) => a + b) / values.length;
    var sum = 0.0;
    for (final value in values) {
      final delta = value - average;
      sum += delta * delta;
    }
    return sum / values.length;
  }
}

// ignore: unused_element
class _SuryaFlowVoiceCoach implements ExerciseVoiceCoach {
  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {}

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return Future<void>.value();
  }

  @override
  void dispose() {}
}

class _StartGateResult {
  const _StartGateResult({
    required this.ready,
    this.debugData = const {},
  });

  final bool ready;
  final Map<String, dynamic> debugData;
}
