import 'lying_leg_raise_metric_base.dart';
import '../../../utils/debouncer.dart';

class LumbarArchingMetric extends LyingLegRaiseMetricBase {
  @override
  String get name => 'LumbarArching';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _archDebouncer = Debouncer(requiredFrames: 4);

  double? _baselineHipY;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state == LyingLegRaiseState.lying) {
      _baselineHipY = ctx.hipY; // Học vị trí hông phẳng sát sàn
      ctx.resultIssues.feedback['Lumbar'] = 'Lưng ép sàn';
      return;
    }

    if (_baselineHipY == null) return;

    // Khi võng lưng, hông thường bị nảy bổng lên so với vai (Y giảm)
    double hipLiftNorm = (_baselineHipY! - ctx.hipY) / (ctx.scaleFactor == 0 ? 1 : ctx.scaleFactor);
    _debugData['hipLiftNorm'] = hipLiftNorm.toStringAsFixed(3);

    // Chỉ đo lỗi này ở pha hạ (Lowering) vì đây là lúc kháng lực mạnh nhất, dễ võng lưng nhất
    if (ctx.state == LyingLegRaiseState.lowering) {
      bool isArching = hipLiftNorm > LegRaiseConfig.LUMBAR_ARCH_TOLERANCE;

      if (_archDebouncer.update(isArching)) {
        ctx.resultIssues.feedback['Lumbar'] = 'Võng lưng! Ép lưng xuống!';
        if (!_faults.any((f) => f.type == 'Arching')) {
          _faults.add(FaultRecord(
            phase: 'LOWERING', type: 'Arching', message: 'Lưng võng khỏi sàn',
            affectsForm: true, priority: LegRaiseVoicePriority.lumbarArch, 
            voiceMessage: 'Lưng bạn đang võng lên! Ép chặt thắt lưng xuống sàn hoặc đừng hạ chân quá sâu!'
          ));
        }
      }
    } else {
      ctx.resultIssues.feedback['Lumbar'] = 'Tốt, giữ bụng siết';
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _archDebouncer.reset();
  }
}