import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/recommendation/fitness_test_scoring.dart';

void main() {
  test('home scorer preserves beginner cap for poor compensation', () {
    final result = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '1y+',
        squatAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 1,
          peakKneeAngles: [68, 70, 72, 71, 69],
        ),
      ),
    );

    expect(result.suggestedLevel, 'beginner');
  });

  test('home scorer can suggest advanced from stable clean depth', () {
    final result = FitnessTestScorer.score(
      const FitnessTestScoringInput(
        fork: 'home',
        trainingDuration: '1y+',
        squatAssessment: FiveRepAssessment(
          totalReps: 5,
          goodReps: 5,
          peakKneeAngles: [66, 68, 67, 69, 66],
        ),
      ),
    );

    expect(result.suggestedLevel, 'advanced');
  });
}
