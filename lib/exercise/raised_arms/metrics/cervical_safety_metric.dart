// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:collection';
import 'dart:math' as math;

import 'raised_arms_metric_base.dart';
import '../raised_arms.dart';
import '../../../utils/debouncer.dart';

class CervicalSafetyConfig {
  static const double GOOD_THRESHOLD = 125.0;
  static const int MEDIAN_WINDOW = 7;
  static const double ONE_EURO_MIN_CUTOFF = 0.6;
  static const double ONE_EURO_BETA = 0.01;
}

/// MET-2: Cervical Safety.
/// Coaching-only detector for cranking the neck back to look at the hands.
class CervicalSafetyMetric extends RaisedArmsMetricBase {
  @override
  String get name => 'CervicalSafety';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _dangerDebouncer =
      StickyDebouncer(requiredFrames: 20, currentState: false);
  final _AngleOneEuro _euro = _AngleOneEuro(
    minCutoff: CervicalSafetyConfig.ONE_EURO_MIN_CUTOFF,
    beta: CervicalSafetyConfig.ONE_EURO_BETA,
  );
  final Queue<double> _medianBuf = Queue<double>();

  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RaisedArmsContext ctx) {
    if (ctx.state != RaisedArmsState.holding) return;
    if (ctx.ear == null || ctx.ear!.likelihood < 0.5) {
      _debugData['cervicalAngle'] = 'low_conf';
      return;
    }

    final euroAngle = _euro.filter(ctx.cervicalAngle, ctx.frameTimestampMs);
    final angle = _rollingMedian(euroAngle);

    _debugData['cervicalRaw'] = ctx.cervicalAngle.toStringAsFixed(1);
    _debugData['cervicalFilt'] = angle.toStringAsFixed(1);

    final danger =
        _dangerDebouncer.update(angle < CervicalSafetyConfig.GOOD_THRESHOLD);

    if (danger) {
      ctx.resultIssues.feedback['Neck'] =
          'Nhìn lên nhẹ thôi, đừng ngửa cổ ra sau';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'holding',
          'cervicalDanger',
          'Giữ cổ dài, nhìn lên nhẹ hoặc nhìn thẳng về trước.',
        );
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Neck cranked back', 'CervicalDanger');
    } else {
      ctx.resultIssues.feedback['Neck'] = 'Cổ thoải mái ✓';
    }
  }

  double _rollingMedian(double v) {
    _medianBuf.addLast(v);
    if (_medianBuf.length > CervicalSafetyConfig.MEDIAN_WINDOW) {
      _medianBuf.removeFirst();
    }
    final sorted = _medianBuf.toList()..sort();
    final n = sorted.length;
    return n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }

  void _logFault(String phase, String message, String type) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        affectsForm: false,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _dangerDebouncer.reset();
    _euro.reset();
    _medianBuf.clear();
    _instructionSet = false;
  }
}

class _AngleOneEuro {
  final double minCutoff;
  final double beta;
  final double dCutoff = 1.0;

  _AngleOneEuro({
    required this.minCutoff,
    required this.beta,
  });

  double? _xPrev;
  double? _dxPrev;
  int? _tPrevMs;

  double filter(double x, int tMs) {
    if (_tPrevMs == null) {
      _tPrevMs = tMs;
      _xPrev = x;
      _dxPrev = 0.0;
      return x;
    }
    final dt = (tMs - _tPrevMs!) / 1000.0;
    _tPrevMs = tMs;
    if (dt <= 0.0) return _xPrev!;

    final dx = (x - _xPrev!) / dt;
    final edx = _lowPass(dx, _dxPrev!, _alpha(dt, dCutoff));
    _dxPrev = edx;

    final cutoff = minCutoff + beta * edx.abs();
    final ex = _lowPass(x, _xPrev!, _alpha(dt, cutoff));
    _xPrev = ex;
    return ex;
  }

  double _alpha(double dt, double cutoff) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double _lowPass(double v, double prev, double a) => a * v + (1 - a) * prev;

  void reset() {
    _xPrev = null;
    _dxPrev = null;
    _tPrevMs = null;
  }
}
