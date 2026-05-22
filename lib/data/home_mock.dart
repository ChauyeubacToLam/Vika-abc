// Mock data for the Home tab. Mirrors the inline values in the
// vika-main-app-ivory-v1.jsx. Single source of truth so the screen stays
// declarative and easy to tweak.
//
// All Vietnamese strings copied verbatim from the JSX prototype.

import 'package:flutter/material.dart';

import '../widgets/home/hero_day_card.dart';

class HomeUserSnapshot {
  const HomeUserSnapshot({
    required this.name,
    required this.initial,
    required this.dayLabel,
    required this.sessionLabel,
  });

  final String name;
  final String initial;
  final String dayLabel; // 'Thứ Sáu · 8 tháng 5'
  final String sessionLabel; // 'Buổi 03'
}

class HomeHeroDayMock {
  const HomeHeroDayMock({
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.stats,
    required this.cta,
    required this.isToday,
  });

  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final List<HeroDayStat> stats;
  final String cta;
  final bool isToday;
}

const HomeUserSnapshot homeMockUser = HomeUserSnapshot(
  name: 'Nam',
  initial: 'N',
  dayLabel: 'Thứ Sáu · 8 tháng 5',
  sessionLabel: 'Buổi 03',
);

const List<HomeHeroDayMock> homeMockHeroDays = [
  HomeHeroDayMock(
    eyebrow: 'HÔM NAY · BUỔI 03',
    titleLine1: 'Toàn',
    titleLine2: 'thân nhẹ',
    stats: [
      HeroDayStat(icon: Icons.access_time_rounded, value: '15', label: 'phút'),
      HeroDayStat(
          icon: Icons.bar_chart_rounded, value: 'Beginner', label: 'Cấp độ'),
      HeroDayStat(
          icon: Icons.gps_fixed_rounded, value: 'Cốt lõi', label: 'Trọng tâm'),
      HeroDayStat(
          icon: Icons.check_circle_outline_rounded,
          value: '4 bài',
          label: '3 có AI'),
    ],
    cta: 'Bắt đầu Buổi 3',
    isToday: true,
  ),
  HomeHeroDayMock(
    eyebrow: 'THỨ BẢY · BUỔI 04',
    titleLine1: 'Đánh',
    titleLine2: 'giá lại',
    stats: [
      HeroDayStat(icon: Icons.access_time_rounded, value: '8', label: 'phút'),
      HeroDayStat(icon: Icons.bar_chart_rounded, value: 'Test', label: 'Loại'),
      HeroDayStat(
          icon: Icons.gps_fixed_rounded, value: 'Form', label: 'Đo lại'),
      HeroDayStat(
          icon: Icons.check_circle_outline_rounded,
          value: '2 bài',
          label: 'Squat + PU'),
    ],
    cta: 'Xem chi tiết',
    isToday: false,
  ),
];

const int homeMockStreakDays = 12;
const List<bool> homeMockWeekDots = [
  true,
  true,
  false,
  true,
  true,
  false,
  true
];

const int homeMockFormToday = 78;
const int homeMockFormDelta = 6;
const List<int> homeMockFormWeek = [62, 68, 64, 71, 70, 75, 78];

const String homeMockJournalDate = 'Bạn viết · 27 tháng 4';
const String homeMockJournalQuote =
    'Muốn ngủ ngon hơn và không còn nhức lưng khi ngồi cả ngày.';
