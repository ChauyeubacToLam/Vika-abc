// ignore_for_file: curly_braces_in_flow_control_structures

import 'ashtanga_metric_base.dart';
import '../ashtanga_namaskara.dart';
import '../../../utils/debouncer.dart';

/// MET-1: Hip Position.
/// Form-critical detector that distinguishes Ashtanga Namaskara from
/// chaturanga / half-cobra collapse.
class HipCollapseMetric extends AshtangaMetricBase {
  @override
  String get name => 'HipPosition';

  static const double _goodMin = 0.40;
  static const double _warningMin = 0.15;
  static const double _errorMax = 0.15;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _warningDebouncer = StickyDebouncer(requiredFrames: 6);
  final StickyDebouncer _errorDebouncer = StickyDebouncer(requiredFrames: 6);
  final StickyDebouncer _stickyErrorDebouncer =
      StickyDebouncer(requiredFrames: 15);

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(AshtangaContext ctx) {
    if (ctx.state != AshtangaState.recognized &&
        ctx.state != AshtangaState.holding) return;

    final ratio = ctx.hipPositionRatio;
    _debugData['hipPositionRatio'] = ratio.toStringAsFixed(3);

    if (_errorDebouncer.update(ratio < _errorMax)) {
      ctx.resultIssues.feedback['Hips'] = '⚠️ Đẩy hông lên cao!';
      ctx.resultIssues.addInstruction(
        ctx.state.name,
        'hipCollapse',
        'Đây không phải chaturanga. Đẩy hông lên cao, hạ ngực xuống.',
      );
    }

    if (_stickyErrorDebouncer.update(ratio < _errorMax)) {
      _logFault(
          ctx.state.name, 'Hips collapsed toward shoulders', 'HipCollapse');
      return;
    }

    if (_warningDebouncer.update(ratio < _goodMin && ratio >= _warningMin)) {
      ctx.resultIssues.feedback['Hips'] =
          'Đẩy hông lên cao hơn, đừng để bằng vai';
    } else if (ratio >= _goodMin) {
      ctx.resultIssues.feedback['Hips'] =
          'Hông lên cao, đúng tư thế Ashtanga ✓';
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
