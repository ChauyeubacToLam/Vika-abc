// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/bird_dog_metric_base.dart';
import 'metrics/lumbar_extension_metric.dart';
import 'metrics/alignment_metric.dart';
import 'metrics/trunk_stability_metric.dart';
import 'metrics/tempo_metric.dart';

class BirdDogConfig {
  static const int MAX_REP = 24;
  static const int TIMEOUT_MS = 90000;

  static const double START_KNEE_MIN = 40;
  static const double START_KNEE_MAX = 140;
  static const double START_ARM_MIN = 40;
  static const double START_ARM_MAX = 140;
  static const double START_TRUNK_HORIZ_MAX = 20;

  static const double EXTENDING_KNEE_START = 120;
  static const double HOLD_KNEE_THRESHOLD = 160;
  static const double HOLD_ARM_THRESHOLD = 150;
  static const double RETURNING_KNEE_THRESHOLD = 150;
  static const double NEUTRAL_KNEE_THRESHOLD = 110;
  static const double HOLD_TARGET_SECONDS = 5.0;
}

class BirdDog extends ExerciseBase {
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

  final Debouncer _holdDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _returningDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _neutralDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _extendingDebouncer = Debouncer(requiredFrames: 2);

  List<String> lastRepFaultVoiceMessages = [];
  String? lastRepTopVoiceMessage;
  int? lastRepTopVoicePriority;
  bool lastRepWasClean = true;

  // Biến Snapshot: Chỉ lưu tay/chân đang thao tác ở đúng đỉnh của rep
  bool? _peakLeftLeg;
  bool? _peakLeftArm;
  bool? _lastPeakLeftLeg;
  bool? _lastPeakLeftArm;

  BirdDog({this.maxRep = BirdDogConfig.MAX_REP});

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Bird Dog';

  @override
  ExerciseVoiceCoach? createVoiceCoach() => BirdDogVoiceCoach();

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
        return 'Giữ 5s!';
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
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return 'Vui lòng quay ngang người 100% với camera!';
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
    logger.pushKey("target_rep", maxRep);
    logger.pushKey("max_rep", repCount);
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
        resultIssues.addInstruction('TIMEOUT', 'Status', 'Đang lưu kết quả...');
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
        _transitionState(BirdDogState.neutral, now);
        _resetRepState();
        resultIssues.feedback['Result'] = 'Không tính rep';
        resultIssues.feedback['Error'] = 'Mất mốc cơ thể';
        resultIssues.addInstruction(
            'BLOCK', 'Error', 'Giữ toàn thân trong khung hình');
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
      _transitionState(BirdDogState.neutral, now);
      _peakLeftLeg = null;
      _peakLeftArm = null;
      resultIssues.feedback['Error'] = 'Sai tư thế (Đang Plank)';
      resultIssues.addInstruction('BLOCK', 'Error', 'Hạ hai gối xuống sàn!');
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

    final blockingFault = _blockingFaultFor(ctx);
    if (blockingFault != null && state != BirdDogState.neutral) {
      _publishBlockingFault(blockingFault);
    }

    _updateStateMachine(activeKneeAngle, activeArmAngle, now);

