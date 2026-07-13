import 'package:flutter/material.dart';

import '../services/catalog/catalog_source.dart';
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
import '../exercise/bow_pose/bow_pose.dart';
import '../exercise/butterfly_stretch/butterfly_stretch.dart';
import '../exercise/Cobra/cobra.dart';
import '../exercise/cossack_squat/cossack_squat.dart';
import '../exercise/Jump_Squat/jump_squat.dart';
import '../exercise/russian_twist/russian_twist.dart';
import '../exercise/seated_forward_fold/seated_forward_fold.dart';
import '../exercise/side_plank_dip/side_plank_dip.dart';
import '../exercise/Sphinx_Pose/sphinx_stretch.dart';
import '../exercise/standing_knee_to_elbow/standing_knee_to_elbow.dart';
import '../exercise/step_back_burpee/step_back_burpee.dart';
import '../exercise/tricep_dip/tricep_dip.dart';
import '../exercise/walking_lunge/walking_lunge.dart';
import '../exercise/surya_namaskar/surya_namaskar.dart';
import '../exercise/wall_push_up/wall_push_up.dart';
import '../exercise/downward_dog/downward_dog.dart';
import '../exercise/ashtanga_namaskara/ashtanga_namaskara.dart';
import '../exercise/low_lunge/low_lunge.dart';
import '../exercise/prayer_pose/prayer_pose.dart';
import '../exercise/raised_arms/raised_arms.dart';

typedef ExerciseFactory = ExerciseBase Function({int? reps, int? seconds});

enum ExerciseTargetType { reps, seconds }

ExerciseBase _withReps(
  int? reps,
  ExerciseBase Function(int reps) createWithTarget,
) {
  assert(
      reps != null, 'reps target must be supplied; no class default remains');
  return createWithTarget(reps ?? 1);
}

ExerciseBase _withSeconds(
  int? seconds,
  ExerciseBase Function(int seconds) createWithTarget,
) {
  assert(seconds != null,
      'seconds target must be supplied; no class default remains');
  return createWithTarget(seconds ?? 1);
}

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
  final String? videoAsset;
  final ExerciseFactory createExercise;
  final ExerciseTargetType targetType;

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
    this.videoAsset,
    required this.createExercise,
    this.targetType = ExerciseTargetType.reps,
    this.safetyWarning,
    required this.phaseColors,
  });
}

/// Display name resolved from the bundled catalog ([CatalogSource]) — the
/// single source of truth for exercise names. Assessment variants
/// (`<base>_assessment`) reuse the base exercise's catalog name, so onboarding
/// shows e.g. "Squat" rather than "Squat Assessment". Falls back to [name] only
/// before the catalog loads or for ids the catalog doesn't carry; [name] stays
/// the raw/build-time label.
extension ExerciseDefinitionDisplayName on ExerciseDefinition {
  String get displayName {
    final direct = CatalogSource.instance.lookup(id)?.vietnameseName;
    if (direct != null && direct.isNotEmpty) return direct;
    const suffix = '_assessment';
    if (id.endsWith(suffix)) {
      final base = id.substring(0, id.length - suffix.length);
      final vn = CatalogSource.instance.lookup(base)?.vietnameseName;
      if (vn != null && vn.isNotEmpty) return vn;
    }
    return name;
  }
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
  videoAsset: 'assets/video/squat.mp4',
  createExercise: ({int? reps, int? seconds}) => Squat(maxRep: reps ?? 5),
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
  videoAsset: 'assets/video/wall_pushup.mp4',
  createExercise: ({int? reps, int? seconds}) => WallPushUp(maxRep: reps ?? 5),
  phaseColors: {
    'standing': const Color(0xFF00E676),
    'descending': const Color(0xFFFFD600),
    'bottom': const Color(0xFFFF6D00),
    'ascending': const Color(0xFF00B0FF),
  },
);

