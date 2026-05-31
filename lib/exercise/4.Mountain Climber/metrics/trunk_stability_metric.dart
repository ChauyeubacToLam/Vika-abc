import 'mountain_climber_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Giám sát độ ổn định thân trên (lưng thẳng, hông không nhấp nhô).
/// Metric này chạy ĐỘC LẬP mỗi frame — không phụ thuộc vào state machine hay
/// peak counter — vì lỗi trunk có thể xảy ra bất kỳ lúc nào.
class TrunkStabilityMetric extends ClimberMetricBase {
  @override
  String get name => 'TrunkStability';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Debouncer yêu cầu N frame liên tiếp trước khi log lỗi,
  // tránh noise 1–2 frame gây false positive.
  final Debouncer _dropDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _bounceDebouncer = Debouncer(requiredFrames: 4);

  /// Toạ độ Y của hông ở frame đầu tiên sau khi plank ổn định.
  /// Không reset giữa các rep vì hông phải GIỮ NGUYÊN suốt cả set.
  double? _baselineHipY;

  // Theo dõi % thời gian hông ổn định để tính Core Stability Score
  int _stableFrames = 0;
  int _totalFrames = 0;

  double get coreStabilityRatio =>
      _totalFrames == 0 ? 1.0 : _stableFrames / _totalFrames;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Set baseline hông từ frame đầu tiên khi plank
    _baselineHipY ??= ctx.hipY;

    _totalFrames++;

    // --- Kiểm tra 1: Võng lưng / Sụt hông ---
    final bool isHipDropping =
        ctx.trunkAngle < ClimberConfig.HIP_DROP_TRUNK_ANGLE;

    // --- Kiểm tra 2: Nhấp nhô hông ---
    final double hipVarianceNorm = (ctx.hipY - _baselineHipY!).abs() /
        (ctx.scaleFactor == 0 ? 1.0 : ctx.scaleFactor);
    final bool isBouncing = hipVarianceNorm > ClimberConfig.HIP_BOUNCE_NORM;

    // --- Cập nhật debug ---
    _debugData['TS_trunkAngle'] = ctx.trunkAngle.toStringAsFixed(1);
    _debugData['TS_hipVarianceNorm'] = hipVarianceNorm.toStringAsFixed(3);
    _debugData['TS_isDropping'] = isHipDropping;
    _debugData['TS_isBouncing'] = isBouncing;
    _debugData['TS_coreRatio'] = coreStabilityRatio.toStringAsFixed(2);

    final String phase = ctx.state.name.toUpperCase();

    // --- Log fault & feedback ---
    if (_dropDebouncer.update(isHipDropping)) {
      ctx.resultIssues.feedback['Core'] = 'Võng lưng! Siết bụng lại';
      _logFault(
        phase,
        'HipDrop',
        'Giữ thẳng lưng, siết chặt cơ bụng',
        ClimberVoicePriority.trunkStability,
      );
    } else if (_bounceDebouncer.update(isBouncing)) {
      ctx.resultIssues.feedback['Core'] = 'Hông nhấp nhô!';
      _logFault(
        phase,
        'HipBounce',
        'Giữ hông cố định, không nảy mông',
        ClimberVoicePriority.trunkStability,
      );
    } else {
      ctx.resultIssues.feedback['Core'] = 'Core ổn định';
      _stableFrames++;
    }
  }

  void _logFault(String phase, String type, String msg, int priority) {
    // Mỗi loại lỗi chỉ log 1 lần / rep để tránh spam
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: true,
        priority: priority,
        voiceMessage: msg,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _dropDebouncer.reset();
    _bounceDebouncer.reset();
    _stableFrames = 0;
    _totalFrames = 0;
    // _baselineHipY KHÔNG reset — hông phải giữ nguyên suốt set
  }

  /// Gọi khi kết thúc toàn bộ set (onSetComplete) để reset cả baseline
  void fullReset() {
    reset();
    _baselineHipY = null;
  }
}
