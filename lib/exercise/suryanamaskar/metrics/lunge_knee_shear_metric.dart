import 'surya_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P4/P9: Lực cắt đầu gối chân trước trong tư thế Kỵ sĩ.
///
/// Nếu Knee X vượt quá xa FOOT_INDEX X → đầu gối bị đẩy quá trước,
/// gây áp lực lên dây chằng đầu gối.
class LungeKneeShearMetric extends SuryaMetricBase {
  @override
  String get name => 'LungeKneeShear';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 3);

  // Lưu góc gối ở P4 và P9 để so sánh đối xứng
  double? lungeKneeAngleP4;
  double? lungeKneeAngleP9;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SuryaContext ctx) {
    final isActive = ctx.state == SuryaState.p4_ashwa_sanchalanasana ||
        ctx.state == SuryaState.p9_ashwa_return;
    if (!isActive) return;

    // Khoảng cách normalized: knee vượt trước foot_index
    final sf = ctx.scaleFactor == 0 ? 1.0 : ctx.scaleFactor;
    final kneeOverFoot = (ctx.kneeX - ctx.footIndexX).abs() / sf;

    final isShearing = kneeOverFoot > SuryaConfig.KNEE_OVER_FOOT_TOLERANCE;

    // Ghi lại góc gối cho symmetry tracking
    if (ctx.state == SuryaState.p4_ashwa_sanchalanasana) {
      lungeKneeAngleP4 = ctx.kneeAngle;
    } else {
      lungeKneeAngleP9 = ctx.kneeAngle;
    }

    _debugData['kneeOverFootNorm'] = kneeOverFoot.toStringAsFixed(2);
    _debugData['kneeAngle'] = ctx.kneeAngle.toStringAsFixed(1);
    _debugData['isShearing'] = isShearing;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isShearing)) {
      ctx.resultIssues.feedback['Lunge'] =
          'Bước chân sau dài ra, giữ đầu gối thẳng góc với mắt cá!';
      _logFault(phase, 'KneeShear',
          'Bước chân sau dài ra, giữ đầu gối thẳng góc với mắt cá!');
    } else {
      // Kiểm tra góc gối có trong khoảng chuẩn không
      if (ctx.kneeAngle >= SuryaConfig.LUNGE_KNEE_ANGLE_RANGE[0] &&
          ctx.kneeAngle <= SuryaConfig.LUNGE_KNEE_ANGLE_RANGE[1]) {
        ctx.resultIssues.feedback['Lunge'] = 'Kỵ sĩ chuẩn';
      } else {
        ctx.resultIssues.feedback['Lunge'] = 'Điều chỉnh góc gối';
      }
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: true,
        priority: SuryaVoicePriority.lungeKneeShear,
        voiceMessage: 'Giữ đầu gối thẳng góc',
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _debouncer.reset();
    // Không reset lungeKneeAngleP4/P9 vì cần cho symmetry cuối rep
  }
}
