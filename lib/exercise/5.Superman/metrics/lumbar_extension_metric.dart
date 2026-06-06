import 'superman_metric_base.dart';
import '../../../utils/debouncer.dart';

class LumbarExtensionMetric extends SupermanMetricBase {
  @override
  String get name => 'LumbarExtension';

  // Fix #2: Bỏ ghi đè _faults, _debugData và get faults, get debugData

  final Debouncer _dangerDebouncer = Debouncer(requiredFrames: 3);

  double? _minTrunkAngle;

  @override
  void update(SupermanRepContext ctx) {
    if (_minTrunkAngle == null || ctx.trunkAngle < _minTrunkAngle!) {
      _minTrunkAngle = ctx.trunkAngle;
    }

    debugData['trunkAngle'] = ctx.trunkAngle.toStringAsFixed(1);
    debugData['minTrunkAngle'] = _minTrunkAngle?.toStringAsFixed(1) ?? '-';

    final bool isDangerousExtension =
        ctx.trunkAngle.abs() > SupermanConfig.LUMBAR_EXTENSION_DANGER;

    if (_dangerDebouncer.update(isDangerousExtension)) {
      ctx.resultIssues.feedback['Spine'] = 'Uốn lưng quá gắt! Hạ thấp tay chân';
      _logFault(
          ctx.state.name.toUpperCase(),
          'Uốn lưng quá mức',
          'Hạ thấp tay chân xuống, không uốn cong lưng quá gắt!',
          SupermanVoicePriority.lumbarExtension);
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Cột sống an toàn';
    }
  }

  void _logFault(String phase, String type, String msg, int priority) {
    if (!faults.any((f) => f.type == type)) {
      // Fix #2: Sử dụng addFault() của base class
      addFault(FaultRecord(
          phase: phase,
          type: type,
          message: msg,
          affectsForm: true,
          priority: priority,
          voiceMessage: msg));
    }
  }

  @override
  void reset() {
    super.reset(); // Gọi reset của base class để xoá faults
    _dangerDebouncer.reset();
    _minTrunkAngle = null;
  }
}
