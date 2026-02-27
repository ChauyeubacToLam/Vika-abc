/* =========================================================================
   Metric 2: Cervical Spine (Head/Neck) Alignment
   Priority: IMPORTANT
   
   Measures ear→shoulder→hip angle. Detects:
   - Head DROP (looking down too far / chin to chest)
   - Head LIFT (looking up / neck extension)
   
   Vietnamese context:
   - IT professionals with severe forward head posture (CVA ~32°)
   - Planking with head dropped strains cervical spine
   - Tucking chin to neutral increases abdominal activation
   
   Angle interpretation (ear→shoulder→hip):
   - 180° = head perfectly in line with trunk
   - < 180° = head dropped (angle closes as ear moves toward floor)
   - > 180° = head lifted (angle opens as ear moves away from floor)
   
   NOTE: Whether drop/lift maps to <180 or >180 depends on
   calculateAngle() behavior. Verify with debug data and swap if needed.
   
   Thresholds:
     Drop Error:    deviation > 20° → Đừng cúi đầu!
     Drop Warning:  deviation 10°–20° → Đầu hơi cúi
     Good:          deviation < 10° → Đầu tốt
     Lift Warning:  deviation 10°–20° → Đầu hơi ngẩng
     Lift Error:    deviation > 20° → Đừng ngẩng đầu!
   ========================================================================= */

import 'plank_metric_base.dart';
import '../../../utils/debouncer.dart';

class HeadNeckConfig {
  /// 180° = head perfectly in line with trunk
  static const double NEUTRAL = 180.0;

  /// Deviation thresholds from neutral
  static const double WARNING_DEVIATION = 10.0;
  static const double ERROR_DEVIATION = 20.0;

  /// Fault percentage threshold
  static const double FAULT_PERCENT_THRESHOLD = 0.30;
}

class HeadNeckMetric extends PlankMetricBase {
  @override
  String get name => 'HeadNeck';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Separate debouncers for drop and lift
  final Debouncer _dropDebouncer = Debouncer(requiredFrames: 8);
  final Debouncer _liftDebouncer = Debouncer(requiredFrames: 8);

  // Fault time tracking
  int _totalFrames = 0;
  int _faultFrames = 0;

  // Prevent instruction spam — one per direction per hold
  bool _dropInstructionSet = false;
  bool _liftInstructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  double get faultPercentage =>
      _totalFrames > 0 ? _faultFrames / _totalFrames : 0.0;

  @override
  void update(RepContext ctx) {
    _totalFrames++;

    final angle = ctx.neckAngle;
    final deviation = (HeadNeckConfig.NEUTRAL - angle).abs();
    bool isFault = false;

    // Signed deviation: positive = dropped, negative = lifted
    // NOTE: Verify with debug data — swap signs if needed
    final signedDeviation = HeadNeckConfig.NEUTRAL - angle;

    _debugData['neckAngle'] = angle.toStringAsFixed(1);
    _debugData['neckDeviation'] =
        '${signedDeviation >= 0 ? "Drop" : "Lift"} ${deviation.toStringAsFixed(1)}°';
    _debugData['neckFault%'] = '${(faultPercentage * 100).toStringAsFixed(0)}%';

    // --- Drop detection (head dropping toward floor) ---
    bool isDropError =
        signedDeviation > 0 && deviation > HeadNeckConfig.ERROR_DEVIATION;
    bool isDropWarning = signedDeviation > 0 &&
        deviation > HeadNeckConfig.WARNING_DEVIATION &&
        deviation <= HeadNeckConfig.ERROR_DEVIATION;

    // --- Lift detection (head lifting / looking up) ---
    bool isLiftError =
        signedDeviation < 0 && deviation > HeadNeckConfig.ERROR_DEVIATION;
    bool isLiftWarning = signedDeviation < 0 &&
        deviation > HeadNeckConfig.WARNING_DEVIATION &&
        deviation <= HeadNeckConfig.ERROR_DEVIATION;

    // --- Debounced drop ---
    if (_dropDebouncer.update(isDropError || isDropWarning)) {
      isFault = true;
      if (isDropError) {
        ctx.resultIssues.feedback['Neck'] = 'Đừng cúi đầu!';
        if (!_dropInstructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Neck', 'Đầu cúi quá — nhìn xuống sàn nhẹ thôi!');
          _dropInstructionSet = true;
        }
        _logFault('Cúi đầu quá mức');
      } else {
        ctx.resultIssues.feedback['Neck'] = 'Đầu hơi cúi';
        if (!_dropInstructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Neck', 'Đầu hơi cúi — giữ thẳng hàng với lưng!');
          _dropInstructionSet = true;
        }
        _logFault('Đầu hơi cúi');
      }
    }
    // --- Debounced lift ---
    else if (_liftDebouncer.update(isLiftError || isLiftWarning)) {
      isFault = true;
      if (isLiftError) {
        ctx.resultIssues.feedback['Neck'] = 'Đừng ngẩng đầu!';
        if (!_liftInstructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Neck', 'Ngẩng đầu quá — nhìn xuống sàn!');
          _liftInstructionSet = true;
        }
        _logFault('Ngẩng đầu quá mức');
      } else {
        ctx.resultIssues.feedback['Neck'] = 'Đầu hơi ngẩng';
        if (!_liftInstructionSet) {
          ctx.resultIssues.addInstruction(
              'resting', 'Neck', 'Đầu hơi ngẩng — nhìn xuống sàn!');
          _liftInstructionSet = true;
        }
        _logFault('Đầu hơi ngẩng');
      }
    }
    // --- Good form ---
    else {
      ctx.resultIssues.feedback['Neck'] = 'Đầu tốt';
    }

    if (isFault) _faultFrames++;

    _debugData['neckStatus'] = isFault ? 'FAULT' : 'GOOD';
  }

  void _logFault(String message) {
    if (!_faults.any((f) => f.message == message)) {
      _faults.add(FaultRecord(
        faultPercentage: 0.0,
        type: 'Neck',
        message: message,
        affectsForm: false,
      ));
    }
  }

  @override
  void finalizeHold() {
    final shouldAffect =
        faultPercentage > HeadNeckConfig.FAULT_PERCENT_THRESHOLD;

    final updated = _faults
        .map((f) => FaultRecord(
              faultPercentage: faultPercentage,
              type: f.type,
              message: shouldAffect
                  ? '${f.message} (${(faultPercentage * 100).toStringAsFixed(0)}% thời gian)'
                  : f.message,
              affectsForm: shouldAffect,
            ))
        .toList();
    _faults.clear();
    _faults.addAll(updated);
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _dropDebouncer.reset();
    _liftDebouncer.reset();
    _totalFrames = 0;
    _faultFrames = 0;
    _dropInstructionSet = false;
    _liftInstructionSet = false;
  }
}
