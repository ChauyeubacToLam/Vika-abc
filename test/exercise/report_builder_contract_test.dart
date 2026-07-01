import 'package:flutter_test/flutter_test.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class _SecondBasedBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_fails': 'Trục thân',
        'neck_fails_count': 'Cổ vai',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_fails': (
          watch: 'Giữ thân ổn định.',
          next: 'Siết bụng trước khi giữ.',
        ),
        'neck_fails_count': (
          watch: 'Giữ cổ cùng đường với thân.',
          next: 'Nhìn xuống sàn và thả lỏng vai.',
        ),
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}

void main() {
  group('ExerciseReportBuilder shared contract', () {
    test('aggregates both _fails and _fails_count fault keys', () {
      final logger = ExerciseLogger()
        ..pushKey('total_seconds', 30.0)
        ..pushKey('good_seconds', 24.0)
        ..pushKey('max_rep', 1)
        ..pushKey('good_rep_count', 0)
        ..pushKey('trunk_fails', 2)
        ..pushKey('neck_fails_count', 1);

      final report = _SecondBasedBuilder().buildReport(
        setLoggers: [logger],
        exerciseName: 'Hold',
        metValue: 3.0,
      );

      expect(report.faultCounts['trunk_fails'], 2);
      expect(report.faultCounts['neck_fails_count'], 1);
    });

    test('scores hold exercises with seconds instead of max_rep', () {
      final logger = ExerciseLogger()
        ..pushKey('total_seconds', 40.0)
        ..pushKey('good_seconds', 30.0)
        ..pushKey('max_rep', 1)
        ..pushKey('good_rep_count', 0);

      final report = _SecondBasedBuilder().buildReport(
        setLoggers: [logger],
        exerciseName: 'Hold',
        metValue: 3.0,
      );

      expect(report.isSecondBased, isTrue);
      expect(report.formScore, 75);
      expect(report.totalReps, isNull);
      expect(report.totalGoodReps, isNull);
      expect(report.totalSeconds, 40.0);
      expect(report.goodSeconds, 30.0);
      expect(report.sets.single.score, 75);
    });
  });
}
