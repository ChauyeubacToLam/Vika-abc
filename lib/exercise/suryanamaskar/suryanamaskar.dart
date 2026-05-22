// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/surya_metric_base.dart';
import 'metrics/lumbar_break_metric.dart';
import 'metrics/knee_bend_metric.dart';
import 'metrics/lunge_knee_shear_metric.dart';
import 'metrics/downdog_spine_metric.dart';
import 'metrics/ashtanga_hip_metric.dart';
import 'metrics/cobra_neck_metric.dart';
import 'metrics/symmetry_metric.dart';

/// Suryanamaskar — Chuỗi Chào Mặt Trời 12 bước.
///
/// Camera: Side (sagittal plane, 100%).
/// 1 Rep = 12 poses liên tiếp (P1 → P12 → count).
class Suryanamaskar extends ExerciseBase with SideTrackedExerciseMixin {
  // ── Orientation ──
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Suryanamaskar';

  // ── Side-tracked landmarks ──
  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'ear': (
          right: PoseLandmarkType.rightEar,
          left: PoseLandmarkType.leftEar
        ),
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
  Map<String, SideLandmarkPair> get optionalSideLandmarks => const {
        'footIndex': (
          right: PoseLandmarkType.rightFootIndex,
          left: PoseLandmarkType.leftFootIndex
        ),
        'nose': (
          right: PoseLandmarkType.nose,
          left: PoseLandmarkType.nose
        ),
      };

  // ── State Machine ──
  SuryaState _state = SuryaState.p1_pranamasana;
  SuryaState _prevState = SuryaState.p1_pranamasana;

  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

  int _lastTransitionTimeMs = 0;
  String _transitionMessage = "";

  // ── Metrics ──
  final LumbarBreakMetric lumbarMetric = LumbarBreakMetric();
  final KneeBendMetric kneeBendMetric = KneeBendMetric();
  final LungeKneeShearMetric lungeMetric = LungeKneeShearMetric();
  final DowndogSpineMetric downdogMetric = DowndogSpineMetric();
  final AshtangaHipMetric ashtangaMetric = AshtangaHipMetric();
  final CobraNeckMetric cobraMetric = CobraNeckMetric();
  final SymmetryMetric symmetryMetric = SymmetryMetric();

  late final List<SuryaMetricBase> _metrics = [
    lumbarMetric,
    kneeBendMetric,
    lungeMetric,
    downdogMetric,
    ashtangaMetric,
    cobraMetric,
    symmetryMetric,
  ];

  // ── Phase UI ──
  @override
  String get currentPhaseKey => _state.name;

  @override
  String get currentPhaseLabel {
    switch (_state) {
      case SuryaState.p1_pranamasana:
        return 'P1: Cầu nguyện';
      case SuryaState.p2_hasta_uttanasana:
        return 'P2: Vươn tay';
      case SuryaState.p3_hastapaadasana:
        return 'P3: Gập người';
      case SuryaState.p4_ashwa_sanchalanasana:
        return 'P4: Kỵ sĩ';
      case SuryaState.p5_parvatasana:
        return 'P5: Chó cúi mặt';
      case SuryaState.p6_ashtanga_namaskara:
        return 'P6: 8 điểm';
      case SuryaState.p7_bhujangasana:
        return 'P7: Rắn hổ mang';
      case SuryaState.p8_parvatasana_return:
        return 'P8: Chó cúi mặt';
      case SuryaState.p9_ashwa_return:
        return 'P9: Kỵ sĩ';
      case SuryaState.p10_hastapaadasana_return:
        return 'P10: Gập người';
      case SuryaState.p11_hasta_uttanasana_return:
        return 'P11: Vươn tay';
      case SuryaState.p12_pranamasana_return:
        return 'P12: Cầu nguyện';
    }
  }

