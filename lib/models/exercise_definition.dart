import 'package:flutter/material.dart';

import '../exercise/curl_up/curl_up.dart';
import '../exercise/exercise_base.dart';
import '../exercise/glute bridge/glute_bridge.dart';
import '../exercise/jumping jack/jumping_jack.dart';
import '../exercise/plank/plank.dart';
import '../exercise/lunge/lunge.dart';
import '../exercise/push up/push_up.dart';
import '../exercise/squat/squat.dart';
import '../exercise/warrior_1/warrior_one.dart';
import '../exercise/1.Bird Dog/bird_dog.dart';
import '../exercise/10.Vup/v_up.dart';
import '../exercise/12.Dead Bug/dead_bug.dart';
import '../exercise/13.Plank Up-Down/plank_up_down.dart';
import '../exercise/14.Bear Plank/bear_plank.dart';
import '../exercise/2.Sit-Up/sit_up.dart';
import '../exercise/3.High Plank/high_plank.dart';
import '../exercise/4.Mountain Climber/mountain_climber.dart';
import '../exercise/5.Superman/superman.dart';
import '../exercise/7.Plank Shoulder Tap/plank_shoulder_tap.dart';
import '../exercise/8.Leg Raises (Supine)/leg_raise.dart';
import '../exercise/9.Reverse Crunch/reverse_crunch.dart';
import '../exercise/ashtanga_namaskara/ashtanga_namaskara.dart';
import '../exercise/ashtanga_to_cobra/ashtanga_to_cobra.dart';
import '../exercise/ashwa_sanchalanasana/ashwa_sanchalanasana.dart';
import '../exercise/bow_pose/bow_pose.dart';
import '../exercise/butterfly_stretch/butterfly_stretch.dart';
import '../exercise/Cobra/cobra.dart';
import '../exercise/cossack_squat/cossack_squat.dart';
import '../exercise/hastapaadasana/hastapaadasana.dart';
import '../exercise/hasta_uttanasana/hasta_uttanasana.dart';
import '../exercise/Jump_Squat/jump_squat.dart';
import '../exercise/parvatasana/parvatasana.dart';
import '../exercise/pranamasana/pranamasana.dart';
import '../exercise/russian_twist/russian_twist.dart';
import '../exercise/seated_forward_fold/seated_forward_fold.dart';
import '../exercise/side_plank_dip/side_plank_dip.dart';
import '../exercise/Sphinx_Pose/sphinx_stretch.dart';
import '../exercise/standing_knee_to_elbow/standing_knee_to_elbow.dart';
import '../exercise/step_back_burpee/step_back_burpee.dart';
import '../exercise/tricep_dip/tricep_dip.dart';
import '../exercise/walking_lunge/walking_lunge.dart';

