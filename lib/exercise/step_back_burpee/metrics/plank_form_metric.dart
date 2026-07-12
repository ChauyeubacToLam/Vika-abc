/* =========================================================================
   Metric 2, 3, 4: High Plank Form (Định tuyến tư thế Plank)
   - Metric 2 (CRITICAL): Võng lưng (Sagging) gây áp lực cắt lên thắt lưng.
   - Metric 3 (MEDIUM): Bước quá ngắn (Bear Plank) làm mất tác dụng bài.
   - Metric 4 (MEDIUM): Tay chống không thẳng.
   ========================================================================= */

import 'step_back_burpee_metric_base.dart';

class PlankConfig {
  static const double SAG_WARNING = 150.0;
  static const double SAG_DANGER = 140.0; // Góc trục thân (võng)

  static const double SHORT_STEP_WARNING = 145.0; // Góc hông mở (bear plank)
  static const double ARM_BENT_WARNING = 135.0; // Góc khuỷu tay
}

class PlankFormMetric extends StepBackBurpeeMetricBase {
  @override
  String get name => 'PlankForm';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _minBodyAngle;
  double? _maxHipAngle;
  double? _minElbowAngle;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.burpeeState == BurpeeState.highPlank) {
      // 1. Check võng lưng (tìm góc nhỏ nhất)
      if (_minBodyAngle == null || ctx.bodyAlignmentAngle < _minBodyAngle!) {
        _minBodyAngle = ctx.bodyAlignmentAngle;
      }

      // 2. Check biên độ bước (tìm góc lớn nhất của Hông mở ra)
      if (_maxHipAngle == null || ctx.hipAngle > _maxHipAngle!) {
        _maxHipAngle = ctx.hipAngle;
      }

      // 3. Check tay thẳng
      if (_minElbowAngle == null || ctx.elbowAngle < _minElbowAngle!) {
        _minElbowAngle = ctx.elbowAngle;
      }

      // Live feedback ưu tiên lỗi nguy hiểm nhất
      if (ctx.bodyAlignmentAngle < PlankConfig.SAG_DANGER) {
        ctx.resultIssues.feedback['Plank'] = 'Gồng bụng! Đang võng lưng.';
      } else if (ctx.hipAngle < PlankConfig.SHORT_STEP_WARNING) {
        ctx.resultIssues.feedback['Plank'] = 'Bước chân lùi xa hơn nữa!';
      }
    }
  }

  @override
  void onStateTransition(BurpeeState from, BurpeeState to, int timestampMs) {
    // Vừa thoát khỏi Plank để bước lên -> Chốt đánh giá
    if (from == BurpeeState.highPlank &&
        (to == BurpeeState.steppingForward || to == BurpeeState.standingUp)) {
      // Lỗi võng lưng
      if (_minBodyAngle != null && _minBodyAngle! < PlankConfig.SAG_DANGER) {
        _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'plank_sag',
          message: 'Lưng bị gập quá mức khi nằm!',
          affectsForm: true,
        ));
      }

      // Lỗi bước ngắn (bear plank / co gập khi nằm)
      if (_maxHipAngle != null &&
          _maxHipAngle! < PlankConfig.SHORT_STEP_WARNING) {
        _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'plank_extension',
          message: 'Chân chưa duỗi thẳng hết cỡ khi nằm xuống.',
          affectsForm: false,
        ));
      }

      // Đã bỏ kiểm tra lỗi cong tay vì nằm hoàn toàn xuống sàn thì tay bắt buộc phải cong.
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minBodyAngle = null;
    _maxHipAngle = null;
    _minElbowAngle = null;
  }
}
