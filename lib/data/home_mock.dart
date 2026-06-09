// Mock data for the polished Stage Home design. Single source of truth so
// the screen stays declarative. Replace each block per the
// `// TODO(wiring)` markers inside dashboard_home_screen.dart.

import '../widgets/home/home_stage_hero.dart';

class HomeUserSnapshot {
  const HomeUserSnapshot({
    required this.name,
    required this.initial,
  });

  final String name;
  final String initial;
}

class HomeTodayStage {
  const HomeTodayStage({
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.duration,
    required this.totalCount,
    required this.aiCount,
    required this.exercises,
    required this.cta,
  });

  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final String duration;
  final int totalCount;
  final int aiCount;
  final List<HomeStageExercise> exercises;
  final String cta;
}

const HomeUserSnapshot homeMockUser = HomeUserSnapshot(
  name: 'Nam',
  initial: 'N',
);

const HomeTodayStage homeMockToday = HomeTodayStage(
  eyebrow: 'HÔM NAY · BUỔI 03',
  titleLine1: 'Toàn',
  titleLine2: 'thân nhẹ.',
  duration: '15 phút',
  totalCount: 4,
  aiCount: 3,
  exercises: [
    HomeStageExercise(name: 'Squat', detail: '3 × 8 rep', hasAi: true),
    HomeStageExercise(name: 'Wall push-up', detail: '3 × 8 rep', hasAi: true),
    HomeStageExercise(name: 'Glute bridge', detail: '3 × 10 rep', hasAi: true),
    HomeStageExercise(name: 'McGill curl-up', detail: '3 × 12 rep'),
  ],
  cta: 'Bắt đầu Buổi 03',
);

// ─── Vitals panel data ────────────────────────────────────────
const String homeMockWeekLabel = 'TUẦN 03';
const String homeMockPhaseLabel = 'NỀN TẢNG';
const int homeMockSessionsDone = 3;
const int homeMockSessionsTotal = 4;
// Consecutive active weeks (preview only) → '1 quý' via streakTierLabel.
const int homeMockStreakWeeks = 12;
// Form 7-day vitals are wired to real data via SessionPersistence
// .homeFormSummary(); see HomeVitalsSpread.formPercent/formDelta/formWeek.

// ─── Vitals spread standfirst ─────────────────────────────────
const String homeMockVitalsStandfirst =
    'Tuần đang đi đúng nhịp. Một buổi nữa là khoá.';

// ─── Coach voice (embedded inside hero) ───────────────────────
const String homeMockCoachQuote =
    'Hôm nay tập nhẹ thôi — giữ form sạch, thở đều.';
const String homeMockCoachAttribution = 'Vika';
