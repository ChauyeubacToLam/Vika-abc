import 'butterfly_metric_base.dart';
import '../../../utils/debouncer.dart';

class FootPlacementConfig {
  static const double MAX_FOOT_TO_HIP_DISTANCE_NORM = 0.95;
}

class FootPlacementMetric extends ButterflyMetricBase {
  @override
  String get name => 'FootPlacement';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _tooFarDebouncer = Debouncer(requiredFrames: 5);

  bool _instructionSet = false;
  double? _currentValue;
  MetricStatus _status = MetricStatus.pass;
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _currentValue;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        faultAbove: FootPlacementConfig.MAX_FOOT_TO_HIP_DISTANCE_NORM,
      );

  @override
  MetricStatus get status => _status;
  @override
  void update(StretchContext ctx) {
    _isFaultingNow = false;
    _currentValue = ctx.footToHipDistanceNorm;
    _debugData['foot_to_hip_norm'] =
        ctx.footToHipDistanceNorm.toStringAsFixed(3);

    final phase = ctx.currentState.toString().split('.').last.toUpperCase();
    final tooFar = _tooFarDebouncer.update(
      ctx.footToHipDistanceNorm >
          FootPlacementConfig.MAX_FOOT_TO_HIP_DISTANCE_NORM,
    );
    _status = tooFar ? MetricStatus.fault : MetricStatus.pass;

    if (tooFar) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Foot'] = 'Kéo gót chân lại gần hông!';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Kéo hai gót chân lại gần hông trước khi giữ tư thế.
        _instructionSet = true;
      }
      _logFault(phase, 'Gót chân đặt quá xa hông');
    } else {
      ctx.resultIssues.feedback['Foot'] = 'Gót chân sát hông';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'FootPlacement')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'FootPlacement',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _tooFarDebouncer.reset();
    _instructionSet = false;
    _currentValue = null;
    _status = MetricStatus.pass;
    _isFaultingNow = false;
  }
}
