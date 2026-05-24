import 'cmt_7_metric_base.dart';

/// Metric Äá»‘i xá»©ng: So sÃ¡nh gÃ³c gá»‘i giá»¯a P4 (Ká»µ sÄ© lÆ°á»£t Ä‘i)
/// vÃ  P9 (Ká»µ sÄ© lÆ°á»£t vá»).
///
/// Náº¿u chÃªnh lá»‡ch quÃ¡ lá»›n â†’ ghi nháº­n fault thÃ´ng tin (khÃ´ng block form).
class SymmetryMetric extends Cmt7MetricBase {
  @override
  String get name => 'Symmetry';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  static const double _ASYMMETRY_THRESHOLD = 15.0; // ChÃªnh > 15Â° â†’ cáº£nh bÃ¡o

  // Ghi láº¡i best knee angle má»—i lÆ°á»£t
  double? _bestKneeAngleP4;
  double? _bestKneeAngleP9;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(Cmt7Context ctx) {
    // Ghi láº¡i gÃ³c gá»‘i á»Ÿ P4
    if (ctx.state == Cmt7State.p4_ashwa_sanchalanasana) {
      if (_bestKneeAngleP4 == null || ctx.kneeAngle < _bestKneeAngleP4!) {
        _bestKneeAngleP4 = ctx.kneeAngle;
      }
    }

    // Ghi láº¡i gÃ³c gá»‘i á»Ÿ P9
    if (ctx.state == Cmt7State.p9_ashwa_return) {
      if (_bestKneeAngleP9 == null || ctx.kneeAngle < _bestKneeAngleP9!) {
        _bestKneeAngleP9 = ctx.kneeAngle;
      }
    }

    _debugData['bestKneeP4'] =
        _bestKneeAngleP4?.toStringAsFixed(1) ?? '-';
    _debugData['bestKneeP9'] =
        _bestKneeAngleP9?.toStringAsFixed(1) ?? '-';
  }

  /// Gá»i cuá»‘i rep Ä‘á»ƒ Ä‘Ã¡nh giÃ¡ Ä‘á»‘i xá»©ng.
  void evaluateRepEnd(Cmt7Context ctx) {
    if (_bestKneeAngleP4 != null && _bestKneeAngleP9 != null) {
      final delta = (_bestKneeAngleP4! - _bestKneeAngleP9!).abs();
      _debugData['symmetryDelta'] = delta.toStringAsFixed(1);

      if (delta > _ASYMMETRY_THRESHOLD) {
        ctx.resultIssues.addInstruction(
            'p12_pranamasana_return', 'Symmetry',
            'ChÃªnh lá»‡ch gá»‘i 2 bÃªn: ${delta.toStringAsFixed(0)}Â°. '
            'Cá»‘ gáº¯ng bÆ°á»›c Ä‘á»u 2 bÃªn.');
        _faults.add(FaultRecord(
          phase: 'REP_END',
          type: 'Asymmetry',
          message:
              'ChÃªnh lá»‡ch gá»‘i 2 bÃªn: ${delta.toStringAsFixed(0)}Â°',
          affectsForm: false, // ThÃ´ng tin, khÃ´ng block form
          priority: SuryaVoicePriority.symmetry,
          voiceMessage: 'Cá»‘ gáº¯ng bÆ°á»›c Ä‘á»u 2 bÃªn',
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

