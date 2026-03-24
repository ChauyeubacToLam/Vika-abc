import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';

class DashboardUser {
  const DashboardUser({
    required this.name,
    required this.initial,
    required this.dateLabel,
    required this.level,
    required this.levelTitle,
    required this.xp,
    required this.nextLevelXp,
    required this.workoutCount,
    required this.totalTime,
    required this.completionRate,
  });

  final String name;
  final String initial;
  final String dateLabel;
  final int level;
  final String levelTitle;
  final int xp;
  final int nextLevelXp;
  final int workoutCount;
  final String totalTime;
  final String completionRate;

  double get xpProgress => xp / nextLevelXp;
}

class HomeInsightData {
  const HomeInsightData({
    required this.tag,
    required this.value,
    required this.metric,
    required this.description,
    required this.spark,
    required this.color,
    required this.background,
  });

  final String tag;
  final String value;
  final String metric;
  final String description;
  final List<double> spark;
  final Color color;
  final Color background;
}

class MetricCardData {
  const MetricCardData({
    required this.value,
    required this.label,
    this.accent = false,
  });

  final String value;
  final String label;
  final bool accent;
}

class WeekStripDay {
  const WeekStripDay({
    required this.label,
    this.isDone = false,
    this.isToday = false,
  });

  final String label;
  final bool isDone;
  final bool isToday;
}

class ExerciseTagData {
  const ExerciseTagData({
    required this.name,
    required this.color,
    required this.background,
    this.isAi = false,
  });

  final String name;
  final Color color;
  final Color background;
  final bool isAi;
}

class TodayWorkoutData {
  const TodayWorkoutData({
    required this.label,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.badgeBackground,
    required this.progress,
    required this.meta,
    required this.exercises,
  });

  final String label;
  final String title;
  final String badge;
  final Color badgeColor;
  final Color badgeBackground;
  final double progress;
  final String meta;
  final List<ExerciseTagData> exercises;
}

class PremiumWorkoutData {
  const PremiumWorkoutData({
    required this.label,
    required this.title,
    required this.description,
    required this.tags,
  });

  final String label;
  final String title;
  final String description;
  final List<ExerciseTagData> tags;
}

class MuscleTagData {
  const MuscleTagData({
    required this.name,
    required this.color,
  });

  final String name;
  final Color color;
}

class PlanDayData {
  const PlanDayData.rest({
    required this.shortDay,
  })  : label = '',
        focus = '',
        duration = '',
        exerciseCount = 0,
        color = VFTheme.surfaceAlt,
        background = VFTheme.surfaceAlt,
        muscles = const [],
        exercisePreview = const [],
        isRest = true;

  const PlanDayData.workout({
    required this.shortDay,
    required this.label,
    required this.focus,
    required this.duration,
    required this.exerciseCount,
    required this.color,
    required this.background,
    required this.muscles,
    required this.exercisePreview,
  }) : isRest = false;

  final String shortDay;
  final String label;
  final String focus;
  final String duration;
  final int exerciseCount;
  final Color color;
  final Color background;
  final List<MuscleTagData> muscles;
  final List<String> exercisePreview;
  final bool isRest;
}

class PlanWeekData {
  const PlanWeekData({
    required this.label,
    required this.subtitle,
    required this.workouts,
    required this.days,
  });

  final String label;
  final String subtitle;
  final int workouts;
  final List<PlanDayData> days;
}

class CoachInsightData {
  const CoachInsightData({
    required this.iconText,
    required this.title,
    required this.detail,
    required this.color,
    required this.background,
    required this.isFree,
  });

  final String iconText;
  final String title;
  final String detail;
  final Color color;
  final Color background;
  final bool isFree;
}

class GlowMetricData {
  const GlowMetricData({
    required this.valueLabel,
    required this.progress,
    required this.label,
    required this.color,
  });

  final String valueLabel;
  final double progress;
  final String label;
  final Color color;
}

class AngleFigureData {
  const AngleFigureData({
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.angle,
  });

  final Offset hip;
  final Offset knee;
  final Offset ankle;
  final String angle;
}

class FormComparisonData {
  const FormComparisonData({
    required this.name,
    required this.color,
    required this.background,
    required this.delta,
    required this.label,
    required this.before,
    required this.after,
  });

