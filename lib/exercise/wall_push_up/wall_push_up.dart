// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names, annotate_overrides

/* =========================================================================
   WALL PUSH-UP — Main exercise class.
 
   Mirrors the Push-Up implementation (lib/exercise/push up/) exactly:
   same ExerciseBase contract, same getSideLandmark(), same debouncer,
   same RepContext + MetricBase split, same feedback/instructions channels.
 
   This single file holds "the rest" (per Nam's instruction):
     - WallPushUpConfig          (thresholds)
     - WallPushUpState           (state machine enum)
     - RepContext                (shared per-frame geometry → metrics)
     - WallPushUpMetricBase      (abstract metric interface + captureBaseline)
     - TempoMetric               (Check 7 — descent control, lives here)
     - WallPushUp                (state machine + orchestration + Checks 6 & 8)
 
   The 5 SAFETY metrics each live in their own file under metrics/.
 
   Camera: side view. Elbow angle β = SHOULDER→ELBOW→WRIST (normalized,
   ~175° straight, ~90° bent) drives the state machine.
   ========================================================================= */

import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/exercise_logger.dart';

import '../../utils/pose_math_helpers.dart';
import '../../services/wall_push_up_voice_coach.dart';
import '../exercise_base.dart';
import '../fault_record.dart';
export '../fault_record.dart';

import 'metrics/body_line.dart';
import 'metrics/shoulder_shrug.dart';
import 'metrics/forward_head.dart';
import 'metrics/elbow_flare.dart';
import 'metrics/cervical_extension.dart';
import 'metrics/foot_stationary.dart';
import 'metrics/wall_contact.dart';

// --- Config ---

class WallPushUpConfig {
  // State machine — driven by elbow angle β (shoulder→elbow→wrist), normalized.
  // ~175° = arms straight (standing/lockout). ~90° = elbows bent (bottom).
  static const double STANDING_ANGLE_THRESHOLD = 138.0; // > this → standing
  static const double DESCEND_ANGLE_THRESHOLD =
      135.0; // < this → entering descent
  static const double BOTTOM_ANGLE_MAX = 132.0; // ≤ this → bottom
  static const double BOTTOM_EXIT = 136.0; // > this from bottom → ascending

  // Start position gates (hold-still).
  static const double START_ELBOW_MIN = 135.0; // arms extended enough
  static const double START_BODYLINE_MIN = 128.0; // body roughly straight
  static const double START_TRUNK_INCLINATION_MIN = 25.0;
  static const double ACTIVE_TRUNK_INCLINATION_MIN = 20.0;
  static const double HAND_PLACEMENT_MAX_OFFSET_RATIO = 0.55;
  static const double HEEL_RAISE_MIN_RATIO = 0.01;
  static const String WALL_DISTANCE_SETUP =
      'Đứng cách tường một cánh tay + 30-40 cm, đặt tay lên tường.';
  // NOTE: normalized angle caps at 180°, so the spec's 195° upper bound
  // is unreachable here. Lower gate only — see body_line_metric.dart caveat.

  // --- Effectiveness Check 6: Depth (min elbow angle at bottom) ---
  // Week 1-4 thresholds. affectsForm = false (coach, don't punish).
  static const double DEPTH_GOOD_MAX = 122.0; // ≤110° = good depth
  static const double DEPTH_SHALLOW_MAX = 142.0; // 110-130° = shallow warning
  // > DEPTH_SHALLOW_MAX = too shallow (wasted rep) coaching

  // --- Effectiveness Check 8: Full lockout (peak elbow angle at top) ---
  // Week 1-4 thresholds. affectsForm = false.
  static const double LOCKOUT_GOOD_MIN = 140.0; // relaxed beginner lockout
  static const double LOCKOUT_WARN_MIN = 135.0; // 150-160° = partial warning
}

enum WallPushUpState { standing, descending, bottom, ascending }

/* =========================================================================
   RepContext — Shared per-frame geometry, passed to all metrics.
   Angles depending on optional landmarks (ear/nose/ankle) are nullable;
   metrics null-gate and skip when their input is unavailable.
   ========================================================================= */
class RepContext {
  /// Elbow angle β: SHOULDER→ELBOW→WRIST (normalized, 0-180).
  /// ~175° straight (standing), ~90° bottom. Drives the state machine.
  final double elbowAngle;

  /// Body line angle: SHOULDER→HIP→ANKLE (normalized). 180° = straight.
  /// Lower = body bent (sag/pike — direction not separable, see metric).
  final double? bodyLineAngle;

  /// Shrug ratio: earToShoulder / shoulderToHip. Smaller = shoulders hiked.
  final double? shrugRatio;

  /// Forward-head angle: EAR→SHOULDER→HIP (normalized). 180° = ear stacked
  /// over shoulder. Smaller = head poking forward.
  final double? forwardHeadAngle;

