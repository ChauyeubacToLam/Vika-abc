// ProfileScreen — the Hồ sơ tab. Premium Ivory v1.
//
// Mirrors ProfileScreen in vika-main-app-ivory-v1.jsx:
//   • §01 section mark "Hồ sơ"
//   • IdentityBlock — avatar + italic name + meta
//   • LifetimeHero — warm-dark goal card with 3-stat trio + coach line
//   • BodyCard — supporting cream card with vóc dáng + BMI
//   • Settings groups (Tập luyện / Quyền riêng tư / Cộng đồng & Hỗ trợ /
//     Tài khoản)
//   • Editorial closer with the Vika V badge
//
// Note: Replaces the legacy ProfileScreen. The previous version had a
// debug-preferences toggle for development; that's been moved out — the
// new design is for end users. Reintroduce a hidden debug entry if needed.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/profile_mock.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/plan/section_mark.dart';
import '../widgets/profile/body_card.dart';
import '../widgets/profile/identity_block.dart';
import '../widgets/profile/lifetime_hero.dart';
import '../widgets/profile/settings_group.dart';
import '../theme/app_colors.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.bottomPadding});

  final double bottomPadding;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      color: c.bg,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionMark(num: '01', label: 'Hồ sơ'),
            const IdentityBlock(
              name: profileMockName,
              initial: profileMockInitial,
              memberSince: profileMockMemberSince,
              level: profileMockLevel,
              phase: profileMockPhase,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: LifetimeHero(
                goalTitle: profileMockGoalTitle,
                goalQuote: profileMockGoalQuote,
                stats: profileMockLifetimeStats,
                coach: profileMockCoachLine,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: BodyCard(
                height: profileMockHeight,
                weight: profileMockWeight,
                age: profileMockAge,
                bmi: profileMockBMI,
              ),
            ),
            // Settings.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use the eyebrow from plan_typography directly via a
                  // SettingsGroup label — keeps consistency.
                  SettingsGroup(
                    label: 'Cài đặt · Tập luyện',
                    rows: [
                      SettingRow(
                        icon: Icons.notifications_none_rounded,
                        label: 'Nhắc tập',
                        sub: 'T2/T4/T6 · 17:30',
                        onTap: () {},
                      ),
                      SettingRow(
                        icon: Icons.mic_none_rounded,
                        label: 'Giọng huấn luyện viên',
                        sub: 'Nữ · Tự nhiên',
                        onTap: () {},
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Quyền riêng tư',
                    rows: [
                      SettingRow(
                        icon: Icons.shield_outlined,
                        label: 'Quyền riêng tư',
                        sub: 'Camera xử lý trong máy',
                        onTap: () {},
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Cộng đồng & Hỗ trợ',
                    rows: [
                      SettingRow(
                        icon: Icons.star_border_rounded,
                        label: 'Mời bạn dùng Vika',
                        sub: 'Cùng tập, cùng khoẻ',
                        onTap: () {},
                      ),
                      SettingRow(
                        icon: Icons.help_outline_rounded,
                        label: 'Trợ giúp & Phản hồi',
                        onTap: () {},
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Tài khoản',
                    rows: [
                      SettingRow(
                        icon: Icons.logout_rounded,
                        label: 'Đăng xuất',
                        danger: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Editorial closer with Vika V badge.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Container(
                padding: const EdgeInsets.only(top: 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'V',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VIKA · HỒ SƠ',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Container(
                            height: 1, color: c.border)),
                    const SizedBox(width: 14),
                    Text(
                      'v0.1.0 · Beta',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: c.inkFaint,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
