import 'package:shared_preferences/shared_preferences.dart';

import '../interpreter/intepreting_map.dart';

class UserProgramData {
  const UserProgramData({
    required this.userName,
    required this.level,
    required this.goalKey,
    required this.isPro,
    required this.workoutDays,
    required this.workouts,
  });

  final String userName;
  final String level;
  final String goalKey;
  final bool isPro;
  final List<int> workoutDays;
  final List<UserWorkoutData> workouts;
}

class UserWorkoutData {
  const UserWorkoutData({
    required this.title,
    required this.duration,
    required this.muscles,
    required this.exercises,
    this.issueTag = '',
  });

  final String title;
  final String duration;
  final List<String> muscles;
  final List<UserExerciseData> exercises;
  final String issueTag;
}

class UserExerciseData {
  const UserExerciseData({
    required this.name,
    required this.sets,
    required this.pose,
    this.isCorrective = false,
    this.bodyRegion = '',
  });

  final String name;
  final String sets;
  final String pose;
  final bool isCorrective;
  final String bodyRegion;
}

class UserProgramService {
  const UserProgramService._();

  static const _defaultWorkoutDays = [0, 2, 4];

  static const goalExercisePatterns = <String, List<List<String>>>{
    'health': [
      ['squat', 'plank', 'glute_bridge', 'bird_dog'],
      ['lunge', 'bird_dog', 'plank', 'squat'],
      ['squat', 'glute_bridge', 'bird_dog', 'plank'],
    ],
    'body': [
      ['squat', 'lunge', 'plank', 'glute_bridge'],
      ['glute_bridge', 'mcgill_curl_up', 'jumping_jack', 'squat'],
      ['squat', 'plank', 'lunge', 'glute_bridge'],
    ],
    'strength': [
      ['squat', 'glute_bridge', 'plank', 'push_up'],
      ['push_up', 'plank', 'mcgill_curl_up', 'squat'],
      ['squat', 'glute_bridge', 'plank', 'push_up'],
    ],
    'flexible': [
      ['squat', 'bird_dog', 'cat_cow', 'plank'],
      ['glute_bridge', 'plank', 'bird_dog', 'cat_cow'],
      ['squat', 'cat_cow', 'plank', 'bird_dog'],
    ],
  };

  static const exerciseRegistry = <String, UserExerciseData>{
    'squat': UserExerciseData(name: 'Squat', sets: '3×8', pose: 'squat'),
    'plank': UserExerciseData(name: 'Plank', sets: '3×20s', pose: 'plank'),
    'glute_bridge':
        UserExerciseData(name: 'Glute Bridge', sets: '3×10', pose: 'bridge'),
    'lunge': UserExerciseData(name: 'Lunge', sets: '3×8', pose: 'lunge'),
    'bird_dog':
        UserExerciseData(name: 'Bird Dog', sets: '3×8', pose: 'birddog'),
    'mcgill_curl_up':
        UserExerciseData(name: 'McGill Curl-up', sets: '3×8', pose: 'curlup'),
    'jumping_jack':
        UserExerciseData(name: 'Jumping Jack', sets: '3×15', pose: 'jump'),
    'push_up': UserExerciseData(name: 'Push-up', sets: '3×6', pose: 'pushup'),
    'cat_cow': UserExerciseData(name: 'Cat-Cow', sets: '3×8', pose: 'catcow'),
  };

  static const correctiveRegistry = <String, UserExerciseData>{
    'wall_calf_stretch': UserExerciseData(
      name: 'Wall Calf Stretch',
      sets: '30s ×3',
      pose: 'stretch',
      isCorrective: true,
    ),
    'kneeling_hip_flexor_stretch': UserExerciseData(
      name: 'Kneeling Hip Flexor Stretch',
      sets: '30s ×3',
      pose: 'stretch',
      isCorrective: true,
    ),
    'floor_glute_bridge': UserExerciseData(
      name: 'Floor Glute Bridge',
      sets: '3×10',
      pose: 'bridge',
      isCorrective: true,
    ),
    'wall_squat': UserExerciseData(
      name: 'Wall Squat',
      sets: '20s ×3',
      pose: 'squat',
      isCorrective: true,
    ),
    'bird_dog': UserExerciseData(
      name: 'Bird Dog',
      sets: '3×8',
      pose: 'birddog',
      isCorrective: true,
    ),
    'hip_flexor_stretch': UserExerciseData(
      name: 'Hip Flexor Stretch',
      sets: '30s ×3',
      pose: 'stretch',
      isCorrective: true,
    ),
    'bodyweight_squat_to_box': UserExerciseData(
      name: 'Squat ghế',
      sets: '3×8',
      pose: 'squat',
      isCorrective: true,
    ),
    'seated_toe_raise': UserExerciseData(
      name: 'Nâng mũi chân',
      sets: '3×15',
      pose: 'stretch',
      isCorrective: true,
    ),
  };

