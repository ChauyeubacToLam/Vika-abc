/* =========================================================================
   Metric 4: Shoulder-Arm Angle / Elbow Flare
   Priority: 🔴 SAFETY (extreme = form-critical) — wide elbows pinch the
   rotator cuff. #1 cause of shoulder pain from push-ups.
 
   ANGLE metric (absolute, no baseline). Measures HIP→SHOULDER→ELBOW
   (normalized), so the measured joint is the SHOULDER and the two segments are
   trunk line and upper arm. Small = upper arm tucked near body. Large = arm
   flared wide from the shoulder.
 
   COARSE from a side camera — see spec caveat. Treat as good / too-wide,
   NOT a precise angle. Do NOT surface the raw number to the user.
 
   Phase-gated: only meaningful while the arm is loaded, so check ONLY
   during DESCENDING / BOTTOM and only when elbowAngle < 150°. At the top
   the angle is meaningless.
 
   Thresholds (Week 1-4 — Elbow Flare good band is CLINICAL, error is ESTIMATE):
     Good:    20-55°
     Warning: 55-70°
     Error:   > 70°       (8-frame debounce, affectsForm = true)
   ========================================================================= */

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class ElbowFlareConfig {
  static const double GOOD_MAX = 65.0;
  static const double ERROR_MIN = 82.0; // > this = error

  /// Only check flare when the arm is actually bending into the rep.
  static const double PHASE_GATE_ELBOW = 140.0;
}

class ElbowFlareMetric extends WallPushUpMetricBase {
  @override
  String get name => 'ShoulderArmAngle';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _debouncer = Debouncer(requiredFrames: 8);
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Phase gate: descending/bottom only, and only once the arm is bending.
    final inPhase = ctx.state == WallPushUpState.descending ||
        ctx.state == WallPushUpState.bottom;
    if (!inPhase || ctx.elbowAngle >= ElbowFlareConfig.PHASE_GATE_ELBOW) {
      return;
    }

    final shoulderArmAngle = ctx.elbowFlareAngle;
    final phase = ctx.state.toString().split('.').last.toUpperCase();
    // UI should use the label; raw angle is kept for debug/QA.
    _debugData['shoulderArmAngle'] = shoulderArmAngle.toStringAsFixed(1);
    _debugData['flareLabel'] = shoulderArmAngle > ElbowFlareConfig.GOOD_MAX
        ? (shoulderArmAngle > ElbowFlareConfig.ERROR_MIN ? 'wide' : 'moderate')
        : 'tucked';

    final bool isOff = shoulderArmAngle > ElbowFlareConfig.GOOD_MAX;
    final bool confirmed = _debouncer.update(isOff);

    if (confirmed) {
      if (shoulderArmAngle > ElbowFlareConfig.ERROR_MIN) {
        ctx.resultIssues.feedback['Arms'] = 'Ép khuỷu tay sát người hơn!';
        if (!_instructionSet) {
          ctx.resultIssues.addInstruction(
              'standing', 'Arms', 'Khuỷu tay mở quá rộng — ép sát người lại!');
          _instructionSet = true;
        }
        _logFault(phase, 'Khuỷu tay mở rộng — hại vai',
            voiceMessage: 'Ép khuỷu tay vào', affectsForm: true);
      } else {
        ctx.resultIssues.feedback['Arms'] = 'Khuỷu tay hơi mở rộng.';
        if (!_instructionSet) {
          ctx.resultIssues.addInstruction(
              'standing', 'Arms', 'Khuỷu tay hơi rộng — giữ sát người.');
          _instructionSet = true;
        }
        _logFault(phase, 'Khuỷu tay hơi rộng',
            voiceMessage: 'Ép khuỷu tay vào', affectsForm: false);
      }
    } else {
      ctx.resultIssues.feedback['Arms'] = 'Tay sát người tốt!';
    }

    _debugData['flareStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }

  void _logFault(String phase, String message,
      {String? voiceMessage, required bool affectsForm}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Arms',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: affectsForm,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _debouncer.reset();
    _instructionSet = false;
  }
}
