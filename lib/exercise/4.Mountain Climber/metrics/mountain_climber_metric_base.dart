// ignore_for_file: constant_identifier_names, annotate_overrides
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

// ---------------------------------------------------------------------------
// Enums & Config
// ---------------------------------------------------------------------------

/// Chỉ dùng để hiển thị label UI và cho TrunkMetric biết phase.
/// KHÔNG dùng để đếm rep nữa — việc đó thuộc về KneePeakRepCounter.
enum ClimberState {
  high_plank_base,
  knee_driving_in,
  max_flexion,
  knee_driving_out
}

enum KneeSide { left, right }

class ClimberConfig {
  // --- Rep / Thời gian ---
  static const int MAX_REP = 30; // 15 mỗi chân
  static const int MAX_DURATION_MS = 90000; // 90 s

  // --- Setup gate ---
  static const double ARM_STRAIGHT_THRESHOLD = 150.0;
  static const List<double> TRUNK_STRAIGHT_RANGE = [160.0, 180.0];

  // --- Trunk stability ---
  static const double HIP_DROP_TRUNK_ANGLE = 150.0; // Dưới mức này = võng lưng
  static const double HIP_BOUNCE_NORM = 0.18; // ~10 cm / scale

  // --- Peak detection ---
  /// Khi dist_chuẩn_hóa < ngưỡng này → coi là gối đã vào zone (co đủ sâu).
  /// Được hiệu chỉnh lại trong Setup: = restDist * ZONE_RATIO
  static const double ZONE_RATIO = 0.76;
  static const double MIN_ZONE_DELTA = 0.18;
  static const double MIN_ZONE_THRESHOLD = 0.35;
  static const double ZONE_RATIO_DEFAULT = 1.25; // fallback nếu chưa calibrate

  /// Hysteresis: phải ra ngoài (threshold + margin) mới tính exit
  static const double ZONE_HYSTERESIS = 0.20; // Increased from 0.12 to prevent bouncing

  /// Cooldown tối thiểu giữa 2 rep liên tiếp (ms). 250 ms = tối đa 4 rep/s
  static const int REP_COOLDOWN_MS = 600; // Increased from 350
  static const int GLOBAL_REP_COOLDOWN_MS = 400; // Increased from 280
  static const int SAME_SIDE_REP_COOLDOWN_MS = 1200; // Increased from 700

  /// EMA smoothing factor cho knee distance (0 < α ≤ 1, nhỏ = mượt hơn)
  static const double EMA_ALPHA = 0.45;
  static const double KNEE_FLEXION_ENTER_ANGLE = 138.0;
  static const double KNEE_EXTENSION_EXIT_ANGLE = 150.0;
  static const double GOOD_ROM_RATIO_OF_COUNT_ZONE = 0.72;
  static const double MIN_COUNT_PEAK_RATIO = 0.92;
  static const int MIN_ZONE_FRAMES = 1;
  static const int DOUBLE_KNEE_REQUIRED_FRAMES = 4;
}

class ClimberVoicePriority {
  static const int trunkStability = 0;
  static const int kneeRom = 1;
  static const int pace = 2;
}

// ---------------------------------------------------------------------------
// Rep Context — truyền dữ liệu frame tới các metric
// ---------------------------------------------------------------------------

class RepContext {
  final ClimberState state;
  final int frameTimestamp;
  final double scaleFactor; // Khoảng cách Vai–Hông (pixel), dùng chuẩn hóa

  // Angles
  final double armAngle; // Vai–Khuỷu–Cổ tay
  final double trunkAngle; // Vai–Hông–Gót (chân trụ)

  // Coordinates
  final double hipY;
  final double shoulderX;
  final double hipX;

  // Cả 2 đầu gối để track độc lập
  final double leftKneeDistNorm;
  final double rightKneeDistNorm;
  final double leftKneeAngle;
  final double rightKneeAngle;

  final ResultIssues resultIssues;

  const RepContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.armAngle,
    required this.trunkAngle,
    required this.hipY,
    required this.shoulderX,
    required this.hipX,
    required this.leftKneeDistNorm,
    required this.rightKneeDistNorm,
    required this.leftKneeAngle,
    required this.rightKneeAngle,
    required this.resultIssues,
  });
}

// ---------------------------------------------------------------------------
// KneePeakRepCounter
// Đếm rep bằng zone-enter / zone-exit thay vì state machine 4 bước.
// Bền vững với frame drop và chuyển động nhanh.
// ---------------------------------------------------------------------------

class KneePeakRepCounter {
  KneePeakRepCounter({required this.side});

  final KneeSide side;

  /// Ngưỡng zone, được set sau calibration. Mặc định = ZONE_RATIO_DEFAULT.
  double zoneThreshold = ClimberConfig.ZONE_RATIO_DEFAULT;

  // --- Internal state ---
  double _smoothedDist = 1.0; // EMA-filtered distance
  double _rawDist = 1.0;
  double _restDist = 1.0;
  double _kneeAngle = 180.0;
  bool _isInZone = false;
  bool _hasCountableTuckInZone = false;
  int _zoneFrames = 0;
  int _lastRepTimeMs = 0;
  double _minDistInZone = 1.0; // Gần nhất trong lần co hiện tại
  double _minAngleInZone = 180.0;
  double? _lastCompletedPeakDist;
  double? _lastCompletedPeakAngle;

