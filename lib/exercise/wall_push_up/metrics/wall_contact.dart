/* =========================================================================
   Metric 7: Wall Contact Proxy (Are the hands anchored on the wall?)

   A 2D pose model cannot see the wall plane directly. The practical proxy is:
     1. the initial wrist X coordinate on the wall is captured at setup, and
     2. the wrist X coordinate must stay within +/-15 px of that anchor.

   Example: if setup wristDrift is 230, values from 215 to 245 pass.

   shoulderHandClosure is kept as debug only. It no longer blocks rep counting
   because live camera data showed it was too strict for setup.

   Thresholds:
     Wrist anchor good:  |currentX - setupX| <= 15 px
     Wrist anchor error: |currentX - setupX| > 15 px
   ========================================================================= */

import 'dart:math';

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class WallContactConfig {
  static const double MAX_HAND_DRIFT_PX = 15.0;
}

class WallContactMetric extends WallPushUpMetricBase {
  @override
  String get name => 'WallContact';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _anchorErrorDebouncer = Debouncer(requiredFrames: 8);

  double? _baselineHandX;
  double? _baselineHandY;
  double? _baselineShoulderToHandDistance;
  double? _minShoulderToHandDistance;
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void capturePointBaseline(double? x, double? y) {
    if (x == null || y == null) return;
    _baselineHandX = x;
    _baselineHandY = y;
  }

  @override
  void captureBaseline(double? value) {
    if (value != null && value > 0) _baselineShoulderToHandDistance = value;
  }

  @override
  void update(RepContext ctx) {
    if (_baselineHandX == null || _baselineHandY == null) {
      return;
    }

    final wristDriftValue = ctx.wristAnchorX;
    final anchorDriftDelta = (wristDriftValue - _baselineHandX!).abs();

    double? shoulderClosure;
    final baselineShoulderToHandDistance = _baselineShoulderToHandDistance;
    if (baselineShoulderToHandDistance != null &&
        baselineShoulderToHandDistance > 0) {
      final shoulderDx = ctx.shoulderAnchorX - ctx.wristAnchorX;
      final shoulderDy = ctx.shoulderAnchorY - ctx.wristAnchorY;
      final shoulderToHandDistance =
          sqrt(shoulderDx * shoulderDx + shoulderDy * shoulderDy);
      if (_minShoulderToHandDistance == null ||
          shoulderToHandDistance < _minShoulderToHandDistance!) {
        _minShoulderToHandDistance = shoulderToHandDistance;
      }
      shoulderClosure =
          (baselineShoulderToHandDistance - _minShoulderToHandDistance!) /
              baselineShoulderToHandDistance;
    }

    final phase = ctx.state.toString().split('.').last.toUpperCase();

    _debugData['wristDrift'] = wristDriftValue.toStringAsFixed(1);
    _debugData['wristDriftBaseline'] = _baselineHandX!.toStringAsFixed(1);
    _debugData['wristDriftDelta'] = anchorDriftDelta.toStringAsFixed(1);
    _debugData['handAnchorDrift'] = anchorDriftDelta.toStringAsFixed(1);
    if (shoulderClosure != null) {
      _debugData['shoulderHandClosure'] =
          '${(shoulderClosure * 100).toStringAsFixed(0)}%';
    }

    final isAnchorError =
        anchorDriftDelta > WallContactConfig.MAX_HAND_DRIFT_PX;
    final anchorErrorConfirmed = _anchorErrorDebouncer.update(isAnchorError);

    if (anchorErrorConfirmed) {
      const message = 'Tay bị di chuyển — giữ tay cố định trên tường.';
      ctx.resultIssues.feedback['Wall'] = message;
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction('standing', 'Wall',
            'Giữ tay cố định trên tường, không để tay đi theo người.');
        _instructionSet = true;
      }
      _logFault(phase, message,
          voiceMessage: 'Chống tay vào tường', affectsForm: true);
    } else {
      ctx.resultIssues.feedback['Wall'] = 'Tay giữ cố định tốt!';
    }

    _debugData['wallStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }

  void _logFault(String phase, String message,
      {String? voiceMessage, required bool affectsForm}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Wall',
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
    _anchorErrorDebouncer.reset();
    _minShoulderToHandDistance = null;
    _instructionSet = false;
    // Baselines intentionally persist across reps.
  }
}