  /// Neck-tilt angle: NOSE→EAR→SHOULDER (normalized). ~180° = neutral.
  /// Smaller = head tilting back to look up at the wall.
  final double? neckTiltAngle;

  /// Elbow-flare angle: HIP→SHOULDER→ELBOW (normalized). Small = tucked,
  /// large = flared. Coarse from side camera (see metric caveat).
  final double elbowFlareAngle;

  /// Wrist anchor point used as a proxy for hand contact on the wall.
  final double wristAnchorX;
  final double wristAnchorY;

  /// Shoulder point used to confirm the torso moves toward the fixed hand.
  final double shoulderAnchorX;
  final double shoulderAnchorY;

  /// Side-view foot anchor point. Used to make sure the feet stay planted.
  final double? footAnchorX;
  final double? footAnchorY;

  /// Angle HIP→ANKLE→FOOT_INDEX captured at setup for stance diagnostics.
  final double? bodyFootAngle;
  final double? heelRaiseRatio;

  /// Full side-line angle: SHOULDER→HIP→FOOT_ANCHOR.
  /// 180° means shoulder, hip and foot are aligned in one straight line.
  final double? shoulderHipFootLineAngle;

  /// Inclination of the side-line vs the floor. Floor push-ups stay near
  /// horizontal; wall push-ups should be closer to standing.
  final double? trunkInclinationAngle;

  final double? scaleFactor; // shoulder-to-hip distance
  final WallPushUpState state;
  final int frameTimestamp; // ms

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  RepContext({
    required this.elbowAngle,
    required this.bodyLineAngle,
    required this.shrugRatio,
    required this.forwardHeadAngle,
    required this.neckTiltAngle,
    required this.elbowFlareAngle,
    required this.wristAnchorX,
    required this.wristAnchorY,
    required this.shoulderAnchorX,
    required this.shoulderAnchorY,
    required this.footAnchorX,
    required this.footAnchorY,
    required this.bodyFootAngle,
    required this.heelRaiseRatio,
    required this.shoulderHipFootLineAngle,
    required this.trunkInclinationAngle,
    required this.scaleFactor,
    required this.state,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

/* =========================================================================
   WallPushUpMetricBase — Interface every wall push-up metric implements.
   Identical to PushUpMetricBase plus a captureBaseline() hook for the
   metrics that personalize against a hold-still resting snapshot.
   ========================================================================= */
abstract class WallPushUpMetricBase with FaultMetricDebugSource {
  int faultsCount = 0;

  /// Human-readable name for debug/logging.
  String get name;

  /// Called every frame during an active rep (state != standing).
  void update(RepContext ctx);

  /// Faults accumulated this rep.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Reset per-rep state for the next rep. MUST keep the baseline.
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  /// Push the hold-still baseline value into the metric (once, at activation).
  /// Default no-op for metrics that use absolute thresholds.
  void captureBaseline(double? value) {}

  /// Capture a point baseline at activation. Metrics that need a stable
  /// anchor, such as feet or hands-on-wall, override this.
  void capturePointBaseline(double? x, double? y) {}

  /// Called when the state machine transitions (e.g. descending → bottom).
  /// Override in metrics that care about transitions (tempo).
  void onStateTransition(
      WallPushUpState from, WallPushUpState to, int timestampMs) {}
}

/* =========================================================================
   Check 7: Descent Tempo Control  (lives in the main file per file plan)
   Priority: 🟡 — effectiveness only. affectsForm = false (safe at wall load).
 
   Measures descent duration (standing → bottom) via onStateTransition().
   Week 1-4: flag drops faster than 0.5s. Slow descents are GOOD — never
   penalize a beginner for lowering slowly.
   ========================================================================= */
class TempoConfig {
  /// Week 1-4: descent faster than this (seconds) = uncontrolled drop.
  static const double DESCENT_FAST_ERROR = 0.3;
}

class TempoMetric extends WallPushUpMetricBase {
  @override
  String get name => 'Tempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _descentStartMs;
  int? _ascentStartMs;
  double? _descentDuration;
  double? _ascentDuration;

  double? get descentDuration => _descentDuration;
  double? get ascentDuration => _ascentDuration;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(
      WallPushUpState from, WallPushUpState to, int timestampMs) {
    switch (to) {
      case WallPushUpState.descending:
        _descentStartMs = timestampMs;
        break;
      case WallPushUpState.bottom:
        if (_descentStartMs != null) {
          _descentDuration = (timestampMs - _descentStartMs!) / 1000.0;
          _debugData['descentDur'] =
              _descentDuration?.toStringAsFixed(2) ?? '-';
        }
        break;
      case WallPushUpState.ascending:
        _ascentStartMs = timestampMs;
        break;
      case WallPushUpState.standing:
        if (_ascentStartMs != null) {
          _ascentDuration = (timestampMs - _ascentStartMs!) / 1000.0;
          _debugData['ascentDur'] = _ascentDuration?.toStringAsFixed(2) ?? '-';
        }
        break;
    }
  }

  @override
  void update(RepContext ctx) {
    // Live feedback once descent duration is known (after entering bottom).
    if (_descentDuration != null) {
      if (_descentDuration! < TempoConfig.DESCENT_FAST_ERROR) {
        ctx.resultIssues.feedback['Tempo'] = 'Hạ chậm lại, kiểm soát tốc độ.';
      } else {
        ctx.resultIssues.feedback['Tempo'] = 'Tốc độ hạ tốt!';
      }
    }
  }

  /// Called by WallPushUp after a rep completes. Coaching only.
  void evaluateRep(RepContext ctx) {
    if (_descentDuration == null) {
      _debugData['tempoResult'] = 'no data';
      return;
    }
    if (_descentDuration! < TempoConfig.DESCENT_FAST_ERROR) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'Tempo',
        message: 'Hạ quá nhanh (${_descentDuration!.toStringAsFixed(1)}s)',
        affectsForm: false, // safe at wall push-up load, just less effective
        voiceMessage: 'Chậm lại',
      ));
      ctx.resultIssues.addInstruction(
          'standing', 'Tempo', 'Hạ người chậm hơn, kiểm soát tốc độ.');
    }
    _debugData['tempoResult'] = _faults.isEmpty ? 'good' : 'fast';
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _descentStartMs = null;
    _ascentStartMs = null;
    _descentDuration = null;
    _ascentDuration = null;
  }
}

