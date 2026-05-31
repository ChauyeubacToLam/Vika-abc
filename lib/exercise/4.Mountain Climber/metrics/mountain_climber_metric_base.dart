// ignore_for_file: constant_identifier_names
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
  static const double ARM_STRAIGHT_THRESHOLD = 160.0;
  static const List<double> TRUNK_STRAIGHT_RANGE = [170.0, 180.0];

  // --- Trunk stability ---
  static const double HIP_DROP_TRUNK_ANGLE = 160.0; // Dưới mức này = võng lưng
  static const double HIP_BOUNCE_NORM = 0.12; // ~10 cm / scale

  // --- Peak detection ---
  /// Khi dist_chuẩn_hóa < ngưỡng này → coi là gối đã vào zone (co đủ sâu).
  /// Được hiệu chỉnh lại trong Setup: = restDist * ZONE_RATIO
  static const double ZONE_RATIO = 0.60;
  static const double ZONE_RATIO_DEFAULT = 0.50; // fallback nếu chưa calibrate

  /// Hysteresis: phải ra ngoài (threshold + margin) mới tính exit
  static const double ZONE_HYSTERESIS = 0.08;

  /// Cooldown tối thiểu giữa 2 rep liên tiếp (ms). 250 ms = tối đa 4 rep/s
  static const int REP_COOLDOWN_MS = 250;

  /// EMA smoothing factor cho knee distance (0 < α ≤ 1, nhỏ = mượt hơn)
  static const double EMA_ALPHA = 0.35;
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
  final double leftKneeX;
  final double rightKneeX;

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
    required this.leftKneeX,
    required this.rightKneeX,
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
  bool _isInZone = false;
  int _lastRepTimeMs = 0;
  double _minDistInZone = 1.0; // Gần nhất trong lần co hiện tại

  // --- Debug ---
  double get smoothedDist => _smoothedDist;
  double get minDistInZone => _minDistInZone;
  bool get isInZone => _isInZone;

  /// Gọi mỗi frame. Trả về số rep được tính trong frame này (0 hoặc 1).
  int update({
    required double kneeX,
    required double shoulderX,
    required double scaleFactor,
    required int nowMs,
  }) {
    // 1. Tính raw dist chuẩn hóa
    final double scale = scaleFactor == 0 ? 1.0 : scaleFactor;
    final double rawDist = (kneeX - shoulderX).abs() / scale;

    // 2. EMA smoothing — giảm nhiễu landmark
    _smoothedDist = ClimberConfig.EMA_ALPHA * rawDist +
        (1.0 - ClimberConfig.EMA_ALPHA) * _smoothedDist;

    // 3. Vào zone
    if (!_isInZone && _smoothedDist < zoneThreshold) {
      _isInZone = true;
      _minDistInZone = _smoothedDist;
    }

    // 4. Đang trong zone → track điểm gần nhất
    if (_isInZone) {
      if (_smoothedDist < _minDistInZone) _minDistInZone = _smoothedDist;
    }

    // 5. Ra khỏi zone (hysteresis) → đếm rep
    if (_isInZone &&
        _smoothedDist > zoneThreshold + ClimberConfig.ZONE_HYSTERESIS) {
      _isInZone = false;
      final int elapsed = nowMs - _lastRepTimeMs;
      if (elapsed >= ClimberConfig.REP_COOLDOWN_MS) {
        _lastRepTimeMs = nowMs;
        _minDistInZone = 1.0;
        return 1;
      }
      _minDistInZone = 1.0;
    }

    return 0;
  }

  /// Hiệu chỉnh ngưỡng zone dựa trên khoảng cách nghỉ thực tế của người dùng.
  void calibrate(double restDistNormalized) {
    zoneThreshold = restDistNormalized * ClimberConfig.ZONE_RATIO;
  }

  void reset() {
    _smoothedDist = 1.0;
    _isInZone = false;
    _minDistInZone = 1.0;
    // _lastRepTimeMs giữ nguyên để cooldown vẫn hoạt động xuyên rep
  }
}

// ---------------------------------------------------------------------------
// Metric Base
// ---------------------------------------------------------------------------

abstract class ClimberMetricBase {
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