/// Warrior I — one short hold for the yoga onboarding assessment.
final warriorOneAssessmentDefinition = ExerciseDefinition(
  id: 'warrior_one_assessment',
  name: 'Warrior I Assessment',
  subtitle: 'Kiểm tra tư thế Chiến Binh I',
  description: 'Giữ Chiến Binh I một bên để AI đánh giá thể lực của bạn.',
  icon: Icons.self_improvement,
  primaryColor: const Color(0xFF00E5FF),
  secondaryColor: const Color(0xFF0091EA),
  difficulty: 'Dễ',
  targetMuscles: ['Đùi', 'Mông', 'Hông'],
  duration: '30s',
  cameraHint: 'Quay nghiêng người so với camera.',
  framingHint: 'Giữ vai, hông, tai, hai tay và cả hai chân trong khung hình.',
  setupTips: [
    'Đặt camera ngang hông, cách bạn khoảng 2–3 mét.',
    'Quay nghiêng 90° để AI thấy rõ chân trước, chân sau và thân người.',
    'Chừa khoảng trống phía trên đầu vì hai tay sẽ vươn cao.',
  ],
  safetyWarning:
      'Giữ thân người thẳng, không gập lưng quá mức. Dừng lại nếu thấy đau lưng dưới hoặc đầu gối.',
  videoAsset: 'assets/video/warrior_I.mp4',
  createExercise: ({int? reps, int? seconds}) =>
      WarriorOne(maxHolds: reps ?? 1),
  phaseColors: {
    'entry': const Color(0xFFFFB300),
    'hold': const Color(0xFF00E676),
    'exit': const Color(0xFF29B6F6),
  },
);

