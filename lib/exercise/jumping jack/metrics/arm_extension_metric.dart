/* =========================================================================
   Metric 1: Arm Extension
   Priority: CRITICAL — Ship Day 1
   
   Detects whether arms fully extend overhead during the OPEN phase.
   This is the primary quality indicator — lazy jumping jacks with
   bent arms or low reach are the #1 form error.
   
   Detection strategy:
   - Arm elevation angle: shoulder→wrist vector from horizontal
     0° = arms horizontal, 90° = straight overhead
   - Elbow straightness: shoulder→elbow→wrist angle (180° = straight)
   
   Thresholds (normalized, body-size independent):
     Good:     Both arms elevation > 60° AND elbows > 150°
     Warning:  Elevation 30°-60° OR elbows 120°-150°
     Error:    Elevation < 30° (arms barely lift)
   
   Vietnamese desk worker context:
   - Tight shoulders from hunching over laptops limit overhead reach
   - Start lenient for beginners, tighten as users progress
   - Encouraging feedback, never harsh
   ========================================================================= */

import 'jumping_jack_metric_base.dart';
import '../jumping_jack.dart';
import '../../../utils/debouncer.dart';

class ArmExtensionConfig {
  // -- Elevation thresholds (degrees from horizontal) --
  /// Good: arms clearly overhead
  // ignore: constant_identifier_names
  static const double ELEVATION_GOOD = 45.0;

  /// Warning: arms reach shoulder height but not overhead
  // ignore: constant_identifier_names
  static const double ELEVATION_WARNING = 20.0;

  // Below ELEVATION_WARNING = error

  // -- Elbow straightness thresholds (shoulder→elbow→wrist angle) --
  /// Good: arms nearly straight
  // ignore: constant_identifier_names
  static const double ELBOW_GOOD = 135.0;

  /// Warning: noticeably bent
  // ignore: constant_identifier_names
  static const double ELBOW_WARNING = 105.0;

  // Below ELBOW_WARNING = error
}

class ArmExtensionMetric extends JJMetricBase {
  @override
  String get name => 'ArmExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Fast movement → low debounce frames
  final Debouncer _elevationDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _elbowDebouncer = Debouncer(requiredFrames: 3);

  /// Track peak elevation this rep (for post-rep analysis)
  double _peakLeftElevation = 0.0;
  double _peakRightElevation = 0.0;

  /// Prevent instruction spam — only set coaching once per rep.
  bool _elevationInstructionSet = false;
  bool _elbowInstructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Track peak elevation
    if (ctx.leftArmElevation > _peakLeftElevation) {
      _peakLeftElevation = ctx.leftArmElevation;
    }
    if (ctx.rightArmElevation > _peakRightElevation) {
      _peakRightElevation = ctx.rightArmElevation;
    }

    _debugData['leftElev'] = ctx.leftArmElevation.toStringAsFixed(1);
    _debugData['rightElev'] = ctx.rightArmElevation.toStringAsFixed(1);
    _debugData['leftElbow'] = ctx.leftArmAngle.toStringAsFixed(1);
    _debugData['rightElbow'] = ctx.rightArmAngle.toStringAsFixed(1);
    _debugData['peakElev'] =
        '${_peakLeftElevation.toStringAsFixed(0)}° / ${_peakRightElevation.toStringAsFixed(0)}°';

    // Only evaluate during OPEN phase — arms should be up
    if (ctx.jjState != JJState.open) {
      // During CLOSED phase, show neutral status
      if (ctx.resultIssues.feedback['Arms'] == null) {
        ctx.resultIssues.feedback['Arms'] = 'Chuẩn bị';
      }
      return;
    }

    // --- Elevation check (average of both arms) ---
    final minElevation = ctx.leftArmElevation < ctx.rightArmElevation
        ? ctx.leftArmElevation
        : ctx.rightArmElevation;

    bool lowArms = minElevation < ArmExtensionConfig.ELEVATION_WARNING;
    bool mediumArms = minElevation >= ArmExtensionConfig.ELEVATION_WARNING &&
        minElevation < ArmExtensionConfig.ELEVATION_GOOD;

    if (_elevationDebouncer.update(lowArms)) {
      ctx.resultIssues.feedback['Arms'] = 'Vươn tay cao hơn!';
      if (!_elevationInstructionSet) {
        // Legacy UI instruction copy: Lần sau, vươn tay thật cao qua đầu!
        _elevationInstructionSet = true;
      }
      _logFault('OPEN', 'Tay chưa đủ cao');
    } else if (mediumArms) {
      ctx.resultIssues.feedback['Arms'] = 'Đưa tay cao hơn!';
      if (!_elevationInstructionSet) {
        // Legacy UI instruction copy: Đưa tay cao hơn lần sau!
        _elevationInstructionSet = true;
      }
    } else {
      // Good elevation — now check elbow straightness
      final minElbow = ctx.leftArmAngle < ctx.rightArmAngle
          ? ctx.leftArmAngle
          : ctx.rightArmAngle;

      bool bentElbow = minElbow < ArmExtensionConfig.ELBOW_WARNING;
      bool softElbow = minElbow >= ArmExtensionConfig.ELBOW_WARNING &&
          minElbow < ArmExtensionConfig.ELBOW_GOOD;

      if (_elbowDebouncer.update(bentElbow)) {
        ctx.resultIssues.feedback['Arms'] = 'Duỗi thẳng tay!';
        if (!_elbowInstructionSet) {
          // Legacy UI instruction copy: Duỗi thẳng khuỷu tay lần sau!
          _elbowInstructionSet = true;
        }
        _logFault('OPEN', 'Khuỷu tay gập nhiều');
      } else if (softElbow) {
        ctx.resultIssues.feedback['Arms'] = 'Duỗi tay thêm!';
      } else {
        ctx.resultIssues.feedback['Arms'] = 'Tay tốt!';
      }
    }

    _debugData['armStatus'] = ctx.resultIssues.feedback['Arms'] ?? '';
  }

  /// Called by JumpingJack when rep completes.
  void evaluateRep(RepContext ctx) {
    final peakMin = _peakLeftElevation < _peakRightElevation
        ? _peakLeftElevation
        : _peakRightElevation;

    if (peakMin < ArmExtensionConfig.ELEVATION_WARNING) {
      _logFault(
          'REP_COMPLETE', 'Tay quá thấp (${peakMin.toStringAsFixed(0)}°)');
    } else if (peakMin < ArmExtensionConfig.ELEVATION_GOOD) {
      _logFault(
          'REP_COMPLETE', 'Tay chưa đủ cao (${peakMin.toStringAsFixed(0)}°)');
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Arms')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Arms',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _elevationDebouncer.reset();
    _elbowDebouncer.reset();
    _peakLeftElevation = 0.0;
    _peakRightElevation = 0.0;
    _elevationInstructionSet = false;
    _elbowInstructionSet = false;
  }
}
