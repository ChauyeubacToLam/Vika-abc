import 'dart:math';
import 'sphinx_metric_base.dart';

class HoldTempoMetric extends SphinxMetricBase {
  @override
  String get name => 'HoldTempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _holdStartMs;
  double activeHoldSeconds = 0.0;

  // Dành cho độ ổn định (Stability)
  final List<double> _spineAnglesDuringHold = [];
  double stabilityScore = 100.0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(SphinxState from, SphinxState to, int timestampMs) {
    if (to == SphinxState.isometricHold) {
      _holdStartMs = timestampMs;
    } else if (from == SphinxState.isometricHold) {
      flushCurrentSegment(timestampMs);
      _calculateStability();
    }
  }

  @override
  void update(SphinxContext ctx) {
    if (ctx.state == SphinxState.isometricHold) {
      if (_holdStartMs != null) {
        final double currentHold =
            (ctx.frameTimestampMs - _holdStartMs!) / 1000.0;
        // Live feedback: hiển thị thời gian đang giữ
        ctx.resultIssues.feedback['Time'] =
            '${(activeHoldSeconds + currentHold).toStringAsFixed(1)}s / ${SphinxConfig.Ae_Min_Hold_Time}s';

        // Ghi nhận góc lưng để đánh giá rung lắc cuối rep
        _spineAnglesDuringHold.add(ctx.spineAngle);
      }
    } else {
      ctx.resultIssues.feedback['Time'] = 'Đang chờ...';
    }
  }

  // --- HÀM MỚI: Lấy thời gian hold đang chạy realtime ---
  double getLiveHoldTime(int currentMs) {
    if (_holdStartMs != null) {
      return activeHoldSeconds + ((currentMs - _holdStartMs!) / 1000.0);
    }
    return activeHoldSeconds;
  }

  void flushCurrentSegment(int currentMs) {
    if (_holdStartMs != null) {
      activeHoldSeconds += (currentMs - _holdStartMs!) / 1000.0;
      _holdStartMs = null;
    }
  }

  void _calculateStability() {
    if (_spineAnglesDuringHold.length < 2) return;

    // Tính trung bình góc lưng
    final double mean = _spineAnglesDuringHold.reduce((a, b) => a + b) /
        _spineAnglesDuringHold.length;

    // Tính phương sai (Variance) -> đo độ rung lắc
    final double variance = _spineAnglesDuringHold
            .map((x) => pow(x - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        _spineAnglesDuringHold.length;

    // Chuyển variance thành điểm 0-100 (rung nhiều thì điểm thấp)
    final double penalty = (variance / SphinxConfig.Ah_Stability_Var) * 10;
    stabilityScore = max(0.0, 100.0 - penalty);

    _debugData['variance'] = variance.toStringAsFixed(2);
    _debugData['stabilityScore'] = stabilityScore.toStringAsFixed(1);
  }

  @override
  void reset() {
    super.reset();
    _holdStartMs = null;
    activeHoldSeconds = 0.0;
    _spineAnglesDuringHold.clear();
    stabilityScore = 100.0;
  }
}
