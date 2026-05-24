// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Warrior I Check 5: Arm Position  (coaching-only, NOT form-critical)

   Two sub-checks:
     Sub-A — are the arms actually overhead?  (wrist→shoulder vs vertical)
     Sub-B — are the elbows straight?         (shoulder–elbow–wrist angle)
   Sub-B is only meaningful if Sub-A says the arms are raised AND the wrist
   is in frame. Low ceilings push the wrist out of the top of the frame.

   Landmarks : SHOULDER (#11/12), ELBOW (#13/14), WRIST (#15/16) — getSideLandmark()
   When      : HOLD phase, after arms reach max height.

   Zones (Week 1-4 launch defaults):
     Sub-A good : 20°–45° from vertical    too low: > 60°
     Sub-B good : 140°–180°                too bent: < 130°
   affectsForm = FALSE for both.
   ========================================================================= */

import 'warrior_one_metric_base.dart';
import '../warrior_one.dart';
import '../../../utils/debouncer.dart';

class ArmPositionConfig {
  /// Sub-A: arms considered "raised enough" to bother checking the elbow.
  static const double RAISED_GATE = 60.0;

  /// Sub-A: above this from vertical = arms too low.
  static const double TOO_LOW = 60.0;

  /// Sub-A good band.
  static const double GOOD_MIN = 20.0;
  static const double GOOD_MAX = 45.0;

  /// Sub-B: below this = elbow too bent.
  static const double ELBOW_TOO_BENT = 130.0;
}

class ArmPositionMetric extends WarriorOneMetricBase {
  @override
  String get name => 'ArmPosition';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // 10 frames (~333ms) so a brief wobble at the top doesn't trigger coaching.
  final Debouncer _tooLowDebouncer = Debouncer(requiredFrames: 10);
  final Debouncer _elbowDebouncer = Debouncer(requiredFrames: 10);

  bool _lowInstructionSet = false;
  bool _elbowInstructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HoldContext ctx) {
    if (ctx.holdState != WarriorOneState.hold) return;

    final double armV = ctx.armVerticalAngle;
    final double elbow = ctx.elbowAngle;
    final phase = ctx.holdState.name.toUpperCase();

    _debugData['armVertical'] = armV.toStringAsFixed(1);
    _debugData['elbowAngle'] = elbow.toStringAsFixed(1);
    _debugData['wristVisible'] = ctx.wristVisible;

    // --- Sub-A: arms overhead? ---
    final bool tooLow = _tooLowDebouncer.update(armV > ArmPositionConfig.TOO_LOW);
    if (tooLow) {
      ctx.resultIssues.feedback['arms'] = 'Vươn tay cao hơn nhé!';
      if (!_lowInstructionSet) {
        ctx.resultIssues.addInstruction(
            'hold', 'arms', 'Vươn tay cao hơn nếu vai cho phép nhé!');
        _lowInstructionSet = true;
      }
      _logFault(phase, 'Arms', 'Arms hanging forward — reach overhead',
          voiceMessage: 'Vươn tay cao hơn');
      return; // don't also nag about elbows when arms aren't even up
    } else if (armV >= ArmPositionConfig.GOOD_MIN &&
        armV <= ArmPositionConfig.GOOD_MAX) {
      ctx.resultIssues.feedback['arms'] = 'Tay vươn tốt!';
    }

    // --- Sub-B: elbows straight? (only if arms raised AND wrist in frame) ---
    final bool armsRaised = armV <= ArmPositionConfig.RAISED_GATE;
    if (!armsRaised || !ctx.wristVisible) return;

    final bool elbowBent =
        _elbowDebouncer.update(elbow < ArmPositionConfig.ELBOW_TOO_BENT);
    if (elbowBent) {
      ctx.resultIssues.feedback['arms'] = 'Duỗi thẳng khuỷu tay nhé!';
      if (!_elbowInstructionSet) {
        ctx.resultIssues
            .addInstruction('hold', 'arms', 'Duỗi thẳng khuỷu tay nhé!');
        _elbowInstructionSet = true;
      }
      _logFault(phase, 'Arms', 'Elbows bent — straighten the arms',
          voiceMessage: 'Duỗi thẳng tay');
    }
  }

  void _logFault(String phase, String type, String message,
      {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: false, // coaching only
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _tooLowDebouncer.reset();
    _elbowDebouncer.reset();
    _lowInstructionSet = false;
    _elbowInstructionSet = false;
  }
}