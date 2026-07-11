/* =========================================================================
   Metric 1: Trunk Sagittal Alignment (Hip Sag & Pike)
   Priority: CRITICAL — Ship Day 1
   
   Now uses trunk deviation from horizontal (degrees).
   Calculated via calculateVerticalAngle(hip, shoulder) — only needs
   shoulder + hip landmarks. No ankle required.
   
   trunkDeviation:
     0°  = perfectly horizontal (ideal plank)
     +N° = sag direction (verify with debug data)
     -N° = pike direction (verify with debug data)
   
   Thresholds (adjust after empirical testing):
     Good:     |deviation| < 8°
     Warning:  8°–15°
     Error:    > 15°
   
   Uses fault percentage to judge hold quality:
     > 30% fault time → affectsForm = true
   ========================================================================= */

import 'plank_metric_base.dart';
import '../plank.dart';
import '../../../utils/debouncer.dart';

class TrunkAlignmentConfig {
  // Threshold references from PlankConfig
  static const double SAG_GOOD_MAX = PlankConfig.SAG_GOOD_MAX;
  static const double PIKE_GOOD_MAX = PlankConfig.PIKE_GOOD_MAX;
  static const double SAG_WARNING_MAX = PlankConfig.SAG_WARNING_MAX;
  static const double PIKE_WARNING_MAX = PlankConfig.PIKE_WARNING_MAX;

  /// Fault percentage threshold
  static const double FAULT_PERCENT_THRESHOLD = 0.45;
}

class TrunkAlignmentMetric extends PlankMetricBase {
  @override
  String get name => 'TrunkAlignment';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Separate debouncers for sag and pike
  final Debouncer _sagDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _pikeDebouncer = Debouncer(requiredFrames: 5);

  // Fault time tracking
  int _totalFrames = 0;
  int _faultFrames = 0;
  bool _isFaultingNow = false;

  // Prevent instruction spam
  bool _sagInstructionSet = false;
  bool _pikeInstructionSet = false;

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
    _totalFrames++;
    _isFaultingNow = false;

    final dev = ctx.trunkDeviation;
    final absDev = dev.abs();
    bool isFault = false;

    _debugData['trunkDev'] = '${dev >= 0 ? "+" : ""}${dev.toStringAsFixed(1)}°';
    _debugData['trunkFault%'] =
        '${(faultPercentage * 100).toStringAsFixed(0)}%';

    // --- Sag detection (positive deviation) ---
    // NOTE: verify with debug data that positive = sag. Swap if needed.
    bool isSagWarning = dev > 0 &&
        absDev > TrunkAlignmentConfig.SAG_GOOD_MAX &&
        absDev <= TrunkAlignmentConfig.SAG_WARNING_MAX;
    bool isSagError = dev > 0 && absDev > TrunkAlignmentConfig.SAG_WARNING_MAX;

    // --- Pike detection (negative deviation) ---
    bool isPikeWarning = dev < 0 &&
        absDev > TrunkAlignmentConfig.PIKE_GOOD_MAX &&
        absDev <= TrunkAlignmentConfig.PIKE_WARNING_MAX;
    bool isPikeError =
        dev < 0 && absDev > TrunkAlignmentConfig.PIKE_WARNING_MAX;

    // --- Debounced sag ---
    if (_sagDebouncer.update(isSagError || isSagWarning)) {
      isFault = true;
      if (isSagError) {
        ctx.resultIssues.feedback['Back'] = 'Lưng võng quá!';
        if (!_sagInstructionSet) {
          // Legacy UI instruction copy: Gồng cơ bụng nhiều hơn lần sau!
          _sagInstructionSet = true;
        }
        _logFault('Hông chùng quá mức');
      } else {
        ctx.resultIssues.feedback['Back'] = 'Gồng cơ bụng!';
        if (!_sagInstructionSet) {
          // Legacy UI instruction copy: Hông hơi chùng — siết bụng lại!
          _sagInstructionSet = true;
        }
        _logFault('Hông hơi chùng');
      }
    }
    // --- Debounced pike ---
    else if (_pikeDebouncer.update(isPikeError || isPikeWarning)) {
      isFault = true;
      if (isPikeError) {
        ctx.resultIssues.feedback['Back'] = 'Hông quá cao!';
        if (!_pikeInstructionSet) {
          // Legacy UI instruction copy: Hạ hông xuống, giữ thân thẳng!
          _pikeInstructionSet = true;
        }
        _logFault('Hông quá cao');
      } else {
        ctx.resultIssues.feedback['Back'] = 'Hơi cao hông';
        if (!_pikeInstructionSet) {
          // Legacy UI instruction copy: Hông hơi cao — hạ thấp một chút!
          _pikeInstructionSet = true;
        }
        _logFault('Hông hơi cao');
      }
    }
    // --- Good form ---
    else {
      ctx.resultIssues.feedback['Back'] = 'Tư thế tốt!';
    }

    if (isFault) _faultFrames++;
    _isFaultingNow = isFault;

    _debugData['trunkStatus'] = isFault ? 'FAULT' : 'GOOD';
  }

  void _logFault(String message) {
    if (!_faults.any((f) => f.message == message)) {
      _faults.add(FaultRecord(
        faultPercentage: 0.0,
        type: 'Back',
        message: message,
        affectsForm: false,
      ));
    }
  }

  @override
  void finalizeHold() {
    final shouldAffect =
        faultPercentage > TrunkAlignmentConfig.FAULT_PERCENT_THRESHOLD;

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
    _sagDebouncer.reset();
    _pikeDebouncer.reset();
    _totalFrames = 0;
    _faultFrames = 0;
    _isFaultingNow = false;
    _sagInstructionSet = false;
    _pikeInstructionSet = false;
  }
}
