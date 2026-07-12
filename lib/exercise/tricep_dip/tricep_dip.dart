import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/tricep_metric_base.dart';
import 'metrics/hip_thrust_metric.dart';
import 'metrics/tricep_rom_metric.dart';
import 'metrics/full_extension_metric.dart';
import 'metrics/scapular_elevation_metric.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

enum TricepDipState { setup_top, descending, bottom, ascending }

class TricepDipConfig {
  static const int MAX_REP = 15;
  static const double MAX_SUPPORT_HEIGHT_DELTA_RATIO = 0.55;
  static const double MAX_SEATED_HIP_HEIGHT_RATIO = 0.65;
  static const double MIN_SEATED_HIP_HEIGHT_RATIO = -0.10;
  static const double HIP_LIFT_START_RATIO = 0.16;
  static const double HIP_LIFT_COUNT_RATIO = 0.22;
  static const double HIP_LOWER_START_RATIO = 0.12;
  static const double HIP_RETURN_RATIO = 0.07;
}

class TricepDip extends ExerciseBase with SideTrackedExerciseMixin {
  static const List<String> _voiceFaultIds = [
    'extension',
    'hip_thrust',
    'shrug',
    'rom',
  ];

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  TricepDip({required this.maxRep}) : super(targetReps: maxRep);

  TricepDipState tricepState = TricepDipState.setup_top;
  TricepDipState previousTricepState = TricepDipState.setup_top;
  double? _setupHipY;
  double? _setupScale;

  final Debouncer _liftDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _topDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lowerDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _returnDebouncer = Debouncer(requiredFrames: 2);

