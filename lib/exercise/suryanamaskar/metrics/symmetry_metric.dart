import 'surya_metric_base.dart';

/// Metric Đối xứng: So sánh góc gối giữa P4 (Kỵ sĩ lượt đi)
/// và P9 (Kỵ sĩ lượt về).
///
/// Nếu chênh lệch quá lớn → ghi nhận fault thông tin (không block form).
class SymmetryMetric extends SuryaMetricBase {
  @override
  String get name => 'Symmetry';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  static const double _ASYMMETRY_THRESHOLD = 15.0; // Chênh > 15° → cảnh báo

  // Ghi lại best knee angle mỗi lượt
  double? _bestKneeAngleP4;
  double? _bestKneeAngleP9;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SuryaContext ctx) {
    // Ghi lại góc gối ở P4
    if (ctx.state == SuryaState.p4_ashwa_sanchalanasana) {
      if (_bestKneeAngleP4 == null || ctx.kneeAngle < _bestKneeAngleP4!) {
        _bestKneeAngleP4 = ctx.kneeAngle;
      }
    }

    // Ghi lại góc gối ở P9
    if (ctx.state == SuryaState.p9_ashwa_return) {
      if (_bestKneeAngleP9 == null || ctx.kneeAngle < _bestKneeAngleP9!) {
        _bestKneeAngleP9 = ctx.kneeAngle;
      }
    }

    _debugData['bestKneeP4'] =
        _bestKneeAngleP4?.toStringAsFixed(1) ?? '-';
    _debugData['bestKneeP9'] =
        _bestKneeAngleP9?.toStringAsFixed(1) ?? '-';
  }

  /// Gọi cuối rep để đánh giá đối xứng.
  void evaluateRepEnd(SuryaContext ctx) {
    if (_bestKneeAngleP4 != null && _bestKneeAngleP9 != null) {
      final delta = (_bestKneeAngleP4! - _bestKneeAngleP9!).abs();
      _debugData['symmetryDelta'] = delta.toStringAsFixed(1);

      if (delta > _ASYMMETRY_THRESHOLD) {
        ctx.resultIssues.addInstruction(
            'p12_pranamasana_return', 'Symmetry',
            'Chênh lệch gối 2 bên: ${delta.toStringAsFixed(0)}°. '
            'Cố gắng bước đều 2 bên.');
        _faults.add(FaultRecord(
          phase: 'REP_END',
          type: 'Asymmetry',
          message:
              'Chênh lệch gối 2 bên: ${delta.toStringAsFixed(0)}°',
          affectsForm: false, // Thông tin, không block form
          priority: SuryaVoicePriority.symmetry,
          voiceMessage: 'Cố gắng bước đều 2 bên',
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _bestKneeAngleP4 = null;
    _bestKneeAngleP9 = null;
  }
}
