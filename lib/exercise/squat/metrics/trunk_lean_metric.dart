/* =========================================================================
   Metric 2: Forward Trunk Lean
   Priority: CRITICAL — Ship Day 1
   
   Angle of the torso from vertical (shoulder-hip line).
   Primary indicator of lumbar spine loading risk.
   ========================================================================= */

import 'squat_metric_base.dart';
import '../../../utils/debouncer.dart';

class TrunkLeanConfig {
  /// Good forward lean range (degrees from vertical)
  /// Wide for Vietnamese Group 1 males (short torso, long femurs)
  static const List<int> GOOD_LEAN_RANGE = [15, 50];

  /// Backward lean threshold (degrees). Below this = leaning back.
  static const double BACKWARD_LIMIT = 0.02;
}

class TrunkLeanMetric extends SquatMetricBase {
  @override
  String get name => 'TrunkLean';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // IMPORTANT: Separate debouncers for forward/backward — they can't share!
  final Debouncer _forwardDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _backwardDebouncer = Debouncer(requiredFrames: 5);

  /// Track maximum trunk lean this rep (for post-rep analysis)
  double? maxTrunkLean;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  Map<String, String> update(RepContext ctx) {
    // Track max lean per rep (spec: record maximum lean angle per rep)
    if (maxTrunkLean == null || ctx.trunkLean > maxTrunkLean!) {
      maxTrunkLean = ctx.trunkLean;
    }

    _debugData['maxTrunkLean'] = maxTrunkLean?.toStringAsFixed(1) ?? 'N/A';

    final phase = ctx.squatState.toString().split('.').last.toUpperCase();
    final feedback = <String, String>{};

    bool leanForward = ctx.trunkLean > TrunkLeanConfig.GOOD_LEAN_RANGE[1];
    bool leanBackward = ctx.trunkLean < -TrunkLeanConfig.BACKWARD_LIMIT;

    bool forwardConfirmed = _forwardDebouncer.update(leanForward);
    bool backwardConfirmed = _backwardDebouncer.update(leanBackward);

    if (forwardConfirmed) {
      feedback['Back'] = 'Chest up!';
      _logFault(phase, 'Leaned too forward');
    } else if (backwardConfirmed) {
      feedback['Back'] = "Don't lean back!";
      _logFault(phase, 'Leaned backward');
    } else {
      feedback['Back'] = 'Good back';
    }

    return feedback;
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
  }
}
