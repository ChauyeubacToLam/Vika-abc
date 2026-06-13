// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../services/bird_dog_voice_assets.dart';
import '../../services/queued_asset_voice_player.dart';
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
  int invalidAttemptCount = 0;

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
      invalidAttemptCount++;
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

abstract class BirdDogVoicePlayer {
  Future<void> speak(String text);
  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _BirdDogAssetVoicePlayer implements BirdDogVoicePlayer {
  _BirdDogAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: BirdDogVoiceAssets.files,
              assetSourcePrefix: BirdDogVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: BirdDogVoiceAssets.assetBundlePrefix,
              logTag: 'BirdDogVoice',
            );

  final QueuedAssetVoicePlayer _player;

  @override
  Future<void> speak(String text) => _player.speak(text);

  @override
  void clearQueue() => _player.clearQueue();

  @override
  void clearPendingButKeepCurrent() => _player.clearPendingButKeepCurrent();

  @override
  void dispose() => _player.dispose();
}

class BirdDogVoiceCoach implements ExerciseVoiceCoach {
  BirdDogVoiceCoach({BirdDogVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _BirdDogAssetVoicePlayer();

  static const String _setupIntro =
      'Đặt điện thoại hơi chéo để thấy toàn thân trên thảm.';
  static const String _setupPosition =
      'Chống hai tay và hai gối. Tay dưới vai, gối dưới hông, lưng phẳng.';
  static const String _activeIntro =
      'Giơ tay và chân đối diện. Vươn dài. Giữ 5 giây rồi đổi bên.';
  static const String _setNextSetup =
      'Hiệp này chống lại bốn điểm. Lưng phẳng, tay dưới vai.';
  static const String _noCount = 'Lần này chưa tính.';
  static const String _ready = 'Sẵn sàng.';
  static const String _complete = 'Hoàn thành bài tập.';
  static const String _goodClean = 'Tốt, hông giữ cân bằng.';

  static const String _faultOppositeSide = 'Giơ tay và chân đối diện.';
  static const String _faultAlternate = 'Đổi sang bên còn lại.';
  static const String _faultAlignment = 'Vươn dài tay và chân.';
  static const String _faultHead = 'Nâng đầu nhẹ, mắt nhìn xuống thảm.';
  static const String _faultLumbar = 'Hạ chân xuống ngang thân.';
  static const String _faultHold = 'Giữ 5 giây ở điểm cao nhất.';
  static const String _faultTrunk = 'Siết bụng, giữ hông cân bằng.';

  static final Map<String, int> _previousSetFaultCounts = {};

  final BirdDogVoicePlayer _voicePlayer;
  final Map<String, int> _setFaultCounts = {};

  int _lastRepCount = 0;
  int _lastInvalidAttemptCount = 0;
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

    final repIncreased = repCount > _lastRepCount;
    final invalidAttemptIncreased =
        exercise.invalidAttemptCount > _lastInvalidAttemptCount;

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didSpeakSetComplete) {
        _voicePlayer.clearPendingButKeepCurrent();
        if (repIncreased) {
          _speakRepOutcome(exercise, repCount);
        } else if (invalidAttemptIncreased) {
          _speakInvalidAttemptOutcome(exercise);
        }
      }
      _handleSetComplete();
      _lastRepCount = repCount;
      _lastInvalidAttemptCount = exercise.invalidAttemptCount;
      return;
    }

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _handleSetup();
      _lastRepCount = repCount;
      _lastInvalidAttemptCount = exercise.invalidAttemptCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastRepCount = repCount;
      _lastInvalidAttemptCount = exercise.invalidAttemptCount;
      return;
    }

    if (!_didSpeakReady) {
      _voicePlayer.speak(_ready);
      _didSpeakReady = true;
    }

    _speakPreviousSetAdviceIfNeeded();

    if (repIncreased) {
      _handleRepComplete(exercise, repCount);
      _lastRepCount = repCount;
      _lastInvalidAttemptCount = exercise.invalidAttemptCount;
      return;
    }

    if (invalidAttemptIncreased) {
      _handleInvalidAttempt(exercise);
      _lastRepCount = repCount;
      _lastInvalidAttemptCount = exercise.invalidAttemptCount;
      return;
    }

    _lastRepCount = repCount;
    _lastInvalidAttemptCount = exercise.invalidAttemptCount;
  }

  void _handleSetup() {
    if (!_didSpeakSetupIntro) {
      _voicePlayer.speak(_setupIntro);
      _voicePlayer.speak(_setupPosition);
      _voicePlayer.speak(_activeIntro);
      _speakPreviousSetAdviceIfNeeded();
      _didSpeakSetupIntro = true;
    }
  }

  void _handleRepComplete(BirdDog exercise, int repCount) {
    _voicePlayer.clearPendingButKeepCurrent();
    _speakRepOutcome(exercise, repCount);
  }

  void _speakRepOutcome(BirdDog exercise, int repCount) {
    _voicePlayer.speak('$repCount');

    if (exercise.lastRepWasClean) {
      _voicePlayer.speak(_goodClean);
      return;
    }

    for (final rawMessage in exercise.lastRepFaultVoiceMessages.take(2)) {
      final voice = _immediateVoiceForRaw(rawMessage);
      final faultId = _faultIdForVoice(voice);
      if (voice == null || faultId == null) continue;
      _setFaultCounts[faultId] = (_setFaultCounts[faultId] ?? 0) + 1;
    }

    final topAdvice = _immediateVoiceForRaw(exercise.lastRepTopVoiceMessage);
    if (topAdvice != null) {
      _voicePlayer.speak(topAdvice);
    }
  }

  void _handleInvalidAttempt(BirdDog exercise) {
    _voicePlayer.clearPendingButKeepCurrent();
    _speakInvalidAttemptOutcome(exercise);
  }

  void _speakInvalidAttemptOutcome(BirdDog exercise) {
    _voicePlayer.speak(_noCount);

    final topAdvice = _immediateVoiceForRaw(exercise.lastRepTopVoiceMessage);
    if (topAdvice != null) {
      final faultId = _faultIdForVoice(topAdvice);
      if (faultId != null) {
        _setFaultCounts[faultId] = (_setFaultCounts[faultId] ?? 0) + 1;
      }
      _voicePlayer.speak(topAdvice);
    }
  }

  void _handleSetComplete() {
    if (_didSpeakSetComplete) return;

    _voicePlayer.speak(_complete);

    _previousSetFaultCounts
      ..clear()
      ..addAll(_setFaultCounts);

    _didSpeakSetComplete = true;
  }

  String? _topPreviousSetAdvice() {
    if (_previousSetFaultCounts.isEmpty) return null;
    final sorted = _previousSetFaultCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _setNextVoiceForId(sorted.first.key);
  }

  void _speakPreviousSetAdviceIfNeeded() {
    if (_didSpeakPreviousSetAdvice || _previousSetFaultCounts.isEmpty) return;

    final advice = _topPreviousSetAdvice();
    _voicePlayer.speak(_setNextSetup);
    if (advice != null) {
      _voicePlayer.speak(advice);
    }
    _didSpeakPreviousSetAdvice = true;
  }

  String? _immediateVoiceForRaw(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    if (value.contains('đối diện') ||
        value.contains('cùng tay') ||
        value.contains('cùng chân')) {
      return _faultOppositeSide;
    }
    if (value.contains('còn lại') || value.contains('luân phiên')) {
      return _faultAlternate;
    }
    if (value.contains('Vươn dài') || value.contains('duỗi')) {
      return _faultAlignment;
    }
    if (value.contains('Nâng đầu') || value.contains('cúi đầu')) {
      return _faultHead;
    }
    if (value.contains('Hạ chân') ||
        value.contains('Hạ thấp chân') ||
        value.contains('võng')) {
      return _faultLumbar;
    }
    if (value.contains('5 giây') || value.contains('5s')) {
      return _faultHold;
    }
    if (value.contains('bụng') || value.contains('hông')) {
      return _faultTrunk;
    }
    return null;
  }

  String? _faultIdForVoice(String? voice) {
    if (voice == _faultOppositeSide) return 'opposite_side';
    if (voice == _faultAlternate) return 'alternate';
    if (voice == _faultAlignment) return 'alignment';
    if (voice == _faultHead) return 'head';
    if (voice == _faultLumbar) return 'lumbar';
    if (voice == _faultHold) return 'hold';
    if (voice == _faultTrunk) return 'trunk';
    return null;
  }

  String? _setNextVoiceForId(String faultId) {
    return switch (faultId) {
      'opposite_side' => 'Hiệp này đừng giơ cùng bên.',
      'alternate' => 'Hiệp này đổi bên sau mỗi lần.',
      'alignment' => 'Hiệp này giữ tay chân thẳng hơn.',
      'head' => 'Hiệp này đừng cúi đầu quá thấp.',
      'lumbar' => 'Hiệp này đừng đá chân quá cao.',
      'hold' => 'Hiệp này giữ đủ lâu rồi mới hạ.',
      'trunk' => 'Hiệp này đừng để hông lệch.',
      _ => null,
    };
  }

  @override
  void dispose() {
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
    _setFaultCounts.clear();
  }
}
