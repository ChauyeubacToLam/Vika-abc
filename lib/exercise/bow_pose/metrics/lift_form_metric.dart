import 'bow_pose_metric_base.dart';
import '../../../../utils/debouncer.dart';

class LiftConfig {
  static const double CHEST_GOOD_MIN = 0.04;
  static const double THIGH_GOOD_MIN = 0.012;
}

class LiftFormMetric extends BowPoseMetricBase {
  @override
  String get name => 'LiftForm';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _thighDebouncer = Debouncer(requiredFrames: 6);
  final Debouncer _chestDebouncer = Debouncer(requiredFrames: 6);

  double _maxChestLift = 0.0;
  double _maxThighLift = 0.0;
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
    final chest = ctx.chestLift;
    final thigh = ctx.thighLiftRelative;

    if (chest > _maxChestLift) _maxChestLift = chest;
    if (thigh > _maxThighLift) _maxThighLift = thigh;

    _debugData['chestLift'] = chest.toStringAsFixed(2);
    _debugData['thighLift'] = thigh.toStringAsFixed(2);

    if (ctx.bowPoseState == BowPoseState.hold) {
      bool chestLow = chest < LiftConfig.CHEST_GOOD_MIN;
      bool thighLow = thigh < LiftConfig.THIGH_GOOD_MIN;

      if (_thighDebouncer.update(thighLow)) {
        _isFaultingNow = true;
        ctx.resultIssues.feedback['Thigh'] = 'Kéo đùi lên cao!';
        _logFault('HOLD', 'Đùi chạm sàn', 'Nâng cao đùi');
      } else {
        ctx.resultIssues.feedback['Thigh'] = 'Đùi nâng tốt!';
      }

      if (_chestDebouncer.update(chestLow)) {
        _isFaultingNow = true;
        ctx.resultIssues.feedback['Chest'] = 'Mở căng lồng ngực!';
        _logFault('HOLD', 'Ngực chưa mở', 'Ưỡn ngực lên');
      } else {
        ctx.resultIssues.feedback['Chest'] = 'Ngực mở đẹp!';
      }
    }
  }

  void _logFault(String phase, String message, String voice) {
    if (!_faults.any((f) => f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'LiftForm',
        message: message,
        voiceMessage: voice,
        affectsForm: true,
      ));
    }
  }

  @override
  void evaluateRep(RepContext ctx) {
    ctx.resultIssues.feedback['MaxExtension'] =
        'Ngực: ${(_maxChestLift * 100).toInt()}% lưng, Đùi: ${(_maxThighLift * 100).toInt()}% đùi';
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _thighDebouncer.reset();
    _chestDebouncer.reset();
    _maxChestLift = 0.0;
    _maxThighLift = 0.0;
    _isFaultingNow = false;
  }
}
