import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/fault_record.dart';
import 'package:vika/exercise/squat/metrics/heel_rise_metric.dart';
import 'package:vika/exercise/squat/metrics/hip_shoulder_sync.dart';
import 'package:vika/exercise/squat/metrics/squat_metric_base.dart';
import 'package:vika/exercise/squat/squat.dart';

RepContext _buildRepContext({
  required SquatState squatState,
  double heelDistance = 0,
  double scaleFactor = 100,
  double hipY = 100,
  double shoulderY = 100,
}) {
  return RepContext(
    kneeAngle: 90,
    trunkLean: 20,
    clockAngle: 0,
    heelDistance: heelDistance,
    scaleFactor: scaleFactor,
    squatState: squatState,
    frameTimestamp: 0,
    kneeY: 110,
    hipY: hipY,
    shoulderY: shoulderY,
    resultIssues: ResultIssues(),
  );
}

void main() {
  test('heel rise fault adds a post-rep voice cue with highest priority', () {
    final metric = HeelRiseMetric();

    for (var i = 0; i < 3; i++) {
      metric.update(
        _buildRepContext(
          squatState: SquatState.bottom,
          heelDistance: 12,
          scaleFactor: 100,
        ),
      );
    }

    expect(metric.faults, hasLength(1));
    expect(metric.faults.single.voiceMessage, 'Nhớ không nâng gót chân');
    expect(metric.faults.single.priority, SquatFaultVoicePriority.heelRise);
  });

  test('hip-shoulder sync fault adds a post-rep voice cue', () {
    final metric = HipShoulderSyncMetric();

    final contexts = [
      _buildRepContext(
        squatState: SquatState.ascending,
        hipY: 100,
        shoulderY: 100,
      ),
      _buildRepContext(
        squatState: SquatState.ascending,
        hipY: 97,
        shoulderY: 99.5,
      ),
      _buildRepContext(
        squatState: SquatState.ascending,
        hipY: 94,
        shoulderY: 99,
      ),
      _buildRepContext(
        squatState: SquatState.ascending,
        hipY: 91,
        shoulderY: 98.5,
      ),
      _buildRepContext(
        squatState: SquatState.ascending,
        hipY: 88,
        shoulderY: 98,
      ),
    ];

    for (final ctx in contexts) {
      metric.update(ctx);
    }

    expect(metric.faults, hasLength(1));
    expect(metric.faults.single.voiceMessage, 'Đừng nhấc hông lên trước');
    expect(
      metric.faults.single.priority,
      SquatFaultVoicePriority.hipShoulderSync,
    );
  });

  test('top post-rep voice picks the highest-priority fault only', () {
    final faults = <FaultRecord>[
      FaultRecord(
        phase: 'BOTTOM',
        type: 'Depth',
        message: 'Too shallow',
        voiceMessage: 'Xuống thấp hơn',
        priority: SquatFaultVoicePriority.depth,
      ),
      FaultRecord(
        phase: 'BOTTOM',
        type: 'Feet',
        message: 'Heels lifting',
        voiceMessage: 'Nhớ không nâng gót chân',
        priority: SquatFaultVoicePriority.heelRise,
      ),
      FaultRecord(
        phase: 'ASCENDING',
        type: 'Back',
        message: 'Leaned too forward',
        voiceMessage: 'Ưỡn ngực lên',
        priority: SquatFaultVoicePriority.trunkLean,
      ),
      FaultRecord(
        phase: 'ASCENDING',
        type: 'Tempo',
        message: 'Dropped too fast',
        voiceMessage: 'Chậm lại',
        priority: SquatFaultVoicePriority.tempo,
      ),
    ];

    final topFault = Squat.topVoicedFault(faults);
    final orderedMessages = Squat.orderedUniqueVoiceMessages(faults);

    expect(topFault?.voiceMessage, 'Nhớ không nâng gót chân');
    expect(topFault?.priority, SquatFaultVoicePriority.heelRise);
    expect(orderedMessages.first, 'Nhớ không nâng gót chân');
  });
}
