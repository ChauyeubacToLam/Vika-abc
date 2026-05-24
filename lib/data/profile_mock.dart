// Mock data for the Profile tab. Mirrors values inline in ProfileScreen of
// vika-main-app-ivory-v1.jsx, plus v2 additions for the new sections
// (achievements, journey, referrals, connections).

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// IDENTITY
// ═══════════════════════════════════════════════════════════════

const String profileMockName = 'Nam Trần';
const String profileMockInitial = 'N';
const String profileMockMemberSince = '27/4/2026';
const String profileMockLevel = 'Beginner';
const String profileMockPhase = 'Lộ trình Phase 1';
const String profileMockPhaseShort = 'PHASE 1 · TUẦN 3 / 7';

// ═══════════════════════════════════════════════════════════════
// LIFETIME STATS + GOAL + COACH
// ═══════════════════════════════════════════════════════════════

const String profileMockGoalTitle = 'Khoẻ đều, bền lâu';
const String profileMockGoalQuote =
    'Muốn ngủ ngon hơn và không còn nhức lưng khi ngồi cả ngày.';
const String profileMockCoachLine =
    'Mười hai ngày. Tám buổi. Form đã tăng đều — không vội.';

/// Goal progress (0..100). Used by the Goal card progress meter.
const int profileMockGoalProgress = 42;
const String profileMockGoalDaysLeft = 'Còn 4 tuần nữa';

@immutable
class ProfileLifetimeStat {
  const ProfileLifetimeStat({
    required this.value,
    required this.unit,
    required this.label,
    this.delta,
  });
  final String value;
  final String unit;
  final String label;

  /// Optional trend note like "+2 tuần này". Italic faint by default.
  final String? delta;
}

const List<ProfileLifetimeStat> profileMockLifetimeStats = [
  ProfileLifetimeStat(
    value: '8',
    unit: 'buổi',
    label: 'ĐÃ TẬP',
    delta: '+2 tuần này',
  ),
  ProfileLifetimeStat(
    value: '1.8',
    unit: 'giờ',
    label: 'TỔNG CỘNG',
  ),
  ProfileLifetimeStat(
    value: '74',
    unit: '%',
    label: 'FORM TB',
    delta: '+14 từ đầu',
  ),
];

// ═══════════════════════════════════════════════════════════════
// BODY
// ═══════════════════════════════════════════════════════════════

const int profileMockHeight = 170;
const int profileMockWeight = 68;
const int profileMockAge = 28;
const String profileMockBMI = '23.5';
const String profileMockBMILabel = 'Cân đối';

// ═══════════════════════════════════════════════════════════════
// ACHIEVEMENTS — editorial italic medallions.
// Each carries a chapter numeral, short label, italic subtitle,
// and either an unlock date or a "still locked" status.
// ═══════════════════════════════════════════════════════════════

@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.headline,
    required this.subtitle,
    required this.unlocked,
    this.unlockedOn,
  });
  final String id;

  /// Short chapter title — italic, 2-3 words. e.g. "Ngày 7", "Form 70".
  final String headline;

  /// Italic subtitle giving context. e.g. "Tuần đầu trọn vẹn".
  final String subtitle;

  final bool unlocked;

  /// e.g. "27 / 4 · GIA NHẬP". Optional, only meaningful when unlocked.
  final String? unlockedOn;
}

const List<Achievement> profileMockAchievements = [
  Achievement(
    id: 'first-session',
    headline: 'Bước đầu',
    subtitle: 'Buổi tập đầu tiên',
    unlocked: true,
    unlockedOn: '27 / 4',
  ),
  Achievement(
    id: 'week-one',
    headline: 'Tuần một',
    subtitle: 'Bảy ngày trọn vẹn',
    unlocked: true,
    unlockedOn: '03 / 5',
  ),
  Achievement(
    id: 'first-pr',
    headline: 'Kỷ lục đầu',
    subtitle: 'Plank 28 giây',
    unlocked: true,
    unlockedOn: '10 / 5',
  ),
  Achievement(
    id: 'form-70',
    headline: 'Form 70',
    subtitle: 'Form chuẩn ổn định',
    unlocked: true,
    unlockedOn: '15 / 5',
  ),
  Achievement(
    id: 'streak-14',
    headline: 'Ngày 14',
    subtitle: 'Hai tuần liên tiếp',
    unlocked: false,
  ),
  Achievement(
    id: 'sessions-30',
    headline: '30 buổi',
    subtitle: 'Bền chí một tháng',
    unlocked: false,
  ),
  Achievement(
    id: 'phase-1-done',
    headline: 'Phase 1',
    subtitle: 'Xong giai đoạn nền tảng',
    unlocked: false,
  ),
];

// ═══════════════════════════════════════════════════════════════
// JOURNEY TIMELINE — chronological milestones with TODAY anchor.
// ═══════════════════════════════════════════════════════════════

enum JourneyKind { join, milestone, pr, formScore, today }

@immutable
class JourneyMilestone {
  const JourneyMilestone({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.kind,
  });
  final String date; // e.g. "27 / 4"
  final String title;
  final String subtitle;
  final JourneyKind kind;
}

const List<JourneyMilestone> profileMockJourney = [
  JourneyMilestone(
    date: '27 / 4',
    title: 'Gia nhập Vika',
    subtitle: 'Bắt đầu hành trình Khoẻ đều, bền lâu.',
    kind: JourneyKind.join,
  ),
  JourneyMilestone(
    date: '03 / 5',
    title: 'Hết tuần đầu',
    subtitle: 'Bảy ngày trọn vẹn không bỏ buổi.',
    kind: JourneyKind.milestone,
  ),
  JourneyMilestone(
    date: '10 / 5',
    title: 'Kỷ lục đầu tiên',
    subtitle: 'Plank 28 giây — vượt qua mức cũ 18 giây.',
    kind: JourneyKind.pr,
  ),
  JourneyMilestone(
    date: '15 / 5',
    title: 'Form chạm 70',
    subtitle: 'Form chuẩn trung bình lần đầu trên 70%.',
    kind: JourneyKind.formScore,
  ),
  JourneyMilestone(
    date: '22 / 5',
    title: 'Hôm nay',
    subtitle: '12 ngày liên tiếp · Form 74. Bền lâu đang gần.',
    kind: JourneyKind.today,
  ),
];

// ═══════════════════════════════════════════════════════════════
// CONNECT & SHARE — referrals + service integrations.
// ═══════════════════════════════════════════════════════════════

const int profileMockReferralCount = 2;
const String profileMockReferralLine =
    'Hai người bạn đã tham gia. Mỗi lượt mời thành công tặng bạn 1 tuần Vika+.';

@immutable
class ConnectedService {
  const ConnectedService({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.connected,
  });
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final bool connected;
}

const List<ConnectedService> profileMockConnections = [
  ConnectedService(
    id: 'apple-health',
    name: 'Apple Health',
    subtitle: 'Đồng bộ buổi tập với Sức khoẻ',
    icon: Icons.favorite_rounded,
    connected: false,
  ),
  ConnectedService(
    id: 'google-fit',
    name: 'Google Fit',
    subtitle: 'Đồng bộ với Google',
    icon: Icons.fitness_center_rounded,
    connected: false,
  ),
  ConnectedService(
    id: 'strava',
    name: 'Strava',
    subtitle: 'Chia sẻ buổi tập với cộng đồng',
    icon: Icons.directions_run_rounded,
    connected: false,
  ),
];

// ═══════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════

const String profileMockVersion = 'v0.1.0 · Beta';
