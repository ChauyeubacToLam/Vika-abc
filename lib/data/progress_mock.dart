// Mock data for the Progress tab. Mirrors values inline in ProgressScreen
// of vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../widgets/progress/personal_records_rail.dart';
import '../widgets/progress/weekly_summary_band.dart';

@immutable
class HeadlineForPeriod {
  const HeadlineForPeriod({
    required this.average,
    required this.label,
    required this.coach,
  });
  final int average; // window mean — the gauge headline
  final String label; // 'CẢ LỘ TRÌNH · 4 TUẦN'
  final String coach; // multi-sentence coach quote
}

const Map<String, HeadlineForPeriod> progressMockHeadline = {
  'week': HeadlineForPeriod(
    average: 72, // mean of progressMockScoreTrend['week']
    label: '7 NGÀY GẦN NHẤT',
    coach: 'Bảy ngày qua: form ổn định. Squat depth giữ chuẩn '
        'rep này qua rep khác.',
  ),
  'month': HeadlineForPeriod(
    average: 69, // mean of progressMockScoreTrend['month']
    label: '30 NGÀY GẦN NHẤT',
    coach: 'Một tháng đều đặn. Cốt lõi đuổi kịp chân — '
        'plank lên 16 điểm.',
  ),
  'program': HeadlineForPeriod(
    average: 67, // mean of progressMockScoreTrend['program']
    label: 'CẢ LỘ TRÌNH · 4 TUẦN',
    coach: 'Bốn tuần đã qua. Squat sâu hơn 12°. Cốt lõi cuối cùng '
        'cũng đuổi kịp chân.',
  ),
};

@immutable
class BodyHeatArea {
  const BodyHeatArea({
    required this.area,
    required this.delta,
    required this.intensity, // 'strong' | 'medium' | 'mild'
    required this.region, // 'legs' | 'glutes' | 'shoulders' | 'core'
    required this.note,
  });
  final String area;
  final String delta;
  final String intensity;
  final String region;
  final String note;
}

const List<BodyHeatArea> progressMockBodyAreas = [
  BodyHeatArea(
    area: 'Chân',
    delta: '+18',
    intensity: 'strong',
    region: 'legs',
    note: 'Squat sâu hơn',
  ),
  BodyHeatArea(
    area: 'Mông',
    delta: '+12',
    intensity: 'medium',
    region: 'glutes',
    note: 'Glute bridge ổn định hơn',
  ),
  BodyHeatArea(
    area: 'Ngực & Vai',
    delta: '+8',
    intensity: 'medium',
    region: 'shoulders',
    note: 'Push-up đều theo từng rep',
  ),
  BodyHeatArea(
    area: 'Cốt lõi',
    delta: '+4',
    intensity: 'mild',
    region: 'core',
    note: 'Plank giữ thẳng người lâu hơn',
  ),
];

@immutable
class ExerciseInsightMock {
  const ExerciseInsightMock({
    required this.idx,
    required this.name,
    required this.metric,
    required this.directionHint,
    required this.improvement,
    required this.from,
    required this.to,
    required this.chart,
    this.stat,
    this.lowerIsBetter = false,
    this.coach,
  });
  final String idx;
  final String name;

  /// What's being measured — the metric in plain Vietnamese.
  /// e.g. "Độ sâu khi xuống", "Thời gian giữ".
  final String metric;

  /// One-liner explaining which direction is "better."
  /// e.g. "Càng thấp càng tốt", "Càng lâu càng tốt".
  final String directionHint;

  /// The headline improvement phrase. Naturally-readable Vietnamese.
  /// e.g. "Sâu hơn 12°", "Lâu hơn 10 giây", "Mạnh hơn 14%".
  final String improvement;

  final String from;
  final String to;

  /// Per-session metric series, oldest-first → the card's bar chart. The
  /// dominant visualization; raw values, [lowerIsBetter] orients them.
  final List<int> chart;

  /// Compact magnitude shown as the card's hero stat, e.g. "12°", "10s",
  /// "14%". Falls back to [improvement] when null.
  final String? stat;

  /// When true a FALLING value is the improvement (fault rate, asymmetry,
  /// depth angle). The chart inverts so progress always reads as a climb.
  final bool lowerIsBetter;

  /// Optional editorial coach quote. Null on real, data-derived insights —
  /// the card simply hides the footer rather than fabricating prose.
  final String? coach;
}

