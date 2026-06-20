// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Warrior I Metric 1: Trunk Lean  (SAFETY — form-critical)

   Torso alignment relative to vertical. Catches BOTH failure modes:
   collapsing forward over the front thigh, AND forcing perfectly upright
   against tight hip flexors (which arches the lumbar / compresses facets).

   Landmarks : SHOULDER (#11/12), HIP (#23/24) — via getSideLandmark()
   Calc      : calculateVerticalAngle(hip, shoulder) → clock angle
               → convertClockAngleToTrunkLean() → signed degrees (fwd = +)
   Type      : ANGLE (self-normalizing, no scaleFactor)
   When      : HOLD phase only.

   Zones (Week 1-4 launch defaults; tighten per threshold table later):
     Good      : 10°–25° forward
     Warning   : 5°–10°  OR  25°–30°   (and <5° = too upright, also warn)
     Error     : > 30° sustained        [affectsForm = TRUE]

   This is the ONLY Warrior I metric that fails the hold.
   ========================================================================= */

import 'warrior_one_metric_base.dart';
import '../warrior_one.dart';
import '../../../utils/debouncer.dart';

class TrunkLeanConfig {
  /// Good forward-lean band.
  static const double GOOD_MIN = 0.0;
  static const double GOOD_MAX = 35.0;

  /// Below this = too upright (lumbar compression risk for tight hip flexors).
  static const double UPRIGHT_WARN = -5.0;

  /// Forward warning band upper bound.
  static const double FORWARD_WARN_MAX = 45.0;

  /// Above this, sustained = safety error.
  static const double ERROR_THRESHOLD = 30.0;
}

class TrunkLeanMetric extends WarriorOneMetricBase {
  @override
  String get name => 'TrunkLean';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Coaching path: 20 frames (~667ms) — stable, non-jumpy feedback.
  final StickyDebouncer _coachingDebouncer =
      StickyDebouncer(requiredFrames: 20, currentState: true);

  /// Safety path: 8 frames (~267ms) — faster confirmation of the >30° error.
  final Debouncer _errorDebouncer = Debouncer(requiredFrames: 8);

  double? maxLean; // peak forward lean this hold (debug / post-hold)
  bool _instructionSet = false;
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HoldContext ctx) {
    _isFaultingNow = false;
    if (ctx.holdState != WarriorOneState.hold) return;

    final double lean = ctx.trunkLean;
    maxLean = (maxLean == null || lean > maxLean!) ? lean : maxLean;

    _debugData['trunkLean'] =
        '${lean >= 0 ? "+" : ""}${lean.toStringAsFixed(1)}°';
    _debugData['maxTrunkLean'] = maxLean?.toStringAsFixed(1) ?? 'N/A';

    final phase = ctx.holdState.name.toUpperCase();

    // --- Safety error (fast path) ---
    final bool isError =
        _errorDebouncer.update(lean > TrunkLeanConfig.ERROR_THRESHOLD);
    if (isError) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['trunk_lean'] =
          'Cẩn thận lưng! Đứng thẳng hơn, đừng gập quá nhiều.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction('hold', 'trunk_lean',
            'Cẩn thận lưng! Đứng thẳng hơn, đừng gập quá nhiều.');
        _instructionSet = true;
      }
      _logFault(phase, 'Trunk collapsing forward (>30°)',
          voiceMessage: 'Đứng thẳng hơn');
      return;
    }

    // --- Coaching zones (slow path, feedback only) ---
    // Only update displayed feedback when the zone is stable, to avoid flicker.
    final bool stable = _coachingDebouncer.update(true);
    if (!stable) return;

    if (lean < TrunkLeanConfig.UPRIGHT_WARN) {
      // Too upright — gently encourage some forward lean.
      ctx.resultIssues.feedback['trunk_lean'] =
          'Hơi nghiêng về trước một chút là bình thường nhé!';
    } else if (lean > TrunkLeanConfig.GOOD_MAX &&
        lean <= TrunkLeanConfig.FORWARD_WARN_MAX) {
      // 25°–30° — drifting toward the error zone.
      ctx.resultIssues.feedback['trunk_lean'] = 'Giữ thân người thẳng hơn nhé!';
    } else if (lean >= TrunkLeanConfig.GOOD_MIN &&
        lean <= TrunkLeanConfig.GOOD_MAX) {
      ctx.resultIssues.feedback['trunk_lean'] = 'Thân người ổn định tốt!';
    } else {
      // 5°–10° — slightly upright, still acceptable.
      ctx.resultIssues.feedback['trunk_lean'] = 'Thân người ổn định tốt!';
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'trunk_lean')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'trunk_lean',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: true, // SAFETY — fails the hold
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _coachingDebouncer.reset();
    _errorDebouncer.reset();
    maxLean = null;
    _instructionSet = false;
    _isFaultingNow = false;
  }
}