  static const exerciseMuscles = <String, List<String>>{
    'Squat': ['Đùi', 'Mông', 'Core'],
    'Lunge': ['Đùi', 'Mông', 'Hông'],
    'Glute Bridge': ['Mông', 'Hông', 'Core'],
    'Plank': ['Core', 'Vai', 'Thân trên'],
    'Push-up': ['Ngực', 'Vai', 'Core'],
    'Bird Dog': ['Core', 'Lưng', 'Hông'],
    'McGill Curl-up': ['Core', 'Bụng'],
    'Jumping Jack': ['Cardio', 'Toàn thân'],
    'Cat-Cow': ['Cột sống', 'Core'],
  };

  static Future<UserProgramData> loadAssignedProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDays = prefs.getStringList('user_workout_days') ?? const [];
    final workoutDays = rawDays
        .map(int.tryParse)
        .whereType<int>()
        .where((day) => day >= 0 && day <= 6)
        .toSet()
        .toList()
      ..sort();

    return buildProgram(
      userName: (prefs.getString('display_name') ?? '').trim(),
      level: prefs.getString('user_level') ?? 'beginner',
      goal: prefs.getString('user_goal'),
      workoutDays: workoutDays.isEmpty ? _defaultWorkoutDays : workoutDays,
      detectedIssues: prefs.getStringList('detected_issues') ?? const [],
      isPro: prefs.getBool('user_is_pro') ?? false,
    );
  }

  static UserProgramData buildProgram({
    required String userName,
    required String level,
    required String? goal,
    required List<int> workoutDays,
    required List<String> detectedIssues,
    required bool isPro,
  }) {
    final sortedDays = workoutDays.isEmpty
        ? List<int>.from(_defaultWorkoutDays)
        : List<int>.from(workoutDays)
      ..sort();
    final goalKey = normalizeGoal(goal);
    final goalPatterns =
        goalExercisePatterns[goalKey] ?? goalExercisePatterns['health']!;
    final topIssue = detectedIssues.isEmpty ? null : detectedIssues.first;

    final workouts = List.generate(sortedDays.length, (dayIndex) {
      final pattern = goalPatterns[dayIndex % goalPatterns.length];
      final mainExerciseIds = pattern.take(3).toList(growable: false);
      final mainExercises = mainExerciseIds
          .map((id) => exerciseRegistry[id] ?? exerciseRegistry['plank']!)
          .toList(growable: false);
      final corrective = _buildCorrectiveExercise(
        topIssue,
        dayIndex,
        mainExerciseIds,
        mainExercises,
      );
      final fallback = _fallbackMainExercise(pattern, mainExercises);
      final summary = _summarizeWorkout(mainExercises);

      return UserWorkoutData(
        title: summary.title,
        duration: summary.duration,
        muscles: summary.muscles,
        issueTag: corrective == null
            ? ''
            : issueSubtitleForRegion(corrective.bodyRegion),
        exercises: [
          ...mainExercises,
          corrective ?? fallback,
        ],
      );
    });

    return UserProgramData(
      userName: userName,
      level: level,
      goalKey: goalKey,
      isPro: isPro,
      workoutDays: sortedDays,
      workouts: workouts,
    );
  }

  static Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_is_pro', value);
  }

  static String normalizeGoal(String? goal) {
    switch (goal) {
      case 'health':
      case 'Sức khỏe':
        return 'health';
      case 'body':
      case 'shape':
      case 'Vóc dáng':
        return 'body';
      case 'strength':
      case 'Sức mạnh':
        return 'strength';
      case 'flexible':
      case 'flexibility':
      case 'Linh hoạt':
        return 'flexible';
      default:
        return 'health';
    }
  }

  static String silhouetteType(String pose) {
    switch (pose) {
      case 'stretch':
        return 'lunge';
      case 'birddog':
        return 'plank';
      case 'catcow':
        return 'bridge';
      default:
        return pose;
    }
  }

  static String issueSubtitleForRegion(String bodyRegion) {
    switch (bodyRegion) {
      case 'ankle':
        return 'Cải thiện cổ chân';
      case 'hip':
        return 'Cải thiện hông';
      case 'core':
        return 'Tăng cường core';
      case 'shoulder':
        return 'Cải thiện vai';
      default:
        return '';
    }
  }

  static String levelLabel(String level) {
    switch (level) {
      case 'advanced':
        return 'Nâng cao';
      case 'intermediate':
        return 'Trung cấp';
      default:
        return 'Cơ bản';
    }
  }

  static UserExerciseData? _buildCorrectiveExercise(
    String? issueId,
    int dayIndex,
    List<String> mainExerciseIds,
    List<UserExerciseData> mainExercises,
  ) {
    if (issueId == null) {
      return null;
    }

    final definition = interpretingMap[issueId];
    if (definition == null) {
      return null;
    }

    final correctiveIds = definition.correctives.whereType<String>().toList();
    if (correctiveIds.isEmpty) {
      return null;
    }

    final bodyRegion = definition.bodyRegion;
    final mainKeys = mainExerciseIds.map(_movementKey).toSet();
    for (var offset = 0; offset < correctiveIds.length; offset++) {
      final correctiveId =
          correctiveIds[(dayIndex + offset) % correctiveIds.length];
      final base = correctiveRegistry[correctiveId];
      if (base == null) {
        continue;
      }
      if (mainKeys.contains(_movementKey(correctiveId)) ||
          mainExercises.any((exercise) => exercise.name == base.name)) {
        continue;
      }

      return UserExerciseData(
        name: base.name,
        sets: base.sets,
        pose: base.pose,
        isCorrective: true,
        bodyRegion: bodyRegion,
      );
    }

    return null;
  }

  static UserExerciseData _fallbackMainExercise(
    List<String> pattern,
    List<UserExerciseData> mainExercises,
  ) {
    for (final fallbackId in pattern.skip(3)) {
      final candidate = exerciseRegistry[fallbackId];
      if (candidate == null) {
        continue;
      }
      if (!mainExercises.any((exercise) => exercise.name == candidate.name)) {
        return candidate;
      }
    }

    return exerciseRegistry.values.firstWhere(
      (candidate) =>
          !mainExercises.any((exercise) => exercise.name == candidate.name),
      orElse: () => exerciseRegistry['plank']!,
    );
  }

  static _WorkoutSummary _summarizeWorkout(
      List<UserExerciseData> mainExercises) {
    const lowerBody = {'Squat', 'Lunge', 'Glute Bridge'};
    const coreHeavy = {
      'Plank',
      'Bird Dog',
      'McGill Curl-up',
      'Push-up',
      'Cat-Cow',
    };
    const mixed = {'Jumping Jack'};

    var lowerScore = 0;
    var coreScore = 0;
    var mixedScore = 0;

    for (final exercise in mainExercises) {
      if (lowerBody.contains(exercise.name)) {
        lowerScore++;
      }
      if (coreHeavy.contains(exercise.name)) {
        coreScore++;
      }
      if (mixed.contains(exercise.name)) {
        mixedScore++;
      }
    }

    final title = lowerScore >= 2
        ? 'Chân & Mông'
        : coreScore >= 2 && mixedScore == 0
            ? 'Core & Thân trên'
            : 'Toàn thân';

    final duration = switch (title) {
      'Chân & Mông' => '15 phút',
      'Core & Thân trên' => '12 phút',
      _ => '18 phút',
    };

    final muscles = <String>[];
    for (final exercise in mainExercises) {
      for (final muscle in exerciseMuscles[exercise.name] ?? const <String>[]) {
        if (!muscles.contains(muscle)) {
          muscles.add(muscle);
        }
      }
    }

    return _WorkoutSummary(
      title: title,
      duration: duration,
      muscles: muscles.isEmpty ? const ['Toàn thân'] : muscles.take(4).toList(),
    );
  }

  static String _movementKey(String? exerciseId) {
    switch (exerciseId) {
      case 'floor_glute_bridge':
        return 'glute_bridge';
      case null:
        return '';
      default:
        return exerciseId;
    }
  }
}

class _WorkoutSummary {
  const _WorkoutSummary({
    required this.title,
    required this.duration,
    required this.muscles,
  });

  final String title;
  final String duration;
  final List<String> muscles;
}
