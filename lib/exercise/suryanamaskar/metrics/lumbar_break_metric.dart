import 'surya_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P2/P11: Lỗi bẻ gập thắt lưng khi vươn tay ngả sau.
///
/// Kiểm tra: Hông (Hip) PHẢI đẩy về trước khi Vai ngả ra sau.
/// Nếu Hông không dịch chuyển mà Vai rạp xuống → Bẻ gãy thắt lưng.
class LumbarBreakMetric extends SuryaMetricBase {
  @override
  String get name => 'LumbarBreak';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 3);

  double? _hipXAtEntry; // Vị trí Hip X khi vào P2/P11

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(SuryaState from, SuryaState to, int timestampMs) {
    if (to == SuryaState.p2_hasta_uttanasana ||
        to == SuryaState.p11_hasta_uttanasana_return) {
      _hipXAtEntry = null; // Sẽ set ở frame đầu tiên
    }
  }

  @override
  void update(SuryaContext ctx) {
    final isActive = ctx.state == SuryaState.p2_hasta_uttanasana ||
        ctx.state == SuryaState.p11_hasta_uttanasana_return;
    if (!isActive) return;

    _hipXAtEntry ??= ctx.hipX;

    final hipForwardDelta = (ctx.hipX - _hipXAtEntry!).abs();
    final shoulderBehindHip = ctx.shoulderX < ctx.hipX; // Vai ngả ra sau

    _debugData['hipForwardDelta'] = hipForwardDelta.toStringAsFixed(1);
    _debugData['shoulderBehindHip'] = shoulderBehindHip;

    // Nếu vai ngả rạp ra sau MÀ hông không đẩy trước → lỗi
    final isLumbarBreak = shoulderBehindHip &&
        hipForwardDelta < SuryaConfig.HIP_FORWARD_PUSH_THRESHOLD;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isLumbarBreak)) {
      ctx.resultIssues.feedback['Spine'] =
          'Đẩy hông về trước, không bẻ gãy thắt lưng!';
      _logFault(phase, 'LumbarBreak',
          'Đẩy hông về trước, không bẻ gãy thắt lưng!');
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Cột sống ổn';
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: true,
        priority: SuryaVoicePriority.lumbarBreak,
        voiceMessage: 'Đẩy hông về trước',
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _debouncer.reset();
    _hipXAtEntry = null;
  }
}
