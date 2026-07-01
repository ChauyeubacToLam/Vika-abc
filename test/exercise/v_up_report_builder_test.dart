import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/10.Vup/v_up_report_builder.dart';

void main() {
  group('VUpReportBuilder', () {
    test('tempo_fails_count is coachable and praiseable', () {
      final builder = VUpReportBuilder();
      final tempoTip = builder.faultToTipMap()['tempo_fails_count'];

      expect(tempoTip, isNotNull);
      expect(tempoTip!.watch, isNotEmpty);
      expect(tempoTip.next, isNotEmpty);

      final candidates = builder.buildFaultCandidates(
        exerciseId: 'v_up',
        exerciseName: 'V-Up',
        exerciseFormScore: 75,
        faultCounts: const {'tempo_fails_count': 1},
        totalReps: 4,
        userPainAreas: const [],
      );

      expect(candidates.single.faultKey, 'tempo_fails_count');
      expect(builder.praiseMetricNames()['tempo_fails_count'], 'Kiểm soát');
      expect(builder.praiseSentenceMap().keys, contains('Kiểm soát'));
    });
  });
}