/// Seated Forward Fold — one short hold for the yoga onboarding assessment.
final seatedForwardFoldAssessmentDefinition = ExerciseDefinition(
  id: 'seated_forward_fold_assessment',
  name: 'Seated Forward Fold Assessment',
  subtitle: 'Kiểm tra tư thế Gập Người',
  description: 'Gập người về trước và giữ 30 giây để AI đánh giá thể lực.',
  icon: Icons.self_improvement,
  primaryColor: const Color(0xFF00E5FF),
  secondaryColor: const Color(0xFF0091EA),
  difficulty: 'Dễ',
  targetMuscles: ['Gân kheo', 'Lưng dưới', 'Hông'],
  duration: '30s',
  cameraHint: 'Quay nghiêng người so với camera.',
  framingHint: 'Đặt điện thoại nằm ngang, thấy rõ vai, hông, gối và bàn chân.',
  setupTips: [
    'Ngồi duỗi thẳng hai chân, đặt camera quay ngang hông.',
    'Gập người từ khớp hông, đẩy ngực về phía mũi chân.',
    'Ưu tiên giữ gối thẳng, đừng cố gập sâu nếu phải co gối.',
  ],
  safetyWarning:
      'Gập từ từ theo hơi thở, đừng giật mạnh. Dừng nếu căng đau ở lưng dưới.',
  videoAsset: 'assets/video/seated_forward_fold.mp4',
  createExercise: ({int? reps, int? seconds}) =>
      SeatedForwardFold(maxSeconds: seconds ?? 30, maxHolds: 1),
  targetType: ExerciseTargetType.seconds,
  phaseColors: {
    'default': const Color(0xFF00E676),
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
    videoAsset: 'assets/video/squat.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => Squat(maxRep: target)),
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
    videoAsset: 'assets/video/plank.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => Plank(maxRep: target)),
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
    videoAsset: 'assets/video/lunge.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => Lunge(maxRep: target)),
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
    videoAsset: 'assets/video/jumping_jack.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => JumpingJack(maxRep: target)),
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
    videoAsset: 'assets/video/push_up.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => PushUp(maxRep: target)),
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
    videoAsset: 'assets/video/glute_bridge.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => GluteBridge(maxRep: target)),
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
    videoAsset: 'assets/video/curl_up.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => CurlUp(maxRep: target)),
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
    videoAsset: 'assets/video/warrior_I.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => WarriorOne(maxHolds: target)),
    phaseColors: {
      'entry': const Color(0xFFFFB300),
      'hold': const Color(0xFF00E676),
      'exit': const Color(0xFF29B6F6),
    },
  ),
  ExerciseDefinition(
    id: 'bird__dog',
    name: 'Bird Dog',
    subtitle: 'Giữ thăng bằng tay chân đối nghịch',
    description:
        'AI theo dõi bài Bird Dog theo thời gian thực.\nTay và chân đối nghịch duỗi thẳng hàng, lưng và hông giữ ổn định.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Core', 'Lưng dưới', 'Mông'],
    duration: '8 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, tay và chân duỗi luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ tay và chân duỗi thẳng hàng.',
      'Chống tay và gối xuống sàn, giữ lưng phẳng trước khi bắt đầu.',
    ],
    videoAsset: 'assets/video/bird_dog.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => BirdDog(maxRep: target)),
    phaseColors: {
      'neutral': const Color(0xFF00E676),
      'extending': const Color(0xFFFFD600),
      'hold_extended': const Color(0xFFFF6D00),
      'returning': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'v__up',
    name: 'Gập bụng chữ V',
    subtitle: 'Tay và chân gặp nhau thành chữ V',
    description:
        'AI phân tích bài gập bụng chữ V theo thời gian thực.\nTheo dõi tay vươn chạm chân, thân tạo chữ V và nhịp lên xuống.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Bụng', 'Cơ gập hông'],
    duration: '6 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ tay, vai, hông và bàn chân luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ tay và chân khép thành chữ V.',
      'Nằm ngửa trên sàn, duỗi thẳng tay và chân trước khi bắt đầu.',
    ],
    videoAsset: 'assets/video/v_up.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => VUp(maxRep: target)),
    phaseColors: {
      'lying': const Color(0xFF00E676),
      'rising': const Color(0xFFFFD600),
      'v_position': const Color(0xFFFF6D00),
      'lowering': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'dead__bug',
    name: 'Dead Bug',
    subtitle: 'Tay chân đối nghịch, lưng giữ phẳng',
    description:
        'AI theo dõi bài Dead Bug theo thời gian thực.\nTay và chân đối nghịch duỗi ra, lưng dưới giữ phẳng và kiểm soát.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Core', 'Bụng sâu'],
    duration: '8 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, tay và chân luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ tay và chân duỗi ra.',
      'Nằm ngửa, tay vươn lên và gối gập vuông trước khi bắt đầu.',
    ],
    videoAsset: 'assets/video/dead_bug.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => DeadBug(maxRep: target)),
    phaseColors: {
      'setup': const Color(0xFF00E676),
      'extending': const Color(0xFFFFD600),
      'hold': const Color(0xFFFF6D00),
      'returning': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'plank__up__down',
    name: 'Plank lên xuống',
    subtitle: 'Đổi tay khuỷu, thân giữ thẳng',
    description:
        'AI phân tích bài plank lên xuống theo thời gian thực.\nTheo dõi chuyển từ khuỷu lên bàn tay, thân giữ thẳng và nhịp độ.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Core', 'Vai', 'Tay sau'],
    duration: '8 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, khuỷu tay và cổ tay luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ chuyển động lên xuống của tay.',
      'Vào tư thế plank, giữ thân thẳng từ vai đến gót trước khi bắt đầu.',
    ],
    safetyWarning:
        'Dồn lực đều lên bàn tay, giữ cổ tay thẳng. Dừng lại nếu cổ tay đau.',
    videoAsset: 'assets/video/plank_up_down.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => PlankUpDown(maxRep: target)),
    phaseColors: {
      'forearm_plank': const Color(0xFF00E676),
      'pushing_up': const Color(0xFFFFD600),
      'high_plank': const Color(0xFFFF6D00),
      'lowering': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'bear__plank',
    name: 'Plank gấu',
    subtitle: 'Lưng phẳng, gối lơ lửng sát sàn',
    description:
        '3 lần giữ × 15 giây mỗi lần.\nAI theo dõi lưng giữ phẳng, hông ổn định và đầu gối lơ lửng sát sàn.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Core', 'Vai'],
    duration: '3 × 15s',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, đầu gối và cổ tay luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ đường lưng và đầu gối.',
      'Chống tay và mũi chân, nhấc gối cao vài phân trước khi bắt đầu.',
    ],
    safetyWarning:
        'Dồn lực đều lên bàn tay, giữ cổ tay thẳng. Dừng lại nếu cổ tay đau.',
    videoAsset: 'assets/video/bear_plank.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withSeconds(seconds, (target) => BearPlank(maxSeconds: target)),
    targetType: ExerciseTargetType.seconds,
    phaseColors: {
      'setup': const Color(0xFFFF6D00),
      'hovering': const Color(0xFF00E676),
      'fatiguing': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'sit__up',
    name: 'Gập bụng',
    subtitle: 'Theo dõi góc gập thân và nhịp độ',
    description:
        'AI phân tích bài gập bụng theo thời gian thực.\nTheo dõi góc gập thân, độ kiểm soát và nhịp lên xuống.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Bụng', 'Cơ gập hông'],
    duration: '10 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, đầu gối và bàn chân luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ góc gập thân.',
      'Nằm ngửa, gập gối và đặt bàn chân chạm sàn trước khi bắt đầu.',
    ],
    videoAsset: 'assets/video/sit_up.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => SitUp(maxRep: target)),
    phaseColors: {
      'lying': const Color(0xFF00E676),
      'rising': const Color(0xFFFFD600),
      'upright': const Color(0xFFFF6D00),
      'lowering': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'high__plank',
    name: 'Plank cao',
    subtitle: 'Thân thẳng, vai vững trên cổ tay',
    description:
        '3 lần giữ × 20 giây mỗi lần.\nAI theo dõi đường vai, hông và gót thẳng hàng, vai vững trên cổ tay.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Core', 'Vai'],
    duration: '3 × 20s',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, đầu gối và cổ tay luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ đường vai đến gót.',
      'Chống thẳng tay, xếp vai trên cổ tay trước khi bắt đầu.',
    ],
    safetyWarning:
        'Dồn lực đều lên bàn tay, giữ cổ tay thẳng. Dừng lại nếu cổ tay đau.',
    videoAsset: 'assets/video/high_plank.mp4',
    createExercise: ({int? reps, int? seconds}) {
      assert(seconds != null, 'High Plank per-hold seconds must be supplied');
      return HighPlank(
        // Interim catalog rows are seconds-only. They remain one hold until
        // the reps-of-holds catalog migration supplies base_reps.
        maxHolds: reps ?? 1,
        holdSeconds: seconds ?? 1,
      );
    },
    targetType: ExerciseTargetType.seconds,
    phaseColors: {
      'setup': const Color(0xFFFF6D00),
      'holding': const Color(0xFF00E676),
      'dropping': const Color(0xFF00B0FF),
      'resting': const Color(0xFFFFD600),
      'reArming': const Color(0xFFFFD600),
    },
  ),
  ExerciseDefinition(
    id: 'mountain__climber',
    name: 'Leo núi',
    subtitle: 'Đầu gối kéo về ngực, thân giữ thẳng',
    description:
        'AI phân tích bài leo núi theo thời gian thực.\nTheo dõi đầu gối kéo về ngực, thân giữ thẳng và nhịp độ.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Bụng', 'Cơ gập hông', 'Vai'],
    duration: '16 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, đầu gối và cổ tay luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ đầu gối kéo lên.',
      'Vào tư thế plank cao, vai trên cổ tay trước khi bắt đầu.',
    ],
    safetyWarning:
        'Dồn lực đều lên bàn tay, giữ cổ tay thẳng. Dừng lại nếu cổ tay đau.',
    videoAsset: 'assets/video/moutain_climber.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => MountainClimber(maxRep: target)),
    phaseColors: {
      'high_plank_base': const Color(0xFF00E676),
      'knee_driving_in': const Color(0xFFFFD600),
      'max_flexion': const Color(0xFFFF6D00),
    },
  ),
  ExerciseDefinition(
    id: 'superman',
    name: 'Superman',
    subtitle: 'Nâng tay chân, siết lưng và mông',
    description:
        '3 lần giữ × 15 giây mỗi lần.\nAI theo dõi tay và chân nâng khỏi sàn, lưng dưới và cơ mông siết đều.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Lưng dưới', 'Cơ dựng sống', 'Mông'],
    duration: '10 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, tay và chân luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ tay và chân nâng lên.',
      'Nằm sấp, duỗi thẳng tay về trước trước khi bắt đầu.',
    ],
    safetyWarning:
        'Nâng người vừa sức, không ưỡn lưng quá mức. Dừng lại nếu thấy đau lưng dưới hoặc cổ.',
    videoAsset: 'assets/video/superman.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => Superman(maxRep: target)),
    phaseColors: {
      'setup': const Color(0xFF00E676),
      'lifting': const Color(0xFFFFD600),
      'hold': const Color(0xFFFF6D00),
      'lowering': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'plank__shoulder__tap',
    name: 'Plank chạm vai',
    subtitle: 'Chạm vai đối diện, hông không lắc',
    description:
        'AI phân tích bài plank chạm vai theo thời gian thực.\nTheo dõi tay chạm vai đối diện, hông giữ vững không lắc và nhịp độ.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Core', 'Cơ liên sườn', 'Vai'],
    duration: '16 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, khuỷu tay và cổ tay luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ tay nhấc lên chạm vai.',
      'Vào tư thế plank cao, mở rộng hai chân để giữ vững trước khi bắt đầu.',
    ],
    safetyWarning:
        'Dồn lực đều lên bàn tay, giữ cổ tay thẳng. Dừng lại nếu cổ tay đau.',
    videoAsset: 'assets/video/plank_shoulder_tap.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => PlankShoulderTap(maxRep: target)),
    phaseColors: {
      'base': const Color(0xFF00E676),
      'lifting': const Color(0xFFFFD600),
      'tap': const Color(0xFFFF6D00),
      'returning': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'leg__raises',
    name: 'Nâng chân',
    subtitle: 'Chân nâng thẳng, lưng giữ ổn định',
    description:
        'AI phân tích bài nâng chân theo thời gian thực.\nTheo dõi chân nâng thẳng, bụng dưới siết và lưng giữ ổn định.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Bụng dưới', 'Cơ gập hông'],
    duration: '10 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, đầu gối và bàn chân luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ chân nâng lên và hạ xuống.',
      'Nằm ngửa, duỗi thẳng hai chân và ép lưng sát sàn trước khi bắt đầu.',
    ],
    videoAsset: 'assets/video/leg_raises.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => LegRaise(maxRep: target)),
    phaseColors: {
      'lying': const Color(0xFF00E676),
      'raising': const Color(0xFFFFD600),
      'top': const Color(0xFFFF6D00),
      'lowering': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'reverse__crunch',
    name: 'Gập bụng ngược',
    subtitle: 'Cuộn hông lên có kiểm soát',
    description:
        'AI phân tích bài gập bụng ngược theo thời gian thực.\nTheo dõi hông cuộn lên, bụng dưới siết và nhịp hạ chậm.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Bụng dưới'],
    duration: '10 reps',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, đầu gối và bàn chân luôn trong khung hình.',
    setupTips: [
      'Đặt camera thấp ngang thân (khoảng 30–50 cm so với mặt sàn).',
      'Quay nghiêng 90° để AI thấy rõ hông cuộn lên.',
      'Nằm ngửa, gập gối và nâng nhẹ chân trước khi bắt đầu.',
    ],
    videoAsset: 'assets/video/reverse_crunch.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => ReverseCrunch(maxRep: target)),
    phaseColors: {
      'lying': const Color(0xFF00E676),
      'curling': const Color(0xFFFFD600),
      'top': const Color(0xFFFF6D00),
      'lowering': const Color(0xFF00B0FF),
    },
  ),
  ExerciseDefinition(
    id: 'bow_',
    name: 'Bow Pose',
    subtitle: 'Nâng ngực và đùi thành hình cánh cung',
    description:
        '10 lần giữ × 15 giây. AI theo dõi kết nối tay-chân và độ nâng đồng đều của ngực và đùi theo thời gian thực.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Lưng dưới', 'Cơ dựng sống', 'Đùi trước'],
    duration: '10 × 15s',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, hông, gối và cổ chân trong khung hình.',
    setupTips: [
      'Nằm sấp, đặt camera thấp ngang thân, quay nghiêng 90°.',
      'Gập gối, đưa tay ra sau nắm lấy cổ chân.',
      'Hít vào, nâng ngực và đùi lên cùng lúc như một khối.',
    ],
    safetyWarning:
        'Nâng vừa sức, mắt nhìn xuống mép trước thảm. Dừng nếu đau lưng dưới hoặc cổ.',
    videoAsset: 'assets/video/bow_pose.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => BowPose(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'butterfly__stretch',
    name: 'Butterfly Stretch',
    subtitle: 'Mở háng, giãn cơ khép đùi',
    description:
        'Giữ tư thế bướm 30 giây. AI theo dõi độ mở của hai gối, lưng thẳng và vị trí bàn chân theo thời gian thực.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Người mới',
    targetMuscles: ['Cơ khép đùi', 'Háng', 'Hông'],
    duration: '30s',
    cameraHint: 'Đặt camera chính diện (camera trước).',
    framingHint: 'Ngồi trọn trong khung hình, thấy rõ hai gối và vai.',
    setupTips: [
      'Ngồi đối diện camera; có thể đặt điện thoại thẳng đứng hoặc nằm ngang.',
      'Chụm hai lòng bàn chân, kéo gót về gần hông.',
      'Giữ lưng thẳng, thả lỏng để hai gối rơi đều xuống sàn.',
    ],
    safetyWarning: 'Đừng dùng tay ép gối xuống. Để gối tự rơi theo nhịp thở.',
    createExercise: ({int? reps, int? seconds}) =>
        _withSeconds(seconds, (target) => ButterflyStretch(maxSeconds: target)),
    targetType: ExerciseTargetType.seconds,
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'cobra_',
    name: 'Cobra Pose',
    subtitle: 'Mở ngực, giãn nhẹ cột sống',
    description:
        '3 lần giữ × 15 giây. AI theo dõi độ nâng ngực, khuỷu tay, cổ và hông neo sàn theo thời gian thực.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Dễ – Trung bình',
    targetMuscles: ['Lưng dưới', 'Cơ dựng sống', 'Ngực'],
    duration: '3 × 15s',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Giữ vai, khuỷu tay, hông và cổ trong khung hình.',
    setupTips: [
      'Nằm sấp, đặt camera thấp ngang thân (30–50 cm so với sàn).',
      'Quay nghiêng 90° để AI thấy rõ độ cong lưng.',
      'Đặt hai tay dưới vai, khuỷu tay sát thân trước khi nâng ngực.',
    ],
    safetyWarning:
        'Nâng ngực vừa sức, đừng ép lưng dưới quá mức. Dừng lại nếu thấy đau lưng hoặc cổ.',
    videoAsset: 'assets/video/cobra.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => Cobra(maxRep: target)),
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
    videoAsset: 'assets/video/cossack_squat.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => CossackSquat(maxRep: target)),
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
    videoAsset: 'assets/video/jump_squat.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => JumpSquat(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'russian__twist',
    name: 'Russian Twist',
    subtitle: 'Vặn chéo thân, siết cơ liên sườn',
    description:
        'AI phân tích bài Russian Twist theo thời gian thực.\nTheo dõi biên độ vặn hai bên, xoay ngực và giữ thân dưới ổn định.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Cơ liên sườn', 'Core', 'Bụng'],
    duration: '20 reps',
    cameraHint: 'Đặt camera chính diện trước mặt.',
    framingHint: 'Ngồi đối diện camera, thấy rõ hai vai, hai tay, hông và gối.',
    setupTips: [
      'Đặt điện thoại nằm ngang trước mặt, ngang tầm ngực.',
      'Ngồi ngả lưng ra sau khoảng 45 độ, co gối, hai tay chụm trước ngực.',
      'Giữ hai vai và hai tay luôn trong khung hình khi vặn sang hai bên.',
    ],
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => RussianTwist(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'seated__forward__fold',
    name: 'Seated Forward Fold',
    subtitle: 'Giãn gân kheo và lưng dưới',
    description:
        '3 lần giữ × 15 giây. Gập nhẹ từ hông trong biên độ thoải mái; AI theo dõi gối và cột sống theo thời gian thực.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Người mới',
    targetMuscles: ['Gân kheo', 'Lưng dưới', 'Hông'],
    duration: '3 × 15s',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint:
        'Đặt điện thoại nằm ngang, thấy rõ vai, hông, gối và bàn chân.',
    setupTips: [
      'Ngồi duỗi thẳng hai chân, đặt camera quay ngang hông.',
      'Gập người từ khớp hông, đẩy ngực về phía mũi chân.',
      'Ưu tiên giữ gối thẳng, đừng cố gập sâu nếu phải co gối.',
    ],
    safetyWarning:
        'Gập từ từ theo hơi thở, đừng giật mạnh. Dừng nếu căng đau ở lưng dưới.',
    videoAsset: 'assets/video/seated_forward_fold.mp4',
    createExercise: ({int? reps, int? seconds}) => _withSeconds(seconds,
        (target) => SeatedForwardFold(maxSeconds: target, maxHolds: 1)),
    targetType: ExerciseTargetType.seconds,
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'side__plank_with__hip__dip',
    name: 'Side Plank',
    subtitle: 'Giữ plank nghiêng tĩnh',
    description:
        '3 lần giữ × 15 giây. Giữ vai, hông và cổ chân trên một đường thẳng; không hạ hông đếm rep.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: '3 × 15s',
    cameraHint: 'Đặt camera quay ngang người.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Chống một khuỷu tay ngay dưới vai và duỗi thẳng hai chân.',
      'Nâng hông để vai, hông và cổ chân thành một đường thẳng.',
      'Giữ nguyên tư thế; đồng hồ dừng khi thân người mất thẳng hàng.'
    ],
    videoAsset: 'assets/video/side_plank.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withSeconds(seconds, (target) => SidePlankDip(maxSeconds: target)),
    targetType: ExerciseTargetType.seconds,
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'sphinx_',
    name: 'Sphinx Pose',
    subtitle: 'Mở nhẹ cột sống trên cẳng tay',
    description:
        '3 lần giữ × 15 giây. Chống cẳng tay, nâng ngực nhẹ; AI theo dõi góc khuỷu tay và cổ vai theo thời gian thực.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Người mới',
    targetMuscles: ['Lưng dưới', 'Cơ dựng sống'],
    duration: '3 × 15s',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đặt điện thoại nằm ngang, thấy rõ vai, khuỷu tay và hông.',
    setupTips: [
      'Nằm sấp, chống hai cẳng tay xuống sàn, khuỷu ngay dưới vai.',
      'Đặt camera thấp ngang thân, quay nghiêng 90°.',
      'Thả lỏng thân dưới và kéo dài cổ trước khi nâng ngực.',
    ],
    safetyWarning:
        'Giữ cẳng tay đỡ lực — đừng duỗi thẳng tay thành Cobra. Dừng nếu đau lưng dưới.',
    videoAsset: 'assets/video/sphinx_pose.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withSeconds(seconds, (target) => SphinxStretch(maxSeconds: target)),
    targetType: ExerciseTargetType.seconds,
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'standing__knee_to__elbow',
    name: 'Standing Knee-to-Elbow',
    subtitle: 'Gối chéo chạm khuỷu tay',
    description:
        'Luân phiên kéo gối lên chạm khuỷu tay đối diện rồi hạ chân về tư thế đứng. AI chỉ đếm một chu kỳ nâng–chạm–hạ hoàn chỉnh.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Đứng chính diện, giữ toàn thân và hai bàn chân trong khung hình.',
      'Nâng hai khuỷu tay ngang vai, kéo một gối về khuỷu tay đối diện.',
      'Chạm rõ rồi hạ chân về vị trí đứng trước khi đổi bên.'
    ],
    videoAsset: 'assets/video/standing_knee_to_elbow.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => StandingKneeToElbow(maxRep: target)),
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
    videoAsset: 'assets/video/step_back_burpee.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => StepBackBurpee(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'tricep__dip_(_floor)',
    name: 'Tricep Dip (Floor)',
    subtitle: 'Nhấc hông với tay sau chống sàn',
    description:
        'Ngồi chạm mông xuống sàn, giữ bàn tay và bàn chân chống chắc; mỗi lần nhấc mông đủ cao được tính một rep.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Đặt camera đối diện hoặc nghiêng góc 45 độ.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Ngồi nghiêng với camera, mông chạm sàn, hai tay chống phía sau.',
      'Giữ bàn tay và bàn chân cùng chống chắc xuống sàn.',
      'Nhấc mông lên rõ ràng, sau đó hạ chạm sàn trước rep tiếp theo.'
    ],
    videoAsset: 'assets/video/trace_dip.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => TricepDip(maxRep: target)),
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
    videoAsset: 'assets/video/walking_lunge.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => WalkingLunge(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'surya_namaskar',
    name: 'Chào Mặt Trời',
    subtitle: 'Chuỗi 12 tư thế yoga',
    description: 'Bản xem trước của bài tập Chào Mặt Trời.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => SuryaNamaskarExercise(maxRounds: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'wall_push_up',
    name: 'Wall Push Up',
    subtitle: 'Chống đẩy tường',
    description: 'Bản xem trước của bài tập Wall Push Up.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Dễ',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    videoAsset: 'assets/video/wall_pushup.mp4',
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => WallPushUp(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'downward_dog',
    name: 'Chó Cúi Mặt',
    subtitle: 'Downward Dog',
    description: 'Bản xem trước của bài tập Downward Dog.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => DownwardDog(maxHolds: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'ashtanga_namaskara',
    name: 'Ashtanga Namaskara',
    subtitle: 'Tám điểm chạm đất',
    description: 'Bản xem trước của bài tập Ashtanga Namaskara.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => AshtangaNamaskara(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'low_lunge',
    name: 'Kỵ Sĩ',
    subtitle: 'Low Lunge',
    description: 'Bản xem trước của bài tập Low Lunge.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Trung bình',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => LowLunge(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'prayer_pose',
    name: 'Cầu Nguyện',
    subtitle: 'Prayer Pose',
    description: 'Bản xem trước của bài tập Prayer Pose.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Dễ',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => PrayerPose(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
  ExerciseDefinition(
    id: 'raised_arms',
    name: 'Vươn Tay',
    subtitle: 'Raised Arms',
    description: 'Bản xem trước của bài tập Raised Arms.',
    icon: Icons.fitness_center,
    primaryColor: const Color(0xFF00E5FF),
    secondaryColor: const Color(0xFF0091EA),
    difficulty: 'Dễ',
    targetMuscles: ['Toàn thân'],
    duration: 'Tùy chọn',
    cameraHint: 'Quay nghiêng người so với camera.',
    framingHint: 'Đảm bảo toàn thân nằm gọn trong khung hình.',
    setupTips: [
      'Giữ đủ khoảng cách để AI nhận diện được toàn bộ cơ thể.',
      'Bắt đầu khi sẵn sàng.'
    ],
    createExercise: ({int? reps, int? seconds}) =>
        _withReps(reps, (target) => RaisedArms(maxRep: target)),
    phaseColors: {
      'default': const Color(0xFF00E676),
    },
  ),
];
