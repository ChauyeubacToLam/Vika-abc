import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/cossack_squat/cossack_squat.dart';
import 'package:vika/exercise/cossack_squat/metrics/cossack_metric_base.dart';
import 'package:vika/exercise/cossack_squat/metrics/heel_lift_metric.dart';
import 'package:vika/exercise/cossack_squat/metrics/knee_valgus_metric.dart';
import 'package:vika/exercise/cossack_squat/metrics/straight_leg_metric.dart';
import 'package:vika/exercise/exercise_base.dart';

CossackRepContext _ctx({
  double workingHeelDistance = 0,
  double workingKneeX = 120,
  double workingAnkleX = 100,
  double straightKneeAngle = 170,
  ResultIssues? issues,
}) {
  return CossackRepContext(
    workingLeg: WorkingLeg.right,
    workingHeelDistance: workingHeelDistance,
    workingKneeX: workingKneeX,
    workingAnkleX: workingAnkleX,
    workingFootIndexX: 100,
    scaleFactor: 100,
    workingKneeAngle: 100,
    straightKneeAngle: straightKneeAngle,
    torsoAngle: 20,
    state: CossackState.bottom,
    frameTimestamp: 0,
    resultIssues: issues ?? ResultIssues(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('heel lift metric publishes live feedback', () {
    final issues = ResultIssues();
    final metric = CossackHeelLiftMetric();

    metric.update(_ctx(workingHeelDistance: 0.12, issues: issues));

    expect(issues.feedback, contains('heel'));
    expect(metric.faults.single.type, 'heel');
  });

  test('knee valgus metric publishes live feedback', () {
    final issues = ResultIssues();
    final metric = CossackKneeValgusMetric();

    metric.update(
      _ctx(
        workingKneeX: 130,
        workingAnkleX: 100,
        issues: issues,
      ),
    );

    expect(issues.feedback, contains('knee_valgus'));
    expect(metric.faults.single.type, 'knee_valgus');
  });

  test('straight leg metric publishes live feedback', () {
    final issues = ResultIssues();
    final metric = CossackStraightLegMetric();

    metric.update(_ctx(straightKneeAngle: 130, issues: issues));

    expect(issues.feedback, contains('straight_leg'));
    expect(metric.faults.single.type, 'straight_leg');
  });
}
