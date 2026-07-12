import 'dead_bug_metric_base.dart';
import '../../../utils/debouncer.dart';

class AntiExtensionMetric extends DeadBugMetricBase {
  @override
  String get name => 'AntiExtension';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _baselineHipY;
  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _debugData['hipLift'] is num
      ? (_debugData['hipLift'] as num).toDouble()
      : double.tryParse('${_debugData['hipLift'] ?? ''}');

  @override
  ThresholdBand? get threshold => const ThresholdBand(faultAbove: 0.05);

  @override
  void onStateTransition(DeadBugState from, DeadBugState to, int timestampMs) {
    if (from == DeadBugState.setup && to == DeadBugState.extending) {
      _baselineHipY = null; // Khởi tạo lại mỗi rep để tránh sai số tịnh tiến
    }
  }

  @override
  void update(DeadBugRepContext ctx) {
    _baselineHipY ??= ctx.hipY;

    if (ctx.state == DeadBugState.extending || ctx.state == DeadBugState.hold) {
      if (ctx.scaleFactor != null && ctx.scaleFactor! > 0) {
        // Trong toạ độ màn hình Y hướng xuống. Lưng nhấc khỏi sàn -> Y giảm -> (baseline - current) > 0.
        double hipLift = (_baselineHipY! - ctx.hipY) / ctx.scaleFactor!;
        _debugData['hipLift'] = hipLift;

        // Nhấc quá 5% chiều dài lưng
        if (_faultDebouncer.update(hipLift > 0.05)) {
          if (!_faults.any((f) => f.type == 'anti_extension')) {
            _faults.add(FaultRecord(
              phase: ctx.state.name,
              type: 'anti_extension',
              message: 'Lưng bị cong khỏi mặt sàn',
              voiceMessage:
                  'Lưng bị cong! Hãy gồng bụng ép chặt thắt lưng xuống sàn!',
              affectsForm: true,
              priority: DeadBugFaultPriority.antiExtension,
            ));
          }
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _faultDebouncer.reset();
    _baselineHipY = null;
  }
}
