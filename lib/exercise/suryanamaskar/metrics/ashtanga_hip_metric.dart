import 'surya_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P6: Sập hông trong tư thế Cá sấu 8 điểm (Ashtanga Namaskara).
///
/// QUAN TRỌNG: Hông (Hip Y) bắt buộc phải cao hơn Vai (Shoulder Y)
/// và Đầu gối (Knee Y). Nếu hông sập bẹp → cờ đỏ.
///
/// Lưu ý: Trong hệ tọa độ camera, Y tăng từ trên xuống dưới,
/// nên "cao hơn" nghĩa là giá trị Y nhỏ hơn.
class AshtangaHipMetric extends SuryaMetricBase {
  @override
  String get name => 'AshtangaHip';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 2); // Nhạy hơn vì nghiêm trọng

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SuryaContext ctx) {
    if (ctx.state != SuryaState.p6_ashtanga_namaskara) return;

    // Hip Y phải nhỏ hơn (cao hơn) cả Shoulder Y và Knee Y
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
          '🔴 Nhô mông lên! Không để bụng chạm thảm!';
      _logFault('P6_ASHTANGA_NAMASKARA', 'HipCollapsed',
          'Nhô mông lên! Không để bụng chạm thảm!');
    } else {
      ctx.resultIssues.feedback['Hip'] = 'Hông đúng vị trí';
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
        voiceMessage: 'Nhô mông lên',
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
