// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:collection';
import 'dart:math' as math;

import 'ashtanga_metric_base.dart';
import '../ashtanga_namaskara.dart';
import '../../../utils/debouncer.dart';

/// MET-2: Cervical Safety.
/// Coaching-only gross detector for chin jutting / neck cranking.
class CervicalSafetyMetric extends AshtangaMetricBase {
  @override
  String get name => 'CervicalSafety';

  static const double _goodMin = 130.0;
  static const double _errorMax = 115.0;
  static const int _medianWindow = 7;
  static const double _minEarConfidence = 0.5;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _dangerDebouncer =
      StickyDebouncer(requiredFrames: 8, currentState: false);
  final _OneEuro1D _euro = _OneEuro1D(minCutoff: 0.6, beta: 0.01);
  final Queue<double> _medianBuf = Queue<double>();

  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(AshtangaContext ctx) {
    if (ctx.state != AshtangaState.recognized &&
        ctx.state != AshtangaState.holding) return;
    if (ctx.ear == null || ctx.ear!.likelihood < _minEarConfidence) {
      _debugData['cervicalAngle'] = 'low_conf';
      return;
    }

    final angle = _rollingMedian(
      _euro.filter(ctx.cervicalAngle, ctx.frameTimestampMs),
    );

    _debugData['cervicalRaw'] = ctx.cervicalAngle.toStringAsFixed(1);
    _debugData['cervicalFilt'] = angle.toStringAsFixed(1);

    if (_dangerDebouncer.update(angle < _errorMax)) {
      ctx.resultIssues.feedback['Neck'] =
          'Đặt cằm xuống nhẹ, đừng đẩy đầu lên cao';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          ctx.state.name,
          'cervicalDanger',
          'Đặt cằm xuống nhẹ, giữ cổ thoải mái.',
        );
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Neck cranked upward', 'CervicalDanger');
    } else if (angle >= _goodMin) {
      ctx.resultIssues.feedback['Neck'] = 'Cổ thoải mái ✓';
    }
  }

  double _rollingMedian(double v) {
    _medianBuf.addLast(v);
    if (_medianBuf.length > _medianWindow) _medianBuf.removeFirst();
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

class _OneEuro1D {
  final double minCutoff;
  final double beta;
  final double dCutoff = 1.0;

  _OneEuro1D({required this.minCutoff, required this.beta});

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
