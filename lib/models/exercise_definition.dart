import 'package:flutter/material.dart';

import '../exercise/exercise_base.dart';
import '../exercise/glute bridge/glute_bridge.dart';
import '../exercise/jumping jack/jumping_jack.dart';
import '../exercise/plank/plank.dart';
import '../exercise/lunge/lunge.dart';
import '../exercise/curl_up/curl_up.dart';
import '../exercise/push up/push_up.dart';
import '../exercise/squat/squat.dart';

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
  final String cameraHint;
  final String framingHint;
  final List<String> setupTips;
  final ExerciseBase Function() createExercise;

  /// Optional safety warning shown prominently before exercise starts.
  final String? safetyWarning;

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
    required this.cameraHint,
    required this.framingHint,
    required this.setupTips,
    required this.createExercise,
    this.safetyWarning,
    required this.phaseColors,
  });
}

/* =========================================================================
   EXERCISE REGISTRY — Add new exercises here.
   ========================================================================= */

/// ------------------ 5-rep for onboarding assessment. ------------------
/// Squat
final squatAssessmentDefinition = ExerciseDefinition(
  id: 'squat_assessment',
  name: 'Squat Assessment',
  subtitle: 'Kiểm tra tư thế Squat',
  description: '5 squats để AI đánh giá thể lực của bạn.',
  icon: Icons.fitness_center,
  primaryColor: const Color(0xFF00E5FF),
  secondaryColor: const Color(0xFF0091EA),
  difficulty: 'Dễ',
  targetMuscles: ['Đùi', 'Mông', 'Core'],
  duration: '5 reps',
  cameraHint: 'Đứng nghiêng người so với camera.',
  framingHint: 'Giữ vai, hông, gối, mắt cá và bàn chân trong khung hình.',
  setupTips: [
    'Đặt camera ngang hông, cách bạn khoảng 2–3 mét.',
    'Quay nghiêng 90° để AI thấy rõ độ sâu và thân người.',
    'Giữ đủ ánh sáng ở chân và thân trên trước khi bắt đầu.',
  ],
  createExercise: () => Squat(maxRep: 5),
  phaseColors: {
    'standing': const Color(0xFF00E676),
    'descending': const Color(0xFFFFD600),
    'bottom': const Color(0xFFFF6D00),
    'ascending': const Color(0xFF00B0FF),
  },
);