/* =========================================================================
   ExerciseDefinition — Metadata + factory for each exercise type.

   To add a new exercise:
   1. Create the exercise class extending ExerciseBase
   2. Add a new ExerciseDefinition entry to [exerciseDefinitions]
   3. Done — the Home tab and exercise flow will pick it up
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
  targetMuscles: ['Ngực', 'Vai', 'Core'],
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
    name: 'Jumping Jack',
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
  ExerciseDefinition(
    id: 'curl_up',
    name: 'McGill Curl-up',
    subtitle: 'Core on dinh va gap than co kiem soat',
    description:
        'AI theo doi bai curl-up theo thoi gian thuc.\nTap trung vao goc gap than, co va dau goi.',
    icon: Icons.accessibility_new_rounded,
    primaryColor: const Color(0xFF26A69A),
    secondaryColor: const Color(0xFF00695C),
    difficulty: 'De - Trung binh',
    targetMuscles: ['Core', 'Bung truoc', 'Hong'],
    duration: '12 reps',
    cameraHint: 'Quay nghieng nguoi so voi camera.',
    framingHint: 'Giu vai, hong, dau goi va tai trong khung hinh.',
    setupTips: [
      'Dat camera thap ngang than de thay ro duong vai-hong.',
      'Giu dau, vai va dau goi du sang truoc khi bat dau.',
      'Nam ngang tren san, gap mot dau goi theo dung tu the McGill.',
    ],
    createExercise: () => CurlUp(maxRep: 12),
    phaseColors: {
      'resting': const Color(0xFF00E676),
      'ascending': const Color(0xFFFFD600),
      'descending': const Color(0xFF00B0FF),
    },
  ),
   ExerciseDefinition(
    id: 'warrior_one',
    name: 'Warrior I',
    subtitle: 'Virabhadrasana I',
    description:
        'Giữ tư thế chiến binh tĩnh, mỗi bên 30 giây.\nAI theo dõi thân người, cổ, tay và chân sau theo thời gian thực.',
    icon: Icons.self_improvement,
    primaryColor: const Color(0xFFFFB300),
    secondaryColor: const Color(0xFFFF8F00),
    difficulty: 'Trung bình',
    targetMuscles: ['Đùi', 'Mông', 'Hông'],
    duration: '2 × 30s',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, tai, hai tay và cả hai chân trong khung hình.',
    setupTips: [
      'Đặt camera ngang hông, cách bạn khoảng 2–3 mét.',
      'Quay nghiêng 90° để AI thấy rõ chân trước, chân sau và thân người.',
      'Chừa khoảng trống phía trên đầu vì hai tay sẽ vươn cao.',
    ],
    safetyWarning:
        'Giữ thân người thẳng, không gập lưng quá mức. Dừng lại nếu thấy đau lưng dưới hoặc đầu gối.',
    createExercise: () => WarriorOne(),
    phaseColors: {
      'entry': const Color(0xFFFFB300),
      'hold': const Color(0xFF00E676),
      'exit': const Color(0xFF29B6F6),
    },
  ),
  ExerciseDefinition(
    id: 'bird__dog',
    name: 'Bird Dog',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Bird Dog.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => BirdDog(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'v__up',
    name: 'V-Up',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập V-Up.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => VUp(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'dead__bug',
    name: 'Dead Bug',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Dead Bug.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => DeadBug(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'plank__up__down',
    name: 'Plank Up-Down',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Plank Up-Down.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => PlankUpDown(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'bear__plank',
    name: 'Bear Plank',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Bear Plank.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => BearPlank(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'sit__up',
    name: 'Sit Up',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Sit Up.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => SitUp(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'high__plank',
    name: 'High Plank',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập High Plank.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => HighPlank(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'mountain__climber',
    name: 'Mountain Climber',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Mountain Climber.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => MountainClimber(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'superman',
    name: 'Superman',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Superman.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => Superman(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'plank__shoulder__tap',
    name: 'Plank Shoulder Tap',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Plank Shoulder Tap.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => PlankShoulderTap(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'leg__raises',
    name: 'Leg Raises',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Leg Raises.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => LegRaise(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'reverse__crunch',
    name: 'Reverse Crunch',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Reverse Crunch.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => ReverseCrunch(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'ashtanga__namaskara',
    name: 'Ashtanga Namaskara',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Ashtanga Namaskara.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => AshtangaNamaskara(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'ashtanga_to__cobra',
    name: 'Ashtanga to Cobra',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Ashtanga to Cobra.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => AshtangaToCobra(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'ashwa__sanchalanasana',
    name: 'Ashwa Sanchalanasana',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Ashwa Sanchalanasana.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => AshwaSanchalanasana(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'bow_',
    name: 'Bow Pose',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Bow Pose.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => BowPose(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'butterfly__stretch',
    name: 'Butterfly Stretch',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Butterfly Stretch.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => ButterflyStretch(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'cobra_',
    name: 'Cobra Pose',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Cobra Pose.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => Cobra(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'cossack__squat',
    name: 'Cossack Squat',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Cossack Squat.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => CossackSquat(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'hastapaadasana',
    name: 'Hastapaadasana',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Hastapaadasana.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => Hastapaadasana(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'hasta__uttanasana',
    name: 'Hasta Uttanasana',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Hasta Uttanasana.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => HastaUttanasana(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'jump__squat',
    name: 'Jump Squat',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Jump Squat.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => JumpSquat(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'parvatasana',
    name: 'Parvatasana',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Parvatasana.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => Parvatasana(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'pranamasana',
    name: 'Pranamasana',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Pranamasana.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => Pranamasana(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'russian__twist',
    name: 'Russian Twist',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Russian Twist.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => RussianTwist(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'seated__forward__fold',
    name: 'Seated Forward Fold',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Seated Forward Fold.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => SeatedForwardFold(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'side__plank_with__hip__dip',
    name: 'Side Plank with Hip Dip',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Side Plank with Hip Dip.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => SidePlankDip(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'sphinx_',
    name: 'Sphinx Pose',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Sphinx Pose.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => SphinxStretch(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'standing__knee_to__elbow',
    name: 'Standing Knee-to-Elbow',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Standing Knee-to-Elbow.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => StandingKneeToElbow(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'step__back__burpee',
    name: 'Step-Back Burpee',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Step-Back Burpee.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => StepBackBurpee(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'tricep__dip_(_floor)',
    name: 'Tricep Dip (Floor)',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Tricep Dip (Floor).',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => TricepDip(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'walking__lunge',
    name: 'Walking Lunge',
    subtitle: 'Chưa có mô tả',
    description: 'Bản xem trước của bài tập Walking Lunge.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: () => WalkingLunge(),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),

];
