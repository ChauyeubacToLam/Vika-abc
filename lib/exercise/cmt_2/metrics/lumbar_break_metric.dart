import 'cmt_2_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P2/P11: Lá»—i báº» gáº­p tháº¯t lÆ°ng khi vÆ°Æ¡n tay ngáº£ sau.
///
/// Kiá»ƒm tra: HÃ´ng (Hip) PHáº¢I Ä‘áº©y vá» trÆ°á»›c khi Vai ngáº£ ra sau.
/// Náº¿u HÃ´ng khÃ´ng dá»‹ch chuyá»ƒn mÃ  Vai ráº¡p xuá»‘ng â†’ Báº» gÃ£y tháº¯t lÆ°ng.
class LumbarBreakMetric extends Cmt2MetricBase {
  @override
  String get name => 'LumbarBreak';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 3);

  double? _hipXAtEntry; // Vá»‹ trÃ­ Hip X khi vÃ o P2/P11

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(Cmt2State from, Cmt2State to, int timestampMs) {
    if (to == Cmt2State.p2_hasta_uttanasana ||
        to == Cmt2State.p11_hasta_uttanasana_return) {
      _hipXAtEntry = null; // Sáº½ set á»Ÿ frame Ä‘áº§u tiÃªn
    }
  }

  @override
  void update(Cmt2Context ctx) {
    final isActive = ctx.state == Cmt2State.p2_hasta_uttanasana ||
        ctx.state == Cmt2State.p11_hasta_uttanasana_return;
    if (!isActive) return;

    _hipXAtEntry ??= ctx.hipX;

    final hipForwardDelta = (ctx.hipX - _hipXAtEntry!).abs();
    final shoulderBehindHip = ctx.shoulderX < ctx.hipX; // Vai ngáº£ ra sau

    _debugData['hipForwardDelta'] = hipForwardDelta.toStringAsFixed(1);
    _debugData['shoulderBehindHip'] = shoulderBehindHip;

    // Náº¿u vai ngáº£ ráº¡p ra sau MÃ€ hÃ´ng khÃ´ng Ä‘áº©y trÆ°á»›c â†’ lá»—i
    final isLumbarBreak = shoulderBehindHip &&
        hipForwardDelta < Cmt2Config.HIP_FORWARD_PUSH_THRESHOLD;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isLumbarBreak)) {
      ctx.resultIssues.feedback['Spine'] =
          'Äáº©y hÃ´ng vá» trÆ°á»›c, khÃ´ng báº» gÃ£y tháº¯t lÆ°ng!';
      _logFault(phase, 'LumbarBreak',
          'Äáº©y hÃ´ng vá» trÆ°á»›c, khÃ´ng báº» gÃ£y tháº¯t lÆ°ng!');
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Cá»™t sá»‘ng á»•n';
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
        voiceMessage: 'Äáº©y hÃ´ng vá» trÆ°á»›c',
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

