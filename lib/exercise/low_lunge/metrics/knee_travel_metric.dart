// ignore_for_file: curly_braces_in_flow_control_structures
import 'low_lunge_metric_base.dart';
import '../low_lunge.dart';
import '../../../utils/debouncer.dart';

/// MET-1: Front Knee Tracking.
/// Safety-critical detector for the front knee sliding too far past the ankle.
class KneeTravelMetric extends LowLungeMetricBase {
  @override
  String get name => 'KneeTravel';

  static const double _goodMax = 0.5;
  static const double _warningMin = 0.5;
  static const double _errorMin = 0.8;
  static const double _minConfidence = 0.45;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _warningDebouncer = StickyDebouncer(requiredFrames: 8);
  final StickyDebouncer _errorDebouncer = StickyDebouncer(requiredFrames: 8);
  final StickyDebouncer _stickyErrorDebouncer =
      StickyDebouncer(requiredFrames: 20);

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LowLungeContext ctx) {
    if (ctx.state != LowLungeState.holding) return;
    if (ctx.frontKnee == null || ctx.frontAnkle == null) return;

    if (ctx.frontKnee!.likelihood < _minConfidence ||
        ctx.frontAnkle!.likelihood < _minConfidence) {
      _debugData['kneeTravel'] = 'low_conf';
      return;
    }

    if (ctx.scaleFactor < 1.0) return;

    final offset =
        ((ctx.frontKnee!.x - ctx.frontAnkle!.x) * ctx.lungeDirection) /
            ctx.scaleFactor;
    _debugData['kneeTravel'] = offset.toStringAsFixed(3);

    final phase = ctx.state.name;

    if (_errorDebouncer.update(offset > _errorMin)) {
      ctx.resultIssues.feedback['Knee'] = '⚠️ Cẩn thận đầu gối!';
      ctx.resultIssues.addInstruction(
        'holding',
        'kneeTravel',
        'Đẩy hông ra sau, giữ cẳng chân trước thẳng đứng.',
      );
    }

    if (_stickyErrorDebouncer.update(offset > _errorMin)) {
      _logFault(phase, 'Front knee travelled too far past ankle', 'KneeTravel');
      return;
    }

    if (_warningDebouncer.update(offset > _warningMin)) {
      ctx.resultIssues.feedback['Knee'] =
          'Lùi hông ra sau để gối không vượt mũi chân';
    } else if (offset <= _goodMax) {
      ctx.resultIssues.feedback['Knee'] = 'Đầu gối trên cổ chân ✓';
    }
  }

  void _logFault(String phase, String message, String type) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _warningDebouncer.reset();
    _errorDebouncer.reset();
    _stickyErrorDebouncer.reset();
  }
}