    // --- HIỆN ĐỒNG HỒ ĐẾM NGƯỢC 5S CHO UI ---
    if (state == BirdDogState.hold_extended &&
        tempoMetric.holdStartMs != null) {
      double elapsed = (now - tempoMetric.holdStartMs!) / 1000.0;
      double progress = (elapsed / 5.0).clamp(0.0, 1.0);
      resultIssues.feedback['progress'] = progress.toStringAsFixed(2);

      if (progress < 1.0) {
        resultIssues.addInstruction(
            'HOLD', 'Timer', 'Giữ: ${elapsed.toStringAsFixed(1)}s');
      } else {
        resultIssues.addInstruction('HOLD', 'Timer', 'Tốt! Hạ chân xuống');
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

    if (state != BirdDogState.neutral) {
      for (final metric in _metrics) metric.update(ctx);
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
      _transitionState(BirdDogState.returning, now);
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
      lastRepFaultVoiceMessages = [
        blockingFault.voiceMessage ?? blockingFault.message
      ];
      lastRepTopVoiceMessage =
          blockingFault.voiceMessage ?? blockingFault.message;
      lastRepTopVoicePriority = blockingFault.priority;
      lastRepWasClean = false;
      _publishBlockingFault(blockingFault);
      _resetRepState();
      return;
    }

    repCount++;
    tempoMetric.evaluateRep(ctx);

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

    logger
        .addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "hold_time": tempoMetric.holdDuration ?? 0,
      "fault_types": allFaults.map((e) => e.type).toSet().toList()
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

  FaultRecord? _blockingFaultFor(BirdDogRepContext ctx) {
    if (ctx.isSameSide) {
      return FaultRecord(
        phase: ctx.state.name,
        type: 'SameSide',
        message: 'Không cùng tay cùng chân',
        voiceMessage: 'Giơ tay và chân đối diện',
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
        type: 'NotAlternating',
        message: 'Chưa luân phiên tay và chân',
        voiceMessage: 'Đổi sang tay và chân còn lại',
        affectsForm: true,
        priority: BirdDogFaultPriority.alignment,
      );
    }

    return null;
  }

  void _publishBlockingFault(FaultRecord fault) {
    resultIssues.feedback['Result'] = 'Không tính rep';
    resultIssues.feedback['Error'] = fault.message;
    resultIssues.addInstruction(
      currentPhaseKey,
      'Error',
      fault.voiceMessage ?? fault.message,
    );
  }

  void _resetRepState() {
    correctForm = true;
    for (var metric in _metrics) metric.resetAndCountFault();
    // Xóa snapshot để chu trình sau nhận diện lại từ đầu
    _peakLeftLeg = null;
    _peakLeftArm = null;
  }
}

class BirdDogVoiceCoach implements ExerciseVoiceCoach {
  static const int _setupCueGapMs = 9000;
  static const int _phaseCueGapMs = 1400;
  static const int _faultCueGapMs = 4500;
  static const int _sameFaultGapMs = 9000;
  static const int _maxReminderReps = 3;

  static final Map<String, int> _previousSetFaultCounts = {};

  final Map<String, int> _activeReminders = {};
  final Map<String, int> _spokenFaultAtMs = {};
  final Map<String, int> _setFaultCounts = {};

  String? _lastPhaseKey;
  int _lastSetupCueAtMs = 0;
  int _lastPhaseCueAtMs = 0;
  int _lastFaultCueAtMs = 0;
  int _lastRepCount = 0;
  bool _didSpeakSetupIntro = false;
  bool _didSpeakReady = false;
  bool _didSpeakPreviousSetAdvice = false;
  bool _didSpeakSetComplete = false;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    if (exercise is! BirdDog) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (exercise.exerciseState == ExerciseState.completed) {
      _handleSetComplete(exercise);
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _handleSetup(exercise, hasPose: hasPose, nowMs: nowMs);
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhaseKey = null;
      _lastRepCount = repCount;
      return;
    }

    if (!_didSpeakReady) {
      exercise.ttsService.clearQueue();
      exercise.ttsService.speak('Bắt đầu');
      exercise.ttsService.speak('Giơ tay và chân đối diện');
      _didSpeakReady = true;
    }

    if (!_didSpeakPreviousSetAdvice && _previousSetFaultCounts.isNotEmpty) {
      final advice = _topPreviousSetAdvice();
      if (advice != null) {
        exercise.ttsService.speak('Set này chú ý');
        exercise.ttsService.speak(advice);
      }
      _didSpeakPreviousSetAdvice = true;
    }

    final repIncreased = repCount > _lastRepCount;
    if (repIncreased) {
      _handleRepComplete(exercise, repCount);
      _lastRepCount = repCount;
      _lastPhaseKey = null;
      return;
    }

    final liveFault = _liveFaultCue(exercise, feedback);
    if (liveFault != null && _canSpeakFault(liveFault, nowMs)) {
      exercise.ttsService.speak(liveFault);
      _spokenFaultAtMs[liveFault] = nowMs;
      _lastFaultCueAtMs = nowMs;
      return;
    }

    _handlePhaseCue(exercise, nowMs);
    _lastRepCount = repCount;
  }

  void _handleSetup(
    BirdDog exercise, {
    required bool hasPose,
    required int nowMs,
  }) {
    if (nowMs - _lastSetupCueAtMs < _setupCueGapMs) return;

    if (!_didSpeakSetupIntro) {
      exercise.ttsService.speak(
        'Vào tư thế bò bốn điểm, vai trên cổ tay, hông trên gối',
      );
      exercise.ttsService.speak('Quay ngang người với camera');
      _didSpeakSetupIntro = true;
      _lastSetupCueAtMs = nowMs;
      return;
    }

    if (!hasPose) {
      exercise.ttsService.speak('Giữ toàn thân trong khung hình');
    } else if (exercise.activationProgress != null) {
      exercise.ttsService.speak('Giữ yên để bắt đầu');
    } else {
      exercise.ttsService.speak('Đặt lưng phẳng, hai tay dưới vai');
    }
    _lastSetupCueAtMs = nowMs;
  }

  void _handleRepComplete(BirdDog exercise, int repCount) {
    exercise.ttsService.clearPendingButKeepCurrent();
    exercise.ttsService.speak('$repCount');

    if (exercise.lastRepWasClean) {
      exercise.ttsService.speak('tốt');
      _activeReminders.clear();
      return;
    }

    for (final message in exercise.lastRepFaultVoiceMessages.take(2)) {
      _setFaultCounts[message] = (_setFaultCounts[message] ?? 0) + 1;
      _activeReminders[message] = _maxReminderReps;
    }

    final topAdvice = exercise.lastRepTopVoiceMessage;
    if (topAdvice != null && topAdvice.trim().isNotEmpty) {
      exercise.ttsService.speak(topAdvice);
      _activeReminders[topAdvice] = _maxReminderReps;
    }
  }

  void _handlePhaseCue(BirdDog exercise, int nowMs) {
    final phaseKey = exercise.currentPhaseKey;
    if (phaseKey == _lastPhaseKey) return;
    if (nowMs - _lastPhaseCueAtMs < _phaseCueGapMs) return;

    final cue = switch (exercise.state) {
      BirdDogState.neutral => _nextNeutralCue(),
      BirdDogState.extending => 'Vươn dài tay và chân đối diện',
      BirdDogState.hold_extended => 'Giữ lưng phẳng, siết bụng',
      BirdDogState.returning => 'Thu tay chân về chậm',
    };

    exercise.ttsService.speak(cue);
    _lastPhaseKey = phaseKey;
    _lastPhaseCueAtMs = nowMs;
  }

  String _nextNeutralCue() {
    final reminder = _nextReminder();
    if (reminder != null) return reminder;
    return 'Đổi bên, giơ tay và chân đối diện';
  }

  String? _nextReminder() {
    if (_activeReminders.isEmpty) return null;

    final sorted = _activeReminders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selected = sorted.first.key;
    final remaining = sorted.first.value - 1;
    if (remaining <= 0) {
      _activeReminders.remove(selected);
    } else {
      _activeReminders[selected] = remaining;
    }
    return selected;
  }

  String? _liveFaultCue(BirdDog exercise, Map<String, String> feedback) {
    final phaseInstruction =
        exercise.resultIssues.instructions[exercise.currentPhaseKey];
    final instructionError = phaseInstruction?['Error'];
    if (instructionError != null && instructionError.trim().isNotEmpty) {
      return instructionError.trim();
    }

    final feedbackError = feedback['Error'];
    if (feedbackError != null) {
      if (feedbackError.contains('cùng tay') ||
          feedbackError.contains('cùng chân')) {
        return 'Giơ tay và chân đối diện';
      }
      if (feedbackError.contains('luân phiên')) {
        return 'Đổi sang tay và chân còn lại';
      }
      if (feedbackError.contains('Plank')) {
        return 'Hạ hai gối xuống sàn';
      }
    }

    final spine = feedback['Spine'];
    if (spine != null && spine.contains('võng')) {
      return 'Hạ thấp chân xuống một chút';
    }

    return null;
  }

  bool _canSpeakFault(String message, int nowMs) {
    if (nowMs - _lastFaultCueAtMs < _faultCueGapMs) return false;
    final lastSameFaultAt = _spokenFaultAtMs[message] ?? 0;
    return nowMs - lastSameFaultAt >= _sameFaultGapMs;
  }

  void _handleSetComplete(BirdDog exercise) {
    if (_didSpeakSetComplete) return;

    exercise.ttsService.clearPendingButKeepCurrent();
    exercise.ttsService.speak('Hoàn thành bài tập');

    _previousSetFaultCounts
      ..clear()
      ..addAll(_setFaultCounts);

    _didSpeakSetComplete = true;
  }

  String? _topPreviousSetAdvice() {
    if (_previousSetFaultCounts.isEmpty) return null;
    final sorted = _previousSetFaultCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  void dispose() {
    _activeReminders.clear();
    _spokenFaultAtMs.clear();
    _setFaultCounts.clear();
  }
}
