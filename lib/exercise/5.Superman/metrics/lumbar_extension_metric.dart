import 'superman_metric_base.dart';
import '../../../utils/debouncer.dart';

class LumbarExtensionMetric extends SupermanMetricBase {
  @override
  String get name => 'LumbarExtension';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _dangerDebouncer = Debouncer(requiredFrames: 3);

  double? _minTrunkAngle;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SupermanRepContext ctx) {
    if (_minTrunkAngle == null || ctx.trunkAngle < _minTrunkAngle!) {
      _minTrunkAngle = ctx.trunkAngle;
    }

    _debugData['trunkAngle'] = ctx.trunkAngle.toStringAsFixed(1);
    _debugData['minTrunkAngle'] = _minTrunkAngle?.toStringAsFixed(1) ?? '-';

    bool isDangerousExtension = ctx.trunkAngle < SupermanConfig.LUMBAR_EXTENSION_DANGER;

    if (_dangerDebouncer.update(isDangerousExtension)) {
      ctx.resultIssues.feedback['Spine'] = 'Uốn lưng quá gắt! Hạ thấp tay chân';
      _logFault(ctx.state.name.toUpperCase(), 'Uốn lưng quá mức', 'Hạ thấp tay chân xuống, không uốn cong lưng quá gắt!', SupermanVoicePriority.lumbarExtension);
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Cột sống an toàn';
    }
  }

  void _logFault(String phase, String type, String msg, int priority) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase, type: type, message: msg, affectsForm: true, priority: priority, voiceMessage: msg
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _dangerDebouncer.reset();
    _minTrunkAngle = null;
  }
}