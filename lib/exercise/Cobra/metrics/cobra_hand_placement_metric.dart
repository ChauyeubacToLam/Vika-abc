// ignore_for_file: curly_braces_in_flow_control_structures
import 'cobra_metric_base.dart';

import '../../../utils/debouncer.dart';
import '../../../utils/pose_math_helpers.dart';

/// MET-2: Hand Placement Offset (Wrist-Shoulder Alignment)
/// Hands too far forward → eliminates back muscle engagement,
/// compresses median nerve (carpal tunnel risk).
class CobraHandPlacementMetric extends CobraMetricBase {
  @override
  String get name => 'HandPlacement';

  // Beginner thresholds (normalized by shoulder-hip distance)
  static const double _goodMin = 0.06;
  static const double _goodMax = 0.50;
  static const double _warningTooFar = 0.50;
  static const double _warningTooClose = 0.04;
  static const double _errorTooFar = 0.60;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _tooFarDebouncer = StickyDebouncer(requiredFrames: 12);
  final StickyDebouncer _tooCloseDebouncer =
      StickyDebouncer(requiredFrames: 12);
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    _isFaultingNow = false;
    // Check primarily in setup, but also drift during hold
    if (ctx.shoulder == null || ctx.wrist == null || ctx.hip == null) return;

    final trunkLength = calculateDistance(ctx.shoulder!, ctx.hip!);
    if (trunkLength < 1.0) return; // avoid division by zero

    final handOffset = (ctx.wrist!.x - ctx.shoulder!.x).abs() / trunkLength;

    _debugData['handOffset'] = handOffset.toStringAsFixed(2);

    final phase = ctx.state.name;

    // Error: extremely far forward
    if (_tooFarDebouncer.update(handOffset >= _errorTooFar)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Hands'] = '⚠️ Tay đặt quá xa!';
      // Legacy UI instruction copy: Đặt tay gần xương sườn hơn, ngay dưới vai.
      _logFault(phase, 'Hands placed too far forward', 'HandsTooFar');
    }
    // Warning: too far
    else if (handOffset >= _warningTooFar) {
      ctx.resultIssues.feedback['Hands'] = 'Kéo tay về gần vai hơn';
    }
    // Warning: too close
    else if (_tooCloseDebouncer.update(handOffset <= _warningTooClose)) {
      ctx.resultIssues.feedback['Hands'] = 'Tay đặt hơi gần, đẩy ra chút';
    }
    // Good
    else if (handOffset >= _goodMin && handOffset <= _goodMax) {
      ctx.resultIssues.feedback['Hands'] = 'Vị trí tay tốt ✓';
    }
  }

  void _logFault(String phase, String message, String type) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _tooFarDebouncer.reset();
    _tooCloseDebouncer.reset();
    _isFaultingNow = false;
  }
}