// Mock ranking for the BÀI TẬP NỔI BẬT 2-up visual cards. Restored as a design
// preview; the real ranker lives in SessionPersistence.rankedInsights and can
// be re-mapped onto these cards once headlines carry their fitted series.
const List<ExerciseInsightMock> progressMockInsights = [
  ExerciseInsightMock(
    idx: '01',
    name: 'Squat',
    metric: 'Độ sâu',
    directionHint: 'Càng thấp càng sâu',
    improvement: 'Sâu hơn 12°',
    stat: '12°',
    lowerIsBetter: true,
    from: '118°',
    to: '106°',
    chart: [118, 116, 113, 111, 109, 108, 106],
  ),
  ExerciseInsightMock(
    idx: '02',
    name: 'Plank',
    metric: 'Thời gian giữ',
    directionHint: 'Càng lâu càng khoẻ',
    improvement: 'Lâu hơn 10 giây',
    stat: '10s',
    from: '18s',
    to: '28s',
    chart: [18, 19, 22, 23, 25, 27, 28],
  ),
  ExerciseInsightMock(
    idx: '03',
    name: 'Glute Bridge',
    metric: 'Kích hoạt mông',
    directionHint: 'Càng cao càng mạnh',
    improvement: 'Mạnh hơn 14%',
    stat: '14%',
    from: '64%',
    to: '78%',
    chart: [64, 66, 68, 71, 74, 76, 78],
  ),
  ExerciseInsightMock(
    idx: '04',
    name: 'Wall Push-up',
    metric: 'Cân hai vai',
    directionHint: 'Càng thấp càng đều',
    improvement: 'Đều hơn 8°',
    stat: '8°',
    lowerIsBetter: true,
    from: '32°',
    to: '24°',
    chart: [32, 30, 29, 27, 26, 25, 24],
  ),
  ExerciseInsightMock(
    idx: '05',
    name: 'Curl-Up',
    metric: 'Kích hoạt cốt lõi',
    directionHint: 'Càng cao càng mạnh',
    improvement: 'Mạnh hơn 14%',
    stat: '14%',
    from: '52%',
    to: '66%',
    chart: [52, 55, 58, 60, 62, 64, 66],
  ),
  ExerciseInsightMock(
    idx: '06',
    name: 'Lunge',
    metric: 'Giữ thăng bằng',
    directionHint: 'Càng cao càng vững',
    improvement: 'Vững hơn 28%',
    stat: '28%',
    from: '40%',
    to: '68%',
    chart: [40, 44, 49, 53, 58, 63, 68],
  ),
];

// Consecutive active weeks (preview only) → '1 quý' via streakTierLabel.
const int progressMockStreakWeeks = 12;
// 12-week activity strip (preview only), oldest-first, last = current week.
// Trailing filled run = 12, coherent with progressMockStreakWeeks above.
const List<bool> progressMockStreakWeekBars = [
  true, true, true, true, true, true,
  true, true, true, true, true, true,
];

// ═══════════════════════════════════════════════════════════════
// WEEKLY SUMMARY — 4 stats per period.
// ═══════════════════════════════════════════════════════════════

const Map<String, List<WeeklyStat>> progressMockSummaries = {
  'week': [
    WeeklyStat(
      value: '5/7',
      label: 'Buổi tập',
      deltaNote: '+1 vs tuần trước',
    ),
    WeeklyStat(
      value: "2h12'",
      label: 'Thời gian',
    ),
    WeeklyStat(
      value: '2',
      label: 'Kỷ lục mới',
      deltaNote: '+2 tuần này',
    ),
    WeeklyStat(
      value: '12',
      label: 'Ngày liên tiếp',
    ),
  ],
  'month': [
    WeeklyStat(
      value: '18/30',
      label: 'Buổi tập',
      deltaNote: '+3 vs tháng trước',
    ),
    WeeklyStat(
      value: "9h48'",
      label: 'Thời gian',
    ),
    WeeklyStat(
      value: '5',
      label: 'Kỷ lục mới',
    ),
    WeeklyStat(
      value: '12',
      label: 'Ngày liên tiếp',
    ),
  ],
  'program': [
    WeeklyStat(
      value: '24/28',
      label: 'Buổi tập',
      deltaNote: '85% xong',
    ),
    WeeklyStat(
      value: '13h',
      label: 'Thời gian',
    ),
    WeeklyStat(
      value: '7',
      label: 'Kỷ lục mới',
    ),
    WeeklyStat(
      value: '12',
      label: 'Ngày liên tiếp',
    ),
  ],
};

// ═══════════════════════════════════════════════════════════════
// SCORE TREND — series points per period (0..100). Last = today.
// ═══════════════════════════════════════════════════════════════

const Map<String, List<int>> progressMockScoreTrend = {
  'week': [69, 70, 70, 72, 73, 73, 74],
  'month': [63, 65, 66, 67, 68, 70, 71, 72, 73, 73, 74],
  'program': [
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
  ],
};

const Map<String, (String, String, String)> progressMockTrendAxis = {
  'week': ('T2', 'T5', 'CN'),
  'month': ('30 NGÀY TRƯỚC', 'GIỮA THÁNG', 'HÔM NAY'),
  'program': ('TUẦN 1', 'TUẦN 4', 'TUẦN 7'),
};

// ═══════════════════════════════════════════════════════════════
// PERSONAL RECORDS — fresh PRs first.
// ═══════════════════════════════════════════════════════════════

const List<PersonalRecord> progressMockRecords = [
  PersonalRecord(
    exercise: 'Plank',
    value: '28',
    unit: 'giây',
    previous: '18 giây',
    dateLabel: 'Hôm nay',
    icon: Icons.timer_rounded,
    isNew: true,
  ),
  PersonalRecord(
    exercise: 'Squat',
    value: '-12°',
    unit: 'sâu hơn',
    previous: '118° hông',
    dateLabel: 'Hôm qua',
    icon: Icons.height_rounded,
    isNew: true,
  ),
  PersonalRecord(
    exercise: 'Glute Bridge',
    value: '78%',
    unit: 'kích hoạt',
    previous: '64% mông',
    dateLabel: '3 ngày trước',
    icon: Icons.straighten_rounded,
    isNew: false,
  ),
  PersonalRecord(
    exercise: 'Push-Up',
    value: '15',
    unit: 'rep liên tiếp',
    previous: '10 rep',
    dateLabel: 'Tuần trước',
    icon: Icons.fitness_center_rounded,
    isNew: false,
  ),
  PersonalRecord(
    exercise: 'Lunge',
    value: '4',
    unit: 'hiệp ổn định',
    previous: '2 hiệp',
    dateLabel: 'Tuần trước',
    icon: Icons.directions_walk_rounded,
    isNew: false,
  ),
];

const int progressMockNextMilestone = 15;