  // ── Safety ──
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "Vui lòng đặt camera quay ngang người (Side View).";
    }
    return null;
  }

  // ── Start Position ──
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return false;

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final ankle = lm['ankle']!;

    // Đứng thẳng: Ankle-Hip-Shoulder ~170-180°
    final bodyAngle = calculateAngleNormalized(
        firstPoint: ankle, midPoint: hip, lastPoint: shoulder);

    debugData['Setup_Diagnostic'] = {
      'bodyAngle': bodyAngle.toStringAsFixed(1),
      'isStanding': bodyAngle >= SuryaConfig.STANDING_STRAIGHT_RANGE[0] &&
          bodyAngle <= SuryaConfig.STANDING_STRAIGHT_RANGE[1],
    };

    return bodyAngle >= SuryaConfig.STANDING_STRAIGHT_RANGE[0] &&
        bodyAngle <= SuryaConfig.STANDING_STRAIGHT_RANGE[1];
  }

  // ── Stop Condition ──
  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null &&
        (frameTimestampMs - _exerciseStartTimeMs!) >
            SuryaConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= SuryaConfig.MAX_REP;
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIN LOOP
  // ═══════════════════════════════════════════════════════════════

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;

    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return;

    final ear = lm['ear']!;
    final shoulder = lm['shoulder']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;
    final footIndex = lm['footIndex'] ?? ankle; // Fallback
    final nose = lm['nose'] ?? ear; // Fallback

    scaleFactor = calculateDistance(shoulder, hip);

    // --- Tính tất cả các góc ---
    final bodyAngle = calculateAngleNormalized(
        firstPoint: ankle, midPoint: hip, lastPoint: shoulder);
    final hipFlexionAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    final kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    final elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    final armShoulderAngle = calculateAngleNormalized(
        firstPoint: wrist, midPoint: shoulder, lastPoint: hip);
    final neckAngle = calculateAngleNormalized(
        firstPoint: ear, midPoint: shoulder, lastPoint: hip);

    // --- DIAGNOSTIC TABLE ---
    debugData['Diagnostic_Table'] = {
      'State': _state.name,
      'BodyAngle': bodyAngle.toStringAsFixed(1),
      'HipFlexion': hipFlexionAngle.toStringAsFixed(1),
      'KneeAngle': kneeAngle.toStringAsFixed(1),
      'ElbowAngle': elbowAngle.toStringAsFixed(1),
      'ArmShoulder': armShoulderAngle.toStringAsFixed(1),
      'NeckAngle': neckAngle.toStringAsFixed(1),
      'WristY': wrist.y.toStringAsFixed(1),
      'NoseY': nose.y.toStringAsFixed(1),
      'HipY': hip.y.toStringAsFixed(1),
      'ShoulderY': shoulder.y.toStringAsFixed(1),
    };

    // --- Build Context ---
    final ctx = SuryaContext(
      state: _state,
      frameTimestamp: frameTimestampMs,
      scaleFactor: scaleFactor,
      bodyAngle: bodyAngle,
      hipFlexionAngle: hipFlexionAngle,
      kneeAngle: kneeAngle,
      elbowAngle: elbowAngle,
      armShoulderAngle: armShoulderAngle,
      neckAngle: neckAngle,
      wristY: wrist.y,
      shoulderY: shoulder.y,
      hipY: hip.y,
      kneeY: knee.y,
      ankleY: ankle.y,
      earY: ear.y,
      noseY: nose.y,
      wristX: wrist.x,
      shoulderX: shoulder.x,
      hipX: hip.x,
      kneeX: knee.x,
      ankleX: ankle.x,
      footIndexX: footIndex.x,
      earShoulderDist: calculateDistance(ear, shoulder),
      resultIssues: resultIssues,
    );

    // --- State Machine ---
    _updateStateMachine(ctx);

    if (frameTimestampMs - _lastTransitionTimeMs < 3000 && _transitionMessage.isNotEmpty) {
      resultIssues.feedback['Chuyển bước'] = _transitionMessage;
    } else {
      resultIssues.feedback['Bước hiện tại'] = currentPhaseLabel;
    }

    // --- Run Metrics ---
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STATE MACHINE — 12 Poses Flow
  // ═══════════════════════════════════════════════════════════════

  void _updateStateMachine(SuryaContext ctx) {
    switch (_state) {
      // ── P1: Cầu nguyện → P2: Vươn tay ──
      case SuryaState.p1_pranamasana:
        // Trigger: Cổ tay vươn lên cao vượt qua Mũi (Nose)
        if (ctx.wristY < ctx.noseY - SuryaConfig.WRIST_ABOVE_NOSE_MARGIN) {
          _transitionTo(SuryaState.p2_hasta_uttanasana, ctx.frameTimestamp);
        }
        break;

      // ── P2: Vươn tay → P3: Gập người ──
      case SuryaState.p2_hasta_uttanasana:
        // Trigger: Cổ tay + Vai lao xuống (hipFlexion giảm)
        if (ctx.hipFlexionAngle < SuryaConfig.FOLD_HIP_ANGLE_THRESHOLD &&
            ctx.wristY > ctx.shoulderY) {
          _transitionTo(SuryaState.p3_hastapaadasana, ctx.frameTimestamp);
        }
        break;

      // ── P3: Gập người → P4: Kỵ sĩ ──
      case SuryaState.p3_hastapaadasana:
        // Trigger: Một chân bước ra sau (ankle X giãn xa),
        // đầu gối hạ thấp, ngực vươn lên (shoulderY < hipY)
        if (ctx.shoulderY < ctx.hipY && ctx.hipFlexionAngle > 80) {
          _transitionTo(
              SuryaState.p4_ashwa_sanchalanasana, ctx.frameTimestamp);
        }
        break;

      // ── P4: Kỵ sĩ → P5: Chó cúi mặt ──
      case SuryaState.p4_ashwa_sanchalanasana:
        // Trigger: Hông đẩy lên cao nhất (hipY là điểm cao nhất)
        if (ctx.hipY < ctx.shoulderY && ctx.hipY < ctx.ankleY) {
          _transitionTo(SuryaState.p5_parvatasana, ctx.frameTimestamp);
        }
        break;

      // ── P5: Chó cúi mặt → P6: 8 điểm ──
      case SuryaState.p5_parvatasana:
        // Trigger: Gối + Ngực hạ xuống (shoulderY tăng, kneeY tăng)
        // Hip vẫn nhô lên
        if (ctx.shoulderY > ctx.hipY && ctx.kneeY > ctx.hipY) {
          _transitionTo(SuryaState.p6_ashtanga_namaskara, ctx.frameTimestamp);
        }
        break;

      // ── P6: 8 điểm → P7: Rắn hổ mang ──
      case SuryaState.p6_ashtanga_namaskara:
        // Trigger: Hông hạ sát sàn, Vai + Đầu nhấc lên
        if (ctx.hipY >= ctx.shoulderY && ctx.shoulderY < ctx.kneeY) {
          _transitionTo(SuryaState.p7_bhujangasana, ctx.frameTimestamp);
        }
        break;

      // ── P7: Rắn hổ mang → P8: Chó cúi mặt (lặp) ──
      case SuryaState.p7_bhujangasana:
        // Trigger: Hông đẩy vọt lên cao (V ngược lần 2)
        if (ctx.hipY < ctx.shoulderY && ctx.hipY < ctx.ankleY) {
          _transitionTo(SuryaState.p8_parvatasana_return, ctx.frameTimestamp);
        }
        break;

      // ── P8: Chó cúi mặt → P9: Kỵ sĩ (bước chân lên) ──
      case SuryaState.p8_parvatasana_return:
        // Trigger: Một bàn chân phóng lên trước (ankleX gần wristX)
        if (ctx.shoulderY < ctx.hipY && ctx.hipFlexionAngle > 80) {
          _transitionTo(SuryaState.p9_ashwa_return, ctx.frameTimestamp);
        }
        break;

      // ── P9: Kỵ sĩ → P10: Gập người ──
      case SuryaState.p9_ashwa_return:
        // Trigger: Thu chân, Hông đẩy lên, Vai hạ thấp, gập sát
        if (ctx.hipFlexionAngle < SuryaConfig.FOLD_HIP_ANGLE_THRESHOLD &&
            ctx.wristY > ctx.hipY) {
          _transitionTo(
              SuryaState.p10_hastapaadasana_return, ctx.frameTimestamp);
        }
        break;

      // ── P10: Gập người → P11: Vươn tay ngả sau ──
      case SuryaState.p10_hastapaadasana_return:
        // Trigger: Thân dựng đứng, Cổ tay vươn qua đầu
        if (ctx.wristY < ctx.noseY - SuryaConfig.WRIST_ABOVE_NOSE_MARGIN &&
            ctx.bodyAngle > 140) {
          _transitionTo(
              SuryaState.p11_hasta_uttanasana_return, ctx.frameTimestamp);
        }
        break;

      // ── P11: Vươn tay → P12: Cầu nguyện ──
      case SuryaState.p11_hasta_uttanasana_return:
        // Trigger: Cổ tay hạ xuống trước ngực (wristY > shoulderY)
        if (ctx.wristY > ctx.shoulderY &&
            ctx.bodyAngle >= SuryaConfig.STANDING_STRAIGHT_RANGE[0]) {
          _transitionTo(
              SuryaState.p12_pranamasana_return, ctx.frameTimestamp);
        }
        break;

      // ── P12: Cầu nguyện → Hoàn thành 1 Rep ──
      case SuryaState.p12_pranamasana_return:
        // Cơ thể đứng thẳng → cộng 1 rep
        if (ctx.bodyAngle >= SuryaConfig.STANDING_STRAIGHT_RANGE[0]) {
          _completeRep(ctx);
        }
        break;
    }
  }

  void _transitionTo(SuryaState newState, int timestampMs) {
    if (newState == _state) return;
    _prevState = _state;
    _state = newState;

    _lastTransitionTimeMs = timestampMs;
    _transitionMessage = "Sang $currentPhaseLabel";
    ttsService.speak(_transitionMessage);

    for (final metric in _metrics) {
      metric.onStateTransition(_prevState, newState, timestampMs);
    }
  }

  void _completeRep(SuryaContext ctx) {
    repCount++;

    // Evaluate symmetry
    symmetryMetric.evaluateRepEnd(ctx);

    // Collect all faults
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    correctForm = !allFaults.any((f) => f.affectsForm);

    // Log rep
    logger.addRepLog(RepLog(
      repNumber: repCount,
      correctForm: correctForm,
      data: {
        'fault_types': allFaults.map((f) => f.type).toSet().toList(),
        'p4_knee_angle': lungeMetric.lungeKneeAngleP4,
        'p9_knee_angle': lungeMetric.lungeKneeAngleP9,
      },
    ));

    // Reset state and metrics
    _transitionTo(SuryaState.p1_pranamasana, ctx.frameTimestamp);
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
    // Also reset lunge angles for next rep
    lungeMetric.lungeKneeAngleP4 = null;
    lungeMetric.lungeKneeAngleP9 = null;
  }

  // ── Set Complete ──
  @override
  void onSetComplete() {
    logger.pushKey("timeout_triggered", _isTimeout);
    logger.pushKey("lumbar_fails_count", lumbarMetric.faultsCount);
    logger.pushKey("knee_bend_fails_count", kneeBendMetric.faultsCount);
    logger.pushKey("lunge_shear_fails_count", lungeMetric.faultsCount);
    logger.pushKey("downdog_fails_count", downdogMetric.faultsCount);
    logger.pushKey("ashtanga_hip_fails_count", ashtangaMetric.faultsCount);
    logger.pushKey("cobra_neck_fails_count", cobraMetric.faultsCount);
    logger.pushKey("symmetry_fails_count", symmetryMetric.faultsCount);
    logger.pushGoodRepCount();
  }
}
