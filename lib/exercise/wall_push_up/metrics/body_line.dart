/* =========================================================================
   Metric 1: Body Line (Is the body straight?)
   Priority: 🔴 CRITICAL — Ship Day 1. Body sag = lower-back load.
 
   Measures the angle SHOULDER→HIP→FOOT_ANCHOR (normalized, 0-180).
     FOOT_ANCHOR = average of visible ankle / heel / footIndex.
     180° = shoulder, hip and foot are on one straight line.
     < 180° = shoulder-hip-foot line is bent.
 
   GEOMETRY CAVEAT (flagged for Nam):
   calculateAngleNormalized returns the interior angle, capped at 180°, so:
     - The spec's pike band (> 195°) is UNREACHABLE — normalized angle can
       never exceed 180°.
     - Sag and pike both *reduce* the interior angle below 180°, and the
       sign of the deviation is discarded, so this metric CANNOT tell sag
       from pike. It detects "body is bent" and coaches toward sag-fix
       (the more common + dangerous case for desk workers).
   If true sag/pike separation is wanted, switch to a signed clock-angle
   approach (hip→shoulder vs hip→foot, like push-up's trunkDeviation).
 
   Thresholds (Week 1-4, ESTIMATE — PT review before ship):
     Good:    ≥ 155°
     Warning: 145-155°   (8-frame debounce)
     Error:   < 145°     (10-frame debounce, affectsForm = true)
   ========================================================================= */

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class BodyLineConfig {
  static const double GOOD_MIN = 155.0;
  static const double ERROR_MAX = 145.0; // < this = error
}

class BodyLineMetric extends WallPushUpMetricBase {
  @override
  String get name => 'BodyLine';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Spec: 8 frames warning, 10 frames error.
  final Debouncer _warningDebouncer = Debouncer(requiredFrames: 8);
  final Debouncer _errorDebouncer = Debouncer(requiredFrames: 10);

  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    final angle = ctx.shoulderHipFootLineAngle;
    if (angle == null) return; // foot landmarks not visible — skip

    final phase = ctx.state.toString().split('.').last.toUpperCase();
    _debugData['bodyLine'] = angle.toStringAsFixed(1);
    _debugData['bodyLineSource'] = 'shoulder-hip-foot';

    final bool isError = angle < BodyLineConfig.ERROR_MAX;
    final bool isWarning =
        angle >= BodyLineConfig.ERROR_MAX && angle < BodyLineConfig.GOOD_MIN;

    final bool errorConfirmed = _errorDebouncer.update(isError);
    final bool warningConfirmed = _warningDebouncer.update(isWarning);

    if (errorConfirmed) {
      ctx.resultIssues.feedback['Body'] =
          'Giữ vai, hông và chân trên một đường thẳng!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction('standing', 'Body',
            'Vai, hông và chân chưa thẳng hàng — siết core và chỉnh lại tư thế.');
        _instructionSet = true;
      }
      _logFault(phase, 'Vai-hông-chân lệch khỏi đường thẳng',
          voiceMessage: 'Giữ thân thẳng', affectsForm: true);
    } else if (warningConfirmed) {
      ctx.resultIssues.feedback['Body'] = 'Vai, hông và chân hơi lệch hàng.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction('standing', 'Body',
            'Vai, hông và chân hơi lệch — giữ người thành một đường thẳng.');
        _instructionSet = true;
      }
      _logFault(phase, 'Vai-hông-chân hơi lệch',
          voiceMessage: 'Giữ thân thẳng', affectsForm: false);
    } else {
      ctx.resultIssues.feedback['Body'] = 'Vai, hông và chân thẳng hàng tốt!';
    }

    _debugData['bodyStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }

  void _logFault(String phase, String message,
      {String? voiceMessage, required bool affectsForm}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Body',
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
    _warningDebouncer.reset();
    _errorDebouncer.reset();
    _instructionSet = false;
  }
}
