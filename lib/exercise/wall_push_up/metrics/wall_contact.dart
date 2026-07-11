/* =========================================================================
   Metric 7: Wall Contact Proxy (Are the hands anchored on the wall?)

   A 2D pose model cannot see the wall plane directly. The practical proxy is
   the wrist anchor captured at setup, normalized by the user's torso scale.
   When a foot anchor is available, drift is measured as wrist-relative-to-foot
   so light camera shake does not look like the hand sliding.

   Thresholds:
     Wrist anchor good:  movement <= 8% body scale
     Wrist anchor error: movement > 8% body scale
   ========================================================================= */

import 'dart:math';

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class WallContactConfig {
  static const double MAX_HAND_DRIFT_RATIO = 0.14;
}

class WallContactMetric extends WallPushUpMetricBase {
  @override
  String get name => 'WallContact';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _anchorErrorDebouncer = Debouncer(requiredFrames: 8);

  double? _baselineHandX;
  double? _baselineHandY;
  double? _baselineScaleFactor;
  double? _baselineWristToFootX;
  double? _baselineWristToFootY;
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

  void captureFootBaseline(double? x, double? y) {
    if (x == null ||
        y == null ||
        _baselineHandX == null ||
        _baselineHandY == null) {
      return;
    }
    _baselineWristToFootX = _baselineHandX! - x;
    _baselineWristToFootY = _baselineHandY! - y;
  }

  @override
  void captureBaseline(double? value) {
    if (value != null && value > 0) _baselineScaleFactor = value;
  }

  @override
  void update(RepContext ctx) {
    if (_baselineHandX == null || _baselineHandY == null) {
      return;
    }

    final scale = _baselineScaleFactor ?? ctx.scaleFactor;
    if (scale == null || scale <= 0) {
      return;
    }

    var anchorDriftDelta = 0.0;
    var driftSource = 'image';
    if (ctx.footAnchorX != null && ctx.footAnchorY != null) {
      final wristToFootX = ctx.wristAnchorX - ctx.footAnchorX!;
      final wristToFootY = ctx.wristAnchorY - ctx.footAnchorY!;
      _baselineWristToFootX ??= wristToFootX;
      _baselineWristToFootY ??= wristToFootY;

      final dx = wristToFootX - _baselineWristToFootX!;
      final dy = wristToFootY - _baselineWristToFootY!;
      anchorDriftDelta = sqrt(dx * dx + dy * dy);
      driftSource = 'wrist-foot';
    } else {
      final dx = ctx.wristAnchorX - _baselineHandX!;
      final dy = ctx.wristAnchorY - _baselineHandY!;
      anchorDriftDelta = sqrt(dx * dx + dy * dy);
    }
    final anchorDriftRatio = anchorDriftDelta / scale;

    double? shoulderClosure;
    final shoulderDx = ctx.shoulderAnchorX - ctx.wristAnchorX;
    final shoulderDy = ctx.shoulderAnchorY - ctx.wristAnchorY;
    final shoulderToHandDistance =
        sqrt(shoulderDx * shoulderDx + shoulderDy * shoulderDy);
    _minShoulderToHandDistance ??= shoulderToHandDistance;
    if (shoulderToHandDistance < _minShoulderToHandDistance!) {
      _minShoulderToHandDistance = shoulderToHandDistance;
    }
    if (shoulderToHandDistance > 0) {
      shoulderClosure = (shoulderToHandDistance - _minShoulderToHandDistance!) /
          shoulderToHandDistance;
    }

    final phase = ctx.state.toString().split('.').last.toUpperCase();

    _debugData['wristDrift'] = ctx.wristAnchorX.toStringAsFixed(1);
    _debugData['wristDriftBaseline'] = _baselineHandX!.toStringAsFixed(1);
    _debugData['wristDriftDelta'] = anchorDriftDelta.toStringAsFixed(1);
    _debugData['handAnchorDrift'] =
        '${(anchorDriftRatio * 100).toStringAsFixed(0)}%';
    _debugData['handAnchorDriftSource'] = driftSource;
    if (shoulderClosure != null) {
      _debugData['shoulderHandClosure'] =
          '${(shoulderClosure * 100).toStringAsFixed(0)}%';
    }

    final isAnchorError =
        anchorDriftRatio > WallContactConfig.MAX_HAND_DRIFT_RATIO;
    final anchorErrorConfirmed = _anchorErrorDebouncer.update(isAnchorError);

    if (anchorErrorConfirmed) {
      const message = 'Tay bị di chuyển — giữ tay cố định trên tường.';
      ctx.resultIssues.feedback['Wall'] = message;
      if (!_instructionSet) {
        // Legacy UI instruction copy: Giữ tay cố định trên tường, không để tay đi theo người.
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
