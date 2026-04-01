/* =========================================================================
   Metric 2: Leg Spread
   Priority: IMPORTANT — Ship Day 2
   
   Measures foot separation in the OPEN position, normalized to
   shoulder width. Ensures user is performing a complete jumping jack
   rather than just waving arms.
   
   Detection strategy:
   - ankleSpreadNorm = distance(leftAnkle, rightAnkle) / shoulderWidth
   - Only evaluate during OPEN state
   - Track peak spread per rep for post-rep analysis
   
   Thresholds (normalized to shoulder width):
     Good:     ankleSpread >= 1.5× shoulder width
     Warning:  ankleSpread 1.0–1.5× shoulder width
     Error:    ankleSpread < 1.0× shoulder width
   
   Vietnamese context:
   - Small apartment tile floors can be slippery
   - Bare feet common at home — may limit willingness to jump wide
   - Frame as encouragement, not criticism
   ========================================================================= */

import 'jumping_jack_metric_base.dart';
import '../jumping_jack.dart';
import '../../../utils/debouncer.dart';

class LegSpreadConfig {
  /// Good: feet clearly spread wider than shoulders
  // ignore: constant_identifier_names
  static const double SPREAD_GOOD = 1.5;

  /// Warning: feet apart but not wide enough
  // ignore: constant_identifier_names
  static const double SPREAD_WARNING = 1.0;

  // Below SPREAD_WARNING = error (feet barely moved)
}

class LegSpreadMetric extends JJMetricBase {
  @override
  String get name => 'LegSpread';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Fast movement → low debounce
  final Debouncer _spreadDebouncer = Debouncer(requiredFrames: 2);

  /// Track peak spread this rep
  double _peakSpread = 0.0;

  /// Prevent instruction spam
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Track peak spread
    if (ctx.ankleSpreadNorm > _peakSpread) {
      _peakSpread = ctx.ankleSpreadNorm;
    }

    _debugData['ankleSpread'] = ctx.ankleSpreadNorm.toStringAsFixed(2);
    _debugData['peakSpread'] = _peakSpread.toStringAsFixed(2);

    // Only evaluate during OPEN phase
    if (ctx.jjState != JJState.open) {
      if (ctx.resultIssues.feedback['Legs'] == null) {
        ctx.resultIssues.feedback['Legs'] = 'Chuẩn bị';
      }
      return;
    }

    bool narrowStance = ctx.ankleSpreadNorm < LegSpreadConfig.SPREAD_WARNING;
    bool mediumStance = ctx.ankleSpreadNorm >= LegSpreadConfig.SPREAD_WARNING &&
        ctx.ankleSpreadNorm < LegSpreadConfig.SPREAD_GOOD;

    if (_spreadDebouncer.update(narrowStance)) {
      ctx.resultIssues.feedback['Legs'] = 'Mở chân rộng hơn!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'closed', 'Legs spread', 'Lần sau, bước rộng bằng vai hoặc hơn!');
        _instructionSet = true;
      }
      _logFault('OPEN', 'Chân chưa đủ rộng', voiceMessage: 'Mở chân rộng hơn');
    } else if (mediumStance) {
      ctx.resultIssues.feedback['Legs'] = 'Rộng hơn chút!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'closed', 'Legs spread', 'Cố gắng mở rộng chân hơn lần sau!');
        _instructionSet = true;
      }
    } else {
      ctx.resultIssues.feedback['Legs'] = 'Chân tốt!';
    }

    _debugData['legStatus'] = ctx.resultIssues.feedback['Legs'] ?? '';
  }

  /// Called by JumpingJack when rep completes.
  void evaluateRep(RepContext ctx) {
    if (_peakSpread < LegSpreadConfig.SPREAD_WARNING) {
      _logFault(
          'REP_COMPLETE', 'Chân quá hẹp (${_peakSpread.toStringAsFixed(1)}×)');
    } else if (_peakSpread < LegSpreadConfig.SPREAD_GOOD) {
      _logFault('REP_COMPLETE',
          'Chân chưa đủ rộng (${_peakSpread.toStringAsFixed(1)}×)');
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Legs')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Legs',
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
    _spreadDebouncer.reset();
    _peakSpread = 0.0;
    _instructionSet = false;
  }
}
