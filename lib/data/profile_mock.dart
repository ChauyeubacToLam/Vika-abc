// Mock data for the Profile tab. Mirrors values inline in ProfileScreen of
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/foundation.dart';

@immutable
class ProfileLifetimeStat {
  const ProfileLifetimeStat({required this.value, required this.unit, required this.label});
  final String value;
  final String unit;
  final String label;
}

const String profileMockName = 'Nam Trần';
const String profileMockInitial = 'N';
const String profileMockMemberSince = '27/4/2026';
const String profileMockLevel = 'Beginner';
const String profileMockPhase = 'Lộ trình Phase 1';

const String profileMockGoalTitle = 'Khoẻ đều, bền lâu';
const String profileMockGoalQuote =
    'Muốn ngủ ngon hơn và không còn nhức lưng khi ngồi cả ngày.';
const String profileMockCoachLine =
    'Mười hai ngày. Tám buổi. Form đã tăng đều — không vội.';

const List<ProfileLifetimeStat> profileMockLifetimeStats = [
  ProfileLifetimeStat(value: '8', unit: 'buổi', label: 'ĐÃ TẬP'),
  ProfileLifetimeStat(value: '1.8', unit: 'giờ', label: 'TỔNG CỘNG'),
  ProfileLifetimeStat(value: '74', unit: '%', label: 'FORM TB'),
];

const int profileMockHeight = 170;
const int profileMockWeight = 68;
const int profileMockAge = 28;
const String profileMockBMI = '23.5';
