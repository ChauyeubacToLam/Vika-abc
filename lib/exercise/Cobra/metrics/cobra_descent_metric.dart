// ignore_for_file: curly_braces_in_flow_control_structures
import 'cobra_metric_base.dart';
import '../cobra.dart';

/// MET-4: Descent Velocity Control (Eccentric Deceleration)
/// Tracks shoulder y-velocity during descent phase.
/// MUST use frameTimestampMs (timestamp-based, not frame count).
class CobraDescentMetric extends CobraMetricBase {
  @override
  String get name => 'DescentVelocity';

  // Thresholds (body-lengths/second)
  static const double _controlledMax = 1.0;
  static const double _crashMin = 2.8;
  static const int _crashFramesRequired = 5;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // State tracking
  double? _prevShoulderY;
  int? _prevTimestampMs;
  double? _peakTrunkDeviation;
  bool _isDescending = false;
  int _crashFrameCount = 0;
  int? _descentStartMs;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.shoulder == null || ctx.hip == null) return;

    final trunkLength = ctx.baselineTrunkLength ?? ctx.scaleFactor;
    if (trunkLength < 1.0) return;

    // Track peak trunk deviation during hold
    if (ctx.state == CobraState.holding) {
      _peakTrunkDeviation = (_peakTrunkDeviation == null)
          ? ctx.trunkDeviation.abs()
          : (ctx.trunkDeviation.abs() > _peakTrunkDeviation!
              ? ctx.trunkDeviation.abs()
              : _peakTrunkDeviation!);
    }

    // Detect descent onset: trunk angle decreasing from peak by >5°
    if (_peakTrunkDeviation != null && ctx.state != CobraState.holding) {
      final dropFromPeak = _peakTrunkDeviation! - ctx.trunkDeviation.abs();
      if (dropFromPeak > 5.0 && !_isDescending) {
        _isDescending = true;
        _descentStartMs = ctx.frameTimestampMs;
      }
    }

    // Only measure velocity during descent
    if (!_isDescending) {
      _prevShoulderY = ctx.shoulder!.y;
      _prevTimestampMs = ctx.frameTimestampMs;
      _debugData['descentVel'] = '-';
      return;
    }

    if (_prevShoulderY != null && _prevTimestampMs != null) {
      final deltaMs = ctx.frameTimestampMs - _prevTimestampMs!;
      if (deltaMs > 0) {
        final deltaY = (ctx.shoulder!.y - _prevShoulderY!).abs();
        final deltaSeconds = deltaMs / 1000.0;
        final vyNorm = (deltaY / trunkLength) / deltaSeconds;

        _debugData['descentVel'] = vyNorm.toStringAsFixed(2);

        // Crash detection (sustained high velocity)
        if (vyNorm >= _crashMin) {
          _crashFrameCount++;
          if (_crashFrameCount >= _crashFramesRequired) {
            ctx.resultIssues.feedback['Descent'] = '⚠️ Hạ quá nhanh!';
            // Legacy UI instruction copy: Hạ người xuống chậm hơn. Kiểm soát chuyển động bằng cơ lưng.
            _logFault('descent', 'Crash descent', 'CrashDescent');
          }
        } else {
          _crashFrameCount = 0;
        }

        // Warning
        if (vyNorm > _controlledMax && vyNorm < _crashMin) {
          ctx.resultIssues.feedback['Descent'] = 'Hạ chậm hơn chút';
        } else if (vyNorm <= _controlledMax) {
          ctx.resultIssues.feedback['Descent'] = 'Tốc độ hạ tốt ✓';
        }

        // Check total descent duration
        if (_descentStartMs != null) {
          final descentDuration =
              (ctx.frameTimestampMs - _descentStartMs!) / 1000.0;
          _debugData['descentDur'] = descentDuration.toStringAsFixed(1);
          // Beginner: flag if total descent < 0.8s
          if (ctx.trunkDeviation.abs() < 5.0 && descentDuration < 0.8) {
            _logFault('descent', 'Descent too fast overall', 'FastDescent');
          }
        }
      }
    }

    _prevShoulderY = ctx.shoulder!.y;
    _prevTimestampMs = ctx.frameTimestampMs;
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
  void onStateTransition(CobraState from, CobraState to, int timestampMs) {
    if (to == CobraState.holding) {
      // Reset descent tracking for new rep
      _isDescending = false;
      _peakTrunkDeviation = null;
      _crashFrameCount = 0;
      _descentStartMs = null;
    }
    if (to == CobraState.setup && from == CobraState.holding) {
      // Descent just ended (went from holding back to setup without rest)
      _isDescending = false;
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _prevShoulderY = null;
    _prevTimestampMs = null;
    _peakTrunkDeviation = null;
    _isDescending = false;
    _crashFrameCount = 0;
    _descentStartMs = null;
  }
}
