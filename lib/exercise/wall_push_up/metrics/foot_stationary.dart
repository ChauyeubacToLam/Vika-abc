/* =========================================================================
   Metric 6: Foot Stationary (Do the feet stay planted?)

   Captures a side-view foot anchor at setup using the visible ankle / heel /
   foot-index landmarks. During active reps, the feet should not walk forward
   or backward to make the rep easier.

   Movement is normalized by shoulder-to-hip distance so the threshold scales
   with the person and camera distance. Only horizontal drift is used because
   side-view "stepping" is forward/backward; vertical foot jitter from pose
   estimation should not fail the rep.

   Thresholds:
     Good:    horizontal movement <= 20% body scale
     Warning: 20-30%      (8-frame debounce)
     Error:   > 30%       (10-frame debounce, affectsForm = true)

   Also stores the setup HIP→ANKLE→FOOT_INDEX angle for debugging stance
   cases where the user stands nearly upright instead of leaning into the wall.
   ========================================================================= */

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class FootStationaryConfig {
  static const double WARNING_MOVE = 0.20;
  static const double ERROR_MOVE = 0.30;
}

class FootStationaryMetric extends WallPushUpMetricBase {
  @override
  String get name => 'FootStationary';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _warningDebouncer = Debouncer(requiredFrames: 8);
  final Debouncer _errorDebouncer = Debouncer(requiredFrames: 10);

  double? _baselineX;
  double? _baselineY;
  double? _baselineBodyFootAngle;
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void capturePointBaseline(double? x, double? y) {
    if (x == null || y == null) return;
    _baselineX = x;
    _baselineY = y;
  }

  @override
  void captureBaseline(double? value) {
    if (value != null) _baselineBodyFootAngle = value;
  }

  @override
  void update(RepContext ctx) {
    final x = ctx.footAnchorX;
    final scale = ctx.scaleFactor;
    if (x == null || scale == null || scale <= 0 || _baselineX == null) {
      return;
    }

    final dx = x - _baselineX!;
    final movement = dx.abs() / scale;
    final phase = ctx.state.toString().split('.').last.toUpperCase();

    _debugData['footMove'] = '${(movement * 100).toStringAsFixed(0)}%';
    if (ctx.footAnchorY != null && _baselineY != null) {
      final verticalMovement = (ctx.footAnchorY! - _baselineY!).abs() / scale;
      _debugData['footVerticalJitter'] =
          '${(verticalMovement * 100).toStringAsFixed(0)}%';
    }
    if (_baselineBodyFootAngle != null) {
      _debugData['setupBodyFootAngle'] =
          _baselineBodyFootAngle!.toStringAsFixed(1);
    }
    if (ctx.bodyFootAngle != null) {
      _debugData['bodyFootAngle'] = ctx.bodyFootAngle!.toStringAsFixed(1);
    }

    final bool isError = movement > FootStationaryConfig.ERROR_MOVE;
    final bool isWarning = movement > FootStationaryConfig.WARNING_MOVE &&
        movement <= FootStationaryConfig.ERROR_MOVE;

    final bool errorConfirmed = _errorDebouncer.update(isError);
    final bool warningConfirmed = _warningDebouncer.update(isWarning);

    if (errorConfirmed) {
      ctx.resultIssues.feedback['Feet'] = 'Giữ chân cố định, đừng bước chân.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'standing', 'Feet', 'Đặt chân cố định, không bước khi chống đẩy.');
        _instructionSet = true;
      }
      _logFault(phase, 'Chân di chuyển khi tập',
          voiceMessage: 'Giữ chân cố định', affectsForm: true);
    } else if (warningConfirmed) {
      ctx.resultIssues.feedback['Feet'] = 'Chân hơi di chuyển.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'standing', 'Feet', 'Chân hơi lệch — giữ nguyên vị trí.');
        _instructionSet = true;
      }
      _logFault(phase, 'Chân hơi di chuyển',
          voiceMessage: 'Giữ chân cố định', affectsForm: false);
    } else {
      ctx.resultIssues.feedback['Feet'] = 'Chân giữ cố định tốt!';
    }

    _debugData['footStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }

  void _logFault(String phase, String message,
      {String? voiceMessage, required bool affectsForm}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Feet',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: affectsForm,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _warningDebouncer.reset();
    _errorDebouncer.reset();
    _instructionSet = false;
    // Baselines intentionally persist across reps.
  }
}
