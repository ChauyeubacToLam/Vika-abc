// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/cmt_1_metric_base.dart';
import 'metrics/lumbar_break_metric.dart';
import 'metrics/knee_bend_metric.dart';
import 'metrics/lunge_knee_shear_metric.dart';
import 'metrics/downdog_spine_metric.dart';
import 'metrics/ashtanga_hip_metric.dart';
import 'metrics/cobra_neck_metric.dart';
import 'metrics/symmetry_metric.dart';

/// Cmt1 â€” Chuá»—i ChÃ o Máº·t Trá»i 12 bÆ°á»›c.
///
/// Camera: Side (sagittal plane, 100%).
/// 1 Rep = 12 poses liÃªn tiáº¿p (P1 â†’ P12 â†’ count).
class Cmt1 extends ExerciseBase with SideTrackedExerciseMixin {
  // â”€â”€ Orientation â”€â”€
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Cmt1';

  // â”€â”€ Side-tracked landmarks â”€â”€
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

  // â”€â”€ State Machine â”€â”€
  Cmt1State _state = Cmt1State.p1_pranamasana;
  Cmt1State _prevState = Cmt1State.p1_pranamasana;

  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

  int _lastTransitionTimeMs = 0;
  String _transitionMessage = "";

  // â”€â”€ Metrics â”€â”€
  final LumbarBreakMetric lumbarMetric = LumbarBreakMetric();
  final KneeBendMetric kneeBendMetric = KneeBendMetric();
  final LungeKneeShearMetric lungeMetric = LungeKneeShearMetric();
  final DowndogSpineMetric downdogMetric = DowndogSpineMetric();
  final AshtangaHipMetric ashtangaMetric = AshtangaHipMetric();
  final CobraNeckMetric cobraMetric = CobraNeckMetric();
  final SymmetryMetric symmetryMetric = SymmetryMetric();

  late final List<Cmt1MetricBase> _metrics = [
    lumbarMetric,
    kneeBendMetric,
    lungeMetric,
    downdogMetric,
    ashtangaMetric,
    cobraMetric,
    symmetryMetric,
  ];

  // â”€â”€ Phase UI â”€â”€
  @override
  String get currentPhaseKey => _state.name;

  @override
  String get currentPhaseLabel {
    switch (_state) {
      case Cmt1State.p1_pranamasana:
        return 'P1: Cáº§u nguyá»‡n';
      case Cmt1State.p2_hasta_uttanasana:
        return 'P2: VÆ°Æ¡n tay';
      case Cmt1State.p3_hastapaadasana:
        return 'P3: Gáº­p ngÆ°á»i';
      case Cmt1State.p4_ashwa_sanchalanasana:
        return 'P4: Ká»µ sÄ©';
      case Cmt1State.p5_parvatasana:
        return 'P5: ChÃ³ cÃºi máº·t';
      case Cmt1State.p6_ashtanga_namaskara:
        return 'P6: 8 Ä‘iá»ƒm';
      case Cmt1State.p7_bhujangasana:
        return 'P7: Ráº¯n há»• mang';
      case Cmt1State.p8_parvatasana_return:
        return 'P8: ChÃ³ cÃºi máº·t';
      case Cmt1State.p9_ashwa_return:
        return 'P9: Ká»µ sÄ©';
      case Cmt1State.p10_hastapaadasana_return:
        return 'P10: Gáº­p ngÆ°á»i';
      case Cmt1State.p11_hasta_uttanasana_return:
        return 'P11: VÆ°Æ¡n tay';
      case Cmt1State.p12_pranamasana_return:
        return 'P12: Cáº§u nguyá»‡n';
    }
  }