/// Wall- push up
final wallPushupAssessmentDefinition = ExerciseDefinition(
  id: 'wall_pushup_assessment',
  name: 'Wall Pushup Assessment',
  subtitle: 'Kiểm tra tư thế Wall Pushup',
  description: '5 wall pushups để AI đánh giá thể lực của bạn.',
  icon: Icons.fitness_center,
  primaryColor: const Color(0xFF00E5FF),
  secondaryColor: const Color(0xFF0091EA),
  difficulty: 'Dễ',
  targetMuscles: ['Đùi', 'Mông', 'Core'],
  duration: '5 reps',
  cameraHint: 'Đứng nghiêng người so với camera.',
  framingHint: 'Giữ vai, hông, gối, mắt cá và bàn chân trong khung hình.',
  setupTips: [
    'Đặt camera ngang hông, cách bạn khoảng 2–3 mét.',
    'Quay nghiêng 90° để AI thấy rõ độ sâu và thân người.',
    'Giữ đủ ánh sáng ở chân và thân trên trước khi bắt đầu.',
  ],
  createExercise: () => PushUp(maxRep: 5),
  phaseColors: {
    'standing': const Color(0xFF00E676),
    'descending': const Color(0xFFFFD600),
    'bottom': const Color(0xFFFF6D00),
    'ascending': const Color(0xFF00B0FF),
  },
);
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
    cameraHint: 'Đứng nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, gối, mắt cá và bàn chân trong khung hình.',
    setupTips: [
      'Đặt camera ngang hông, cách bạn khoảng 2–3 mét.',
      'Quay nghiêng 90° để AI thấy rõ độ sâu và thân người.',
      'Giữ đủ ánh sáng ở chân và thân trên trước khi bắt đầu.',
    ],
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
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Ưu tiên thấy rõ vai, hông, tai và đầu gối.',
    setupTips: [
      'Đặt điện thoại thấp ngang thân người để thấy rõ thân plank.',
      'Giữ phần thân trên sáng và không che khuất vai/hông.',
      'Nếu không đủ chỗ, vẫn cố gắng giữ đầu gối và mông trọn khung.',
    ],
    createExercise: () => Plank(),
    phaseColors: {
      'setup': const Color(0xFFFF9800),
      'holding': const Color(0xFF00E676),
      'resting': const Color(0xFF29B6F6),
    },
  ),
  ExerciseDefinition(
    id: 'lunge',
    name: 'Lunge',
    subtitle: 'Phân tích tư thế Lunge',
    description:
        'AI phân tích form lunge theo thời gian thực.\nTheo dõi độ sâu, đầu gối, gót chân và thân trên.',
    icon: Icons.directions_walk,
    primaryColor: const Color(0xFF7C4DFF),
    secondaryColor: const Color(0xFF6200EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Đùi', 'Mông', 'Hamstring'],
    duration: '10 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, gối và bàn chân trong khung hình.',
    setupTips: [
      'Đặt camera ngang hông, cách bạn khoảng 2–3 mét.',
      'Quay nghiêng 90° để AI thấy rõ độ sâu đầu gối.',
      'Giữ đủ ánh sáng ở chân và thân trên trước khi bắt đầu.',
    ],
    createExercise: () => Lunge(),
    phaseColors: {
      'standing': const Color(0xFF00E676),
      'descending': const Color(0xFFFFD600),
      'bottom': const Color(0xFFFF6D00),
      'ascending': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'jumping_jack',
    name: 'Jumping   Jack',
    subtitle: 'Cardio nhẹ cho dân văn phòng',
    description:
        'AI phân tích tư thế nhảy dạng.\nTheo dõi tay, chân và nhịp độ.',
    icon: Icons.directions_run,
    primaryColor: const Color(0xFF76FF03),
    secondaryColor: const Color(0xFF64DD17),
    difficulty: 'Dễ',
    targetMuscles: ['Toàn thân', 'Vai', 'Chân'],
    duration: '30 reps',
    cameraHint: 'Đứng đối diện camera.',
    framingHint: 'Giữ toàn thân, hai tay và hai chân luôn ở trong khung hình.',
    setupTips: [
      'Lùi xa camera để khi dang tay và chân vẫn không bị cắt khung.',
      'Giữ đầu, cổ tay và mắt cá luôn nhìn thấy rõ.',
      'Chừa khoảng trống phía trên đầu vì tay sẽ vươn cao qua đầu.',
    ],
    createExercise: () => JumpingJack(),
    phaseColors: {
      'closed': const Color(0xFF00E676),
      'open': const Color(0xFFFFD600),
    },
  ),
  ExerciseDefinition(
    id: 'push_up',
    name: 'Push Up',
    subtitle: 'Theo dõi độ sâu và thân người',
    description:
        'AI phân tích chống đẩy theo thời gian thực.\nTheo dõi thân người, độ sâu và nhịp độ.',
    icon: Icons.sports_gymnastics,
    primaryColor: const Color(0xFFFF6E40),
    secondaryColor: const Color(0xFFFF3D00),
    difficulty: 'Trung bình',
    targetMuscles: ['Ngực', 'Vai', 'Core'],
    duration: '15 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, khuỷu tay, cổ tay và hông luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân để thấy rõ đường vai–hông.',
      'Giữ thân trên và khuỷu tay đủ sáng trước khi bắt đầu.',
      'Lùi camera thêm nếu cổ tay hoặc đầu dễ bị cắt khung.',
    ],
    createExercise: () => PushUp(),
    phaseColors: {
      'plank': const Color(0xFF00E676),
      'descending': const Color(0xFFFFD600),
      'bottom': const Color(0xFFFF6D00),
      'ascending': const Color(0xFFFF6E40),
    },
  ),
  ExerciseDefinition(
    id: 'glute_bridge',
    name: 'Glute Bridge',
    subtitle: 'Kích hoạt mông và lưng dưới',
    description:
        'AI phân tích tư thế cầu mông theo thời gian thực.\nTheo dõi độ nâng hông, giữ đỉnh và nhịp độ hạ xuống.',
    icon: Icons.airline_seat_flat,
    primaryColor: const Color(0xFFE040FB),
    secondaryColor: const Color(0xFF7B1FA2),
    difficulty: 'Dễ – Trung bình',
    targetMuscles: ['Mông', 'Hamstring', 'Lưng dưới'],
    duration: '15 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, gối và bàn chân luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ chuyển động hông.',
      'Đảm bảo đủ ánh sáng dọc theo thân người trước khi bắt đầu.',
    ],
    createExercise: () => GluteBridge(),
    phaseColors: {
      'bottom': const Color(0xFF00E676),
      'ascending': const Color(0xFFFFD600),
      'topHold': const Color(0xFFE040FB),
      'descending': const Color(0xFF00B0FF),
    },
  ),
];
