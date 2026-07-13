import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models/exercise_catalog_entry.dart';
import 'models/plan.dart';
import 'models/template.dart';

const int kDefaultVariantUnlockStreak = 3;

const int _kFallbackBeginnerReps = 10;
const int _kFallbackIntermediateReps = 12;
const int _kFallbackAdvancedReps = 15;

const int _kFallbackBeginnerSeconds = 25;
const int _kFallbackIntermediateSeconds = 35;
const int _kFallbackAdvancedSeconds = 45;

const double _kDeloadTargetFactor = 0.75;
const int _kMinRepTarget = 1;
const int _kMinHoldTargetSeconds = 5;

class CarryOverPerformance {
  const CarryOverPerformance({
    this.reps,
    this.seconds,
    this.appliedRestSeconds,
    this.wasHard = false,
    this.isDeloadSource = false,
  });

  final int? reps;
  final int? seconds;
  final int? appliedRestSeconds;
  final bool wasHard;
  final bool isDeloadSource;
}

VolumePrescription prescribeVolume({
  required ExerciseCatalogEntry exercise,
  required int userTier,
  required int absoluteWeek,
  required Template template,
  CarryOverPerformance? carryOver,
}) {
  final progressionWeeks = template.progressionWeeks;
  final isDeloadWeek =
      template.includeDeloadAtEnd && absoluteWeek == progressionWeeks + 1;

  if (absoluteWeek < 1 || absoluteWeek > template.totalWeeks) {
    throw RangeError.value(
      absoluteWeek,
      'absoluteWeek',
      'must be within this template plan',
    );
  }

  final isRepBased = exercise.isRepBased;
  final isHybridHold = exercise.isHybridHold;
  if (!isRepBased && !isHybridHold) {
    throw StateError(
      'Exercise ${exercise.id} must have baseReps or baseSeconds set.',
    );
  }
  if (isHybridHold && exercise.baseReps == null) {
    debugPrint(
      '[ProgressionRules] hybrid exercise ${exercise.id} is missing baseReps; '
      'defaulting hold count to 1 until the catalog migration lands.',
    );
  }

  final sets = prescribeSets(
    absoluteWeek: absoluteWeek,
    template: template,
    isDeloadWeek: isDeloadWeek,
  );

  final plannedRest = isHybridHold
      ? template.defaultRestSecondsHold
      : template.defaultRestSecondsRep;

  final plannedReps = isRepBased
      ? _plannedRepTarget(
          exercise: exercise,
          userTier: userTier,
          absoluteWeek: absoluteWeek,
          progressionWeeks: progressionWeeks,
          isDeloadWeek: isDeloadWeek,
        )
      : exercise.baseReps ?? 1;
  final plannedSeconds = isHybridHold
      ? _plannedSecondTarget(
          exercise: exercise,
          userTier: userTier,
          absoluteWeek: absoluteWeek,
          progressionWeeks: progressionWeeks,
          isDeloadWeek: isDeloadWeek,
        )
      : null;

  final prescription = VolumePrescription(
    sets: sets,
    reps: plannedReps,
    seconds: plannedSeconds,
    restSeconds: plannedRest,
    isDeloadWeek: isDeloadWeek,
  );

  if (isDeloadWeek || carryOver == null || carryOver.isDeloadSource) {
    return prescription;
  }

  return applyCarryOverFloor(
    planned: prescription,
    exercise: exercise,
    userTier: userTier,
    carryOver: carryOver,
  );
}

VolumePrescription applyCarryOverFloor({
  required VolumePrescription planned,
  required ExerciseCatalogEntry exercise,
  required int userTier,
  required CarryOverPerformance carryOver,
}) {
  if (planned.isDeloadWeek || carryOver.isDeloadSource) return planned;

  final isRepBased = exercise.isRepBased;
  final cap = isRepBased
      ? tierRepCap(exercise: exercise, tier: userTier)
      : tierSecondCap(exercise: exercise, tier: userTier);

  final carriedTarget = isRepBased ? carryOver.reps : carryOver.seconds;
  final plannedTarget = isRepBased ? planned.reps : planned.seconds;
  final shouldCarryTarget = carriedTarget != null &&
      plannedTarget != null &&
      carriedTarget > plannedTarget;

  final nextTarget =
      shouldCarryTarget ? math.min(carriedTarget, cap) : plannedTarget;

  final carriedRest = carryOver.appliedRestSeconds;
  final nextRest = !carryOver.wasHard &&
          carriedRest != null &&
          carriedTarget != null &&
          plannedTarget != null &&
          carriedTarget >= plannedTarget
      ? math.min(planned.restSeconds, carriedRest)
      : planned.restSeconds;

  return VolumePrescription(
    sets: planned.sets,
    reps: isRepBased ? nextTarget : planned.reps,
    seconds: exercise.isHybridHold ? nextTarget : null,
    restSeconds: nextRest,
    isDeloadWeek: planned.isDeloadWeek,
  );
}

int prescribeSets({
  required int absoluteWeek,
  required Template template,
  required bool isDeloadWeek,
}) {
  final progressionWeeks = template.progressionWeeks;
  if (isDeloadWeek) {
    return 2;
  }
  if (absoluteWeek < 1 || absoluteWeek > progressionWeeks) {
    throw RangeError.value(
      absoluteWeek,
      'absoluteWeek',
      'must be within progression weeks unless deload',
    );
  }

  final acclimationWeeks = math.min(
    2,
    math.max(1, (progressionWeeks * 0.20).round()),
  );
  return absoluteWeek <= acclimationWeeks ? 2 : 3;
}

