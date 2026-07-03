/* =========================================================================
   Metric 2.2: Head/Neck Position (Cervical Strain Detector)
   Priority: 🟡 IMPORTANT — Injury prevention

   Detects cervical strain from head lifting during bridge.
   Common beginner habit driven by wanting to watch the movement.

   Landmarks:
     Camera-side EAR (#7/8) primary, NOSE (#0) fallback, SHOULDER (#11/12).
     earY is passed through RepContext.headY (resolved in GluteBridge).

   Calculation:
     headLiftRatio = (shoulderY − headY) / scaleFactor
     Positive  →  ear physically above shoulder  →  head lifted (bad).

   Screen-coordinate note (y increases downward):
     headY < shoulderY  →  head raised from floor  →  ratio positive.
     headY ≥ shoulderY  →  head resting normally   →  ratio ≤ 0.

   Detection:
     Binary: head up vs head down — robust even with degraded accuracy,
     because it does not require a precise angle measurement.
     ~80 % catch rate for obvious head-lifting.

   Continuous monitoring through ALL phases (bottom, ascending,
   topHold, descending).
   ========================================================================= */

import 'glute_bridge_metric_base.dart';
import '../../../../utils/debouncer.dart';

class NeckHeadConfig {
  /// Normalized threshold. (shoulderY − headY) / scaleFactor > this → fault.
  /// 5 % of shoulder-to-hip distance — filters minor camera / landmark noise.
  static const double HEAD_LIFT_THRESHOLD = 0.08;

  /// Pixel fallback when scaleFactor is unavailable.
  static const double HEAD_LIFT_PIXELS = 12.0;

  /// Consecutive frames of sustained lift before coaching fires.
  static const int DEBOUNCE_FRAMES = 7;
}

class NeckHeadMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'NeckHead';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _liftDebouncer =
      Debouncer(requiredFrames: NeckHeadConfig.DEBOUNCE_FRAMES);

  // Prevent duplicate instruction and fault within one rep.
  bool _instructionShown = false;
  bool _faultAdded = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /* -----------------------------------------------------------------------
     Continuous monitoring — identical check for all phases.

     onBottomFrame is called when state == bottom (setup / rest phase).
     update        is called for all other phases.
     Both delegate to _check so no coverage gap exists.
     ----------------------------------------------------------------------- */
  @override
  void onBottomFrame(RepContext ctx) => _check(ctx);

  @override
  void update(RepContext ctx) => _check(ctx);

  void _check(RepContext ctx) {
    final double? headY = ctx.headY;
    if (headY == null) return;

    // Positive diff  ↔  ear is physically above shoulder  ↔  head lifted.
    final double rawDiff = ctx.shoulderY - headY;
    final double threshold = ctx.scaleFactor != null
        ? ctx.scaleFactor! * NeckHeadConfig.HEAD_LIFT_THRESHOLD
        : NeckHeadConfig.HEAD_LIFT_PIXELS;

    _debugData['headY'] = headY.toStringAsFixed(1);
    _debugData['headLift'] = ctx.scaleFactor != null
        ? (rawDiff / ctx.scaleFactor!).toStringAsFixed(3)
        : rawDiff.toStringAsFixed(1);

    final bool isLifted = rawDiff > threshold;

    if (_liftDebouncer.update(isLifted)) {
      // Live coaching instruction — shown once per rep (persists until next
      // ascending phase clears resultIssues.instructions).
      if (!_instructionShown) {
        ctx.resultIssues.addInstruction(
          'bottom',
          'NeckHead',
          'Đặt đầu xuống sàn — tránh căng cơ cổ',
        );
        _instructionShown = true;
      }

      // Fault — recorded once per rep (affectsForm = false: injury-risk
      // cue, but does not invalidate the rep's form score).
      if (!_faultAdded) {
        _faults.add(FaultRecord(
          phase: ctx.state.toString().split('.').last,
          type: 'NeckHead',
          message: 'Giữ đầu và cổ trên sàn khi thực hiện bài tập',
          affectsForm: false,
        ));
        _faultAdded = true;
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _liftDebouncer.reset();
    _instructionShown = false;
    _faultAdded = false;
  }
}
