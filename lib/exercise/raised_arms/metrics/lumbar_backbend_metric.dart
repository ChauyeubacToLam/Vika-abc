// ignore_for_file: curly_braces_in_flow_control_structures
import 'raised_arms_metric_base.dart';
import '../raised_arms.dart';
import '../../../utils/debouncer.dart';

/// MET-1: Lumbar Backbend Limiter.
/// Safety-critical cap for a gentle desk-worker backbend.
class LumbarBackbendMetric extends RaisedArmsMetricBase {
  @override
  String get name => 'LumbarBackbend';

  static const double _goodMax = 10.0;
  static const double _warningMin = 10.0;
  static const double _errorMin = 15.0;

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
  void update(RaisedArmsContext ctx) {
    if (ctx.state != RaisedArmsState.holding) return;

    final backLean = ctx.backLean;
    _debugData['lumbarBackLean'] = backLean.toStringAsFixed(1);

    final phase = ctx.state.name;

    if (_errorDebouncer.update(backLean > _errorMin)) {
      ctx.resultIssues.feedback['Backbend'] = '⚠️ Cẩn thận thắt lưng!';
      ctx.resultIssues.addInstruction(
        'holding',
        'lumbarOverextend',
        'Đứng thẳng lại, ưỡn ngực bằng lưng trên thôi.',
      );
    }

    if (_stickyErrorDebouncer.update(backLean > _errorMin)) {
      _logFault(
        phase,
        'Trunk leaned too far backward',
        'LumbarOverextension',
      );
      return;
    }

    if (_warningDebouncer.update(backLean > _warningMin)) {
      ctx.resultIssues.feedback['Backbend'] =
          'Đừng ngả quá sâu, giữ nhẹ nhàng thôi';
    } else if (backLean >= 0.0 && backLean <= _goodMax) {
      ctx.resultIssues.feedback['Backbend'] = 'Ngả nhẹ ra sau ✓';
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
