import 'leg_raise_metric_base.dart';
import '../../../utils/debouncer.dart';

class PelvicStabilityMetric extends LegRaiseMetricBase {
  @override
  String get name => 'PelvicStability';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  double? _baselineHipY; // Tọa độ hông chuẩn khi nằm sát sàn
  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(LegRaiseState from, LegRaiseState to, int timestampMs) {
    // Cập nhật điểm gốc khi chuẩn bị nâng lên (Lúc này lưng đang áp sát sàn nhất)
    if (from == LegRaiseState.lying && to == LegRaiseState.raising) {
       // Note: Reset baseline each rep is safer to account for body slight shifts
      _baselineHipY = null;
    }
  }

  @override
  void update(LegRaiseRepContext ctx) {
    _baselineHipY ??= ctx.hipY;

    // Chỉ check gắt nhất ở pha Lowering (Đặc biệt lúc chân sắp chạm đất)
    if (ctx.state == LegRaiseState.lowering) {
      // Trong ML Kit, Y hướng xuống đất. Nếu hông nhấc lên tức là Y giảm (baselineHipY - hipY > 0)
      double upwardShift = _baselineHipY! - ctx.hipY;
      double normalizedShift = upwardShift / ctx.scaleFactor;

      _debugData['hipUpwardShift'] = normalizedShift.toStringAsFixed(3);

      // Nếu hông bị giật lên > 5% chiều dài thân (khoảng 2-3cm là rất nghiêm trọng ở khung chậu)
      if (_faultDebouncer.update(normalizedShift > 0.05)) {
        if (!_faults.any((f) => f.type == 'PelvicInstability')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'PelvicInstability',
            message: 'Khung chậu bất ổn / Võng lưng',
            voiceMessage: 'Võng lưng! Đừng hạ chân quá sâu nếu bạn không giữ được lưng sát sàn!',
            affectsForm: true,
            priority: LegRaiseFaultPriority.pelvicInstability,
          ));
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _faultDebouncer.reset();
    _baselineHipY = null; // Clear baseline on reset/new set
  }
}