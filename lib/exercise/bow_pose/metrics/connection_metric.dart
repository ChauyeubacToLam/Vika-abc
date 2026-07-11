import 'bow_pose_metric_base.dart';
import '../../../../utils/debouncer.dart';

class ConnectionConfig {
  static const double GRAB_THRESHOLD = 0.35;
  static const double DROP_THRESHOLD = 0.60;
}

class ConnectionMetric extends BowPoseMetricBase {
  @override
  String get name => 'Connection';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _dropDebouncer = Debouncer(requiredFrames: 5);

  bool _instructionSet = false;
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    _isFaultingNow = false;
    _debugData['wristAnkleDist'] = ctx.wristAnkleDist.toStringAsFixed(3);

    if (ctx.bowPoseState == BowPoseState.ascending ||
        ctx.bowPoseState == BowPoseState.hold) {
      bool isDropped = ctx.wristAnkleDist > ConnectionConfig.DROP_THRESHOLD;

      if (_dropDebouncer.update(isDropped)) {
        _isFaultingNow = true;
        ctx.resultIssues.feedback['Connection'] = 'Tuột tay rồi!';
        if (!_instructionSet) {
          _faults.add(FaultRecord(
            phase: ctx.bowPoseState.toString().split('.').last.toUpperCase(),
            type: 'Connection',
            message: 'Mất kết nối tay - chân',
            voiceMessage: 'Nắm chắc cổ chân',
            affectsForm: true,
          ));
          // Legacy UI instruction copy: Hãy giữ chặt cổ chân!
          _instructionSet = true;
        }
      } else {
        ctx.resultIssues.feedback['Connection'] = 'Khóa chặt!';
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _dropDebouncer.reset();
    _instructionSet = false;
    _isFaultingNow = false;
  }
}
