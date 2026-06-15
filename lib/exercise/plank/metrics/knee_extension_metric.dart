/* =========================================================================
   Metric 3: Knee Extension
   Priority: SECONDARY
   
   Measures hip→knee→ankle angle. Ensures legs are actively engaged.
   
   Soft knees = loss of full-body tension, reducing the effectiveness
   of the anti-extension core challenge. Unlike trunk alignment,
   this is about effectiveness, not injury risk.
   
   Uses calculateAngle() (unsigned 0–180°). Knees can only bend
   one direction so no signed detection needed.
   
   Thresholds (from spec):
     Good:     170°–180° → Chân tốt
     Warning:  160°–169° → Thẳng đầu gối ra
     Error:    < 160°    → Đầu gối gập quá nhiều!
   ========================================================================= */

import 'plank_metric_base.dart';
import '../../../utils/debouncer.dart';

class KneeExtensionConfig {
  /// Good range — slight softness is fine
  static const double GOOD_MIN = 170.0;

  /// Warning — knees noticeably bent
  static const double WARNING_MIN = 160.0;

  /// Below WARNING_MIN = error

  /// Fault percentage threshold
  static const double FAULT_PERCENT_THRESHOLD = 0.30;
}

class KneeExtensionMetric extends PlankMetricBase {
  @override
  String get name => 'KneeExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _kneeDebouncer = Debouncer(requiredFrames: 8);

  // Fault time tracking
  int _totalFrames = 0;
  int _faultFrames = 0;
  bool _isFaultingNow = false;

  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  double get faultPercentage =>
      _totalFrames > 0 ? _faultFrames / _totalFrames : 0.0;

  @override
  void update(RepContext ctx) {
    _isFaultingNow = false;
    if (ctx.kneeAngle == null) return; // Ankle not visible, skip
    _totalFrames++;

    final angle = ctx.kneeAngle!;
    bool isFault = false;

    _debugData['kneeAngle'] = angle.toStringAsFixed(1);
    _debugData['kneeFault%'] = '${(faultPercentage * 100).toStringAsFixed(0)}%';

    bool isError = angle < KneeExtensionConfig.WARNING_MIN;
    bool isWarning = angle >= KneeExtensionConfig.WARNING_MIN &&
        angle < KneeExtensionConfig.GOOD_MIN;

    if (_kneeDebouncer.update(isError || isWarning)) {
      isFault = true;
      if (isError) {
        ctx.resultIssues.feedback['Knees'] = 'Gối gập quá nhiều!';
        if (!_instructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Knees', 'Siết đùi, thẳng đầu gối ra!');
          _instructionSet = true;
        }
        _logFault('Đầu gối gập quá nhiều');
      } else {
        ctx.resultIssues.feedback['Knees'] = 'Thẳng gối ra';
        if (!_instructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Knees', 'Gối hơi gập — siết đùi lại!');
          _instructionSet = true;
        }
        _logFault('Đầu gối hơi gập');
      }
    } else {
      ctx.resultIssues.feedback['Knees'] = 'Chân tốt';
    }

    if (isFault) _faultFrames++;
    _isFaultingNow = isFault;

    _debugData['kneeStatus'] = isFault ? 'FAULT' : 'GOOD';
  }

  void _logFault(String message) {
    if (!_faults.any((f) => f.message == message)) {
      _faults.add(FaultRecord(
        faultPercentage: 0.0,
        type: 'Knees',
        message: message,
        affectsForm: false,
      ));
    }
  }

  @override
  void finalizeHold() {
    final shouldAffect =
        faultPercentage > KneeExtensionConfig.FAULT_PERCENT_THRESHOLD;

    final updated = _faults
        .map((f) => FaultRecord(
              faultPercentage: faultPercentage,
              type: f.type,
              message: shouldAffect
                  ? '${f.message} (${(faultPercentage * 100).toStringAsFixed(0)}% thời gian)'
                  : f.message,
              affectsForm: shouldAffect,
            ))
        .toList();
    _faults.clear();
    _faults.addAll(updated);
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _kneeDebouncer.reset();
    _totalFrames = 0;
    _faultFrames = 0;
    _isFaultingNow = false;
    _instructionSet = false;
  }
}
