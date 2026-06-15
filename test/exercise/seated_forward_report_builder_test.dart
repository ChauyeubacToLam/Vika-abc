import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/report_builder_registry.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_report_builder.dart';
import 'package:vika/utils/exercise_logger.dart';

const _kneeBentNext =
    'Bạn có xu hướng co gối để gập được sâu hơn. Hãy ưu tiên giữ thẳng gối, dù không gập được sâu, cơ gân kheo mới được kéo giãn thực sự.';

ExerciseLogger _mockSeatedForwardLogger() {
  return ExerciseLogger()
    ..pushKey('total_seconds', 20)
    ..pushKey('good_seconds', 15)
    ..pushKey('knee_bent_seconds', 2)
    ..pushKey('spine_round_seconds', 1);
}

void main() {
  group('SeatedForwardReportBuilder', () {
    test('scores hold logs from good_seconds over total_seconds', () {
      final report = SeatedForwardReportBuilder().buildReport(
        setLoggers: [_mockSeatedForwardLogger()],
        exerciseName: 'Seated Forward Fold',
        metValue: 2.5,
      );

      expect(report.isSecondBased, isTrue);
      expect(report.formScore, 75);
      expect(report.sets.single.score, 75);
    });

    test('uses highest real fault-count key for coach tip', () {
      final tip = SeatedForwardReportBuilder()
          .buildCoachTip(_mockSeatedForwardLogger());

      expect(tip, _kneeBentNext);
    });

    test('builds pain-linked fault candidates from canonical pain regions', () {
      final builder = SeatedForwardReportBuilder();
      final report = builder.buildReport(
        setLoggers: [_mockSeatedForwardLogger()],
        exerciseName: 'Seated Forward Fold',
        metValue: 2.5,
      );

      final candidates = builder.buildFaultCandidates(
        exerciseId: 'seated_forward_fold',
        exerciseName: 'Seated Forward Fold',
        exerciseFormScore: report.formScore,
        faultCounts: report.faultCounts,
        totalReps: 20,
        userPainAreas: const ['lower_back'],
      );
      final spineCandidate = candidates.singleWhere(
        (candidate) => candidate.faultKey == 'spine_round_seconds',
      );

      expect(spineCandidate.isPainLinked, isTrue);
      expect(spineCandidate.watchCopy, isNotEmpty);
      expect(spineCandidate.nextCopy, isNotEmpty);
    });

    test('registry resolves seated forward fold to custom builder', () {
      final direct = resolveReportBuilder('seated_forward_fold').builder;
      final catalogId = resolveReportBuilder('seated__forward__fold').builder;

      expect(direct, isA<SeatedForwardReportBuilder>());
      expect(direct, isNot(isA<GenericReportBuilder>()));
      expect(catalogId, isA<SeatedForwardReportBuilder>());
    });
  });
}