// --- Wall Push Up ---

class WallPushUp extends ExerciseBase {
  final int maxRep;
  WallPushUp({required this.maxRep});

  WallPushUpState wallPushUpState = WallPushUpState.standing;
  WallPushUpState previousWallPushUpState = WallPushUpState.standing;
  List<String> lastRepFaultVoiceMessages = [];
  String? lastRepTopVoiceMessage;
  int? lastRepTopVoicePriority;
  bool lastRepWasClean = true;

  final Debouncer _entryDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _activeTrunkInclinationDebouncer =
      Debouncer(requiredFrames: 4);

  // --- Safety/setup metrics ---
  final BodyLineMetric bodyLineMetric = BodyLineMetric();
  final ShoulderShrugMetric shoulderShrugMetric = ShoulderShrugMetric();
  final ForwardHeadMetric forwardHeadMetric = ForwardHeadMetric();
  final ElbowFlareMetric elbowFlareMetric = ElbowFlareMetric();
  final CervicalExtensionMetric cervicalExtensionMetric =
      CervicalExtensionMetric();
  final FootStationaryMetric footStationaryMetric = FootStationaryMetric();
  final WallContactMetric wallContactMetric = WallContactMetric();

  // --- Effectiveness Check 7 (tempo lives here too) ---
  final TempoMetric tempoMetric = TempoMetric();

  late final List<WallPushUpMetricBase> _metrics = [
    bodyLineMetric,
    shoulderShrugMetric,
    forwardHeadMetric,
    elbowFlareMetric,
    cervicalExtensionMetric,
    footStationaryMetric,
    wallContactMetric,
    tempoMetric,
  ];

