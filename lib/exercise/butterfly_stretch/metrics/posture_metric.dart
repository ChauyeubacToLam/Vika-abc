import 'butterfly_metric_base.dart';
import '../../../utils/debouncer.dart';

class PostureConfig {
  // Nếu vai nghiêng > 10% so với chiều dài lưng
  static const double TILT_THRESHOLD = 0.10; 
}

class PostureMetric extends ButterflyMetricBase {
  @override
  String get name => 'Posture';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _tiltDebouncer = Debouncer(requiredFrames: 5);

  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(StretchContext ctx) {
    // Chuẩn hóa độ nghiêng vai
    double normalizedTilt = ctx.shoulderTilt / (ctx.shoulderToHipRatio == 0 ? 1 : ctx.shoulderToHipRatio);
    _debugData['shoulder_tilt_norm'] = normalizedTilt.toStringAsFixed(3);

    final phase = ctx.currentState.toString().split('.').last.toUpperCase();

    if (_tiltDebouncer.update(normalizedTilt > PostureConfig.TILT_THRESHOLD)) { 
      ctx.resultIssues.feedback['Posture'] = 'Lệch vai!';
      
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          ctx.currentState.toString().split('.').last,
          'Posture',
          'Ngồi thẳng lưng, giữ hai vai ngang nhau!'
        );
        _instructionSet = true;
      }
      _logFault(phase, 'Nghiêng/Lệch vai');
    } else {
      ctx.resultIssues.feedback['Posture'] = 'Lưng thẳng';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Posture')) {
      _faults.add(FaultRecord(
        phase: phase, 
        type: 'Posture', 
        message: message,
        affectsForm: true, // Lỗi này nghiêm trọng, đánh dấu hỏng form
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _tiltDebouncer.reset();
    _instructionSet = false;
  }
}