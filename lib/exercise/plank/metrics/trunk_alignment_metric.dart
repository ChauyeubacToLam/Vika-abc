/* =========================================================================
   Metric 1: Trunk Sagittal Alignment (Hip Sag & Pike)
   Priority: CRITICAL — Ship Day 1
   
   Measures shoulder→hip→ankle alignment. The primary plank form metric.
   
   Vietnamese desk workers with weak glutes and tight hip flexors
   fatigue around 40s, causing anterior pelvic tilt and hip sag.
   This metric catches that in real-time.
   
   Thresholds (empirically tested):
     Pike Error:   < 165°  → Hông quá cao!
     Pike Warning:  165°–169° → Hơi cao hông
     Perfect:       170°–185° → Tư thế tốt!
     Sag Warning:   186°–190° → Gồng cơ bụng!
     Sag Error:     > 190°  → Lưng võng quá!
   
   Uses fault percentage to judge hold quality:
     - Tracks frames in fault vs total frames
     - > 30% fault time → affectsForm = true
   ========================================================================= */

import 'plank_metric_base.dart';
import '../plank.dart';
import '../../../utils/debouncer.dart';

class TrunkAlignmentConfig {
  // Perfect range (from empirical testing)
  static const double GOOD_MIN = PlankConfig.TRUNK_PIKE_LIMIT;
  static const double GOOD_MAX = PlankConfig.TRUNK_SAG_LIMIT;

  // Warning zones
  static const double PIKE_WARNING = 165.0; // 165–169 = mild pike
  static const double SAG_WARNING = 190.0; // 186–190 = mild sag

  // Error zones (below PIKE_WARNING or above SAG_WARNING)

  /// Fault percentage threshold — above this, the hold is marked bad
  static const double FAULT_PERCENT_THRESHOLD = 0.30;
}

class TrunkAlignmentMetric extends PlankMetricBase {
  @override
  String get name => 'TrunkAlignment';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Debouncers — separate for sag and pike to avoid interference
  final Debouncer _sagDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _pikeDebouncer = Debouncer(requiredFrames: 5);

  // Fault time tracking
  int _totalFrames = 0;
  int _faultFrames = 0;

  // Prevent instruction spam
  bool _sagInstructionSet = false;
  bool _pikeInstructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /// Percentage of hold spent in bad form (0.0–1.0)
  double get faultPercentage =>
      _totalFrames > 0 ? _faultFrames / _totalFrames : 0.0;

  @override
  void update(RepContext ctx) {
    _totalFrames++;

    final angle = ctx.backAngle;
    bool isFault = false;

    _debugData['trunkAngle'] = angle.toStringAsFixed(1);
    _debugData['trunkFault%'] =
        '${(faultPercentage * 100).toStringAsFixed(0)}%';

    // --- Sag detection (hip dropping) ---
    bool isSagError = angle > TrunkAlignmentConfig.SAG_WARNING;
    bool isSagWarning = angle > TrunkAlignmentConfig.GOOD_MAX &&
        angle <= TrunkAlignmentConfig.SAG_WARNING;

    // --- Pike detection (hip rising) ---
    bool isPikeError = angle < TrunkAlignmentConfig.PIKE_WARNING;
    bool isPikeWarning = angle >= TrunkAlignmentConfig.PIKE_WARNING &&
        angle < TrunkAlignmentConfig.GOOD_MIN;

    // --- Debounced sag ---
    if (_sagDebouncer.update(isSagError || isSagWarning)) {
      isFault = true;
      if (isSagError) {
        ctx.resultIssues.feedback['Back'] = 'Lưng võng quá!';
        if (!_sagInstructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Back', 'Gồng cơ bụng nhiều hơn lần sau!');
          _sagInstructionSet = true;
        }
        _logFault('Hông chùng quá mức');
      } else {
        ctx.resultIssues.feedback['Back'] = 'Gồng cơ bụng!';
        if (!_sagInstructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Back', 'Hông hơi chùng — siết bụng lại!');
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
          ctx.resultIssues.addInstruction(
              'resting', 'Back', 'Hạ hông xuống, giữ thân thẳng!');
          _pikeInstructionSet = true;
        }
        _logFault('Hông quá cao');
      } else {
        ctx.resultIssues.feedback['Back'] = 'Hơi cao hông';
        if (!_pikeInstructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Back', 'Hông hơi cao — hạ thấp một chút!');
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

    _debugData['trunkStatus'] = isFault ? 'FAULT' : 'GOOD';
  }

  void _logFault(String message) {
    // Only log one fault per type — we use faultPercentage for severity
    if (!_faults.any((f) => f.message == message)) {
      _faults.add(FaultRecord(
        faultPercentage: 0.0, // Placeholder, will be updated at hold completion
        type: 'Back',
        message: message,
        // Determined at hold completion based on faultPercentage
        affectsForm: false,
      ));
    }
  }

  /// Called by Plank._onHoldComplete to finalize fault judgment.
  /// Sets affectsForm based on how much time was spent in bad form.
  void finalizeHold() {
    final shouldAffect =
        faultPercentage > TrunkAlignmentConfig.FAULT_PERCENT_THRESHOLD;
    if (shouldAffect && _faults.isNotEmpty) {
      // Replace faults with affectsForm = true
      final updated = _faults
          .map((f) => FaultRecord(
                faultPercentage: faultPercentage,
                type: f.type,
                message:
                    '${f.message} (${(faultPercentage * 100).toStringAsFixed(0)}% thời gian)',
                affectsForm: shouldAffect,
              ))
          .toList();
      _faults.clear();
      _faults.addAll(updated);
    }

    _debugData['trunkFaultFinal'] =
        '${(faultPercentage * 100).toStringAsFixed(0)}% → ${shouldAffect ? "BAD" : "OK"}';
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _sagDebouncer.reset();
    _pikeDebouncer.reset();
    _totalFrames = 0;
    _faultFrames = 0;
    _sagInstructionSet = false;
    _pikeInstructionSet = false;
  }
}
