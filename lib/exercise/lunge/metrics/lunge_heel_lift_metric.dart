/* =========================================================================
   Lunge Metric: Heel Lift Detection (Lead Leg)

   Detects whether the lead leg's heel lifts off the ground during the lunge.
   Checks DESCENDING and BOTTOM phases only (continuous monitoring).

   Landmarks: HEEL (#29/#30), FOOT_INDEX (#31/#32)
   Normalization: SHOULDER (#11/#12) to HIP (#23/#24) — torso length

   Calculation:
     1) heel_delta = foot.y - heel.y  (passed in as ctx.heelDistance)
     2) ratio = heel_delta / torso_length
     3) Compare ratio against thresholds

   Thresholds (normalized to torso length):
     ✅  ratio < 0.05        → Good heel contact
     ⚠️  ratio 0.05 – 0.08   → Heel slightly lifting
     ❌  ratio > 0.08        → Keep your heel down!

   Debounce: 10 frames (~333ms at 30fps) — prevents false triggers from
             floor jitter.

   Post-rep instruction: "Gót chân trước đang nhấc lên. Hãy dồn lực đều
   vào cả bàn chân để bảo vệ khớp gối."

   Code pattern: Reuses existing HeelRiseMetric architecture from squat.
   Same Debouncer(requiredFrames: 10), same normalization to torso length.
   ========================================================================= */

import 'lunge_metric_base.dart';
import '../lunge.dart';
import '../../../utils/debouncer.dart';

class LungeHeelLiftConfig {
  /// Good heel contact — ratio below this is fine.
  static const double GOOD_THRESHOLD = 0.05;

  /// Warning zone — heel slightly lifting.
  static const double WARN_THRESHOLD = 0.08;
}

class LungeHeelLiftMetric extends LungeMetricBase {
  @override
  String get name => 'HeelLift';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // 10 frames ~333ms at 30fps — prevents false triggers from floor jitter
  final Debouncer _heelWarnDebouncer = Debouncer(requiredFrames: 10);
  final Debouncer _heelBadDebouncer = Debouncer(requiredFrames: 10);

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
    final String phase =
        ctx.lungeState.toString().split('.').last.toUpperCase();

    _debugData['heelNorm'] = ratio.toStringAsFixed(3);
    _debugData['heelRaw'] = ctx.heelDistance.toStringAsFixed(2);

    // ❌ Bad: ratio > 0.08
    if (_heelBadDebouncer.update(ratio > LungeHeelLiftConfig.WARN_THRESHOLD)) {
      ctx.resultIssues.feedback['Feet'] = 'Giữ gót chân chạm sàn!';

      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'standing',
          'Feet',
          'Gót chân trước đang nhấc lên. Hãy dồn lực đều vào cả bàn chân để bảo vệ khớp gối.',
        );
        _instructionSet = true;
      }
      _logFault(phase, 'Keep your heel down!');
    }
    // ⚠️ Warning: ratio 0.05 – 0.08
    else if (_heelWarnDebouncer
        .update(ratio > LungeHeelLiftConfig.GOOD_THRESHOLD)) {
      ctx.resultIssues.feedback['Feet'] = 'Gót hơi nhấc — ấn gót xuống';

      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'standing',
          'Feet',
          'Gót chân trước đang nhấc lên. Hãy dồn lực đều vào cả bàn chân để bảo vệ khớp gối.',
        );
        _instructionSet = true;
      }
      _logFault(phase, 'Heel slightly lifting');
    }
    // ✅ Good: ratio < 0.05
    else {
      ctx.resultIssues.feedback['Feet'] = 'Tốt! Gót chân tốt';
    }
  }

  void _logFault(String phase, String message) {
    // Only log one fault per phase to avoid spam
    if (!_faults.any((f) => f.phase == phase && f.type == 'Feet')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Feet',
        message: message,
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
