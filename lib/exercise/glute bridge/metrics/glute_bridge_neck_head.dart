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
  /// Fraction of shoulder-to-hip distance the ear must clear ABOVE the
  /// shoulder before it counts as a lifted head.
  ///
  /// FEEL-TUNE (loosened 0.08 → 0.14, Nam device call 07-11): at 0.08 this was
  /// the ONLY glute metric firing — nearly every rep — because a small,
  /// natural head shift during the bridge cleared 8 %. 0.14 requires the ear
  /// clearly above the shoulder line (an obvious "watching the movement" lift)
  /// before it coaches. Not canonical — tune on device against real footage.
  static const double HEAD_LIFT_THRESHOLD = 0.14;

  /// Pixel fallback when scaleFactor is unavailable.
  static const double HEAD_LIFT_PIXELS = 20.0;

  /// Consecutive frames of sustained lift before coaching fires. Bumped 7 → 10
  /// (07-11) so a brief glance up mid-rep no longer trips it — the lift must
  /// persist to count.
  static const int DEBOUNCE_FRAMES = 10;
}

class NeckHeadMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'NeckHead';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _liftDebouncer =
      Debouncer(requiredFrames: NeckHeadConfig.DEBOUNCE_FRAMES);

  // Prevent duplicate fault within one rep.
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
      // Fault — recorded once per rep. Head lift now affects form so it can
      // use the real-time critical voice path and block clean-rep praise.
      if (!_faultAdded) {
        _faults.add(FaultRecord(
          phase: ctx.state.toString().split('.').last,
          type: 'neck_head',
          message: 'Giữ đầu và cổ trên sàn khi thực hiện bài tập',
          affectsForm: true,
        ));
        _faultAdded = true;
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _liftDebouncer.reset();
    _faultAdded = false;
  }
}