  // Metrics
  final HipThrustMetric hipThrustMetric = HipThrustMetric();
  final TricepRomMetric tricepRomMetric = TricepRomMetric();
  final FullExtensionMetric fullExtensionMetric = FullExtensionMetric();
  final ScapularElevationMetric scapularElevationMetric =
      ScapularElevationMetric();

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder
        ),
        'elbow': (
          right: PoseLandmarkType.rightElbow,
          left: PoseLandmarkType.leftElbow
        ),
        'wrist': (
          right: PoseLandmarkType.rightWrist,
          left: PoseLandmarkType.leftWrist
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip
        ),
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle
        ),
      };

  @override
  Map<String, SideLandmarkPair> get optionalSideLandmarks => const {
        'ear': (
          right: PoseLandmarkType.rightEar,
          left: PoseLandmarkType.leftEar
        ),
      };

  @override
  String get exerciseName => 'Tricep Dip (Floor)';

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'tricep_dip',
        faultIds: _voiceFaultIds,
        // Hesitation encouragement, not "push harder"; valid for controlled work too.
        effortPhaseKeys: const {'ascending'},
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
  String get currentPhaseKey => tricepState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (tricepState) {
      case TricepDipState.setup_top:
        return 'Ngồi chạm sàn';
      case TricepDipState.descending:
        return 'Hạ mông';
      case TricepDipState.bottom:
        return 'Đã nhấc mông';
      case TricepDipState.ascending:
        return 'Nhấc mông';
    }
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("hip_thrust_fails_count", hipThrustMetric.faultsCount);
    logger.pushKey("rom_fails_count", tricepRomMetric.faultsCount);
    logger.pushKey("extension_fails_count", fullExtensionMetric.faultsCount);
    logger.pushKey(
        "shrugging_fails_count", scapularElevationMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return const GuidanceSignal.turnSide();
    }
    final req = getSideTrackedLandmarks(landmarks);
    if (req == null) return const GuidanceSignal.bodyInFrame();
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) return false;
    final req = getSideTrackedLandmarks(landmarks);
    if (req == null) return false;

    final shoulder = req['shoulder']!;
    final wrist = req['wrist']!;
    final hip = req['hip']!;
    final ankle = req['ankle']!;

    final scale = calculateDistance(shoulder, hip);
    if (!scale.isFinite || scale <= 1e-6) return false;

    // The setup is the seated floor position: hand and foot share the ground
    // line while the hip remains close to it. The lift happens after activation.
    final supportDelta = (wrist.y - ankle.y).abs() / scale;
    final groundY = (wrist.y + ankle.y) / 2.0;
    final seatedHipHeight = (groundY - hip.y) / scale;
    if (supportDelta > TricepDipConfig.MAX_SUPPORT_HEIGHT_DELTA_RATIO) {
      resultIssues.feedback['System'] =
          'Đặt bàn tay và bàn chân cùng chống chắc xuống sàn.';
      return false;
    }
    if (seatedHipHeight < TricepDipConfig.MIN_SEATED_HIP_HEIGHT_RATIO ||
        seatedHipHeight > TricepDipConfig.MAX_SEATED_HIP_HEIGHT_RATIO) {
      resultIssues.feedback['System'] =
          'Ngồi để mông chạm sàn trước khi bắt đầu.';
      return false;
    }

    _setupHipY = hip.y;
    _setupScale = scale;

    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final req = getSideTrackedLandmarks(smoothedLandmarks);
    if (req == null) return;

    final shoulder = req['shoulder']!;
    final wrist = req['wrist']!;
    final hip = req['hip']!;
    final ankle = req['ankle']!;

    int now = frameTimestampMs;
    final scale = calculateDistance(shoulder, hip);
    if (!scale.isFinite || scale <= 1e-6) return;
    _setupScale ??= scale;
    _setupHipY ??= hip.y;

    final normalizedScale = _setupScale! <= 1e-6 ? scale : _setupScale!;
    final hipLiftRatio = (_setupHipY! - hip.y) / normalizedScale;
    final supportDelta = (wrist.y - ankle.y).abs() / normalizedScale;
    final supportsGrounded =
        supportDelta <= TricepDipConfig.MAX_SUPPORT_HEIGHT_DELTA_RATIO;

    _updateStateMachine(
      hipLiftRatio: hipLiftRatio,
      supportsGrounded: supportsGrounded,
      now: now,
    );

    debugData['tricepState'] = tricepState.name;
    debugData['hipLiftRatio'] = hipLiftRatio;
    debugData['supportHeightDeltaRatio'] = supportDelta;

    if (!supportsGrounded) {
      resultIssues.feedback['Support'] =
          'Giữ bàn tay và bàn chân chống trên sàn.';
    } else if (tricepState == TricepDipState.descending) {
      resultIssues.setPhaseStatus(
          'descending', 'Hạ mông chạm sàn để sẵn sàng nhịp tiếp theo.');
    } else if (tricepState == TricepDipState.bottom) {
      resultIssues.setPhaseStatus('bottom', 'Tốt! Hạ mông xuống.');
    } else if (tricepState == TricepDipState.ascending) {
      resultIssues.setPhaseStatus('ascending', 'Nhấc mông lên!');
    } else {
      resultIssues.setPhaseStatus(
          'setup_top', 'Giữ tay và chân chống sàn, nhấc mông lên.');
    }
  }

  void _updateStateMachine({
    required double hipLiftRatio,
    required bool supportsGrounded,
    required int now,
  }) {
    if (tricepState == TricepDipState.setup_top) {
      if (_liftDebouncer.update(supportsGrounded &&
          hipLiftRatio >= TricepDipConfig.HIP_LIFT_START_RATIO)) {
        _transitionState(TricepDipState.ascending, now);
      }
    } else if (tricepState == TricepDipState.ascending) {
      if (_topDebouncer.update(supportsGrounded &&
          hipLiftRatio >= TricepDipConfig.HIP_LIFT_COUNT_RATIO)) {
        _transitionState(TricepDipState.bottom, now);
        _completeRep();
      } else if (hipLiftRatio <= TricepDipConfig.HIP_RETURN_RATIO) {
        _transitionState(TricepDipState.setup_top, now);
      }
    } else if (tricepState == TricepDipState.bottom) {
      if (_lowerDebouncer
          .update(hipLiftRatio <= TricepDipConfig.HIP_LOWER_START_RATIO)) {
        _transitionState(TricepDipState.descending, now);
      }
    } else if (tricepState == TricepDipState.descending) {
      if (_returnDebouncer.update(supportsGrounded &&
          hipLiftRatio <= TricepDipConfig.HIP_RETURN_RATIO)) {
        _transitionState(TricepDipState.setup_top, now);
        _setupHipY = _setupHipY! * 0.8 +
            (_setupHipY! - hipLiftRatio * (_setupScale ?? 1.0)) * 0.2;
      }
    }
  }

  void _transitionState(TricepDipState newState, int timestampMs) {
    if (newState == tricepState) return;

    previousTricepState = tricepState;
    tricepState = newState;

    if (newState == TricepDipState.ascending &&
        previousTricepState == TricepDipState.setup_top) {
      resultIssues.phaseStatus.clear();
    }
  }

  void _completeRep() {
    repCount++;

    final allFaults = <FaultRecord>[];

    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }

    setFeedback.add({correctForm: faultMap});

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
      "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      "fault_affects_form": faultAffectsForm,
      "fault_priorities": faultPriorities,
    }));

    correctForm = true;
  }
}
