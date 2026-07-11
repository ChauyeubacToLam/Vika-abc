// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:collection';
import 'dart:math' as math;

import 'package:vika/exercise/exercise_base.dart';

import 'prayer_pose_metric_base.dart';
import '../prayer_pose.dart';
import '../../../utils/debouncer.dart';

/// Check 1: Upright Stack.
/// Coaching-only detector for forward-head posture in Prayer Pose.
class PostureStackMetric extends PrayerPoseMetricBase {
  @override
  String get name => 'PostureStack';

  static const double _goodMax = 0.55;
  static const double _coachingMin = 0.75;
  static const int _medianWindow = 7;
  static const double _minEarConfidence = 0.5;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _coachingDebouncer =
      StickyDebouncer(requiredFrames: 10);
  final _OneEuro1D _euro = _OneEuro1D(minCutoff: 0.6, beta: 0.01);
  final Queue<double> _medianBuf = Queue<double>();

  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(PrayerPoseContext ctx) {
    if (ctx.state != PrayerPoseState.holding) return;
    if (ctx.ear == null || ctx.shoulder == null) return;
    if (ctx.ear!.likelihood < _minEarConfidence || ctx.scaleFactor < 1.0) {
      _debugData['postureStack'] = 'low_conf';
      return;
    }

    final rawOffset =
        ((ctx.ear!.x - ctx.shoulder!.x) * _forwardSign(ctx.cameraFacing)) /
            ctx.scaleFactor;
    final filtered = _rollingMedian(
      _euro.filter(rawOffset, ctx.frameTimestampMs),
    );

    _debugData['postureStackRaw'] = rawOffset.toStringAsFixed(3);
    _debugData['postureStack'] = filtered.toStringAsFixed(3);

    if (_coachingDebouncer.update(filtered > _coachingMin)) {
      ctx.resultIssues.feedback['Posture'] =
          'Đưa đầu nhẹ về sau, mở ngực ra nhé';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Nhẹ nhàng đưa đầu về sau cho thẳng cổ, ngực mở ra nhé.
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Forward-head posture', 'PostureStack');
    } else if (filtered <= _goodMax) {
      ctx.resultIssues.feedback['Posture'] = 'Đứng thẳng đẹp lắm ✓';
    }
  }

  double _forwardSign(CameraFacing facing) {
    return facing == CameraFacing.right ? -1.0 : 1.0;
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
    _coachingDebouncer.reset();
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
