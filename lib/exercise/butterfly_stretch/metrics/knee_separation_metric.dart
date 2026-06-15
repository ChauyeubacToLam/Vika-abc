import 'butterfly_metric_base.dart';
import '../../../utils/debouncer.dart';

class KneeSeparationConfig {
  // Ngưỡng chênh lệch Y giữa 2 gối (tính theo tỷ lệ % so với chiều dài lưng)
  // Nếu lưng dài 100px, gối lệch nhau > 15px sẽ báo lỗi.
  static const double ASYMMETRY_THRESHOLD = 0.15;
}

class KneeSeparationMetric extends ButterflyMetricBase {
  @override
  String get name => 'KneeSeparation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Dùng debouncer 5 frames để tránh nhiễu do rung camera hoặc cử động nhỏ
  final Debouncer _asymmetryDebouncer = Debouncer(requiredFrames: 5);

  double maxSeparation = 0.0;
  bool _instructionSet = false;
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(StretchContext ctx) {
    _isFaultingNow = false;
    // 1. Cập nhật biên độ lớn nhất
    if (ctx.kneeSeparation > maxSeparation) {
      maxSeparation = ctx.kneeSeparation;
    }
    _debugData['max_sep'] = maxSeparation.toStringAsFixed(1);

    // 2. Kiểm tra lệch gối (Asymmetry) dựa trên trục Y
    double yDiff = (ctx.leftKneeY - ctx.rightKneeY).abs();

    // Chuẩn hóa độ lệch theo tỷ lệ lưng để bỏ qua yếu tố xa/gần camera
    double normalizedDiff =
        yDiff / (ctx.shoulderToHipRatio == 0 ? 1 : ctx.shoulderToHipRatio);
    _debugData['knee_y_diff_norm'] = normalizedDiff.toStringAsFixed(3);

    // 3. Đánh giá và Feedback
    final phase = ctx.currentState.toString().split('.').last.toUpperCase();

    if (_asymmetryDebouncer
        .update(normalizedDiff > KneeSeparationConfig.ASYMMETRY_THRESHOLD)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Knee'] = 'Lệch gối!';

      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            ctx.currentState.toString().split('.').last,
            'Knee',
            'Ép đều hai gối, đừng để một bên cao một bên thấp!');
        _instructionSet = true;
      }
      _logFault(phase, 'Hai gối không đều (Asymmetry)');
    } else {
      ctx.resultIssues.feedback['Knee'] = 'Gối cân bằng';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Knee')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Knee',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    maxSeparation = 0.0;
    _faults.clear();
    _debugData.clear();
    _asymmetryDebouncer.reset();
    _instructionSet = false;
    _isFaultingNow = false;
  }
}
