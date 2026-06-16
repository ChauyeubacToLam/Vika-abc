import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/recommendation/fitness_test_scoring.dart';

void main() {
  test('2y+ with both assessments clean suggests advanced', () {
    final result = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '2y+',
        squatAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 5,
          peakKneeAngles: [],
        ),
        wallPushUpAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 5,
          peakKneeAngles: [],
        ),
      ),
    );

    expect(result.suggestedLevel, 'advanced');
  });

  test('2y+ with average clean below 40% degrades to intermediate', () {
    final result = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '2y+',
        squatAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 1,
          peakKneeAngles: [],
        ),
        wallPushUpAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 2,
          peakKneeAngles: [],
        ),
      ),
    );

    expect(result.suggestedLevel, 'intermediate');
  });

  test('<6m with clean movement stays beginner', () {
    final result = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '<6m',
        squatAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 5,
          peakKneeAngles: [],
        ),
        wallPushUpAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 5,
          peakKneeAngles: [],
        ),
      ),
    );

    expect(result.suggestedLevel, 'beginner');
  });

  test('<6m with poor movement stays beginner', () {
    final result = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '<6m',
        squatAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 0,
          peakKneeAngles: [],
        ),
        wallPushUpAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 1,
          peakKneeAngles: [],
        ),
      ),
    );

    expect(result.suggestedLevel, 'beginner');
  });

  test('one missing assessment uses the available clean ratio', () {
    final cleanSquatOnly = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '2y+',
        squatAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 5,
          peakKneeAngles: [],
        ),
      ),
    );
    final poorWallPushUpOnly = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '2y+',
        wallPushUpAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 1,
          peakKneeAngles: [],
        ),
      ),
    );

    expect(cleanSquatOnly.suggestedLevel, 'advanced');
    expect(poorWallPushUpOnly.suggestedLevel, 'intermediate');
  });

  group('yoga fork (clean-hold-seconds)', () {
    test('2y+ with clean holds suggests advanced', () {
      final result = FitnessTestScorer.score(
        const FitnessTestScoringInput(
          fork: 'yoga',
          trainingDuration: '2y+',
          warriorAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 30),
          forwardFoldAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 27),
        ),
      );

      expect(result.suggestedLevel, 'advanced');
    });

    test('6m-2y with avg clean-hold ratio below 50% degrades to beginner', () {
      final result = FitnessTestScorer.score(
        const FitnessTestScoringInput(
          fork: 'yoga',
          trainingDuration: '6m-2y',
          // 0.40 and 0.50 → avg 0.45 < 0.50 threshold.
          warriorAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 12),
          forwardFoldAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 15),
        ),
      );

      expect(result.suggestedLevel, 'beginner');
    });

    test('6m-2y with avg clean-hold ratio at/above 50% stays intermediate', () {
      final result = FitnessTestScorer.score(
        const FitnessTestScoringInput(
          fork: 'yoga',
          trainingDuration: '6m-2y',
          // 0.70 and 0.70 → avg 0.70 >= 0.50 threshold.
          warriorAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 21),
          forwardFoldAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 21),
        ),
      );

      expect(result.suggestedLevel, 'intermediate');
    });

    test('<6m stays beginner even with clean holds', () {
      final result = FitnessTestScorer.score(
        const FitnessTestScoringInput(
          fork: 'yoga',
          trainingDuration: '<6m',
          warriorAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 30),
        ),
      );

      expect(result.suggestedLevel, 'beginner');
    });

    test('no hold assessments fall back to the duration band', () {
      final result = FitnessTestScorer.score(
        const FitnessTestScoringInput(
          fork: 'yoga',
          trainingDuration: '6m-2y',
        ),
      );

      expect(result.suggestedLevel, 'intermediate');
    });

    test('one missing hold assessment uses the available clean ratio', () {
      final cleanWarriorOnly = FitnessTestScorer.score(
        const FitnessTestScoringInput(
          fork: 'yoga',
          trainingDuration: '2y+',
          warriorAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 30),
        ),
      );
      final poorFoldOnly = FitnessTestScorer.score(
        const FitnessTestScoringInput(
          fork: 'yoga',
          trainingDuration: '2y+',
          // 0.30 < 0.50 → degrade advanced → intermediate.
          forwardFoldAssessment:
              YogaHoldAssessment(totalSeconds: 30, goodSeconds: 9),
        ),
      );

      expect(cleanWarriorOnly.suggestedLevel, 'advanced');
      expect(poorFoldOnly.suggestedLevel, 'intermediate');
    });
  });
}
