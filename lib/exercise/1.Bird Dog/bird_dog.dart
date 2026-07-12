// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';
import 'metrics/bird_dog_metric_base.dart';
import 'metrics/lumbar_extension_metric.dart';
import 'metrics/alignment_metric.dart';
import 'metrics/trunk_stability_metric.dart';
import 'metrics/tempo_metric.dart';

class BirdDogConfig {
  static const int TIMEOUT_MS = 90000;

  static const double START_KNEE_MIN = 30;
  static const double START_KNEE_MAX = 150;
  static const double START_ARM_MIN = 30;
  static const double START_ARM_MAX = 150;
  static const double START_TRUNK_HORIZ_MAX = 30;

  static const double EXTENDING_KNEE_START = 110;
  static const double HOLD_KNEE_THRESHOLD = 145;
  static const double HOLD_ARM_THRESHOLD = 135;
  static const double RETURNING_KNEE_THRESHOLD = 138;
  static const double NEUTRAL_KNEE_THRESHOLD = 120;
  static const double HOLD_TARGET_SECONDS = BirdDogTiming.holdTargetSeconds;
}

class BirdDog extends ExerciseBase {
  static const List<String> _voiceFaultIds = [
    'opposite_side',
    'alternate',
    'alignment',
    'head',
    'lumbar',
    'hold',
    'trunk',
  ];

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
  final Debouncer _extendingDebouncer = Debouncer(requiredFrames: 2);

  List<String> lastRepFaultVoiceMessages = [];
  String? lastRepTopVoiceMessage;
  int? lastRepTopVoicePriority;
  bool lastRepWasClean = true;
  int invalidAttemptCount = 0;

  // Biến Snapshot: Chỉ lưu tay/chân đang thao tác ở đúng đỉnh của rep
  bool? _peakLeftLeg;
  bool? _peakLeftArm;
  bool? _lastPeakLeftLeg;
  bool? _lastPeakLeftArm;

