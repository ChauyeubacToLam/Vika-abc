/* =========================================================================
   Metric 1: Spine Rounding (Lumbar Flexion)
   Priority: CRITICAL — Ship Day 1

   Measures the wrist–shoulder–hip angle.
   ~165–180° = arms and torso in one long line.
   Lower back rounding drops this angle as the hip falls below the line.

   SAFETY-CRITICAL: affectsForm = true.

   Vietnamese context:
   - Tight hamstrings drag the pelvis under → lumbar rounds under load.
   - Coaching is the INVERSE of textbook yoga:
     tell the user to BEND THEIR KNEES, not to straighten their legs.
     Spine length beats straight legs every time for desk workers.

   THRESHOLDS (ESTIMATE — pending PT review):
   ┌──────────────┬──────────────┬────────────┐
   │ Week 1–4     │ Week 5–8     │ Week 9+    │
   ├──────────────┼──────────────┼────────────┤
   │ Good  ≥ 160° │ Good  ≥ 163° │ Good ≥ 165°│
   │ Warn  < 160° │ Warn  < 163° │ Warn < 165°│
   │ Error < 145° │ Error < 148° │ Error< 150°│
   └──────────────┴──────────────┴────────────┘
   ========================================================================= */

import 'downward_dog_metric_base.dart';
import '../../../utils/debouncer.dart';

class SpineRoundConfig {
  /// Angle at or above which the spine is considered long and safe.
  static const double GOOD_ANGLE = 148.0;

  /// Warning band: spine starting to round but not yet a safety fault.
  static const double WARNING_ANGLE = 132.0;

  // Real-time path: shorter debounce so the alert fires while the user
  // is still in the bad position.
  static const int REALTIME_CONFIRM_FRAMES = 10;

  // Sticky hold: once confirmed, keep the cue until the user corrects.
  static const int STICKY_CONFIRM_FRAMES = 20;
}

class SpineRoundMetric extends DownwardDogMetricBase {
  @override
  String get name => 'SpineRound';

  @override
  String? get nameVi => 'Cột sống';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Short debouncer for live safety alert.
  final Debouncer _errorDebouncer =
      Debouncer(requiredFrames: SpineRoundConfig.REALTIME_CONFIRM_FRAMES);

  // Sticky debouncer for warning band.
  final Debouncer _warningDebouncer =
      Debouncer(requiredFrames: SpineRoundConfig.STICKY_CONFIRM_FRAMES);

  double? _spineAngle;
  MetricStatus _status = MetricStatus.pass;
  bool _isFaultingNow = false;

  /// Prevent instruction spam — coaching set once per hold.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _spineAngle;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningBelow: SpineRoundConfig.GOOD_ANGLE,
        faultBelow: SpineRoundConfig.WARNING_ANGLE,
      );

  @override
  MetricStatus get status => _status;

  @override
  void update(HoldContext ctx) {
    _isFaultingNow = false;
    if (ctx.holdState != DownwardDogState.hold) {
      _status = MetricStatus.pass;
      return;
    }

    _spineAngle = ctx.spineAngle;
    _debugData['spineAngle'] = ctx.spineAngle;
    _debugData['spineBaseline'] = ctx.spineBaseline ?? 'N/A';

    final bool isError = ctx.spineAngle < SpineRoundConfig.WARNING_ANGLE;
    final bool isWarning = ctx.spineAngle < SpineRoundConfig.GOOD_ANGLE;

    final bool errorConfirmed = _errorDebouncer.update(isError);
    final bool warningConfirmed = _warningDebouncer.update(isWarning);

    if (errorConfirmed) {
      _isFaultingNow = true;
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['spine_round'] =
          'Cong gối nhiều hơn nhé! Giữ lưng dài, đừng gù lưng. Chân thẳng không quan trọng bằng lưng thẳng.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'hold',
          'spine_round',
          'Cong gối nhiều hơn nhé! Giữ lưng dài, đừng gù lưng.',
        );
        _instructionSet = true;
      }
      _logFault('HOLD', 'Spine rounding — lumbar flexion detected');
    } else if (warningConfirmed) {
      _status = MetricStatus.near;
      ctx.resultIssues.feedback['spine_round'] =
          'Gập gối một chút để kéo dài lưng nhé!';
    } else {
      _status = MetricStatus.pass;
      ctx.resultIssues.feedback['spine_round'] =
          'Lưng dài và thẳng, tuyệt vời!';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'SpineRound')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'SpineRound',
        message: message,
        affectsForm: true,
        voiceMessage: 'Gập gối để giữ lưng thẳng',
        priority: DownwardDogFaultVoicePriority.spineRound,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _errorDebouncer.reset();
    _warningDebouncer.reset();
    _spineAngle = null;
    _status = MetricStatus.pass;
    _instructionSet = false;
    _isFaultingNow = false;
  }
}
