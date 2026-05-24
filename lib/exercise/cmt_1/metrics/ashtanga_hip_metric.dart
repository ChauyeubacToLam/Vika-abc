import 'cmt_1_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P6: Sáº­p hÃ´ng trong tÆ° tháº¿ CÃ¡ sáº¥u 8 Ä‘iá»ƒm (Ashtanga Namaskara).
///
/// QUAN TRá»ŒNG: HÃ´ng (Hip Y) báº¯t buá»™c pháº£i cao hÆ¡n Vai (Shoulder Y)
/// vÃ  Äáº§u gá»‘i (Knee Y). Náº¿u hÃ´ng sáº­p báº¹p â†’ cá» Ä‘á».
///
/// LÆ°u Ã½: Trong há»‡ tá»a Ä‘á»™ camera, Y tÄƒng tá»« trÃªn xuá»‘ng dÆ°á»›i,
/// nÃªn "cao hÆ¡n" nghÄ©a lÃ  giÃ¡ trá»‹ Y nhá» hÆ¡n.
class AshtangaHipMetric extends Cmt1MetricBase {
  @override
  String get name => 'AshtangaHip';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 2); // Nháº¡y hÆ¡n vÃ¬ nghiÃªm trá»ng

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(Cmt1Context ctx) {
    if (ctx.state != Cmt1State.p6_ashtanga_namaskara) return;

    // Hip Y pháº£i nhá» hÆ¡n (cao hÆ¡n) cáº£ Shoulder Y vÃ  Knee Y
    final isHipHigherThanShoulder = ctx.hipY < ctx.shoulderY;
    final isHipHigherThanKnee = ctx.hipY < ctx.kneeY;
    final isHipCollapsed = !isHipHigherThanShoulder || !isHipHigherThanKnee;

    _debugData['hipY'] = ctx.hipY.toStringAsFixed(1);
    _debugData['shoulderY'] = ctx.shoulderY.toStringAsFixed(1);
    _debugData['kneeY'] = ctx.kneeY.toStringAsFixed(1);
    _debugData['isHipHigherThanShoulder'] = isHipHigherThanShoulder;
    _debugData['isHipHigherThanKnee'] = isHipHigherThanKnee;

    if (_debouncer.update(isHipCollapsed)) {
      ctx.resultIssues.feedback['Hip'] =
          'ðŸ”´ NhÃ´ mÃ´ng lÃªn! KhÃ´ng Ä‘á»ƒ bá»¥ng cháº¡m tháº£m!';
      _logFault('P6_ASHTANGA_NAMASKARA', 'HipCollapsed',
          'NhÃ´ mÃ´ng lÃªn! KhÃ´ng Ä‘á»ƒ bá»¥ng cháº¡m tháº£m!');
    } else {
      ctx.resultIssues.feedback['Hip'] = 'HÃ´ng Ä‘Ãºng vá»‹ trÃ­';
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: true,
        priority: SuryaVoicePriority.ashtangaHip,
        voiceMessage: 'NhÃ´ mÃ´ng lÃªn',
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

