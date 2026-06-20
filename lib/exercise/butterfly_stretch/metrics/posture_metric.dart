import 'butterfly_metric_base.dart';
import '../../../utils/debouncer.dart';

class PostureConfig {
  // Nếu vai nghiêng > 10% so với chiều dài lưng
  static const double TILT_THRESHOLD = 0.18;
  static const double COLLAPSE_THRESHOLD = 0.48;
}

class PostureMetric extends ButterflyMetricBase {
  @override
  String get name => 'Posture';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _tiltDebouncer = Debouncer(requiredFrames: 7);
  final Debouncer _collapseDebouncer = Debouncer(requiredFrames: 7);

  bool _tiltInstructionSet = false;
  bool _collapseInstructionSet = false;
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
    // Chuẩn hóa độ nghiêng vai
    double normalizedTilt = ctx.shoulderTilt /
        (ctx.shoulderToHipRatio == 0 ? 1 : ctx.shoulderToHipRatio);
    _debugData['shoulder_tilt_norm'] = normalizedTilt.toStringAsFixed(3);
    _debugData['torso_vertical_norm'] =
        ctx.torsoVerticalNorm.toStringAsFixed(3);

    final phase = ctx.currentState.toString().split('.').last.toUpperCase();
    final isCollapsed = _collapseDebouncer.update(
      ctx.torsoVerticalNorm < PostureConfig.COLLAPSE_THRESHOLD,
    );
    final isTilted =
        _tiltDebouncer.update(normalizedTilt > PostureConfig.TILT_THRESHOLD);

    if (isCollapsed) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Posture'] =
          'Giữ lưng thẳng, không gập người xuống!';

      if (!_collapseInstructionSet) {
        ctx.resultIssues.addInstruction(
            ctx.currentState.toString().split('.').last,
            'Posture',
            'Giữ ngực mở và lưng thẳng, đừng gập rạp người xuống khi ép gối.');
        _collapseInstructionSet = true;
      }
      _logFault(phase, 'PostureCollapse', 'Gập người/gù lưng khi giữ tư thế');
    } else if (isTilted) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Posture'] = 'Lệch vai!';

      if (!_tiltInstructionSet) {
        ctx.resultIssues.addInstruction(
            ctx.currentState.toString().split('.').last,
            'Posture',
            'Ngồi thẳng lưng, giữ hai vai ngang nhau!');
        _tiltInstructionSet = true;
      }
      _logFault(phase, 'Posture', 'Nghiêng/Lệch vai');
    } else {
      ctx.resultIssues.feedback['Posture'] = 'Lưng thẳng';
    }
  }

  void _logFault(String phase, String type, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
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
    _collapseDebouncer.reset();
    _tiltInstructionSet = false;
    _collapseInstructionSet = false;
    _isFaultingNow = false;
  }
}