  BirdDog({required this.maxRep}) : super(targetReps: maxRep);

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Bird Dog';

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'bird_dog',
        faultIds: _voiceFaultIds,
        reminderPools: const {
          'lumbar': ['bird_dog.lumbar_reminder'],
        },
        repStartPhaseKeys: const {'extending'},
      ),
      targetReps: targetReps,
      coach: VoiceCoach(
        sink: AssetVoiceSink(),
        policy: VoicePolicy(),
      ),
    );
  }

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case BirdDogState.neutral:
        return 'Chuẩn bị';
      case BirdDogState.extending:
        return 'Đang duỗi';
      case BirdDogState.hold_extended:
        return 'Giữ ${BirdDogTiming.holdTargetShortLabel}!';
      case BirdDogState.returning:
        return 'Thu về';
    }
  }

  @override
  double? get liveHoldSeconds =>
      state == BirdDogState.hold_extended && tempoMetric.holdStartMs != null
          ? (frameTimestampMs - tempoMetric.holdStartMs!) / 1000.0
          : null;

  @override
  double? get liveHoldTargetSeconds => BirdDogConfig.HOLD_TARGET_SECONDS;

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return const GuidanceSignal.turnSide();
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    bool checkSide(PoseLandmark? shoulder, PoseLandmark? hip,
        PoseLandmark? knee, PoseLandmark? ankle, PoseLandmark? wrist) {
      if (shoulder == null ||
          hip == null ||
          knee == null ||
          ankle == null ||
          wrist == null) return false;
      if (![shoulder, hip, knee, ankle, wrist]
          .every(ExerciseBase.isLandmarkConfident)) {
        return false;
      }

      // Ensure the user is facing down (wrist below shoulder, knee below hip)
      if (wrist.y < shoulder.y) return false;
      if (knee.y < hip.y) return false;

      double kneeAngle = calculateAngleNormalized(
          firstPoint: hip, midPoint: knee, lastPoint: ankle);
      double armAngle = calculateAngleNormalized(
          firstPoint: hip, midPoint: shoulder, lastPoint: wrist);
      double trunkHoriz = calculateAbsoluteHorizontalAngle(
        point1: shoulder,
        point2: hip,
      );

      if (kneeAngle < BirdDogConfig.START_KNEE_MIN ||
          kneeAngle > BirdDogConfig.START_KNEE_MAX) return false;
      if (armAngle < BirdDogConfig.START_ARM_MIN ||
          armAngle > BirdDogConfig.START_ARM_MAX) return false;
      if (trunkHoriz > BirdDogConfig.START_TRUNK_HORIZ_MAX) return false;
      return true;
    }

    bool isLeftValid = checkSide(
        landmarks[PoseLandmarkType.leftShoulder],
        landmarks[PoseLandmarkType.leftHip],
        landmarks[PoseLandmarkType.leftKnee],
        landmarks[PoseLandmarkType.leftAnkle],
        landmarks[PoseLandmarkType.leftWrist]);
    bool isRightValid = checkSide(
        landmarks[PoseLandmarkType.rightShoulder],
        landmarks[PoseLandmarkType.rightHip],
        landmarks[PoseLandmarkType.rightKnee],
        landmarks[PoseLandmarkType.rightAnkle],
        landmarks[PoseLandmarkType.rightWrist]);

    return isLeftValid || isRightValid;
  }

  @override
  bool requestStop() {
    if (_timeoutReached) return true;
    return repCount >= maxRep;
  }

  @override
  void onSetComplete() {
    logger.pushKey("max_rep", maxRep);
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
        resultIssues.setPhaseStatus('TIMEOUT', 'Đang lưu kết quả...');
      }
      return;
    }

    // --- XÁC ĐỊNH CHÂN (Live Data) ---
    final requiredTypes = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ];
    final requiredLandmarks =
        requiredTypes.map((type) => landmarks[type]).toList();
    if (requiredLandmarks.any((landmark) =>
        landmark == null || !ExerciseBase.isLandmarkConfident(landmark))) {
      if (state != BirdDogState.neutral) {
        _rejectAttempt(
          FaultRecord(
            phase: state.name,
            type: 'MissingBody',
            message: 'Mất mốc cơ thể',
            voiceMessage: 'Giữ cả người trong khung hình.',
            affectsForm: true,
            priority: BirdDogFaultPriority.alignment,
          ),
          transitionToNeutralAtMs: now,
        );
      }
      return;
    }

    final leftKneeAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.leftHip]!,
        midPoint: landmarks[PoseLandmarkType.leftKnee]!,
        lastPoint: landmarks[PoseLandmarkType.leftAnkle]!);
    final rightKneeAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.rightHip]!,
        midPoint: landmarks[PoseLandmarkType.rightKnee]!,
        lastPoint: landmarks[PoseLandmarkType.rightAnkle]!);

    // --- XÁC ĐỊNH TAY (Live Data) ---
    final leftArmAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.leftHip]!,
        midPoint: landmarks[PoseLandmarkType.leftShoulder]!,
        lastPoint: landmarks[PoseLandmarkType.leftWrist]!);
    final rightArmAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.rightHip]!,
        midPoint: landmarks[PoseLandmarkType.rightShoulder]!,
        lastPoint: landmarks[PoseLandmarkType.rightWrist]!);

    // ML Kit Label có thể bị sai. Tạm thời xác định "cái nào đang giơ lên" dựa vào nhãn hiện tại
    bool mlKitActiveLegIsLeft = leftKneeAngle > rightKneeAngle;
    bool mlKitActiveArmIsLeft = leftArmAngle > rightArmAngle;

    double activeKneeAngle =
        mlKitActiveLegIsLeft ? leftKneeAngle : rightKneeAngle;
    double activeArmAngle = mlKitActiveArmIsLeft ? leftArmAngle : rightArmAngle;
    double nonActiveKneeAngle =
        mlKitActiveLegIsLeft ? rightKneeAngle : leftKneeAngle;

    PoseLandmark activeAnkle = mlKitActiveLegIsLeft
        ? landmarks[PoseLandmarkType.leftAnkle]!
        : landmarks[PoseLandmarkType.rightAnkle]!;
    PoseLandmark activeWrist = mlKitActiveArmIsLeft
        ? landmarks[PoseLandmarkType.leftWrist]!
        : landmarks[PoseLandmarkType.rightWrist]!;

    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;
    bool activeLegLabelIsLeft =
        isPhysicalLeftSide(activeAnkle, leftHip, rightHip);
    bool activeArmLabelIsLeft =
        isPhysicalLeftSide(activeWrist, leftShoulder, rightShoulder);

    // --- SNAPSHOT DATA (Chỉ chốt số liệu tay chân khi đang ở đỉnh rep) ---
    if (state == BirdDogState.hold_extended) {
      _peakLeftLeg = activeLegLabelIsLeft;
      _peakLeftArm = activeArmLabelIsLeft;
    }

    // --- EVALUATION DATA (Dữ liệu chống nhiễu dùng để chấm điểm) ---
    bool evalLeftLeg =
        (state == BirdDogState.returning || state == BirdDogState.neutral) &&
                _peakLeftLeg != null
            ? _peakLeftLeg!
            : activeLegLabelIsLeft;

    bool evalLeftArm =
        (state == BirdDogState.returning || state == BirdDogState.neutral) &&
                _peakLeftArm != null
            ? _peakLeftArm!
            : activeArmLabelIsLeft;

    // Không còn bắt lỗi Push-up (Plank) quá gắt vì góc chéo 45 độ làm biến dạng hình chiếu 2D của chân trụ
    // Vẫn giữ lại safety catch nếu cần nhưng nới lỏng
    if (nonActiveKneeAngle > 150 && state != BirdDogState.neutral) {
      _rejectAttempt(
        FaultRecord(
          phase: state.name,
          type: 'Plank',
          message: 'Sai tư thế, đang chuyển sang plank',
          voiceMessage:
              'Chống hai tay và hai gối. Tay dưới vai, gối dưới hông, lưng phẳng.',
          affectsForm: true,
          priority: BirdDogFaultPriority.alignment,
        ),
        transitionToNeutralAtMs: now,
      );
      return;
    }

    bool isSameSide = (evalLeftLeg == evalLeftArm);

    // Vẫn lấy dữ liệu bằng ML Kit labels cho việc render (nếu có)
    final hip = landmarks[mlKitActiveLegIsLeft
        ? PoseLandmarkType.leftHip
        : PoseLandmarkType.rightHip]!;
    final ankle = activeAnkle;
    final shoulder = landmarks[mlKitActiveArmIsLeft
        ? PoseLandmarkType.leftShoulder
        : PoseLandmarkType.rightShoulder]!;
    final wrist = activeWrist;
    final ear = landmarks[mlKitActiveArmIsLeft
            ? PoseLandmarkType.leftEar
            : PoseLandmarkType.rightEar] ??
        landmarks[PoseLandmarkType.leftEar] ??
        landmarks[PoseLandmarkType.rightEar] ??
        shoulder;

    scaleFactor = calculateDistance(shoulder, hip);

    double shaAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double trunkHoriz =
        calculateAbsoluteHorizontalAngle(point1: shoulder, point2: hip);
    double armHoriz =
        calculateAbsoluteHorizontalAngle(point1: shoulder, point2: wrist);
    double legHoriz =
        calculateAbsoluteHorizontalAngle(point1: hip, point2: ankle);

    final ctx = BirdDogRepContext(
      activeKneeAngle: activeKneeAngle,
      nonActiveKneeAngle: nonActiveKneeAngle,
      activeArmAngle: activeArmAngle,
      shoulderHipAnkleAngle: shaAngle,
      trunkHorizontalAngle: trunkHoriz,
      activeArmHorizontalAngle: armHoriz,
      activeLegHorizontalAngle: legHoriz,
      hipY: hip.y,
      activeAnkleY: ankle.y,
      earY: ear.y,
      shoulderY: shoulder.y,
      scaleFactor: scaleFactor,
      isLeftLegActive: evalLeftLeg,
      isLeftArmActive: evalLeftArm,
      isSameSide: isSameSide,
      state: state,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    debugData['birdDogState'] = state.name;
    debugData['previousBirdDogState'] = previousState.name;
    debugData['activeKneeAngle'] = activeKneeAngle;
    debugData['activeArmAngle'] = activeArmAngle;
    debugData['nonActiveKneeAngle'] = nonActiveKneeAngle;
    debugData['trunkHorizontalAngle'] = trunkHoriz;
    debugData['activeArmHorizontalAngle'] = armHoriz;
    debugData['activeLegHorizontalAngle'] = legHoriz;
    debugData['shoulderHipAnkleAngle'] = shaAngle;
    debugData['isSameSide'] = isSameSide;
    debugData['evalLeftLeg'] = evalLeftLeg;
    debugData['evalLeftArm'] = evalLeftArm;
    debugData['peakLeftLeg'] = _peakLeftLeg;
    debugData['peakLeftArm'] = _peakLeftArm;
    debugData['lastPeakLeftLeg'] = _lastPeakLeftLeg;
    debugData['lastPeakLeftArm'] = _lastPeakLeftArm;

    _updateStateMachine(activeKneeAngle, activeArmAngle, now);
    debugData['birdDogState'] = state.name;
    debugData['previousBirdDogState'] = previousState.name;

    // --- HIỆN ĐỒNG HỒ ĐẾM NGƯỢC 5S CHO UI ---
    if (state == BirdDogState.hold_extended &&
        tempoMetric.holdStartMs != null) {
      double elapsed = (now - tempoMetric.holdStartMs!) / 1000.0;
      double progress =
          (elapsed / BirdDogConfig.HOLD_TARGET_SECONDS).clamp(0.0, 1.0);
      resultIssues.feedback['progress'] = progress.toStringAsFixed(2);

      if (progress < 1.0) {
        // Legacy UI instruction copy: Giữ: ${elapsed.toStringAsFixed(1)}s
      } else {
        // Legacy UI instruction copy: Tốt! Hạ chân xuống
      }
    } else {
      resultIssues.feedback['progress'] = '0.0';
    }

    if (state == BirdDogState.neutral &&
        previousState == BirdDogState.returning) {
      _completeRep(ctx);
      previousState = BirdDogState.neutral;
      return;
    }

    for (var i = 0; i < _metrics.length; i++) {
      _metrics[i].update(ctx);
    }
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(double kneeAngle, double armAngle, int now) {
    if (_extendingDebouncer.update(state == BirdDogState.neutral &&
        kneeAngle > BirdDogConfig.EXTENDING_KNEE_START)) {
      _transitionState(BirdDogState.extending, now);
    } else if (_holdDebouncer.update(state == BirdDogState.extending &&
        kneeAngle > BirdDogConfig.HOLD_KNEE_THRESHOLD &&
        armAngle > BirdDogConfig.HOLD_ARM_THRESHOLD)) {
      _transitionState(BirdDogState.hold_extended, now);
    } else if (state == BirdDogState.extending &&
        kneeAngle < BirdDogConfig.NEUTRAL_KNEE_THRESHOLD) {
      // FIX DEADLOCK: Đang giơ lên mà rớt xuống luôn thì clear về chuẩn bị
      _transitionState(BirdDogState.neutral, now);
      _peakLeftLeg = null;
      _peakLeftArm = null;
    } else if (_returningDebouncer.update(state == BirdDogState.hold_extended &&
        kneeAngle < BirdDogConfig.RETURNING_KNEE_THRESHOLD)) {
      final holdSeconds = tempoMetric.holdStartMs == null
          ? 0.0
          : (now - tempoMetric.holdStartMs!) / 1000.0;
      if (holdSeconds < BirdDogConfig.HOLD_TARGET_SECONDS) {
        _rejectAttempt(
          _shortHoldFault(holdSeconds),
          transitionToNeutralAtMs: now,
        );
      } else {
        _transitionState(BirdDogState.returning, now);
      }
    } else if (_neutralDebouncer.update(state == BirdDogState.returning &&
        kneeAngle < BirdDogConfig.NEUTRAL_KNEE_THRESHOLD)) {
      _transitionState(BirdDogState.neutral, now);
    }
  }

  void _transitionState(BirdDogState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    for (var metric in _metrics)
      metric.onStateTransition(previousState, newState, now);
  }

  void _completeRep(BirdDogRepContext ctx) {
    final blockingFault = _blockingFaultFor(ctx);
    if (blockingFault != null) {
      _rejectAttempt(blockingFault);
      return;
    }

    tempoMetric.evaluateRep(ctx);
    FaultRecord? tempoFault;
    for (final fault in tempoMetric.faults) {
      if (fault.type == 'hold') {
        tempoFault = fault;
        break;
      }
    }
    if (tempoFault != null) {
      _rejectAttempt(tempoFault);
      return;
    }

    repCount++;

    final allFaults = <FaultRecord>[];
    for (var metric in _metrics) allFaults.addAll(metric.faults);

    final voicedFaults = _orderedVoicedFaults(allFaults);
    lastRepFaultVoiceMessages = _orderedUniqueVoiceMessages(voicedFaults);
    lastRepTopVoiceMessage =
        voicedFaults.isEmpty ? null : voicedFaults.first.voiceMessage;
    lastRepTopVoicePriority =
        voicedFaults.isEmpty ? null : voicedFaults.first.priority;

    _lastPeakLeftLeg = ctx.isLeftLegActive;
    _lastPeakLeftArm = ctx.isLeftArmActive;

    correctForm = !allFaults.any((f) => f.affectsForm);
    lastRepWasClean = correctForm;
    if (!correctForm) resultIssues.feedback['Result'] = 'Sai Form';

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
      "hold_time": tempoMetric.holdDuration ?? 0,
      "fault_types": allFaults.map((e) => e.type).toSet().toList(),
      "fault_affects_form": faultAffectsForm,
      "fault_priorities": faultPriorities,
    }));

    _resetRepState();
  }

  List<FaultRecord> _orderedVoicedFaults(Iterable<FaultRecord> faults) {
    final voicedFaults = faults
        .where((fault) =>
            fault.voiceMessage != null && fault.voiceMessage!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.type.compareTo(b.type);
      });
    return voicedFaults;
  }

  List<String> _orderedUniqueVoiceMessages(Iterable<FaultRecord> faults) {
    final messages = <String>[];
    final seen = <String>{};
    for (final fault in faults) {
      final message = fault.voiceMessage!.trim();
      if (seen.add(message)) {
        messages.add(message);
      }
    }
    return messages;
  }

  FaultRecord _shortHoldFault(double holdSeconds) {
    return FaultRecord(
      phase: state.name,
      type: 'hold',
      message:
          'Giữ chưa đủ ${BirdDogTiming.holdTargetShortLabel} (${holdSeconds.toStringAsFixed(1)}s)',
      voiceMessage:
          'Giữ ${BirdDogTiming.holdTargetVoiceLabel} ở điểm cao nhất.',
      affectsForm: true,
      priority: BirdDogFaultPriority.tempo,
    );
  }

  void _rejectAttempt(
    FaultRecord fault, {
    int? transitionToNeutralAtMs,
  }) {
    lastRepFaultVoiceMessages = [fault.voiceMessage ?? fault.message];
    lastRepTopVoiceMessage = fault.voiceMessage ?? fault.message;
    lastRepTopVoicePriority = fault.priority;
    lastRepWasClean = false;
    invalidAttemptCount++;
    _publishBlockingFault(fault);
    if (transitionToNeutralAtMs != null && state != BirdDogState.neutral) {
      _transitionState(BirdDogState.neutral, transitionToNeutralAtMs);
      previousState = BirdDogState.neutral;
    }
    _resetRepState();
  }

  FaultRecord? _blockingFaultFor(BirdDogRepContext ctx) {
    if (ctx.isSameSide) {
      return FaultRecord(
        phase: ctx.state.name,
        type: 'opposite_side',
        message: 'Không cùng tay cùng chân',
        voiceMessage: 'Giơ tay và chân đối diện.',
        affectsForm: true,
        priority: BirdDogFaultPriority.alignment,
      );
    }

    final hasPreviousRep = _lastPeakLeftLeg != null && _lastPeakLeftArm != null;
    final repeatedLeg =
        hasPreviousRep && _lastPeakLeftLeg == ctx.isLeftLegActive;
    final repeatedArm =
        hasPreviousRep && _lastPeakLeftArm == ctx.isLeftArmActive;

    if (repeatedLeg || repeatedArm) {
      return FaultRecord(
        phase: ctx.state.name,
        type: 'alternate',
        message: 'Chưa luân phiên tay và chân',
        voiceMessage: 'Đổi sang bên còn lại.',
        affectsForm: true,
        priority: BirdDogFaultPriority.alignment,
      );
    }

    return null;
  }

  void _publishBlockingFault(FaultRecord fault) {
    resultIssues.feedback['Result'] = 'Không tính rep';
    resultIssues.feedback['Error'] = fault.message;
  }

  void _resetRepState({bool countFaults = true}) {
    correctForm = true;
    for (var metric in _metrics) {
      if (countFaults) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }
    // Xóa snapshot để chu trình sau nhận diện lại từ đầu
    _peakLeftLeg = null;
    _peakLeftArm = null;
  }
}
