import 'surya_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P3/P10: Theo dõi góc gối khi gập người về trước.
///
/// Mặc dù lâm sàng cho phép gập gối nếu khoeo chân cứng,
/// AI vẫn nhắc nhẹ nếu gối cong quá nhiều.
class KneeBendMetric extends SuryaMetricBase {
  @override
  String get name => 'KneeBend';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 4);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SuryaContext ctx) {
    final isActive = ctx.state == SuryaState.p3_hastapaadasana ||
        ctx.state == SuryaState.p10_hastapaadasana_return;
    if (!isActive) return;

    final isKneeBent = ctx.kneeAngle < SuryaConfig.KNEE_STRAIGHT_MIN;

    _debugData['kneeAngle'] = ctx.kneeAngle.toStringAsFixed(1);
    _debugData['isKneeBent'] = isKneeBent;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isKneeBent)) {
      ctx.resultIssues.feedback['Knee'] =
          'Cố gắng giữ thẳng chân để kéo giãn cơ khoeo';
      _logFault(phase, 'KneeBent',
          'Cố gắng giữ thẳng chân để kéo giãn cơ khoeo');
    } else {
      ctx.resultIssues.feedback['Knee'] = 'Chân tốt';
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: false, // Nhắc nhẹ, không ảnh hưởng form
        priority: SuryaVoicePriority.kneeBend,
        voiceMessage: 'Giữ thẳng chân',
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _debouncer.reset();
  }
}
