import 'mountain_climber_metric_base.dart';
import '../../../utils/debouncer.dart';

class TrunkStabilityMetric extends ClimberMetricBase {
  @override
  String get name => 'TrunkStability';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  final Debouncer _dropDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _bounceDebouncer = Debouncer(requiredFrames: 4);

  double? _baselineHipY; // Tọa độ hông lúc bắt đầu Plank

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(ClimberState from, ClimberState to, int timestampMs) {
    if (to == ClimberState.high_plank_base && _baselineHipY == null) {
      // Sẽ được set bằng ctx.hipY trong hàm update đầu tiên của rep
    }
  }

  @override
  void update(RepContext ctx) {
    _baselineHipY ??= ctx.hipY;
    
    // 1. Lỗi võng lưng (Angle)
    bool isHipDropping = ctx.trunkAngle < ClimberConfig.HIP_DROP_THRESHOLD;
    
    // 2. Lỗi nhấp nhô (Y Variance)
    double hipVariance = (ctx.hipY - _baselineHipY!).abs() / (ctx.scaleFactor == 0 ? 1 : ctx.scaleFactor);
    bool isBouncing = hipVariance > ClimberConfig.HIP_BOUNCE_TOLERANCE_NORMALIZED;

    _debugData['trunkAngle'] = ctx.trunkAngle.toStringAsFixed(1);
    _debugData['hipVarianceNorm'] = hipVariance.toStringAsFixed(2);

    final phase = ctx.state.name.toUpperCase();

    if (_dropDebouncer.update(isHipDropping)) {
      ctx.resultIssues.feedback['Core'] = 'Võng lưng! Siết bụng lại';
      _logFault(phase, 'Sụt hông / Võng lưng', 'Giữ thẳng lưng, siết chặt cơ bụng', ClimberVoicePriority.trunkStability);
    } else if (_bounceDebouncer.update(isBouncing)) {
      ctx.resultIssues.feedback['Core'] = 'Hông nhấp nhô!';
      _logFault(phase, 'Nhấp nhô hông / Bật mông', 'Giữ hông cố định, không nảy mông', ClimberVoicePriority.trunkStability);
    } else {
      ctx.resultIssues.feedback['Core'] = 'Core ổn định';
    }
  }

  void _logFault(String phase, String type, String msg, int priority) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase, type: type, message: msg, affectsForm: true, priority: priority, voiceMessage: msg
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _dropDebouncer.reset();
    _bounceDebouncer.reset();
    // Không reset baselineHipY giữa các rep vì Plank phải giữ nguyên
  }
}