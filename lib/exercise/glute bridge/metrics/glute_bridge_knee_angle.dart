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

   Threshold Table — Vietnamese-adjusted (90-130° sweet spot unchanged, shorter
   femurs naturally produce more acute angles which already FAVORS glutes):

     Good  (glute-biased)  :  90–130°  affectsForm = false
     Acceptable            :  80–90°   OR  130–140°  affectsForm = false
     Warning               :  60–80°   (hamstring cramp risk)  affectsForm = false
     Error                 :  < 60°    (pure hamstring)        affectsForm = true
   ========================================================================= */

import 'glute_bridge_metric_base.dart';
import '../glute_bridge.dart';

class KneeAngleConfig {
  static const double GOOD_MIN = 90.0;
  static const double GOOD_MAX = 130.0;

  static const double ACCEPTABLE_LOWER_MIN = 80.0; // 80–90 range
  // lower bound for "acceptable upper" = GOOD_MAX (130), upper bound = 140
  static const double ACCEPTABLE_UPPER_MAX = 140.0;

  static const double WARNING_MIN = 60.0; // 60–80 range
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

    String? msg;
    if (angle >= KneeAngleConfig.GOOD_MIN &&
        angle <= KneeAngleConfig.GOOD_MAX) {
      // Perfect — no instruction needed, just show a positive cue once.
      msg = 'Tư thế chân tốt!';
      _setupInstructionShown = true;
    } else if (angle > KneeAngleConfig.GOOD_MAX) {
      // Feet too far from hips.
      msg = 'Di chân lại gần hông hơn để kích hoạt mông';
      _setupInstructionShown = true;
    } else if (angle >= KneeAngleConfig.WARNING_MIN) {
      // Feet too close to hips.
      msg = 'Di chân ra xa hông hơn một chút';
      _setupInstructionShown = true;
    } else {
      // Error level — feet very far (legs nearly straight).
      msg = 'Gập gối nhiều hơn — di chân lại gần hông';
    }

    ctx.resultIssues.addInstruction('bottom', 'KneeAngle', msg);
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
        type: 'KneeAngle',
        message: 'Gập gối nhiều hơn — di chân lại gần hông',
        affectsForm: true,
      ));
    } else if (kneeAngle < KneeAngleConfig.GOOD_MIN) {
      // Warning: 60–80° — hamstring cramp zone.
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'KneeAngle',
        message: 'Di chân ra xa hông thêm để giảm áp lực hamstring',
        affectsForm: false,
      ));
    } else if (kneeAngle > KneeAngleConfig.ACCEPTABLE_UPPER_MAX) {
      // Too close to hips (>140°) — loss of tension.
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'KneeAngle',
        message: 'Di chân ra xa hông hơn một chút',
        affectsForm: false,
      ));
    }
    // 90–130° = good, 80–90° and 130–140° = acceptable → no fault.
  }

  /* -----------------------------------------------------------------------
     State transition hook.
     ----------------------------------------------------------------------- */
  @override
  void onStateTransition(
      GluteBridgeState from, GluteBridgeState to, int timestampMs) {
    // Once a rep has started, allow setup instruction to re-show next bottom.
    // (Foot placement rarely changes mid-set, but allow one re-check per rep.)
    if (to == GluteBridgeState.bottom) {
      _setupInstructionShown = false;
    }
  }

  @override
  void reset() {
    _faults.clear();
    // Keep _setupInstructionShown so we don't spam between reps;
    // it resets via onStateTransition → bottom.
  }
}
