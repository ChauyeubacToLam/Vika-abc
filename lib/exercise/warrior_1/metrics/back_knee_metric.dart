// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Warrior I Check 6: Back Knee  (coaching-only, NOT form-critical)

   Back leg should stay straight and engaged. A bent, floppy back knee
   means the quads aren't firing and the hip-flexor stretch is lost.

   Landmarks : back-leg HIP (#23/24), KNEE (#25/26), ANKLE (#27/28) — getSideLandmark()
   Calc      : calculateAngle(hip_back, knee_back, ankle_back). 180° = straight.
   When      : HOLD phase.

   Zones (Week 1-4 launch defaults):
     Good     : ≥ 160°
     Warning  : 150°–160°
     Coaching : < 150°   [affectsForm = FALSE]

   The threshold is intentionally WIDE: the ~45° back-foot rotation
   foreshortens the limb in 2D, so a genuinely straight leg can look bent
   to a side camera. Only flag gross bends.
   ========================================================================= */

import 'warrior_one_metric_base.dart';
import '../warrior_one.dart';
import '../../../utils/debouncer.dart';

class BackKneeConfig {
  static const double GOOD_THRESHOLD = 145.0;
  static const double WARN_THRESHOLD = 130.0; // 150–160 = warning
  // < 150 = coaching fault
}

class BackKneeMetric extends WarriorOneMetricBase {
  @override
  String get name => 'BackKnee';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // 10 frames (~333ms) to ride out foreshortening jitter.
  final Debouncer _bentDebouncer = Debouncer(requiredFrames: 10);

  bool _instructionSet = false;
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HoldContext ctx) {
    _isFaultingNow = false;
    if (ctx.holdState != WarriorOneState.hold) return;

    final double angle = ctx.backKneeAngle;
    final phase = ctx.holdState.name.toUpperCase();
    _debugData['backKneeAngle'] = angle.toStringAsFixed(1);

    final bool bent =
        _bentDebouncer.update(angle < BackKneeConfig.WARN_THRESHOLD);

    if (bent) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['back_knee'] =
          'Duỗi thẳng chân sau hơn nhé! Siết cơ đùi trước để giữ chân vững.';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Duỗi thẳng chân sau hơn nhé! Siết cơ đùi trước để giữ chân vững.
        _instructionSet = true;
      }
      _logFault(phase, 'Back knee bent / floppy',
          voiceMessage: 'Duỗi thẳng chân sau');
    } else if (angle >= BackKneeConfig.WARN_THRESHOLD &&
        angle < BackKneeConfig.GOOD_THRESHOLD) {
      // 150°–160° warning band — feedback only, no fault.
      ctx.resultIssues.feedback['back_knee'] =
          'Chân sau gần thẳng rồi, cố thêm chút!';
    } else {
      ctx.resultIssues.feedback['back_knee'] = 'Chân sau thẳng tốt!';
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'back_knee')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'back_knee',
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
    _bentDebouncer.reset();
    _instructionSet = false;
    _isFaultingNow = false;
  }
}
