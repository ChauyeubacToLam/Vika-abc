// Mock data for the Progress tab. Mirrors values inline in ProgressScreen
// of vika-main-app-ivory-v1.jsx.

import 'package:flutter/foundation.dart';

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
    required this.from,
    required this.to,
    required this.coach,
    required this.chart,
  });
  final String idx;
  final String name;
  final String from;
  final String to;
  final String coach;
  final List<int> chart;
}

const List<ExerciseInsightMock> progressMockInsights = [
  ExerciseInsightMock(
    idx: '01',
    name: 'Squat',
    from: '118°',
    to: '106°',
    coach: 'Bốn tuần đẩy. Hông mở dần — đó là chìa khoá.',
    chart: [118, 115, 113, 111, 109, 108, 106],
  ),
  ExerciseInsightMock(
    idx: '02',
    name: 'Wall Push-up',
    from: '32°',
    to: '24°',
    coach: 'Vai đứng yên hơn rồi. Lệch trái-phải giảm đi.',
    chart: [32, 30, 28, 27, 26, 25, 24],
  ),
  ExerciseInsightMock(
    idx: '03',
    name: 'Plank',
    from: '18s',
    to: '28s',
    coach: 'Cốt lõi cuối cùng cũng đến. 28 giây là đỉnh tuần.',
    chart: [18, 19, 22, 23, 25, 27, 28],
  ),
  ExerciseInsightMock(
    idx: '04',
    name: 'Glute Bridge',
    from: '64%',
    to: '78%',
    coach: 'Mông kích hoạt rõ — không còn đẩy bằng lưng dưới.',
    chart: [64, 66, 68, 71, 74, 76, 78],
  ),
  ExerciseInsightMock(
    idx: '05',
    name: 'Curl-Up',
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
  true, false, true, true, false, true, true,
  true, false, true, true, false, true, true,
];
