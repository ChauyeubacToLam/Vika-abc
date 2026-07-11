/* =========================================================================
   Metric 5: Cervical Extension / Neck Tilt (Looking up at the wall?)
   Priority: 🟡 SAFETY (coaching) — crunches cervical joints, headaches.
 
   Different from Metric 3: Forward Head checks the head sliding FORWARD
   horizontally (ear-shoulder-hip). This checks the head tilting BACKWARD
   vertically to look up at the hands/wall. Both can happen independently.
 
   ANGLE metric WITH baseline. Measures NOSE→EAR→SHOULDER (normalized).
   Nose + ear are face landmarks → very stable.
     ~180° = head neutral.
     smaller = head tilting back (looking up).
   Deviation = baseline - current (positive = tilting back).
 
   Phase-gated: DESCENDING / BOTTOM only — that's when people crane the neck.
 
   Thresholds (Week 1-4, ESTIMATE — PT review):
     Good:    deviation < 15°
     Warning: 15-25°
     Error:   > 25°       (10-frame debounce)
     affectsForm = false  (coaching only)
   ========================================================================= */

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class CervicalExtensionConfig {
  static const double WARNING_DEVIATION = 22.0;
  static const double ERROR_DEVIATION = 35.0;
}

class CervicalExtensionMetric extends WallPushUpMetricBase {
  @override
  String get name => 'CervicalExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _debouncer = Debouncer(requiredFrames: 10);

  double? _baseline;
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void captureBaseline(double? value) {
    if (value != null) _baseline = value;
  }

  @override
  void update(RepContext ctx) {
    // Phase gate: descending/bottom only.
    final inPhase = ctx.state == WallPushUpState.descending ||
        ctx.state == WallPushUpState.bottom;
    if (!inPhase) return;

    final angle = ctx.neckTiltAngle;
    if (angle == null || _baseline == null) return;

    final deviation = _baseline! - angle; // + = tilting back / looking up
    final phase = ctx.state.toString().split('.').last.toUpperCase();
    _debugData['neckDev'] = '${deviation.toStringAsFixed(0)}°';

    final bool isOff = deviation > CervicalExtensionConfig.WARNING_DEVIATION;
    final bool confirmed = _debouncer.update(isOff);

    if (confirmed) {
      if (deviation > CervicalExtensionConfig.ERROR_DEVIATION) {
        ctx.resultIssues.feedback['Neck'] = 'Giữ cổ thẳng, nhìn về phía trước.';
        if (!_instructionSet) {
          // Legacy UI instruction copy: Đừng ngửa đầu nhìn lên tường — giữ cổ thẳng.
          _instructionSet = true;
        }
        _logFault(phase, 'Ngửa cổ nhìn lên', voiceMessage: 'Giữ cổ thẳng');
      } else {
        ctx.resultIssues.feedback['Neck'] = 'Đừng ngửa đầu lên nhìn tường.';
        if (!_instructionSet) {
          // Legacy UI instruction copy: Cổ hơi ngửa — nhìn về phía trước.
          _instructionSet = true;
        }
        _logFault(phase, 'Cổ hơi ngửa', voiceMessage: 'Giữ cổ thẳng');
      }
    } else {
      ctx.resultIssues.feedback['Neck'] = 'Cổ giữ thẳng tốt!';
    }

    _debugData['neckStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Neck',
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
    _debouncer.reset();
    _instructionSet = false;
    // NOTE: _baseline intentionally preserved across reps.
  }
}
