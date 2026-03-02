/* =========================================================================
   Lunge Metric: Trunk Lean

   Angle of the torso from vertical (shoulder-hip line).
   Primary indicator of lumbar spine loading risk.

   Landmarks: HIP (#23/#24) — pivot, SHOULDER (#11/#12) — point
   Calculation: calculateVerticalAngle(Hip, Shoulder) then
                convertClockAngleToTrunkLean(clockAngle, cameraFacing)

   When to check: Bottom phase primarily (when lever arm on lumbar is longest).
                  Continuous monitoring for live feedback.
   Per-rep evaluation at point of maximum depth.

   Thresholds (Vietnamese-Adjusted):
     ✅  10° – 30° forward    → Good back posture!
     ⚠️  31° – 39° forward    → Leaning a bit — chest up
     ❌  ≥ 40° forward        → Chest up! Core collapse
     ❌  < 0° (backward)      → Don't lean back!

   Debounce: 10 frames (~333ms) for forward lean,
             5  frames for backward lean.

   Code pattern: Reuses existing TrunkLeanMetric architecture from squat.
   Same Debouncer pattern, same convertClockAngleToTrunkLean helper.
   ========================================================================= */

import 'lunge_metric_base.dart';
import '../lunge.dart';
import '../../../utils/debouncer.dart';

class LungeTrunkLeanConfig {
  /// Good forward lean range (degrees from vertical).
  /// Wider than squat: Vietnamese body type (long femurs, short torso)
  /// REQUIRES more forward lean for balance during lunge.
  static const List<int> GOOD_LEAN_RANGE = [10, 30];

  /// Warning zone upper bound (degrees). Above this = core collapse.
  static const int WARN_LEAN_LIMIT = 39;

  /// Backward lean threshold (degrees). Below 0 = leaning back.
  static const double BACKWARD_LIMIT = 0.0;
}

class LungeTrunkLeanMetric extends LungeMetricBase {
  @override
  String get name => 'TrunkLean';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Separate debouncers for forward/backward — they can't share!
  // 10 frames (~333ms) for forward lean
  final Debouncer _forwardDebouncer = Debouncer(requiredFrames: 10);
  // 5 frames for backward lean
  final Debouncer _backwardDebouncer = Debouncer(requiredFrames: 5);

  /// Track maximum trunk lean this rep (for post-rep analysis)
  double? maxTrunkLean;

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LungeRepContext ctx) {
    // Track max lean per rep
    if (maxTrunkLean == null || ctx.trunkLean > maxTrunkLean!) {
      maxTrunkLean = ctx.trunkLean;
    }

    _debugData['maxTrunkLean'] = maxTrunkLean?.toStringAsFixed(1) ?? 'N/A';

    final phase = ctx.lungeState.toString().split('.').last.toUpperCase();

    // ❌ Core collapse: ≥ 40° forward
    bool leanForwardBad =
        ctx.trunkLean >= (LungeTrunkLeanConfig.WARN_LEAN_LIMIT + 1);
    // ⚠️ Warning: 31° – 39° forward
    bool leanForwardWarn =
        ctx.trunkLean > LungeTrunkLeanConfig.GOOD_LEAN_RANGE[1] &&
            ctx.trunkLean <= LungeTrunkLeanConfig.WARN_LEAN_LIMIT;
    // ❌ Backward lean: < 0°
    bool leanBackward = ctx.trunkLean < LungeTrunkLeanConfig.BACKWARD_LIMIT;

    bool forwardBadConfirmed = _forwardDebouncer.update(leanForwardBad);
    bool backwardConfirmed = _backwardDebouncer.update(leanBackward);

    if (forwardBadConfirmed) {
      // ❌ ≥ 40° — Core collapse
      ctx.resultIssues.feedback['Back'] = 'Nâng ngực lên!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'standing',
          'Back',
          'Giữ thân trên thẳng, siết cơ core khi bước lùi.',
        );
        _instructionSet = true;
      }
      _logFault(phase, 'Chest up! Core collapse');
    } else if (backwardConfirmed) {
      // ❌ < 0° — Leaning backward
      ctx.resultIssues.feedback['Back'] = 'Đừng ngả ra sau!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'standing',
          'Back',
          'Đừng ngả ra sau! Giữ thân trên thẳng.',
        );
        _instructionSet = true;
      }
      _logFault(phase, "Don't lean back!");
    } else if (leanForwardWarn) {
      // ⚠️ 31° – 39° — Warning zone (no debounce needed, just feedback)
      ctx.resultIssues.feedback['Back'] = 'Hơi gập người, giữ lưng thẳng';
    } else {
      // ✅ 10° – 30° — Good posture
      ctx.resultIssues.feedback['Back'] = 'Lưng tốt!';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Back')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Back',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _forwardDebouncer.reset();
    _backwardDebouncer.reset();
    maxTrunkLean = null;
    _instructionSet = false;
  }
}
