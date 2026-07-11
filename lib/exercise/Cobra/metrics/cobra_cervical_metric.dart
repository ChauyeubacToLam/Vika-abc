// ignore_for_file: curly_braces_in_flow_control_structures
import 'cobra_metric_base.dart';
import '../cobra.dart';
import '../../../utils/debouncer.dart';
import '../../../utils/pose_math_helpers.dart';

/// MET-3: Cervical Neutrality Angle (Neck Hyperextension Detector)
/// CRITICAL safety priority — covers cervical facet injury (Very Common)
/// and cervical radiculopathy (High severity).
/// MANDATORY: Skip when ear landmark confidence < 0.5.
class CobraCervicalMetric extends CobraMetricBase {
  @override
  String get name => 'CervicalNeutrality';

  // Beginner thresholds (degrees, relative to trunk)
  static const double _goodMin = -30.0;
  static const double _goodMax = 45.0;
  static const double _errorHyperextension = 60.0;
  static const double _minEarConfidence = 0.5;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _hyperextensionDebouncer =
      StickyDebouncer(requiredFrames: 8);
  final StickyDebouncer _warningDebouncer = StickyDebouncer(requiredFrames: 8);
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
    if (ctx.state == CobraState.setup) return;
    if (ctx.ear == null || ctx.shoulder == null || ctx.hip == null) return;

    // MANDATORY confidence gate
    if (ctx.ear!.likelihood < _minEarConfidence) {
      _debugData['cervicalAngle'] = 'low_conf';
      return;
    }

    // Relative method: cervicalAngle = neckAngle - trunkAngle
    final trunkAngle =
        calculateVerticalAngle(pivot: ctx.hip!, point: ctx.shoulder!);
    final neckAngle =
        calculateVerticalAngle(pivot: ctx.shoulder!, point: ctx.ear!);

    // Compute cervical extension relative to trunk
    double cervicalAngle = neckAngle - trunkAngle;
    // Normalize to -180..+180
    if (cervicalAngle > 180) cervicalAngle -= 360;
    if (cervicalAngle < -180) cervicalAngle += 360;

    _debugData['cervicalAngle'] = cervicalAngle.toStringAsFixed(1);

    final phase = ctx.state.name;

    // Error: severe hyperextension (>45°)
    if (_hyperextensionDebouncer.update(cervicalAngle > _errorHyperextension)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Neck'] = '⚠️ Đầu ngửa quá nhiều!';
      // Legacy UI instruction copy: Đừng ngửa đầu ra sau. Nhìn thẳng hoặc hơi nhìn xuống.
      _logFault(phase, 'Neck hyperextension', 'NeckHyperextension');
    }
    // Warning: outside good range
    else if (_warningDebouncer
        .update(cervicalAngle > _goodMax || cervicalAngle < _goodMin)) {
      if (cervicalAngle > _goodMax) {
        ctx.resultIssues.feedback['Neck'] = 'Hạ đầu xuống chút';
      } else {
        ctx.resultIssues.feedback['Neck'] = 'Ngẩng đầu lên chút';
      }
    }
    // Good
    else {
      ctx.resultIssues.feedback['Neck'] = 'Cổ tốt ✓';
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
    _hyperextensionDebouncer.reset();
    _warningDebouncer.reset();
    _isFaultingNow = false;
  }
}
