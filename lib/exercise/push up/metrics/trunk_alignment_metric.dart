/* =========================================================================
   Metric 1: Dynamic Trunk Alignment (Hip Sag & Pike)
   Priority: 🔴 CRITICAL — Ship Day 1
   
   Uses trunk deviation from horizontal (same approach as Plank).
   Calculated via calculateVerticalAngle(hip, shoulder) → clock angle
   → deviation from horizontal target.
   
   Only needs SHOULDER + HIP landmarks — no ankle/knee required.
   This avoids the problem of feet being cut off in small Vietnamese
   apartments (1.5-2m camera distance with horizontal body).
   
   trunkDeviation:
     0°  = perfectly horizontal
     +N° = sag direction (hips dropping → lumbar hyperextension)
     -N° = pike direction (hips too high → inverted V)
   
   Vietnamese context:
   - Short torso + long legs → 165°-175° three-point angle is normal
   - With horizontal deviation approach, slight pike (-2° to -5°) is
     actually correct form with glute engagement
   - Desk workers with weak cores sag quickly under fatigue
   - CRITICAL: Never enforce strict 0° — slight pike is SAFE
   
   Runs CONTINUOUSLY (not per-rep) during descending, bottom, ascending.
   Hip sag is the #1 acute spinal injury risk in push-ups.
   ========================================================================= */

import 'push_up_metric_base.dart';
import '../../../../utils/debouncer.dart';

class TrunkAlignmentConfig {
  /// Sag thresholds (positive deviation = hips dropping)
  /// More lenient than plank because dynamic movement causes natural sway
  static const double SAG_GOOD_MAX = 12.0; // degrees
  static const double SAG_WARNING_MAX = 16.0;
  static const double SAG_ERROR_MAX = 25.0; // STOP level

  /// Pike thresholds (negative deviation = hips too high)
  /// Slight pike is NORMAL for Vietnamese users — don't over-flag
  static const double PIKE_GOOD_MAX = 6.0;
  static const double PIKE_WARNING_MAX = 10.0;
  static const double PIKE_ERROR_MAX = 16.0;
}

class TrunkAlignmentMetric extends PushUpMetricBase {
  @override
  String get name => 'TrunkAlignment';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Separate debouncers for sag and pike — they can't share!
  final Debouncer _sagDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _pikeDebouncer = Debouncer(requiredFrames: 5);

  /// Prevent instruction spam — only set coaching once per rep.
  bool _sagInstructionSet = false;
  bool _pikeInstructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    final dev = ctx.trunkDeviation;
    final absDev = dev.abs();

    final phase = ctx.pushUpState.toString().split('.').last.toUpperCase();

    _debugData['trunkDev'] = '${dev >= 0 ? "+" : ""}${dev.toStringAsFixed(1)}°';

    // --- Sag detection (positive deviation = hips dropping) ---
    // NOTE: verify with debug data that positive = sag. Swap if needed.
    bool isSagWarning = dev > 0 &&
        absDev > TrunkAlignmentConfig.SAG_GOOD_MAX &&
        absDev <= TrunkAlignmentConfig.SAG_WARNING_MAX;
    bool isSagError = dev > 0 && absDev > TrunkAlignmentConfig.SAG_WARNING_MAX;
    bool isSagCritical = dev > 0 && absDev > TrunkAlignmentConfig.SAG_ERROR_MAX;

    // --- Pike detection (negative deviation = hips too high) ---
    bool isPikeWarning = dev < 0 &&
        absDev > TrunkAlignmentConfig.PIKE_GOOD_MAX &&
        absDev <= TrunkAlignmentConfig.PIKE_WARNING_MAX;
    bool isPikeError =
        dev < 0 && absDev > TrunkAlignmentConfig.PIKE_WARNING_MAX;

    // --- Debounced sag ---
    if (_sagDebouncer.update(isSagError || isSagWarning || isSagCritical)) {
      if (isSagCritical) {
        ctx.resultIssues.feedback['Back'] = 'DỪNG LẠI! Lưng võng quá nhiều!';
        if (!_sagInstructionSet) {
          // Legacy UI instruction copy: Lưng võng nguy hiểm — siết cơ bụng mạnh hơn!
          _sagInstructionSet = true;
        }
        _logFault(phase, 'Lưng võng quá mức — nguy hiểm',
            voiceMessage: 'Siết cơ bụng');
      } else if (isSagError) {
        ctx.resultIssues.feedback['Back'] = 'Hông hơi võng — siết cơ bụng!';
        if (!_sagInstructionSet) {
          // Legacy UI instruction copy: Hông hơi võng — gồng bụng nhiều hơn!
          _sagInstructionSet = true;
        }
        _logFault(phase, 'Hông hơi võng', voiceMessage: 'Siết cơ bụng');
      } else {
        ctx.resultIssues.feedback['Back'] = 'Gồng cơ bụng!';
        if (!_sagInstructionSet) {
          // Legacy UI instruction copy: Gồng bụng lại, giữ thân thẳng!
          _sagInstructionSet = true;
        }
        _logFault(phase, 'Hông hơi chùng', voiceMessage: 'Siết cơ bụng');
      }
    }
    // --- Debounced pike ---
    else if (_pikeDebouncer.update(isPikeError || isPikeWarning)) {
      if (isPikeError) {
        ctx.resultIssues.feedback['Back'] = 'Hông quá cao! Giữ người thẳng.';
        if (!_pikeInstructionSet) {
          // Legacy UI instruction copy: Hạ hông xuống, giữ thân thẳng!
          _pikeInstructionSet = true;
        }
        _logFault(phase, 'Hông quá cao', voiceMessage: 'Hạ hông xuống');
      } else {
        ctx.resultIssues.feedback['Back'] = 'Hạ hông xuống một chút!';
        if (!_pikeInstructionSet) {
          // Legacy UI instruction copy: Hông hơi cao — hạ thấp một chút!
          _pikeInstructionSet = true;
        }
        _logFault(phase, 'Hông hơi cao', voiceMessage: 'Hạ hông xuống');
      }
    }
    // --- Good form ---
    else {
      ctx.resultIssues.feedback['Back'] = 'Lưng tốt!';
    }

    _debugData['trunkStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Back',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _sagDebouncer.reset();
    _pikeDebouncer.reset();
    _sagInstructionSet = false;
    _pikeInstructionSet = false;
  }
}