  // --- Debug ---
  double get smoothedDist => _smoothedDist;
  double get rawDist => _rawDist;
  double get kneeAngle => _kneeAngle;
  double get minDistInZone => _minDistInZone;
  double get minAngleInZone => _minAngleInZone;
  double? get lastCompletedPeakDist => _lastCompletedPeakDist;
  double? get lastCompletedPeakAngle => _lastCompletedPeakAngle;
  bool get isInZone => _isInZone;
  bool get isDeepTuck =>
      _isInZone &&
      (_rawDist <= zoneThreshold * ClimberConfig.GOOD_ROM_RATIO_OF_COUNT_ZONE ||
          _kneeAngle <= ClimberConfig.KNEE_FLEXION_ENTER_ANGLE - 18.0);

  /// Gọi mỗi frame. Trả về số rep được tính trong frame này (0 hoặc 1).
  int update({
    required double kneeShoulderDistNorm,
    required double kneeAngle,
    required int nowMs,
  }) {
    _rawDist = kneeShoulderDistNorm.isFinite ? kneeShoulderDistNorm : _rawDist;
    _kneeAngle = kneeAngle.isFinite ? kneeAngle : _kneeAngle;

    // 1. EMA smoothing: quick enough for fast reps, still dampens jitter.
    _smoothedDist = ClimberConfig.EMA_ALPHA * _rawDist +
        (1.0 - ClimberConfig.EMA_ALPHA) * _smoothedDist;

    final bool enterZone = _rawDist <= zoneThreshold ||
        _smoothedDist <= zoneThreshold ||
        _kneeAngle <= ClimberConfig.KNEE_FLEXION_ENTER_ANGLE;
    final bool exitZone =
        (_rawDist >= zoneThreshold + ClimberConfig.ZONE_HYSTERESIS &&
                _smoothedDist >= zoneThreshold) ||
            (_kneeAngle >= ClimberConfig.KNEE_EXTENSION_EXIT_ANGLE &&
                _rawDist >= zoneThreshold);

    // 2. Vào zone
    if (!_isInZone && enterZone) {
      _isInZone = true;
      _minDistInZone = _smoothedDist;
      _minAngleInZone = _kneeAngle;
      _hasCountableTuckInZone = false;
      _zoneFrames = 0;
    }

    // 3. Đang trong zone → track điểm gần nhất
    if (_isInZone) {
      _zoneFrames++;
      if (_smoothedDist < _minDistInZone) _minDistInZone = _smoothedDist;
      if (_rawDist < _minDistInZone) _minDistInZone = _rawDist;
      if (_kneeAngle < _minAngleInZone) _minAngleInZone = _kneeAngle;

      final countableByDistance =
          _minDistInZone <= zoneThreshold * ClimberConfig.MIN_COUNT_PEAK_RATIO;
      final countableByAngle =
          _minAngleInZone <= ClimberConfig.KNEE_FLEXION_ENTER_ANGLE;
      if (_zoneFrames >= ClimberConfig.MIN_ZONE_FRAMES &&
          (countableByDistance || countableByAngle)) {
        _hasCountableTuckInZone = true;
      }
    }

    // 4. Ra khỏi zone (hysteresis) → đếm rep
    if (_isInZone && exitZone) {
      _isInZone = false;
      final int elapsed = nowMs - _lastRepTimeMs;
      if (_hasCountableTuckInZone &&
          (_lastRepTimeMs == 0 || elapsed >= ClimberConfig.REP_COOLDOWN_MS)) {
        _lastRepTimeMs = nowMs;
        _lastCompletedPeakDist = _minDistInZone;
        _lastCompletedPeakAngle = _minAngleInZone;
        _minDistInZone = 1.0;
        _minAngleInZone = 180.0;
        _hasCountableTuckInZone = false;
        _zoneFrames = 0;
        return 1;
      }
      _minDistInZone = 1.0;
      _minAngleInZone = 180.0;
      _hasCountableTuckInZone = false;
      _zoneFrames = 0;
    }

    return 0;
  }

  /// Hiệu chỉnh ngưỡng zone dựa trên khoảng cách nghỉ thực tế của người dùng.
  void calibrate(double restDistNormalized) {
    if (!restDistNormalized.isFinite || restDistNormalized <= 0) return;
    _restDist = restDistNormalized;
    final ratioThreshold = restDistNormalized * ClimberConfig.ZONE_RATIO;
    final deltaThreshold = restDistNormalized - ClimberConfig.MIN_ZONE_DELTA;
    var nextThreshold =
        ratioThreshold < deltaThreshold ? ratioThreshold : deltaThreshold;
    if (nextThreshold < ClimberConfig.MIN_ZONE_THRESHOLD) {
      nextThreshold = ClimberConfig.MIN_ZONE_THRESHOLD;
    }
    if (nextThreshold >= restDistNormalized) {
      nextThreshold = restDistNormalized * 0.8;
    }
    zoneThreshold = nextThreshold;
    _smoothedDist = restDistNormalized;
    _rawDist = restDistNormalized;
  }

  void reset() {
    _smoothedDist = _restDist;
    _rawDist = _restDist;
    _kneeAngle = 180.0;
    _isInZone = false;
    _hasCountableTuckInZone = false;
    _zoneFrames = 0;
    _minDistInZone = 1.0;
    _minAngleInZone = 180.0;
    _lastCompletedPeakDist = null;
    _lastCompletedPeakAngle = null;
    // _lastRepTimeMs giữ nguyên để cooldown vẫn hoạt động xuyên rep
  }
}

// ---------------------------------------------------------------------------
// Metric Base
// ---------------------------------------------------------------------------

abstract class ClimberMetricBase with FaultMetricDebugSource {
  String get name;
  int faultsCount = 0;

  void update(RepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(ClimberState from, ClimberState to, int timestampMs) {}
}