  static List<FaultRecord> orderedVoicedFaults(Iterable<FaultRecord> faults) {
    final voicedFaults = faults
        .where((fault) =>
            fault.voiceMessage != null && fault.voiceMessage!.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }

        final typeCompare = a.type.compareTo(b.type);
        if (typeCompare != 0) {
          return typeCompare;
        }

        return a.message.compareTo(b.message);
      });

    return voicedFaults;
  }

  static FaultRecord? topVoicedFault(Iterable<FaultRecord> faults) {
    final voicedFaults = orderedVoicedFaults(faults);
    return voicedFaults.isEmpty ? null : voicedFaults.first;
  }

  static List<String> orderedUniqueVoiceMessages(Iterable<FaultRecord> faults) {
    final orderedVoiceMessages = <String>[];
    final seenVoiceMessages = <String>{};

    for (final fault in orderedVoicedFaults(faults)) {
      final voiceMessage = fault.voiceMessage!;
      if (seenVoiceMessages.add(voiceMessage)) {
        orderedVoiceMessages.add(voiceMessage);
      }
    }

    return orderedVoiceMessages;
  }

  // --- Effectiveness Checks 6 & 8 state (reuse state-machine elbow angle) ---
  double? _repMinElbow; // deepest point this rep (Check 6: depth)
  double? _repMaxElbow; // peak during ascending this rep (Check 8: lockout)

  // --- Hold-still baselines (captured in isInStartPosition) ---
  double? _baselineShrugRatio;
  double? _baselineForwardHead;
  double? _baselineNeckTilt;
  double? _baselineFootAnchorX;
  double? _baselineFootAnchorY;
  double? _baselineWristAnchorX;
  double? _baselineWristAnchorY;
  double? _baselineBodyFootAngle;
  double? _baselineScaleFactor;
  bool _trunkInclinationInvalidThisRep = false;

  // --- UI Bridge ---

  @override
  String get exerciseName => 'Wall Push Up';

  @override
  ExerciseVoiceCoach? createVoiceCoach() => WallPushUpVoiceCoach();

  @override
  String get currentPhaseKey => wallPushUpState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (wallPushUpState) {
      case WallPushUpState.standing:
        return 'Chuẩn bị';
      case WallPushUpState.descending:
        return 'Hạ xuống';
      case WallPushUpState.bottom:
        return 'Sát tường';
      case WallPushUpState.ascending:
        return 'Đẩy ra';
    }
  }

  // --- Start Position ---

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    resultIssues.feedback['Setup'] = WallPushUpConfig.WALL_DISTANCE_SETUP;

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
    final elbow = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightElbow,
      leftType: PoseLandmarkType.leftElbow,
    );
    final wrist = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightWrist,
      leftType: PoseLandmarkType.leftWrist,
    );
    final ankle = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightAnkle,
      leftType: PoseLandmarkType.leftAnkle,
    );
    final heel = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHeel,
      leftType: PoseLandmarkType.leftHeel,
    );
    final footIndex = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightFootIndex,
      leftType: PoseLandmarkType.leftFootIndex,
    );

    if (shoulder == null ||
        hip == null ||
        elbow == null ||
        wrist == null ||
        ankle == null) {
      return false;
    }

    // 1. Standing, not lying down: shoulder above hip (smaller y = higher).
    if (shoulder.y >= hip.y) return false;

    final shoulderToHip = calculateDistance(shoulder, hip);
    if (shoulderToHip <= 0) return false;

    final trunkInclination = calculateAbsoluteHorizontalAngle(
      point1: shoulder,
      point2: ankle,
    );
    if (trunkInclination < WallPushUpConfig.START_TRUNK_INCLINATION_MIN) {
      resultIssues.feedback['Setup'] =
          'Đứng nghiêng người vào tường, không chống đẩy dưới sàn.';
      return false;
    }

    final handOffset = (wrist.y - shoulder.y).abs() / shoulderToHip;
    if (handOffset > WallPushUpConfig.HAND_PLACEMENT_MAX_OFFSET_RATIO) {
      resultIssues.feedback['Setup'] =
          'Đặt tay ngang vai hoặc lệch nhẹ, không quá cao hoặc quá thấp.';
      return false;
    }

    // 2. Arms extended: elbow angle > 155°.
    final elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    if (elbowAngle < WallPushUpConfig.START_ELBOW_MIN) return false;

    // 3. Body roughly straight enough for setup.
    final bodyLine = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    if (bodyLine < WallPushUpConfig.START_BODYLINE_MIN) return false;

    final heelRaiseRatio =
        _calculateHeelRaiseRatio(heel, footIndex, shoulderToHip);
    if (heelRaiseRatio == null) {
      resultIssues.feedback['Feet'] =
          'Giữ gót và mũi chân rõ trong khung hình.';
      return false;
    }
    if (heelRaiseRatio < WallPushUpConfig.HEEL_RAISE_MIN_RATIO) {
      resultIssues.feedback['Feet'] =
          'Kiễng gót chân lên, dồn lực vào mũi chân.';
      return false;
    }

    // --- Capture hold-still baselines (last held frame wins) ---
    final ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );
    final nose = landmarks[PoseLandmarkType.nose];

    if (ear != null) {
      if (shoulderToHip > 0) {
        _baselineShrugRatio = calculateDistance(ear, shoulder) / shoulderToHip;
      }
      _baselineForwardHead = calculateAngleNormalized(
          firstPoint: ear, midPoint: shoulder, lastPoint: hip);
      if (nose != null) {
        _baselineNeckTilt = calculateAngleNormalized(
            firstPoint: nose, midPoint: ear, lastPoint: shoulder);
      }
    }

    final footAnchor = _averagePoint([ankle, heel, footIndex]);
    _baselineFootAnchorX = footAnchor?.x;
    _baselineFootAnchorY = footAnchor?.y;
    _baselineWristAnchorX = wrist.x;
    _baselineWristAnchorY = wrist.y;
    _baselineScaleFactor = shoulderToHip;
    if (footIndex != null) {
      _baselineBodyFootAngle = calculateAngleNormalized(
          firstPoint: hip, midPoint: ankle, lastPoint: footIndex);
    }

    return true;
  }

  /// Push hold-still baselines into the metrics once, at activation.
  @override
  void onExerciseActivated() {
    shoulderShrugMetric.captureBaseline(_baselineShrugRatio);
    forwardHeadMetric.captureBaseline(_baselineForwardHead);
    cervicalExtensionMetric.captureBaseline(_baselineNeckTilt);
    footStationaryMetric.capturePointBaseline(
        _baselineFootAnchorX, _baselineFootAnchorY);
    footStationaryMetric.captureBaseline(_baselineBodyFootAngle);
    footStationaryMetric.captureScaleBaseline(_baselineScaleFactor);
    wallContactMetric.capturePointBaseline(
        _baselineWristAnchorX, _baselineWristAnchorY);
    wallContactMetric.captureFootBaseline(
        _baselineFootAnchorX, _baselineFootAnchorY);
    wallContactMetric.captureBaseline(_baselineScaleFactor);
  }

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey('body_line_fails_count', bodyLineMetric.faultsCount);
    logger.pushKey(
        'shoulder_shrug_fails_count', shoulderShrugMetric.faultsCount);
    logger.pushKey('forward_head_fails_count', forwardHeadMetric.faultsCount);
    logger.pushKey('elbow_flare_fails_count', elbowFlareMetric.faultsCount);
    logger.pushKey(
        'cervical_extension_fails_count', cervicalExtensionMetric.faultsCount);
    logger.pushKey(
        'foot_stationary_fails_count', footStationaryMetric.faultsCount);
    logger.pushKey('wall_contact_fails_count', wallContactMetric.faultsCount);
    logger.pushKey('tempo_fails_count', tempoMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
    logger.pushKey('completed_reps', repCount);
    logger.pushAverage('min_elbow_angle', 'avg_min_elbow_angle');
    logger.pushAverage('max_elbow_angle', 'avg_max_elbow_angle');
    logger.pushAverage('descent_duration', 'avg_descent_duration');
    logger.pushAverage('ascent_duration', 'avg_ascent_duration');
  }

  // --- Safety Checks ---

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "⚠️ Xin hãy quay nghiêng để theo dõi tư thế Wall Push Up";
    }

    final shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    final elbow = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightElbow,
        leftType: PoseLandmarkType.leftElbow);
    final wrist = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);
    final hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);

    if (shoulder == null || elbow == null || wrist == null || hip == null) {
      return "⚠️ Đảm bảo phần trên cơ thể trong khung hình";
    }

    if (!ExerciseBase.isLandmarkConfident(shoulder) ||
        !ExerciseBase.isLandmarkConfident(elbow) ||
        !ExerciseBase.isLandmarkConfident(wrist) ||
        !ExerciseBase.isLandmarkConfident(hip)) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
    }

    return null;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Get landmarks (core: shoulder/elbow/wrist/hip; optional: ankle/ear/nose)
    final shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    final elbow = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightElbow,
        leftType: PoseLandmarkType.leftElbow);
    final wrist = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);
    final hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);

    if (shoulder == null || elbow == null || wrist == null || hip == null) {
      return;
    }

    final ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    final heel = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHeel,
        leftType: PoseLandmarkType.leftHeel);
    final footIndex = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);
    final ear = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightEar,
        leftType: PoseLandmarkType.leftEar);
    final nose = smoothedLandmarks[PoseLandmarkType.nose];

    // 2. Calculate geometry (normalized interior angles, 0-180)
    final double elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);

    final double? bodyLineAngle = ankle == null
        ? null
        : calculateAngleNormalized(
            firstPoint: shoulder, midPoint: hip, lastPoint: ankle);

    double? shrugRatio;
    double? forwardHeadAngle;
    final shoulderToHip = calculateDistance(shoulder, hip);
    if (ear != null) {
      if (shoulderToHip > 0) {
        shrugRatio = calculateDistance(ear, shoulder) / shoulderToHip;
      }
      forwardHeadAngle = calculateAngleNormalized(
          firstPoint: ear, midPoint: shoulder, lastPoint: hip);
    }

    final double? neckTiltAngle = (ear == null || nose == null)
        ? null
        : calculateAngleNormalized(
            firstPoint: nose, midPoint: ear, lastPoint: shoulder);

    final double elbowFlareAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: shoulder, lastPoint: elbow);

    final footAnchor = _averagePoint([ankle, heel, footIndex]);
    final double? bodyFootAngle = (ankle == null || footIndex == null)
        ? null
        : calculateAngleNormalized(
            firstPoint: hip, midPoint: ankle, lastPoint: footIndex);
    final double? heelRaiseRatio =
        _calculateHeelRaiseRatio(heel, footIndex, shoulderToHip);
    final double? shoulderHipFootLineAngle = footAnchor == null
        ? null
        : _calculateAngleFromCoordinates(
            firstX: shoulder.x,
            firstY: shoulder.y,
            midX: hip.x,
            midY: hip.y,
            lastX: footAnchor.x,
            lastY: footAnchor.y,
          );
    final double? trunkInclinationAngle = footAnchor == null
        ? (ankle == null
            ? null
            : calculateAbsoluteHorizontalAngle(
                point1: shoulder,
                point2: ankle,
              ))
        : _calculateAbsoluteHorizontalAngleFromCoordinates(
            firstX: shoulder.x,
            firstY: shoulder.y,
            secondX: footAnchor.x,
            secondY: footAnchor.y,
          );

    final int now = frameTimestampMs;

    // 3. Build RepContext
    final ctx = RepContext(
      elbowAngle: elbowAngle,
      bodyLineAngle: bodyLineAngle,
      shrugRatio: shrugRatio,
      forwardHeadAngle: forwardHeadAngle,
      neckTiltAngle: neckTiltAngle,
      elbowFlareAngle: elbowFlareAngle,
      wristAnchorX: wrist.x,
      wristAnchorY: wrist.y,
      shoulderAnchorX: shoulder.x,
      shoulderAnchorY: shoulder.y,
      footAnchorX: footAnchor?.x,
      footAnchorY: footAnchor?.y,
      bodyFootAngle: bodyFootAngle,
      heelRaiseRatio: heelRaiseRatio,
      shoulderHipFootLineAngle: shoulderHipFootLineAngle,
      trunkInclinationAngle: trunkInclinationAngle,
      scaleFactor: shoulderToHip > 0 ? shoulderToHip : scaleFactor,
      state: wallPushUpState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // 4. Debug data
    debugData['wallPushUpState'] = wallPushUpState.toString().split('.').last;
    debugData['elbowAngle'] = elbowAngle.toStringAsFixed(1);
    debugData['bodyLine'] = bodyLineAngle?.toStringAsFixed(1) ?? 'N/A';
    debugData['shoulderHipFootLine'] =
        shoulderHipFootLineAngle?.toStringAsFixed(1) ?? 'N/A';
    debugData['trunkInclination'] =
        trunkInclinationAngle?.toStringAsFixed(1) ?? 'N/A';
    debugData['flareAngle'] = elbowFlareAngle.toStringAsFixed(1);
    debugData['bodyFootAngle'] = bodyFootAngle?.toStringAsFixed(1) ?? 'N/A';
    debugData['heelRaiseRatio'] = heelRaiseRatio?.toStringAsFixed(2) ?? 'N/A';
    debugData['correctForm'] = correctForm.toString();

    // 5. Update state machine before checking completion so the frame that
    // reaches lockout can count immediately.
    _updateState(elbowAngle, now);

    // 6. Rep completion (return to standing after a rep)
    if (wallPushUpState == WallPushUpState.standing &&
        previousWallPushUpState != WallPushUpState.standing) {
      if (previousWallPushUpState == WallPushUpState.ascending ||
          previousWallPushUpState == WallPushUpState.descending) {
        if (_repMaxElbow == null || elbowAngle > _repMaxElbow!) {
          _repMaxElbow = elbowAngle;
        }
      }

      // Effectiveness checks 6 & 8 use accumulated elbow extremes.
      _evaluateDepth(ctx);
      _evaluateLockout(ctx);

      tempoMetric.evaluateRep(ctx);

      // Collect faults from every metric.
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      final countRejectReason = _countRejectReason(allFaults, elbowAngle);
      if (countRejectReason != null) {
        final rejectVoice = _voiceForCountRejectReason(countRejectReason);
        lastRepFaultVoiceMessages = rejectVoice == null ? [] : [rejectVoice];
        lastRepTopVoiceMessage = rejectVoice;
        lastRepTopVoicePriority = rejectVoice == null ? null : 0;
        lastRepWasClean = false;
        correctForm = false;
        resultIssues.feedback['Result'] = 'Lần này chưa tính nhé';
        resultIssues.feedback['Form'] = countRejectReason;

        final faultMap = <String, Map<String, String>>{};
        for (final fault in allFaults) {
          faultMap.putIfAbsent(fault.phase, () => {});
          faultMap[fault.phase]![fault.type] = fault.message;
        }
        faultMap.putIfAbsent('REP_COMPLETE', () => {});
        faultMap['REP_COMPLETE']!['NoCount'] = countRejectReason;
        setFeedback.add({false: faultMap});

        _resetRepCycle(countMetricFaults: false);
        return;
      }

      repCount += 1;
      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] = correctForm ? 'Tốt!' : 'Chỉnh tư thế';

      final topVoicedFault = WallPushUp.topVoicedFault(allFaults);
      lastRepFaultVoiceMessages =
          WallPushUp.orderedUniqueVoiceMessages(allFaults);
      lastRepTopVoiceMessage = topVoicedFault?.voiceMessage;
      lastRepTopVoicePriority = topVoicedFault?.priority;
      lastRepWasClean = correctForm;

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        faultMap.putIfAbsent(fault.phase, () => {});
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      logger.addRepLog(
        RepLog(
          correctForm: correctForm,
          repNumber: repCount,
          data: {
            'min_elbow_angle': _repMinElbow,
            'max_elbow_angle': _repMaxElbow,
            'descent_duration': tempoMetric.descentDuration,
            'ascent_duration': tempoMetric.ascentDuration,
            'fault_types': allFaults.map((f) => f.type).toSet().toList(),
          },
        ),
      );

      if (tempoMetric.descentDuration != null) {
        var tempo = '↓${tempoMetric.descentDuration!.toStringAsFixed(1)}s';
        if (tempoMetric.ascentDuration != null) {
          tempo += ' ↑${tempoMetric.ascentDuration!.toStringAsFixed(1)}s';
        }
        resultIssues.feedback['Tempo'] = tempo;
      }

      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }

      _resetRepCycle(countMetricFaults: true);
      return;
    }

    // 7. Run all metrics + track effectiveness extremes (active states only)
    if (wallPushUpState != WallPushUpState.standing) {
      final trunkInclination = trunkInclinationAngle;
      final isFloorLike = trunkInclination != null &&
          trunkInclination < WallPushUpConfig.ACTIVE_TRUNK_INCLINATION_MIN;
      if (_activeTrunkInclinationDebouncer.update(isFloorLike)) {
        _trunkInclinationInvalidThisRep = true;
        resultIssues.feedback['Setup'] =
            'Giữ người nghiêng vào tường, không hạ xuống như chống đẩy sàn.';
        resultIssues.addInstruction('standing', 'Setup',
            'Đứng nghiêng người vào tường; vai, hông và chân tạo một đường chéo rõ.');
      }

      for (final metric in _metrics) {
        metric.update(ctx);
      }

      if (wallPushUpState == WallPushUpState.descending ||
          wallPushUpState == WallPushUpState.bottom) {
        if (_repMinElbow == null || elbowAngle < _repMinElbow!) {
          _repMinElbow = elbowAngle;
        }
      }
      if (wallPushUpState == WallPushUpState.ascending) {
        if (_repMaxElbow == null || elbowAngle > _repMaxElbow!) {
          _repMaxElbow = elbowAngle;
        }
      }
    }

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Phase status chips.
    if (wallPushUpState == WallPushUpState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Đang hạ...');
    } else if (wallPushUpState == WallPushUpState.bottom) {
      resultIssues.addInstruction('bottom', 'Status', 'Đẩy ra!');
    } else if (wallPushUpState == WallPushUpState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Đang đẩy ra!');
    }
  }

  // --- Effectiveness Check 6: Depth (coaching only, affectsForm=false) ---

  void _evaluateDepth(RepContext ctx) {
    final min = _repMinElbow;
    if (min == null) return;
    debugData['minElbow'] = min.toStringAsFixed(1);

    if (min > WallPushUpConfig.DEPTH_SHALLOW_MAX) {
      ctx.resultIssues.addInstruction('standing', 'Depth',
          'Cố gắng hạ người thấp hơn, khuỷu tay gập 90 độ.');
    } else if (min > WallPushUpConfig.DEPTH_GOOD_MAX) {
      ctx.resultIssues
          .addInstruction('standing', 'Depth', 'Thử xuống sâu hơn một chút!');
    }
  }

  // --- Effectiveness Check 8: Full lockout (coaching only) ---

  void _evaluateLockout(RepContext ctx) {
    final peak = _repMaxElbow;
    if (peak == null) return;
    debugData['peakElbow'] = peak.toStringAsFixed(1);

    if (peak < WallPushUpConfig.LOCKOUT_WARN_MIN) {
      ctx.resultIssues.addInstruction(
          'standing', 'Lockout', 'Đẩy tay thẳng ra hết cỡ, khóa khuỷu tay.');
    } else if (peak < WallPushUpConfig.LOCKOUT_GOOD_MIN) {
      ctx.resultIssues.addInstruction(
          'standing', 'Lockout', 'Duỗi thẳng tay hết cỡ ở lần sau!');
    }
  }

  String? _countRejectReason(List<FaultRecord> faults, double currentElbow) {
    final minElbow = _repMinElbow;
    if (minElbow == null || minElbow > WallPushUpConfig.BOTTOM_ANGLE_MAX) {
      return 'Chưa xuống đủ sâu — gập khuỷu tay rõ hơn.';
    }

    if (currentElbow <= WallPushUpConfig.STANDING_ANGLE_THRESHOLD) {
      return 'Chưa đẩy tay thẳng về vị trí ban đầu.';
    }

    if (_trunkInclinationInvalidThisRep) {
      return 'Đây chưa giống Wall Push Up — hãy đứng nghiêng người vào tường.';
    }

    return null;
  }

  String? _voiceForCountRejectReason(String reason) {
    if (reason.contains('Chưa xuống đủ sâu')) return 'Xuống thấp hơn';
    if (reason.contains('Wall Push Up')) return 'Đứng nghiêng vào tường';
    if (reason.contains('Vai, hông') || reason.contains('thẳng hàng')) {
      return 'Giữ thân thẳng';
    }
    return null;
  }

  void _resetRepCycle({required bool countMetricFaults}) {
    // Reset for next rep. Baselines stay inside metrics by design.
    correctForm = true;
    wallPushUpState = WallPushUpState.standing;
    previousWallPushUpState = WallPushUpState.standing;
    _entryDebouncer.reset();
    for (final metric in _metrics) {
      if (countMetricFaults) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }
    _repMinElbow = null;
    _repMaxElbow = null;
    _trunkInclinationInvalidThisRep = false;
    _activeTrunkInclinationDebouncer.reset();
  }

  // --- State Machine (mirrors push-up: entry-debounced threshold machine) ---

  void _updateState(double elbowAngle, int timestampMs) {
    final bool isEntering =
        elbowAngle < WallPushUpConfig.DESCEND_ANGLE_THRESHOLD;
    final bool confirmedEntry = _entryDebouncer.update(isEntering);

    if (confirmedEntry && wallPushUpState == WallPushUpState.standing) {
      _transitionState(WallPushUpState.descending, timestampMs);
    } else if (elbowAngle <= WallPushUpConfig.BOTTOM_ANGLE_MAX &&
        wallPushUpState == WallPushUpState.descending) {
      _transitionState(WallPushUpState.bottom, timestampMs);
    } else if (elbowAngle > WallPushUpConfig.BOTTOM_EXIT &&
        wallPushUpState == WallPushUpState.bottom) {
      _transitionState(WallPushUpState.ascending, timestampMs);
    } else if (elbowAngle > WallPushUpConfig.STANDING_ANGLE_THRESHOLD &&
        (wallPushUpState == WallPushUpState.ascending ||
            wallPushUpState == WallPushUpState.descending)) {
      _transitionState(WallPushUpState.standing, timestampMs);
    }
  }

  void _transitionState(WallPushUpState newState, int timestampMs) {
    previousWallPushUpState = wallPushUpState;
    wallPushUpState = newState;

    // Clear old coaching at the start of a new rep.
    if (newState == WallPushUpState.descending &&
        previousWallPushUpState == WallPushUpState.standing) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousWallPushUpState, newState, timestampMs);
    }
  }

  double? _calculateHeelRaiseRatio(
    PoseLandmark? heel,
    PoseLandmark? footIndex,
    double? scale,
  ) {
    if (heel == null || footIndex == null || scale == null || scale <= 0) {
      return null;
    }
    if (!ExerciseBase.isLandmarkConfident(heel) ||
        !ExerciseBase.isLandmarkConfident(footIndex)) {
      return null;
    }

    return (footIndex.y - heel.y) / scale;
  }

  _Point? _averagePoint(List<PoseLandmark?> points) {
    final visible = points.whereType<PoseLandmark>().toList(growable: false);
    if (visible.isEmpty) return null;

    var x = 0.0;
    var y = 0.0;
    for (final point in visible) {
      x += point.x;
      y += point.y;
    }

    return _Point(x / visible.length, y / visible.length);
  }

  double _calculateAngleFromCoordinates({
    required double firstX,
    required double firstY,
    required double midX,
    required double midY,
    required double lastX,
    required double lastY,
  }) {
    var radians = math.atan2(lastY - midY, lastX - midX) -
        math.atan2(firstY - midY, firstX - midX);
    var degrees = (radians * 180.0 / math.pi).abs();
    if (degrees > 180.0) {
      degrees = 360.0 - degrees;
    }
    return degrees;
  }

  double _calculateAbsoluteHorizontalAngleFromCoordinates({
    required double firstX,
    required double firstY,
    required double secondX,
    required double secondY,
  }) {
    final dy = (secondY - firstY).abs();
    final dx = (secondX - firstX).abs();
    return math.atan2(dy, dx) * (180.0 / math.pi);
  }
}

class _Point {
  final double x;
  final double y;

  const _Point(this.x, this.y);
}
