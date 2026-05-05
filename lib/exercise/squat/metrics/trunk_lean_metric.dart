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
  /// Keep a bit more tolerance here so the chest-up cue is less trigger-happy
  /// on natural forward lean during descent.
  static const List<double> GOOD_LEAN_RANGE = [15, 40];
  static const double WarningLean =
      30.0; // Leaning forward but not past good range yet

  /// Require fewer consecutive frames so the live cue reacts while the user
  /// is still in the bad position instead of after they start recovering.
  static const int FORWARD_CONFIRM_FRAMES = 3;

  /// Backward lean threshold (degrees). Below this = leaning back.
  static const double BACKWARD_LIMIT = 0.02;
}

class TrunkLeanMetric extends SquatMetricBase {
  @override
  String get name => 'TrunkLean';

  @override
  String? get nameVi => 'Thân trên';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // IMPORTANT: Separate debouncers for forward/backward — they can't share!
  final Debouncer _forwardDebouncer =
      Debouncer(requiredFrames: TrunkLeanConfig.FORWARD_CONFIRM_FRAMES);
  final Debouncer _backwardDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _warningDebouncer = Debouncer(requiredFrames: 5);

  /// Track maximum trunk lean this rep (for post-rep analysis)
  double? maxTrunkLean;
  double? _trunkLean;
  MetricStatus _status = MetricStatus.pass;

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _trunkLean;

  @override
  ThresholdBand? get threshold => ThresholdBand(
        faultAbove: TrunkLeanConfig.GOOD_LEAN_RANGE[1],
        faultBelow: -TrunkLeanConfig.BACKWARD_LIMIT,
        warningAbove: TrunkLeanConfig.WarningLean,
      );

  @override
  MetricStatus get status => _status;

  @override
  void update(RepContext ctx) {
    _trunkLean = ctx.trunkLean;

    // Track max lean per rep
    if (maxTrunkLean == null || ctx.trunkLean > maxTrunkLean!) {
      maxTrunkLean = ctx.trunkLean;
    }

    _debugData['trunkLean'] = ctx.trunkLean;
    _debugData['maxTrunkLean'] = maxTrunkLean ?? 'N/A';

    final phase = ctx.squatState.toString().split('.').last.toUpperCase();

    bool leanForward = ctx.trunkLean > TrunkLeanConfig.GOOD_LEAN_RANGE[1];
    bool leanBackward = ctx.trunkLean < -TrunkLeanConfig.BACKWARD_LIMIT;
    bool warningForward = ctx.trunkLean > TrunkLeanConfig.WarningLean;

    bool forwardConfirmed = _forwardDebouncer.update(leanForward);
    bool backwardConfirmed = _backwardDebouncer.update(leanBackward);
    bool warningConfirmed = _warningDebouncer.update(warningForward);

    if (forwardConfirmed) {
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['Back'] = 'Chest up!';
      if (!_instructionSet) {
        ctx.resultIssues
            .addInstruction('standing', 'Back', 'Keep chest up next time!');
        _instructionSet = true;
      }
      _logFault(
        phase,
        'Leaned too forward',
        null,
        priority: SquatFaultVoicePriority.trunkLean,
      );
    } else if (warningConfirmed) {
      _status = MetricStatus.near;
      ctx.resultIssues.feedback['Back'] = 'Try to keep chest up';
    } else if (backwardConfirmed) {
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['Back'] = "Don't lean back!";
      if (!_instructionSet) {
        ctx.resultIssues
            .addInstruction('standing', 'Back', "Don't lean back next time!");
        _instructionSet = true;
      }
      _logFault(
        phase,
        'Leaned backward',
        null,
        priority: SquatFaultVoicePriority.trunkLeanBackward,
      );
    } else {
      _status =
          leanForward || leanBackward ? MetricStatus.near : MetricStatus.pass;
      ctx.resultIssues.feedback['Back'] = 'Good back';
    }
  }

  void _logFault(
    String phase,
    String message,
    String? voiceMessage, {
    required int priority,
  }) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Back')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Back',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: true,
        priority: priority,
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
    _trunkLean = null;
    _status = MetricStatus.pass;
    _instructionSet = false;
  }
}
