import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/recommendation/models/exercise_catalog_entry.dart';
import 'package:vika/services/recommendation/models/slot.dart';
import 'package:vika/services/recommendation/models/template.dart';
import 'package:vika/services/recommendation/progression_rules.dart';
import 'package:vika/services/recommendation/progression_service.dart';

ExerciseCatalogEntry _repExercise({
  String id = 'squat',
  int baseReps = 8,
  int beginnerCap = 10,
  String? progressionTo,
}) {
  return ExerciseCatalogEntry(
    id: id,
    vietnameseName: 'Squat',
    englishName: 'Squat',
    fork: 'both',
    bodyRegions: const ['lower_body'],
    muscleGroups: const ['quads', 'glutes'],
    difficultyTier: 1,
    goalFit: const {'health': 1},
    painSafe: const [],
    painContraindicated: const [],
    isFormChecked: true,
    isCorrective: false,
    correctiveFor: const [],
    baseReps: baseReps,
    maxRepsBeginner: beginnerCap,
    maxRepsIntermediate: 12,
    maxRepsAdvanced: 15,
    progressionTo: progressionTo,
  );
}

Template _template({
  int numPhases = 2,
  int weeksPerPhase = 3,
}) {
  return Template(
    key: 'home_health',
    fork: 'home',
    goal: 'health',
    vietnameseName: 'Tập tại nhà - Khỏe hơn',
    slots: const [
      Slot(
        name: 'lower',
        acceptedBodyRegions: ['lower_body'],
        difficultyRange: (min: 1, max: 3),
      ),
    ],
    phaseNames: List.generate(numPhases, (i) => 'Giai đoạn ${i + 1}'),
    deloadName: 'Phục hồi',
    numPhases: numPhases,
    weeksPerPhase: weeksPerPhase,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 60,
    defaultRestSecondsHold: 30,
  );
}

void main() {
  test('7-week default interpolates to cap and deloads from peak', () {
    final exercise = _repExercise();
    final template = _template();

    final reps = [
      for (var week = 1; week <= template.totalWeeks; week++)
        prescribeVolume(
          exercise: exercise,
          userTier: 1,
          absoluteWeek: week,
          template: template,
        ).reps,
    ];

    expect(reps, [8, 9, 9, 10, 10, 10, 7]);
  });

  test('deload uses the final progression target after tier cap clamp', () {
    final exercise = _repExercise(
      id: 'glute_bridge',
      baseReps: 12,
      beginnerCap: 10,
    );
    final template = _template();

    final weekOne = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: 1,
      template: template,
    );
    final peak = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: template.progressionWeeks,
      template: template,
    );
    final deload = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: template.totalWeeks,
      template: template,
    );

    expect(weekOne.reps, 10);
    expect(peak.reps, 10);
    expect(deload.reps, 7);
  });

  test('deload is anchored to peak week rather than week one', () {
    final exercise = _repExercise(
      id: 'squat',
      baseReps: 8,
      beginnerCap: 15,
    );
    final template = _template();

    final weekOne = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: 1,
      template: template,
    );
    final peak = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: template.progressionWeeks,
      template: template,
    );
    final deload = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: template.totalWeeks,
      template: template,
    );

    expect(weekOne.reps, 8);
    expect(peak.reps, 15);
    expect(deload.reps, 11);
  });

  test('12-week plans progress monotonically without exceeding cap', () {
    final exercise = _repExercise(beginnerCap: 12);
    final template = _template(numPhases: 3, weeksPerPhase: 4);

    final progressionReps = [
      for (var week = 1; week <= template.progressionWeeks; week++)
        prescribeVolume(
          exercise: exercise,
          userTier: 1,
          absoluteWeek: week,
          template: template,
        ).reps!,
    ];

    expect(progressionReps.first, 8);
    expect(progressionReps.last, 12);
    expect(progressionReps.every((value) => value <= 12), isTrue);
    for (var i = 1; i < progressionReps.length; i++) {
      expect(progressionReps[i], greaterThanOrEqualTo(progressionReps[i - 1]));
    }
  });

  test('carry-over lifts target but never exceeds tier cap', () {
    final exercise = _repExercise(beginnerCap: 10);
    final template = _template();
    final planned = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: 1,
      template: template,
      carryOver: const CarryOverPerformance(
        reps: 12,
        appliedRestSeconds: 45,
      ),
    );

    expect(planned.reps, 10);
    expect(planned.restSeconds, 45);
  });

  test('hard carry-over does not reduce planned rest', () {
    final exercise = _repExercise(beginnerCap: 10);
    final template = _template();
    final planned = prescribeVolume(
      exercise: exercise,
      userTier: 1,
      absoluteWeek: 2,
      template: template,
      carryOver: const CarryOverPerformance(
        reps: 10,
        appliedRestSeconds: 75,
        wasHard: true,
      ),
    );

    expect(planned.reps, 10);
    expect(planned.restSeconds, 60);
  });

  test('variant unlock requires cap hit and easy ratings', () {
    final exercise = _repExercise(progressionTo: 'split_squat');

    final qualifies = sessionQualifiesForVariantUnlock(
      exercise: exercise,
      userTier: 1,
      difficultyRatings: const ['easy', 'easy', 'easy'],
      setData: const [
        {'actual_reps': 10, 'applied_rest': 45},
      ],
    );

    final hardSession = sessionQualifiesForVariantUnlock(
      exercise: exercise,
      userTier: 1,
      difficultyRatings: const ['easy', 'hard'],
      setData: const [
        {'actual_reps': 10, 'applied_rest': 75},
      ],
    );

    expect(qualifies, isTrue);
    expect(hardSession, isFalse);
  });
}
