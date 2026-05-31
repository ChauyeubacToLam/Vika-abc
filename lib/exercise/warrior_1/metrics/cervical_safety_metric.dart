// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Warrior I Metric 2: Cervical Safety  (coaching-only, NOT form-critical)

   GROSS detector for the head being thrown sharply backward to look up
   at the hands. Desk workers (stiff thoracic spine) hinge at C5–C7 to
   look up, crushing the cervical facets. This catches the extreme case
   only — the ear landmark is far too jittery for subtle neck coaching.

   Landmarks : EAR (#7/8), SHOULDER (#11/12), HIP (#23/24) — getSideLandmark()
   Calc      : calculateAngle(ear, shoulder, hip). 180° = head in line.
   Type      : ANGLE (self-normalizing)
   When      : HOLD phase only.

   Filtering (ear is the noisiest landmark):
     NOTE: incoming landmarks are ALREADY One-Euro smoothed globally by
     PoseSmoother, so re-smoothing the 2D ear coords is redundant. Instead
     we filter the COMPUTED angle: a light 1D One-Euro pass, then a
     7-frame rolling median, before threshold evaluation. Same denoising
     goal as the spec, without double-filtering coordinates.
     >>> If you want the literal spec (One-Euro on ear coords), that has to
         move up into WarriorOne before the angle is computed — flag to Nam.

   Zones (Week 1-4 launch defaults):
     Good  : ≥ 140°
     Error : < 140° sustained   [affectsForm = FALSE — coaching only]
   140° is ~40° below neutral, so this fires only when the head is WAY back.
   ========================================================================= */

import 'dart:collection';
import 'dart:math' as math;

import 'warrior_one_metric_base.dart';
import '../warrior_one.dart';
import '../../../utils/debouncer.dart';

class CervicalSafetyConfig {
  /// At/above this the neck is fine.
  static const double GOOD_THRESHOLD = 140.0;

  /// Rolling median window over the computed angle.
  static const int MEDIAN_WINDOW = 7;

  /// 1D One-Euro tuning for the angle signal (degrees, ~30fps).
  static const double ONE_EURO_MIN_CUTOFF = 0.6;
  static const double ONE_EURO_BETA = 0.01;
}

class CervicalSafetyMetric extends WarriorOneMetricBase {
  @override
  String get name => 'CervicalSafety';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Heavy debounce — 20 frames (~667ms). Combined with the filtering below,
  /// this only fires on a sustained, real hyperextension.
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
  void update(HoldContext ctx) {
    if (ctx.holdState != WarriorOneState.hold) return;

    // 1) light 1D One-Euro on the angle, 2) 7-frame rolling median.
    final double euroAngle =
        _euro.filter(ctx.cervicalAngle, ctx.frameTimestamp);
    final double angle = _rollingMedian(euroAngle);

    _debugData['cervicalRaw'] = ctx.cervicalAngle.toStringAsFixed(1);
    _debugData['cervicalFilt'] = angle.toStringAsFixed(1);

    final phase = ctx.holdState.name.toUpperCase();
    final bool danger =
        _dangerDebouncer.update(angle < CervicalSafetyConfig.GOOD_THRESHOLD);

    if (danger) {
      ctx.resultIssues.feedback['cervical_danger'] =
          'Cẩn thận cổ nhé! Nhìn thẳng hoặc hơi lên thôi. Không ngửa đầu ra sau.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction('hold', 'cervical_danger',
            'Cẩn thận cổ nhé! Nhìn thẳng hoặc hơi lên thôi. Không ngửa đầu ra sau.');
        _instructionSet = true;
      }
      _logFault(phase, 'Head thrown back (cervical hyperextension)',
          voiceMessage: 'Đừng ngửa đầu ra sau');
    } else {
      ctx.resultIssues.feedback['cervical_danger'] = 'Cổ thoải mái tốt!';
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

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'cervical_danger')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'cervical_danger',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: false, // coaching only — does NOT fail the hold
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

/* -------------------------------------------------------------------------
   _AngleOneEuro — minimal 1D One-Euro filter for a single scalar (the
   ear-shoulder-hip angle). Self-contained so we don't touch lib/utils/.
   Mirrors the math in lib/utils/pose_smoother.dart.
   ------------------------------------------------------------------------- */
class _AngleOneEuro {
  final double minCutoff;
  final double beta;
  final double dCutoff = 1.0; // derivative cutoff, fixed

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
    final double dt = (tMs - _tPrevMs!) / 1000.0;
    _tPrevMs = tMs;
    if (dt <= 0.0) return _xPrev!;

    final double dx = (x - _xPrev!) / dt;
    final double edx = _lowPass(dx, _dxPrev!, _alpha(dt, dCutoff));
    _dxPrev = edx;

    final double cutoff = minCutoff + beta * edx.abs();
    final double ex = _lowPass(x, _xPrev!, _alpha(dt, cutoff));
    _xPrev = ex;
    return ex;
  }

  double _alpha(double dt, double cutoff) {
    final double tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double _lowPass(double v, double prev, double a) => a * v + (1 - a) * prev;

  void reset() {
    _xPrev = null;
    _dxPrev = null;
    _tPrevMs = null;
  }
}