  // â”€â”€ Safety â”€â”€
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "Vui lÃ²ng Ä‘áº·t camera quay ngang ngÆ°á»i (Side View).";
    }
    return null;
  }

  // â”€â”€ Start Position â”€â”€
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return false;

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final ankle = lm['ankle']!;

    // Äá»©ng tháº³ng: Ankle-Hip-Shoulder ~170-180Â°
    final bodyAngle = calculateAngleNormalized(
        firstPoint: ankle, midPoint: hip, lastPoint: shoulder);

    debugData['Setup_Diagnostic'] = {
      'bodyAngle': bodyAngle.toStringAsFixed(1),
      'isStanding': bodyAngle >= Cmt1Config.STANDING_STRAIGHT_RANGE[0] &&
          bodyAngle <= Cmt1Config.STANDING_STRAIGHT_RANGE[1],
    };

    return bodyAngle >= Cmt1Config.STANDING_STRAIGHT_RANGE[0] &&
        bodyAngle <= Cmt1Config.STANDING_STRAIGHT_RANGE[1];
  }

  // â”€â”€ Stop Condition â”€â”€
  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null &&
        (frameTimestampMs - _exerciseStartTimeMs!) >
            Cmt1Config.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= Cmt1Config.MAX_REP;
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // MAIN LOOP
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

    // --- TÃ­nh táº¥t cáº£ cÃ¡c gÃ³c ---
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
    final ctx = Cmt1Context(
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
      resultIssues.feedback['Chuyá»ƒn bÆ°á»›c'] = _transitionMessage;
    } else {
      resultIssues.feedback['BÆ°á»›c hiá»‡n táº¡i'] = currentPhaseLabel;
    }

    // --- Run Metrics ---
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // STATE MACHINE â€” 12 Poses Flow
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _updateStateMachine(Cmt1Context ctx) {
    switch (_state) {
      // â”€â”€ P1: Cáº§u nguyá»‡n â†’ P2: VÆ°Æ¡n tay â”€â”€
      case Cmt1State.p1_pranamasana:
        // Trigger: Cá»• tay vÆ°Æ¡n lÃªn cao vÆ°á»£t qua MÅ©i (Nose)
        if (ctx.wristY < ctx.noseY - Cmt1Config.WRIST_ABOVE_NOSE_MARGIN) {
          _transitionTo(Cmt1State.p2_hasta_uttanasana, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P2: VÆ°Æ¡n tay â†’ P3: Gáº­p ngÆ°á»i â”€â”€
      case Cmt1State.p2_hasta_uttanasana:
        // Trigger: Cá»• tay + Vai lao xuá»‘ng (hipFlexion giáº£m)
        if (ctx.hipFlexionAngle < Cmt1Config.FOLD_HIP_ANGLE_THRESHOLD &&
            ctx.wristY > ctx.shoulderY) {
          _transitionTo(Cmt1State.p3_hastapaadasana, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P3: Gáº­p ngÆ°á»i â†’ P4: Ká»µ sÄ© â”€â”€
      case Cmt1State.p3_hastapaadasana:
        // Trigger: Má»™t chÃ¢n bÆ°á»›c ra sau (ankle X giÃ£n xa),
        // Ä‘áº§u gá»‘i háº¡ tháº¥p, ngá»±c vÆ°Æ¡n lÃªn (shoulderY < hipY)
        if (ctx.shoulderY < ctx.hipY && ctx.hipFlexionAngle > 80) {
          _transitionTo(
              Cmt1State.p4_ashwa_sanchalanasana, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P4: Ká»µ sÄ© â†’ P5: ChÃ³ cÃºi máº·t â”€â”€
      case Cmt1State.p4_ashwa_sanchalanasana:
        // Trigger: HÃ´ng Ä‘áº©y lÃªn cao nháº¥t (hipY lÃ  Ä‘iá»ƒm cao nháº¥t)
        if (ctx.hipY < ctx.shoulderY && ctx.hipY < ctx.ankleY) {
          _transitionTo(Cmt1State.p5_parvatasana, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P5: ChÃ³ cÃºi máº·t â†’ P6: 8 Ä‘iá»ƒm â”€â”€
      case Cmt1State.p5_parvatasana:
        // Trigger: Gá»‘i + Ngá»±c háº¡ xuá»‘ng (shoulderY tÄƒng, kneeY tÄƒng)
        // Hip váº«n nhÃ´ lÃªn
        if (ctx.shoulderY > ctx.hipY && ctx.kneeY > ctx.hipY) {
          _transitionTo(Cmt1State.p6_ashtanga_namaskara, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P6: 8 Ä‘iá»ƒm â†’ P7: Ráº¯n há»• mang â”€â”€
      case Cmt1State.p6_ashtanga_namaskara:
        // Trigger: HÃ´ng háº¡ sÃ¡t sÃ n, Vai + Äáº§u nháº¥c lÃªn
        if (ctx.hipY >= ctx.shoulderY && ctx.shoulderY < ctx.kneeY) {
          _transitionTo(Cmt1State.p7_bhujangasana, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P7: Ráº¯n há»• mang â†’ P8: ChÃ³ cÃºi máº·t (láº·p) â”€â”€
      case Cmt1State.p7_bhujangasana:
        // Trigger: HÃ´ng Ä‘áº©y vá»t lÃªn cao (V ngÆ°á»£c láº§n 2)
        if (ctx.hipY < ctx.shoulderY && ctx.hipY < ctx.ankleY) {
          _transitionTo(Cmt1State.p8_parvatasana_return, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P8: ChÃ³ cÃºi máº·t â†’ P9: Ká»µ sÄ© (bÆ°á»›c chÃ¢n lÃªn) â”€â”€
      case Cmt1State.p8_parvatasana_return:
        // Trigger: Má»™t bÃ n chÃ¢n phÃ³ng lÃªn trÆ°á»›c (ankleX gáº§n wristX)
        if (ctx.shoulderY < ctx.hipY && ctx.hipFlexionAngle > 80) {
          _transitionTo(Cmt1State.p9_ashwa_return, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P9: Ká»µ sÄ© â†’ P10: Gáº­p ngÆ°á»i â”€â”€
      case Cmt1State.p9_ashwa_return:
        // Trigger: Thu chÃ¢n, HÃ´ng Ä‘áº©y lÃªn, Vai háº¡ tháº¥p, gáº­p sÃ¡t
        if (ctx.hipFlexionAngle < Cmt1Config.FOLD_HIP_ANGLE_THRESHOLD &&
            ctx.wristY > ctx.hipY) {
          _transitionTo(
              Cmt1State.p10_hastapaadasana_return, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P10: Gáº­p ngÆ°á»i â†’ P11: VÆ°Æ¡n tay ngáº£ sau â”€â”€
      case Cmt1State.p10_hastapaadasana_return:
        // Trigger: ThÃ¢n dá»±ng Ä‘á»©ng, Cá»• tay vÆ°Æ¡n qua Ä‘áº§u
        if (ctx.wristY < ctx.noseY - Cmt1Config.WRIST_ABOVE_NOSE_MARGIN &&
            ctx.bodyAngle > 140) {
          _transitionTo(
              Cmt1State.p11_hasta_uttanasana_return, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P11: VÆ°Æ¡n tay â†’ P12: Cáº§u nguyá»‡n â”€â”€
      case Cmt1State.p11_hasta_uttanasana_return:
        // Trigger: Cá»• tay háº¡ xuá»‘ng trÆ°á»›c ngá»±c (wristY > shoulderY)
        if (ctx.wristY > ctx.shoulderY &&
            ctx.bodyAngle >= Cmt1Config.STANDING_STRAIGHT_RANGE[0]) {
          _transitionTo(
              Cmt1State.p12_pranamasana_return, ctx.frameTimestamp);
        }
        break;

      // â”€â”€ P12: Cáº§u nguyá»‡n â†’ HoÃ n thÃ nh 1 Rep â”€â”€
      case Cmt1State.p12_pranamasana_return:
        // CÆ¡ thá»ƒ Ä‘á»©ng tháº³ng â†’ cá»™ng 1 rep
        if (ctx.bodyAngle >= Cmt1Config.STANDING_STRAIGHT_RANGE[0]) {
          _completeRep(ctx);
        }
        break;
    }
  }

  void _transitionTo(Cmt1State newState, int timestampMs) {
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

  void _completeRep(Cmt1Context ctx) {
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
    _transitionTo(Cmt1State.p1_pranamasana, ctx.frameTimestamp);
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
    // Also reset lunge angles for next rep
    lungeMetric.lungeKneeAngleP4 = null;
    lungeMetric.lungeKneeAngleP9 = null;
  }

  // â”€â”€ Set Complete â”€â”€
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

