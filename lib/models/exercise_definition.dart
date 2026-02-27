import 'package:flutter/material.dart';

import '../exercise/exercise_base.dart';
import '../exercise/squat/squat.dart';
import '../exercise/plank/plank.dart';

/* =========================================================================
   ExerciseDefinition — Metadata + factory for each exercise type.

   To add a new exercise:
   1. Create the exercise class extending ExerciseBase
   2. Add a new ExerciseDefinition entry to [exerciseDefinitions]
   3. Done — the HomeScreen and ExerciseScreen will pick it up
   ========================================================================= */

class ExerciseDefinition {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String difficulty;
  final List<String> targetMuscles;
  final String duration;
  final ExerciseBase Function() createExercise;

  /// Maps phaseKey → Color for the state pill during activated state.
  final Map<String, Color> phaseColors;

  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.difficulty,
    required this.targetMuscles,
    required this.duration,
    required this.createExercise,
    required this.phaseColors,
  });
}

/* =========================================================================
   EXERCISE REGISTRY — Add new exercises here.
   ========================================================================= */

final List<ExerciseDefinition> exerciseDefinitions = [
  ExerciseDefinition(
    id: 'squat',
    name: 'Squat',
    subtitle: 'Phân tích tư thế Squat',
    description:
        'AI phân tích form squat theo thời gian thực.\nTheo dõi độ sâu, thân trên, nhịp và nhiều hơn.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Đùi', 'Mông', 'Core'],
    duration: '15 reps',
    createExercise: () => Squat(),
    phaseColors: {
      'standing': const Color(0xFF00E676),
      'descending': const Color(0xFFFFD600),
      'bottom': const Color(0xFFFF6D00),
      'ascending': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'plank',
    name: 'Plank',
    subtitle: 'McGill Short-Hold Protocol',
    description:
        '3 lần giữ × 10 giây mỗi lần.\nPhân tích thân trên, cổ và đầu gối theo thời gian thực.',
    icon: Icons.self_improvement,
    primaryColor: const Color(0xFFFF9800),
    secondaryColor: const Color(0xFFE65100),
    difficulty: 'Dễ – Trung bình',
    targetMuscles: ['Core', 'Vai', 'Lưng'],
    duration: '3 × 10s',
    createExercise: () => Plank(),
    phaseColors: {
      'setup': const Color(0xFFFF9800),
      'holding': const Color(0xFF00E676),
      'resting': const Color(0xFF29B6F6),
    },
  ),
];