int tierRepCap({
  required ExerciseCatalogEntry exercise,
  required int tier,
}) {
  RangeError.checkValueInInterval(tier, 1, 3, 'tier');
  return switch (tier) {
    1 => exercise.maxRepsBeginner ?? _kFallbackBeginnerReps,
    2 => exercise.maxRepsIntermediate ?? _kFallbackIntermediateReps,
    3 => exercise.maxRepsAdvanced ?? _kFallbackAdvancedReps,
    _ => throw StateError('unreachable'),
  };
}

int tierSecondCap({
  required ExerciseCatalogEntry exercise,
  required int tier,
}) {
  RangeError.checkValueInInterval(tier, 1, 3, 'tier');
  return switch (tier) {
    1 => exercise.maxSecondsBeginner ?? _kFallbackBeginnerSeconds,
    2 => exercise.maxSecondsIntermediate ?? _kFallbackIntermediateSeconds,
    3 => exercise.maxSecondsAdvanced ?? _kFallbackAdvancedSeconds,
    _ => throw StateError('unreachable'),
  };
}

int levelToTier(String fitnessLevel) {
  return switch (fitnessLevel) {
    'beginner' => 1,
    'intermediate' => 2,
    'advanced' => 3,
    _ => 1,
  };
}

({int phase, int weekInPhase}) phaseAndWeek({
  required int absoluteWeek,
  required int weeksPerPhase,
}) {
  if (absoluteWeek < 1) {
    throw RangeError.value(absoluteWeek, 'absoluteWeek', 'must be >= 1');
  }
  if (weeksPerPhase < 1) {
    throw RangeError.value(weeksPerPhase, 'weeksPerPhase', 'must be >= 1');
  }

  return (
    phase: ((absoluteWeek - 1) ~/ weeksPerPhase) + 1,
    weekInPhase: ((absoluteWeek - 1) % weeksPerPhase) + 1,
  );
}

int _plannedRepTarget({
  required ExerciseCatalogEntry exercise,
  required int userTier,
  required int absoluteWeek,
  required int progressionWeeks,
  required bool isDeloadWeek,
}) {
  final start = _startingRepTarget(exercise, userTier);
  final cap = tierRepCap(exercise: exercise, tier: userTier);
  final effectiveStart = start.clamp(_kMinRepTarget, cap);
  if (isDeloadWeek) {
    final peak = _interpolatedTarget(
      start: effectiveStart,
      cap: cap,
      absoluteWeek: progressionWeeks,
      progressionWeeks: progressionWeeks,
      minValue: _kMinRepTarget,
    );
    return math.max(
      _kMinRepTarget,
      (peak * _kDeloadTargetFactor).floor(),
    );
  }

  return _interpolatedTarget(
    start: effectiveStart,
    cap: cap,
    absoluteWeek: absoluteWeek,
    progressionWeeks: progressionWeeks,
    minValue: _kMinRepTarget,
  );
}

int _plannedSecondTarget({
  required ExerciseCatalogEntry exercise,
  required int userTier,
  required int absoluteWeek,
  required int progressionWeeks,
  required bool isDeloadWeek,
}) {
  final start = _startingSecondTarget(exercise, userTier);
  final cap = tierSecondCap(exercise: exercise, tier: userTier);
  final effectiveStart = start.clamp(_kMinHoldTargetSeconds, cap);
  if (isDeloadWeek) {
    final peak = _interpolatedTarget(
      start: effectiveStart,
      cap: cap,
      absoluteWeek: progressionWeeks,
      progressionWeeks: progressionWeeks,
      minValue: _kMinHoldTargetSeconds,
    );
    return math.max(
      _kMinHoldTargetSeconds,
      (peak * _kDeloadTargetFactor).floor(),
    );
  }

  return _interpolatedTarget(
    start: effectiveStart,
    cap: cap,
    absoluteWeek: absoluteWeek,
    progressionWeeks: progressionWeeks,
    minValue: _kMinHoldTargetSeconds,
  );
}

int _interpolatedTarget({
  required int start,
  required int cap,
  required int absoluteWeek,
  required int progressionWeeks,
  required int minValue,
}) {
  final safeStart = start.clamp(minValue, cap);
  if (progressionWeeks <= 1 || absoluteWeek <= 1 || safeStart >= cap) {
    return safeStart;
  }

  final t = ((absoluteWeek - 1) / (progressionWeeks - 1)).clamp(0.0, 1.0);
  final raw = safeStart + ((cap - safeStart) * t);
  return raw.ceil().clamp(safeStart, cap);
}

int _startingRepTarget(ExerciseCatalogEntry exercise, int userTier) {
  final base = exercise.baseReps;
  if (base == null) {
    throw ArgumentError(
        'Rep target requested for hold exercise ${exercise.id}');
  }

  final adjusted = base +
      switch (userTier) {
        1 => 0,
        2 => 1,
        3 => 2,
        _ => throw RangeError.value(userTier, 'userTier', 'must be 1, 2, or 3'),
      };
  return math.max(_kMinRepTarget, adjusted);
}

int _startingSecondTarget(ExerciseCatalogEntry exercise, int userTier) {
  final base = exercise.baseSeconds;
  if (base == null) {
    throw ArgumentError(
      'Second target requested for rep exercise ${exercise.id}',
    );
  }

  final adjusted = base +
      switch (userTier) {
        1 => 0,
        2 => 5,
        3 => 10,
        _ => throw RangeError.value(userTier, 'userTier', 'must be 1, 2, or 3'),
      };
  return math.max(_kMinHoldTargetSeconds, adjusted);
}

extension ExerciseCatalogVolumeX on ExerciseCatalogEntry {
  bool get isRepBased => baseReps != null && baseSeconds == null;
  bool get isHybridHold => baseSeconds != null;
}
