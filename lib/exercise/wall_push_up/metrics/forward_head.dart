/* =========================================================================
   Metric 3: Forward Head (Is the head poking forward?)
   Priority: 🟡 SAFETY (coaching) — neck strain, headaches. Very common
   in desk workers.
 
   ANGLE metric WITH baseline. Measures EAR→SHOULDER→HIP (normalized).
     180° = ear stacked over shoulder (good).
     smaller = head sliding forward toward the wall (chicken-peck).
   Deviation = baseline - current (positive = head moved forward).
 
   Thresholds (Week 1-4, ESTIMATE — PT review):
     Good:    deviation < 12°
     Warning: 12-18°
     Error:   > 18°       (12-frame debounce — ear-shoulder is short, jitter
                           amplified, so a high frame count is intentional)
     affectsForm = false  (coaching only — do not fail the rep)
   ========================================================================= */

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class ForwardHeadConfig {
  static const double WARNING_DEVIATION = 18.0;
  static const double ERROR_DEVIATION = 28.0;
}

class ForwardHeadMetric extends WallPushUpMetricBase {
  @override
  String get name => 'ForwardHead';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Single debouncer (high frame count for jitter); severity classified by value.
  final Debouncer _debouncer = Debouncer(requiredFrames: 12);

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
    final angle = ctx.forwardHeadAngle;
    if (angle == null || _baseline == null) return;

    final deviation = _baseline! - angle; // + = head forward
    final phase = ctx.state.toString().split('.').last.toUpperCase();
    _debugData['headDev'] = '${deviation.toStringAsFixed(0)}°';

    final bool isOff = deviation > ForwardHeadConfig.WARNING_DEVIATION;
    final bool confirmed = _debouncer.update(isOff);

    if (confirmed) {
      if (deviation > ForwardHeadConfig.ERROR_DEVIATION) {
        ctx.resultIssues.feedback['Head'] = 'Kéo cằm về, giữ đầu thẳng.';
        if (!_instructionSet) {
          // Legacy UI instruction copy: Kéo cằm về sau — giữ đầu thẳng hàng.
          _instructionSet = true;
        }
        _logFault(phase, 'Đầu đưa về trước nhiều', voiceMessage: 'Kéo cằm về');
      } else {
        ctx.resultIssues.feedback['Head'] = 'Đầu hơi đưa về trước.';
        if (!_instructionSet) {
          // Legacy UI instruction copy: Đầu hơi đưa về trước — giữ thẳng hàng.
          _instructionSet = true;
        }
        _logFault(phase, 'Đầu hơi đưa về trước', voiceMessage: 'Kéo cằm về');
      }
    } else {
      ctx.resultIssues.feedback['Head'] = 'Đầu thẳng hàng tốt!';
    }

    _debugData['headStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'head',
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
