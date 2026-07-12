// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Lunge Metric: Heel Lift

   Detects whether the front foot's heel lifts off the ground.

   Landmarks: HEEL (#29/#30) — lead foot
   Calculation: heelDistance / scaleFactor (torso length) → normalized ratio

   When to check: Descending and bottom phases only.
   Uses debounced confirmation (10 frames ~333ms) to filter pose-detection
   jitter before logging a fault.
   ========================================================================= */

import 'lunge_metric_base.dart';
import '../lunge.dart';
import '../../../utils/debouncer.dart';

class LungeHeelLiftConfig {
  /// Good heel contact — ratio below this is fine.
  static const double WARNING_THRESHOLD = 0.10;

  /// Warning zone — heel slightly lifting.
  static const double BAD_THRESHOLD = 0.16;
}

class LungeHeelLiftMetric extends LungeMetricBase {
  @override
  String get name => 'HeelLift';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // 10 frames ~333ms at 30fps — prevents false triggers from floor jitter
  final Debouncer _heelWarnDebouncer = Debouncer(requiredFrames: 12);
  final Debouncer _heelBadDebouncer = Debouncer(requiredFrames: 12);

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LungeRepContext ctx) {
    // Only check during descending and bottom phases
    if (ctx.lungeState != LungeState.descending &&
        ctx.lungeState != LungeState.bottom) {
      return;
    }

    final double ratio = ctx.heelDistance / (ctx.scaleFactor ?? 1.0);
    final String phase = ctx.lungeState.name.toUpperCase();

    _debugData['heelNorm'] = ratio.toStringAsFixed(2);
    _debugData['heelRaw'] = ctx.heelDistance.toStringAsFixed(2);

    // Bad: ratio > 0.08
    if (_heelBadDebouncer.update(ratio > LungeHeelLiftConfig.BAD_THRESHOLD)) {
      ctx.resultIssues.feedback['Feet'] = 'Giữ gót chân chạm sàn!';

      if (!_instructionSet) {
        // Legacy UI instruction copy: Gót chân trước đang nhấc lên. Hãy dồn lực đều vào cả bàn chân để bảo vệ khớp gối.
        _instructionSet = true;
      }
      _logFault(phase, 'Keep your heel down!', voiceMessage: 'Giữ gót chân');
    }
    // Warning: ratio 0.05 – 0.08
    else if (_heelWarnDebouncer
        .update(ratio > LungeHeelLiftConfig.WARNING_THRESHOLD)) {
      ctx.resultIssues.feedback['Feet'] = 'Gót hơi nhấc — ấn gót xuống';

      if (!_instructionSet) {
        // Legacy UI instruction copy: Gót chân trước đang nhấc lên. Hãy dồn lực đều vào cả bàn chân để bảo vệ khớp gối.
        _instructionSet = true;
      }
      _logFault(phase, 'Heel slightly lifting', voiceMessage: 'Giữ gót chân');
    }
    // Good: ratio < 0.05
    else {
      ctx.resultIssues.feedback['Feet'] = 'Tốt! Gót chân tốt';
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    // Only log one fault per phase to avoid spam
    if (!_faults.any((f) => f.phase == phase && f.type == 'heel')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'heel',
        message: message,
        voiceMessage: voiceMessage,
        priority: 0,
        // Heel lift DOES affect form for lunges (unlike squat where it's informational)
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _heelWarnDebouncer.reset();
    _heelBadDebouncer.reset();
    _instructionSet = false;
  }
}