  final String name;
  final Color color;
  final Color background;
  final String delta;
  final String label;
  final AngleFigureData before;
  final AngleFigureData after;
}

class WeeklyCompletionData {
  const WeeklyCompletionData({
    required this.label,
    required this.done,
    required this.total,
    this.isCurrent = false,
    this.isFuture = false,
  });

  final String label;
  final int done;
  final int total;
  final bool isCurrent;
  final bool isFuture;

  double get progress => total == 0 ? 0 : done / total;
}

class BadgeShelfItem {
  const BadgeShelfItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.background,
    required this.earned,
  });

  final String name;
  final IconData icon;
  final Color color;
  final Color background;
  final bool earned;
}

class SettingItemData {
  const SettingItemData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;
}

class MuscleGroupData {
  const MuscleGroupData({
    required this.id,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String id;
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final Color background;
}

class ExerciseBrowserItem {
  const ExerciseBrowserItem({
    required this.name,
    required this.groupId,
    required this.typeLabel,
    required this.muscles,
    required this.color,
    required this.background,
    required this.difficulty,
  });

  final String name;
  final String groupId;
  final String typeLabel;
  final String muscles;
  final Color color;
  final Color background;
  final int difficulty;

  bool get isAi => typeLabel == 'AI';
}

const dashboardUser = DashboardUser(
  name: 'Nam',
  initial: 'N',
  dateLabel: 'Thứ Tư, 22 tháng 3',
  level: 2,
  levelTitle: 'Người bắt đầu',
  xp: 350,
  nextLevelXp: 1000,
  workoutCount: 12,
  totalTime: '3.2h',
  completionRate: '87%',
);

const homeInsights = [
  HomeInsightData(
    tag: 'Squat',
    value: '+12°',
    metric: 'depth',
    description: 'Độ sâu squat cải thiện trong 7 ngày',
    spark: [92, 95, 100, 103, 106, 110, 108, 104],
    color: VFTheme.accent,
    background: VFTheme.accentBg,
  ),
  HomeInsightData(
    tag: 'Push-up',
    value: '-13°',
    metric: 'elbow depth',
    description: 'Khuỷu tay hạ sâu hơn mỗi buổi tập',
    spark: [135, 132, 128, 126, 125, 123, 122],
    color: VFTheme.blue,
    background: VFTheme.blueBg,
  ),
  HomeInsightData(
    tag: 'Form',
    value: '78%',
    metric: 'tổng điểm',
    description: 'Form score tăng 5 điểm so với tuần trước',
    spark: [58, 62, 64, 68, 70, 73, 75, 78],
    color: VFTheme.accent,
    background: VFTheme.accentBg,
  ),
  HomeInsightData(
    tag: 'Heel rise',
    value: '1/10',
    metric: 'lần nhấc gót',
    description: 'Gót chân ổn định hơn khi squat',
    spark: [4, 3, 3, 2, 2, 1, 1],
    color: VFTheme.coral,
    background: VFTheme.coralBg,
  ),
];

const homeMetrics = [
  MetricCardData(value: '3', label: 'Chuỗi ngày', accent: true),
  MetricCardData(value: '78%', label: 'Form score'),
  MetricCardData(value: '12', label: 'Buổi tập'),
];

const weekStrip = [
  WeekStripDay(label: 'T2', isDone: true),
  WeekStripDay(label: 'T3', isDone: true),
  WeekStripDay(label: 'T4', isToday: true),
  WeekStripDay(label: 'T5'),
  WeekStripDay(label: 'T6'),
  WeekStripDay(label: 'T7'),
  WeekStripDay(label: 'CN'),
];

const todayWorkout = TodayWorkoutData(
  label: 'Ngày 5 · Tuần 1',
  title: 'Toàn thân',
  badge: 'Cơ bản',
  badgeColor: VFTheme.amber,
  badgeBackground: VFTheme.amberBg,
  progress: 0.33,
  meta: '15 phút · 4 bài',
  exercises: [
    ExerciseTagData(
      name: 'Squat',
      color: VFTheme.accent,
      background: VFTheme.accentBg,
      isAi: true,
    ),
    ExerciseTagData(
      name: 'Push-up',
      color: VFTheme.blue,
      background: VFTheme.blueBg,
      isAi: true,
    ),
    ExerciseTagData(
      name: 'Plank',
      color: VFTheme.amber,
      background: VFTheme.amberBg,
    ),
    ExerciseTagData(
      name: 'Lunge',
      color: VFTheme.purple,
      background: VFTheme.purpleBg,
      isAi: true,
    ),
  ],
);

const premiumWorkout = PremiumWorkoutData(
  label: 'Cá nhân hóa bởi AI',
  title: 'Chân & Cổ chân',
  description:
      'Dựa trên kết quả đánh giá: tập trung cải thiện cổ chân và squat depth',
  tags: [
    ExerciseTagData(
      name: 'Ankle mobiliser',
      color: VFTheme.accent,
      background: VFTheme.accentBg,
    ),
    ExerciseTagData(
      name: 'Deep squat',
      color: VFTheme.accent,
      background: VFTheme.accentBg,
    ),
    ExerciseTagData(
      name: 'Calf stretch',
      color: VFTheme.purple,
      background: VFTheme.purpleBg,
    ),
  ],
);

const planWeeks = [
  PlanWeekData(
    label: 'Tuần 1',
    subtitle: 'Làm quen & xây nền tảng',
    workouts: 3,
    days: [
      PlanDayData.workout(
        shortDay: 'T2',
        label: 'Thứ 2',
        focus: 'Toàn thân',
        duration: '15 phút',
        exerciseCount: 4,
        color: VFTheme.blue,
        background: VFTheme.blueBg,
        muscles: [
          MuscleTagData(name: 'Đùi', color: VFTheme.blue),
          MuscleTagData(name: 'Mông', color: VFTheme.purple),
          MuscleTagData(name: 'Core', color: VFTheme.amber),
          MuscleTagData(name: 'Ngực', color: VFTheme.coral),
        ],
        exercisePreview: ['Squat', 'Wall push-up', 'Plank', 'Lunge'],
      ),
      PlanDayData.rest(shortDay: 'T3'),
      PlanDayData.workout(
        shortDay: 'T4',
        label: 'Thứ 4',
        focus: 'Core & Thân trên',
        duration: '12 phút',
        exerciseCount: 3,
        color: VFTheme.coral,
        background: VFTheme.coralBg,
        muscles: [
          MuscleTagData(name: 'Ngực', color: VFTheme.coral),
          MuscleTagData(name: 'Core', color: VFTheme.amber),
          MuscleTagData(name: 'Vai', color: VFTheme.blue),
        ],
        exercisePreview: ['Wall push-up', 'Plank', 'Curl-up'],
      ),
      PlanDayData.rest(shortDay: 'T5'),
      PlanDayData.workout(
        shortDay: 'T6',
        label: 'Thứ 6',
        focus: 'Chân & Mông',
        duration: '15 phút',
        exerciseCount: 4,
        color: VFTheme.purple,
        background: VFTheme.purpleBg,
        muscles: [
          MuscleTagData(name: 'Đùi', color: VFTheme.blue),
          MuscleTagData(name: 'Mông', color: VFTheme.purple),
          MuscleTagData(name: 'Hông', color: VFTheme.accent),
        ],
        exercisePreview: ['Squat', 'Lunge', 'Glute bridge', 'Jumping jack'],
      ),
      PlanDayData.rest(shortDay: 'T7'),
      PlanDayData.rest(shortDay: 'CN'),
    ],
  ),
  PlanWeekData(
    label: 'Tuần 2',
    subtitle: 'Tăng cường độ & thời gian',
    workouts: 4,
    days: [
      PlanDayData.workout(
        shortDay: 'T2',
        label: 'Thứ 2',
        focus: 'Toàn thân',
        duration: '18 phút',
        exerciseCount: 5,
        color: VFTheme.blue,
        background: VFTheme.blueBg,
        muscles: [
          MuscleTagData(name: 'Đùi', color: VFTheme.blue),
          MuscleTagData(name: 'Mông', color: VFTheme.purple),
          MuscleTagData(name: 'Core', color: VFTheme.amber),
          MuscleTagData(name: 'Ngực', color: VFTheme.coral),
        ],
        exercisePreview: [
          'Squat',
          'Wall push-up',
          'Plank',
          'Lunge',
          'Jumping jack',
        ],
      ),
      PlanDayData.rest(shortDay: 'T3'),
      PlanDayData.workout(
        shortDay: 'T4',
        label: 'Thứ 4',
        focus: 'Core & Cardio',
        duration: '15 phút',
        exerciseCount: 4,
        color: VFTheme.amber,
        background: VFTheme.amberBg,
        muscles: [
          MuscleTagData(name: 'Core', color: VFTheme.amber),
          MuscleTagData(name: 'Cardio', color: VFTheme.coral),
        ],
        exercisePreview: ['Plank', 'Curl-up', 'Jumping jack', 'Squat'],
      ),
      PlanDayData.workout(
        shortDay: 'T5',
        label: 'Thứ 5',
        focus: 'Thân trên',
        duration: '12 phút',
        exerciseCount: 3,
        color: VFTheme.coral,
        background: VFTheme.coralBg,
        muscles: [
          MuscleTagData(name: 'Ngực', color: VFTheme.coral),
          MuscleTagData(name: 'Core', color: VFTheme.amber),
          MuscleTagData(name: 'Vai', color: VFTheme.blue),
        ],
        exercisePreview: ['Wall push-up', 'Plank', 'Curl-up'],
      ),
      PlanDayData.rest(shortDay: 'T6'),
      PlanDayData.workout(
        shortDay: 'T7',
        label: 'Thứ 7',
        focus: 'Chân & Mông',
        duration: '18 phút',
        exerciseCount: 4,
        color: VFTheme.purple,
        background: VFTheme.purpleBg,
        muscles: [
          MuscleTagData(name: 'Đùi', color: VFTheme.blue),
          MuscleTagData(name: 'Mông', color: VFTheme.purple),
          MuscleTagData(name: 'Hông', color: VFTheme.accent),
        ],
        exercisePreview: ['Squat', 'Lunge', 'Glute bridge', 'Jumping jack'],
      ),
      PlanDayData.rest(shortDay: 'CN'),
    ],
  ),
];

const coachInsights = [
  CoachInsightData(
    iconText: '!',
    title: 'Hạn chế cổ chân',
    detail: 'Gót chân hay nhấc khi squat. Cổ chân cần linh hoạt hơn',
    color: VFTheme.coral,
    background: VFTheme.coralBg,
    isFree: true,
  ),
  CoachInsightData(
    iconText: '↑',
    title: 'Squat sâu hơn 12°',
    detail: '102° là kỷ lục cá nhân. Cổ chân đang linh hoạt hơn',
    color: VFTheme.accent,
    background: VFTheme.accentBg,
    isFree: true,
  ),
  CoachInsightData(
    iconText: '≡',
    title: 'Chân mạnh hơn thân trên',
    detail: 'Chương trình đã thêm bài tập thân trên để cân bằng',
    color: VFTheme.blue,
    background: VFTheme.blueBg,
    isFree: true,
  ),
  CoachInsightData(
    iconText: '∿',
    title: 'Form giảm từ rep 7',
    detail: 'Form tốt nhất ở rep 1-5, bắt đầu giảm từ rep 6. Bình thường',
    color: VFTheme.amber,
    background: VFTheme.amberBg,
    isFree: false,
  ),
  CoachInsightData(
    iconText: '!',
    title: 'Push-up: thân hơi võng',
    detail: 'Tập thêm plank sẽ giúp giữ thân thẳng hơn khi push-up',
    color: VFTheme.coral,
    background: VFTheme.coralBg,
    isFree: false,
  ),
  CoachInsightData(
    iconText: '↑',
    title: 'Core đang mạnh hơn',
    detail: 'Plank từ 12s lên 18s. Mục tiêu 30s, tiếp tục phát huy',
    color: VFTheme.accent,
    background: VFTheme.accentBg,
    isFree: false,
  ),
  CoachInsightData(
    iconText: '✓',
    title: 'Tập đều 3 ngày/tuần',
    detail: 'Bạn hay tập lúc 18:30. Rất ổn định',
    color: VFTheme.purple,
    background: VFTheme.purpleBg,
    isFree: false,
  ),
  CoachInsightData(
    iconText: '↑',
    title: 'Hoàn thành 87% kế hoạch',
    detail: 'Tuần này tập nhiều hơn tuần trước 15 rep',
    color: VFTheme.accent,
    background: VFTheme.accentBg,
    isFree: false,
  ),
];

const glowMetrics = [
  GlowMetricData(
    valueLabel: '78%',
    progress: 0.78,
    label: 'Form score',
    color: VFTheme.accent,
  ),
  GlowMetricData(
    valueLabel: '3',
    progress: 3 / 7,
    label: 'Chuỗi ngày',
    color: VFTheme.amber,
  ),
  GlowMetricData(
    valueLabel: '12',
    progress: 12 / 16,
    label: 'Buổi tập',
    color: VFTheme.blue,
  ),
];

const formComparisons = [
  FormComparisonData(
    name: 'Squat',
    color: VFTheme.accent,
    background: VFTheme.accentBg,
    delta: '+12°',
    label: 'sâu hơn',
    before: AngleFigureData(
      hip: Offset(30, 45),
      knee: Offset(22, 63),
      ankle: Offset(20, 82),
      angle: '118°',
    ),
    after: AngleFigureData(
      hip: Offset(30, 45),
      knee: Offset(20, 68),
      ankle: Offset(18, 85),
      angle: '106°',
    ),
  ),
  FormComparisonData(
    name: 'Push-up',
    color: VFTheme.blue,
    background: VFTheme.blueBg,
    delta: '+13°',
    label: 'sâu hơn',
    before: AngleFigureData(
      hip: Offset(18, 22),
      knee: Offset(30, 32),
      ankle: Offset(42, 38),
      angle: '135°',
    ),
    after: AngleFigureData(
      hip: Offset(16, 24),
      knee: Offset(28, 38),
      ankle: Offset(40, 44),
      angle: '122°',
    ),
  ),
];

const weeklyCompletion = [
  WeeklyCompletionData(label: 'T1', done: 2, total: 3),
  WeeklyCompletionData(label: 'T2', done: 3, total: 3),
  WeeklyCompletionData(label: 'T3', done: 1, total: 3, isCurrent: true),
  WeeklyCompletionData(label: 'T4', done: 0, total: 3, isFuture: true),
];

const profileBadges = [
  BadgeShelfItem(
    name: 'Tuần 1',
    icon: Icons.star_rounded,
    color: VFTheme.accent,
    background: VFTheme.accentBg,
    earned: true,
  ),
  BadgeShelfItem(
    name: 'Form+',
    icon: Icons.check_rounded,
    color: VFTheme.blue,
    background: VFTheme.blueBg,
    earned: true,
  ),
  BadgeShelfItem(
    name: '3 ngày',
    icon: Icons.local_fire_department_rounded,
    color: VFTheme.amber,
    background: VFTheme.amberBg,
    earned: true,
  ),
  BadgeShelfItem(
    name: '10 buổi',
    icon: Icons.workspace_premium_rounded,
    color: VFTheme.coral,
    background: VFTheme.coralBg,
    earned: true,
  ),
  BadgeShelfItem(
    name: '???',
    icon: Icons.lock_outline_rounded,
    color: VFTheme.textMuted,
    background: VFTheme.surfaceAlt,
    earned: false,
  ),
  BadgeShelfItem(
    name: '???',
    icon: Icons.lock_outline_rounded,
    color: VFTheme.textMuted,
    background: VFTheme.surfaceAlt,
    earned: false,
  ),
];

const profileSettings = [
  SettingItemData(
    label: 'Thông tin cá nhân',
    subtitle: '170cm · 65kg · BMI 22.5',
    icon: Icons.person_outline_rounded,
    color: VFTheme.accent,
    background: VFTheme.accentBg,
  ),
  SettingItemData(
    label: 'Mục tiêu & Lịch tập',
    subtitle: 'Cải thiện sức khỏe · T2, T4, T6',
    icon: Icons.calendar_month_rounded,
    color: VFTheme.blue,
    background: VFTheme.blueBg,
  ),
  SettingItemData(
    label: 'Nhắc nhở',
    subtitle: '18:30 hàng ngày',
    icon: Icons.notifications_none_rounded,
    color: VFTheme.amber,
    background: VFTheme.amberBg,
  ),
  SettingItemData(
    label: 'Ngôn ngữ & Giọng nói',
    subtitle: 'Tiếng Việt · Giọng Bắc',
    icon: Icons.language_rounded,
    color: VFTheme.textSec,
    background: VFTheme.surfaceAlt,
  ),
];

const muscleGroups = [
  MuscleGroupData(
    id: 'leg',
    label: 'Chân',
    count: 4,
    icon: Icons.directions_run_rounded,
    color: VFTheme.accent,
    background: VFTheme.accentBg,
  ),
  MuscleGroupData(
    id: 'upper',
    label: 'Ngực',
    count: 2,
    icon: Icons.fitness_center_rounded,
    color: VFTheme.blue,
    background: VFTheme.blueBg,
  ),
  MuscleGroupData(
    id: 'core',
    label: 'Core',
    count: 2,
    icon: Icons.adjust_rounded,
    color: VFTheme.amber,
    background: VFTheme.amberBg,
  ),
  MuscleGroupData(
    id: 'glute',
    label: 'Mông',
    count: 1,
    icon: Icons.change_history_rounded,
    color: VFTheme.purple,
    background: VFTheme.purpleBg,
  ),
  MuscleGroupData(
    id: 'arm',
    label: 'Tay',
    count: 1,
    icon: Icons.accessibility_new_rounded,
    color: VFTheme.coral,
    background: VFTheme.coralBg,
  ),
];

const browserExercises = [
  ExerciseBrowserItem(
    name: 'Squat',
    groupId: 'leg',
    typeLabel: 'AI',
    muscles: 'Đùi · Mông · Core',
    color: VFTheme.accent,
    background: VFTheme.accentBg,
    difficulty: 1,
  ),
  ExerciseBrowserItem(
    name: 'Lunge',
    groupId: 'leg',
    typeLabel: 'AI',
    muscles: 'Đùi · Hông',
    color: VFTheme.amber,
    background: VFTheme.amberBg,
    difficulty: 2,
  ),
  ExerciseBrowserItem(
    name: 'Calf Raise',
    groupId: 'leg',
    typeLabel: 'Đếm',
    muscles: 'Bắp chân',
    color: VFTheme.textSec,
    background: VFTheme.surfaceAlt,
    difficulty: 1,
  ),
  ExerciseBrowserItem(
    name: 'Jumping Jack',
    groupId: 'leg',
    typeLabel: 'Đếm',
    muscles: 'Toàn thân · Cardio',
    color: VFTheme.textSec,
    background: VFTheme.surfaceAlt,
    difficulty: 1,
  ),
  ExerciseBrowserItem(
    name: 'Wall Push-up',
    groupId: 'upper',
    typeLabel: 'AI',
    muscles: 'Ngực · Vai · Tay',
    color: VFTheme.blue,
    background: VFTheme.blueBg,
    difficulty: 1,
  ),
  ExerciseBrowserItem(
    name: 'Bicep Curl',
    groupId: 'arm',
    typeLabel: 'Đếm',
    muscles: 'Tay trước',
    color: VFTheme.textSec,
    background: VFTheme.surfaceAlt,
    difficulty: 1,
  ),
  ExerciseBrowserItem(
    name: 'McGill Curl-up',
    groupId: 'core',
    typeLabel: 'AI',
    muscles: 'Core · Bụng',
    color: VFTheme.coral,
    background: VFTheme.coralBg,
    difficulty: 1,
  ),
  ExerciseBrowserItem(
    name: 'Plank',
    groupId: 'core',
    typeLabel: 'Timer',
    muscles: 'Core',
    color: VFTheme.textSec,
    background: VFTheme.surfaceAlt,
    difficulty: 1,
  ),
  ExerciseBrowserItem(
    name: 'Glute Bridge',
    groupId: 'glute',
    typeLabel: 'AI',
    muscles: 'Mông · Core',
    color: VFTheme.purple,
    background: VFTheme.purpleBg,
    difficulty: 1,
  ),
];
