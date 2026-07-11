import 'mountain_climber_metric_base.dart';

/// Đánh giá biên độ co gối (Knee Drive ROM).
/// Không cần state MAX_FLEXION nữa — KneePeakRepCounter đã xác định
/// thời điểm gối gần ngực nhất, metric chỉ cần nhận khoảng cách tối thiểu đó.
class KneeDriveRomMetric extends ClimberMetricBase {
  @override
  String get name => 'KneeDriveROM';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Track dist nhỏ nhất trong lần co hiện tại cho từng chân
  double? _minDistLeft;
  double? _minDistRight;

  // Thống kê theo rep
  int _goodRomCount = 0;
  int _shortRomCount = 0;

  int get goodRomCount => _goodRomCount;
  int get shortRomCount => _shortRomCount;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    final double distLeft = ctx.leftKneeDistNorm;
    final double distRight = ctx.rightKneeDistNorm;

    // Cập nhật min cho từng chân
    if (_minDistLeft == null || distLeft < _minDistLeft!) {
      _minDistLeft = distLeft;
    }
    if (_minDistRight == null || distRight < _minDistRight!) {
      _minDistRight = distRight;
    }

    _debugData['ROM_distLeftNorm'] = distLeft.toStringAsFixed(2);
    _debugData['ROM_distRightNorm'] = distRight.toStringAsFixed(2);
    _debugData['ROM_leftKneeAngle'] = ctx.leftKneeAngle.toStringAsFixed(1);
    _debugData['ROM_rightKneeAngle'] = ctx.rightKneeAngle.toStringAsFixed(1);
    _debugData['ROM_minLeft'] = _minDistLeft?.toStringAsFixed(2) ?? '-';
    _debugData['ROM_minRight'] = _minDistRight?.toStringAsFixed(2) ?? '-';
    _debugData['ROM_goodCount'] = _goodRomCount;
    _debugData['ROM_shortCount'] = _shortRomCount;
  }

  /// Gọi ngay khi KneePeakRepCounter xác nhận +1 rep cho 1 bên chân.
  /// [peakDist] = minDistInZone được lấy từ counter tại thời điểm đó.
  /// [zoneThreshold] = ngưỡng đã calibrate của counter, dùng để tham chiếu.
  void evaluateRepEnd(
    RepContext ctx,
    KneeSide side,
    double peakDist,
    double zoneThreshold,
  ) {
    final qualityThreshold =
        zoneThreshold * ClimberConfig.GOOD_ROM_RATIO_OF_COUNT_ZONE;
    final bool isShort = peakDist > qualityThreshold;

    if (isShort) {
      _shortRomCount++;
      _faults.add(FaultRecord(
        phase: 'MAX_FLEXION',
        type: 'ShortROM_${side.name}',
        message: 'Co gối ${side == KneeSide.left ? "trái" : "phải"} quá ngắn',
        affectsForm: true,
        priority: ClimberVoicePriority.kneeRom,
        voiceMessage: 'Co gối sâu hơn về phía ngực',
      ));
      ctx.resultIssues.feedback['ROM'] =
          'Co gối ${side == KneeSide.left ? "trái" : "phải"} sâu hơn!';
      // Legacy UI instruction copy: Co gối sâu hơn ở nhịp sau
    } else {
      _goodRomCount++;
      ctx.resultIssues.feedback['ROM'] = 'Biên độ tốt';
    }

    _debugData['ROM_lastPeak_${side.name}'] = peakDist.toStringAsFixed(2);
    _debugData['ROM_qualityThreshold_${side.name}'] =
        qualityThreshold.toStringAsFixed(2);

    // Reset min dist cho chân vừa hoàn thành
    if (side == KneeSide.left) _minDistLeft = null;
    if (side == KneeSide.right) _minDistRight = null;
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minDistLeft = null;
    _minDistRight = null;
  }

  /// Full reset khi kết thúc set
  void fullReset() {
    reset();
    _goodRomCount = 0;
    _shortRomCount = 0;
  }
}
