import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/* AI-generated please verify logic before use.
   One Euro Filter implementation for smoothing pose landmarks over time.
   Reference: https://cristal.univ-lille.fr/~casiez/1euro/
*/

class PoseSmoother {
  // CONFIGURATION: "Gold Standard" starting values
  final double minCutoff;
  final double beta;
  final double dCutoff = 1.0; // Standard frequency for derivative

  // Map to store a filter for every single landmark type
  // ignore: prefer_final_fields
  Map<PoseLandmarkType, _OneEuroFilter> _filters = {};
  int? _startTime;

  // Constructor allows you to tune these if needed
  PoseSmoother({
    this.minCutoff = 0.5, // Decrease to 0.1 if too jittery
    this.beta = 0.005, // Increase to 0.05 if too laggy
  });

  Map<PoseLandmarkType, PoseLandmark> smoothing(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // 1. Calculate time in seconds (t)
    int now = DateTime.now().millisecondsSinceEpoch;
    _startTime ??= now;
    double t = (now - _startTime!) / 1000.0;

    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks = {};

    landmarks.forEach((type, landmark) {
      // 2. Create a filter if we haven't seen this landmark before
      if (!_filters.containsKey(type)) {
        _filters[type] =
            _OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff);
      }

      // 3. Run the filter on [x, y]
      // Note: We intentionally do not filter Z or Likelihood here to save performance
      List<double> smoothedPos =
          _filters[type]!.filter(t, [landmark.x, landmark.y]);

      smoothedLandmarks[type] = PoseLandmark(
        type: type,
        x: smoothedPos[0],
        y: smoothedPos[1],
        z: landmark.z,
        likelihood: landmark.likelihood,
      );
    });

    return smoothedLandmarks;
  }
}

// =========================================================================
//  INTERNAL MATH CLASSES (One Euro Filter Logic)
// =========================================================================

class _OneEuroFilter {
  final double minCutoff;
  final double beta;
  final double dCutoff;

  _LowPassFilter? _xFilter;
  _LowPassFilter? _dxFilter;
  double? _prevTime;

  _OneEuroFilter({
    required this.minCutoff,
    required this.beta,
    required this.dCutoff,
  });

  List<double> filter(double t, List<double> x) {
    if (_prevTime == null) {
      _prevTime = t;
      _xFilter = _LowPassFilter(x);
      _dxFilter = _LowPassFilter(List.filled(x.length, 0.0));
      return x;
    }

    double dt = t - _prevTime!;
    _prevTime = t;

    if (dt <= 0.0) return _xFilter!.lastVal;

    // 1. Estimate Velocity (dx/dt)
    List<double> dx = [];
    for (int i = 0; i < x.length; i++) {
      dx.add((x[i] - _xFilter!.lastVal[i]) / dt);
    }

    List<double> edx = _dxFilter!.filterWithAlpha(dx, _alpha(dt, dCutoff));

    // 2. Use Velocity to Tune Cutoff
    double speed = 0.0;
    for (double v in edx) {
      speed += v * v;
    }
    speed = math.sqrt(speed);

    // The faster you move, the higher the cutoff (less smoothing)
    double cutoff = minCutoff + beta * speed;

    // 3. Filter the Position
    return _xFilter!.filterWithAlpha(x, _alpha(dt, cutoff));
  }

  double _alpha(double dt, double cutoff) {
    double tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }
}

class _LowPassFilter {
  List<double> lastVal;

  _LowPassFilter(this.lastVal);

  List<double> filterWithAlpha(List<double> val, double alpha) {
    List<double> result = [];
    for (int i = 0; i < val.length; i++) {
      double newVal = alpha * val[i] + (1.0 - alpha) * lastVal[i];
      result.add(newVal);
    }
    lastVal = result;
    return result;
  }
}
