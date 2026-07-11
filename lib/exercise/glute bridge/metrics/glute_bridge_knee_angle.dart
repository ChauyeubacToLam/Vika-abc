/* =========================================================================
   Metric 1.2: Knee Angle (Foot Placement / Hamstring-vs-Glute Bias)
   Priority: 🟠 IMPORTANT (major effectiveness + hamstring cramp risk)

   What it detects:
     Feet placed too far → knee too open → hamstring dominance
     Feet too close     → knee too acute → quad dominance + patellar stress

   EMG evidence (Lehecka 2017, IJSPT / PMC5534144):
     90°  knee flexion  → hamstring activation = 75.3 % MVIC vs glute 51 %
     135° knee flexion  → hamstring drops to 23.4 % MVIC, glute maintained
   The knee angle literally switches which muscle does the work.

   Landmarks:  Camera-side HIP, KNEE, ANKLE via getSideLandmark().
   Calculation: calculateAngleNormalized(HIP, KNEE, ANKLE) — internal angle.
   
   When to check:
     • Setup phase (during bottom state, before any rep) → coaching instruction.
     • Per-rep at top hold (knee angle captured at peak hip position).

   Threshold Table — Vietnamese-adjusted (tightened 07-11 toward the 90-130°
   glute-biased sweet spot; shorter femurs naturally produce more acute angles
   which already FAVORS glutes):

     Good  (glute-biased)  :  85–135°  affectsForm = false
     Acceptable            :  135–145°  affectsForm = false
     Warning               :  55–85°   OR  >145°  affectsForm = false
     Error                 :  < 55°    (pure hamstring)        affectsForm = true
   ========================================================================= */

import 'glute_bridge_metric_base.dart';
import '../glute_bridge.dart';

class KneeAngleConfig {
  static const double GOOD_MIN = 85.0;
  static const double GOOD_MAX = 135.0;

  // lower bound for "acceptable upper" = GOOD_MAX (135), upper bound = 145
  static const double ACCEPTABLE_UPPER_MAX = 145.0;

  static const double WARNING_MIN = 55.0; // 55–75 range
  // Below WARNING_MIN → affectsForm = true (error)
}

class KneeAngleMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'KneeAngle';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Prevents firing the setup instruction more than once per session.
  bool _setupInstructionShown = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /* -----------------------------------------------------------------------
     onBottomFrame — called every frame while state == bottom.
     Provides setup coaching before the first rep.
     ----------------------------------------------------------------------- */
  @override
  void onBottomFrame(RepContext ctx) {
    if (_setupInstructionShown || ctx.kneeAngle == null) return;

    final double angle = ctx.kneeAngle!;
    _debugData['kneeAngle'] = angle.toStringAsFixed(1);

    if (angle >= KneeAngleConfig.GOOD_MIN &&
        angle <= KneeAngleConfig.GOOD_MAX) {
      // Legacy UI instruction copy: Tư thế chân tốt!
      _setupInstructionShown = true;
    } else if (angle > KneeAngleConfig.GOOD_MAX) {
      // Feet too far from hips.
      // Legacy UI instruction copy: Di chân lại gần hông hơn để kích hoạt mông
      _setupInstructionShown = true;
    } else if (angle >= KneeAngleConfig.WARNING_MIN) {
      // Feet too close to hips.
      // Legacy UI instruction copy: Di chân ra xa hông hơn một chút
      _setupInstructionShown = true;
    } else {
      // Error level — feet very close.
      // Legacy UI instruction copy: Di chân ra xa hông đi
    }
  }

  /* -----------------------------------------------------------------------
     Per-frame update — minimal; knee angle stays nearly constant while
     feet are planted. Live feedback is handled via onBottomFrame above.
     During topHold: show the current angle as informational feedback.
     ----------------------------------------------------------------------- */
  @override
  void update(RepContext ctx) {
    if (ctx.kneeAngle == null) return;
    if (ctx.state == GluteBridgeState.topHold) {
      _debugData['kneeAngle'] = ctx.kneeAngle!.toStringAsFixed(1);
    }
  }

  /* -----------------------------------------------------------------------
     Per-rep evaluation — called at TOP_HOLD → DESCENDING transition.
     kneeAngle : hip-knee-ankle angle captured at peak hip position.
     ----------------------------------------------------------------------- */
  void checkRepCompletion(double? kneeAngle) {
    if (kneeAngle == null) return;

    _debugData['repKneeAngle'] = '${kneeAngle.toStringAsFixed(1)}°';

    if (kneeAngle < KneeAngleConfig.WARNING_MIN) {
      // Error: legs nearly straight — pure hamstring.
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'knee_angle',
        message: 'Di chân ra xa hông hơn — duỗi gối nhiều hơn',
        affectsForm: true,
      ));
    } else if (kneeAngle < KneeAngleConfig.GOOD_MIN) {
      // Warning: 55–85° — hamstring cramp zone.
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'knee_angle',
        message: 'Di chân ra xa hông thêm để giảm áp lực hamstring',
        affectsForm: false,
      ));
    } else if (kneeAngle > KneeAngleConfig.ACCEPTABLE_UPPER_MAX) {
      // Feet too far from hips (>145°, knee too open) — hamstring bias, glute
      // tension drops. Correction is move feet CLOSER (matches onBottomFrame's
      // >135 branch); the old copy said "ra xa" which pushed the wrong way.
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'knee_angle',
        message: 'Di chân lại gần hông một chút',
        affectsForm: false,
      ));
    }
    // 85–135° = good and 135–145° = acceptable → no fault.
  }

  /* -----------------------------------------------------------------------
     State transition hook.
     ----------------------------------------------------------------------- */
  @override
  void onStateTransition(
      GluteBridgeState from, GluteBridgeState to, int timestampMs) {
    // Left empty as bottom reset is handled in checkRepCompletion/reset
  }

  @override
  void reset() {
    _faults.clear();
    // Once a rep has finished (hitting bottom), allow setup instruction to re-show next bottom.
    // (Foot placement rarely changes mid-set, but allow one re-check per rep.)
    _setupInstructionShown = false;
  }
}
