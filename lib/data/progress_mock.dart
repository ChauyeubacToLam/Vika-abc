// Mock data for the Progress tab. Mirrors values inline in ProgressScreen
// of vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../widgets/progress/personal_records_rail.dart';
import '../widgets/progress/weekly_summary_band.dart';

@immutable
class HeadlineForPeriod {
  const HeadlineForPeriod({
    required this.delta,
    required this.from,
    required this.to,
    required this.label,
    required this.coach,
  });
  final String delta; // '+14'
  final int from;
  final int to;
  final String label; // 'CẢ LỘ TRÌNH · 4 TUẦN'
  final String coach; // multi-sentence coach quote
}

const Map<String, HeadlineForPeriod> progressMockHeadline = {
  'week': HeadlineForPeriod(
    delta: '+5',
    from: 69,
    to: 74,
    label: '7 NGÀY GẦN NHẤT',
    coach: 'Bảy ngày qua: form ổn định. Squat depth giữ chuẩn '
        'rep này qua rep khác.',
  ),
  'month': HeadlineForPeriod(
    delta: '+11',
    from: 63,
    to: 74,
    label: '30 NGÀY GẦN NHẤT',
    coach: 'Một tháng đều đặn. Cốt lõi đuổi kịp chân — '
        'plank lên 16 điểm.',
  ),
  'program': HeadlineForPeriod(
    delta: '+14',
    from: 60,
    to: 74,
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
    required this.coach,
    required this.chart,
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
  final String coach;

  /// Retained for potential future use; the current insight card
  /// renders a before/after timeline bar rather than a sparkline.
  final List<int> chart;
}

const List<ExerciseInsightMock> progressMockInsights = [
  ExerciseInsightMock(
    idx: '01',
    name: 'Squat',
    metric: 'Độ sâu khi xuống',
    directionHint: 'Càng thấp = càng sâu',
    improvement: 'Sâu hơn 12°',
    from: '118°',
    to: '106°',
    coach: 'Bốn tuần đẩy. Hông mở dần — đó là chìa khoá.',
    chart: [118, 115, 113, 111, 109, 108, 106],
  ),
  ExerciseInsightMock(
    idx: '02',
    name: 'Wall Push-up',
    metric: 'Lệch giữa hai vai',
    directionHint: 'Càng thấp = càng đều',
    improvement: 'Đều hơn 8°',
    from: '32°',
    to: '24°',
    coach: 'Vai đứng yên hơn rồi. Lệch trái-phải giảm đi.',
    chart: [32, 30, 28, 27, 26, 25, 24],
  ),
  ExerciseInsightMock(
    idx: '03',
    name: 'Plank',
    metric: 'Thời gian giữ thẳng',
    directionHint: 'Càng lâu = càng khoẻ',
    improvement: 'Lâu hơn 10 giây',
    from: '18s',
    to: '28s',
    coach: 'Cốt lõi cuối cùng cũng đến. 28 giây là đỉnh tuần.',
    chart: [18, 19, 22, 23, 25, 27, 28],
  ),
  ExerciseInsightMock(
    idx: '04',
    name: 'Glute Bridge',
    metric: 'Kích hoạt cơ mông',
    directionHint: 'Càng cao = càng mạnh',
    improvement: 'Mạnh hơn 14%',
    from: '64%',
    to: '78%',
    coach: 'Mông kích hoạt rõ — không còn đẩy bằng lưng dưới.',
    chart: [64, 66, 68, 71, 74, 76, 78],
  ),
  ExerciseInsightMock(
    idx: '05',
    name: 'Curl-Up',
    metric: 'Kích hoạt cốt lõi',
    directionHint: 'Càng cao = càng mạnh',
    improvement: 'Mạnh hơn 14%',
    from: '52%',
    to: '66%',
    coach: 'Cốt lõi đang lên đều. Hai tuần nữa là chuẩn.',
    chart: [52, 55, 58, 60, 62, 64, 66],
  ),
];

const int progressMockStreakDays = 12;
const String progressMockStreakSummary =
    'Tập đều từ 27/4. Hơn 3 trên 4 ngày trong tuần.';
// 14-day completion array, last entry = today.
const List<bool> progressMockStreakBars = [
  true,
  false,
  true,
  true,
  false,
  true,
  true,
  true,
  false,
  true,
  true,
  false,
  true,
  true,
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
