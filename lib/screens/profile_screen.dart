import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/vf_theme.dart';
import '../widgets/section_head.dart';
import '../widgets/stat_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final padding = VFTheme.screenPadding(context);
    final scale = VFTheme.scale(context);

    return SingleChildScrollView(
      key: const PageStorageKey<String>('profile-scroll'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        padding.left,
        14 * scale,
        padding.right,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 20 * scale,
            ),
            decoration: BoxDecoration(
              color: VFTheme.surface,
              borderRadius: BorderRadius.circular(VFTheme.cardRadius(context)),
            ),
            child: Column(
              children: [
                Container(
                  width: 60 * scale,
                  height: 60 * scale,
                  decoration: BoxDecoration(
                    color: VFTheme.accent,
                    borderRadius: BorderRadius.circular(16 * scale),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dashboardUser.initial,
                    style: TextStyle(
                      fontSize: VFTheme.font(context, 24),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 10 * scale),
                Text(
                  dashboardUser.name,
                  style: TextStyle(
                    fontSize: VFTheme.font(context, 18),
                    fontWeight: FontWeight.w800,
                    color: VFTheme.text,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: VFTheme.accentBg,
                    borderRadius: BorderRadius.circular(6 * scale),
                  ),
                  child: Text(
                    'Level ${dashboardUser.level} · ${dashboardUser.levelTitle}',
                    style: TextStyle(
                      fontSize: VFTheme.font(context, 12),
                      fontWeight: FontWeight.w700,
                      color: VFTheme.accent,
                    ),
                  ),
                ),
                SizedBox(height: 10 * scale),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                  child: Column(
                    children: [
                      Container(
                        height: 6 * scale,
                        decoration: BoxDecoration(
                          color: VFTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(3 * scale),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: dashboardUser.xpProgress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [VFTheme.accent, Color(0xAA2E856E)],
                              ),
                              borderRadius: BorderRadius.circular(3 * scale),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Row(
                        children: [
                          Text(
                            '${dashboardUser.xp} XP',
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 10),
                              fontWeight: FontWeight.w600,
                              color: VFTheme.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(dashboardUser.xpProgress * 100).round()}%',
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 10),
                              fontWeight: FontWeight.w700,
                              color: VFTheme.accent,
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          Text(
                            'Level 3: ${dashboardUser.nextLevelXp} XP',
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 10),
                              fontWeight: FontWeight.w600,
                              color: VFTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Expanded(
                child: StatCard(
                    value: '${dashboardUser.workoutCount}', label: 'Buổi tập'),
              ),
              SizedBox(width: 6 * scale),
              Expanded(
                child: StatCard(value: dashboardUser.totalTime, label: 'Tổng'),
              ),
              SizedBox(width: 6 * scale),
              Expanded(
                child: StatCard(
                    value: dashboardUser.completionRate, label: 'Hoàn thành'),
              ),
            ],
          ),
          const SectionHead(title: 'Huy hiệu', action: 'Tất cả'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: profileBadges.map((badge) {
                return Padding(
                  padding: EdgeInsets.only(right: 6 * scale),
                  child: Opacity(
                    opacity: badge.earned ? 1 : 0.35,
                    child: Container(
                      width: 62 * scale,
                      padding: EdgeInsets.fromLTRB(
                        6 * scale,
                        10 * scale,
                        6 * scale,
                        8 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: badge.background,
                        borderRadius: BorderRadius.circular(12 * scale),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            badge.icon,
                            size: 20 * scale,
                            color: badge.color,
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            badge.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: VFTheme.font(context, 9),
                              fontWeight: FontWeight.w700,
                              color: badge.color,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SectionHead(title: 'Cài đặt'),
          Column(
            children: profileSettings.map((setting) {
              return Padding(
                padding: EdgeInsets.only(bottom: 4 * scale),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * scale,
                    vertical: 12 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: VFTheme.surface,
                    borderRadius: BorderRadius.circular(10 * scale),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34 * scale,
                        height: 34 * scale,
                        decoration: BoxDecoration(
                          color: setting.background,
                          borderRadius: BorderRadius.circular(10 * scale),
                        ),
                        child: Icon(
                          setting.icon,
                          size: 16 * scale,
                          color: setting.color,
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              setting.label,
                              style: TextStyle(
                                fontSize: VFTheme.font(context, 13),
                                fontWeight: FontWeight.w600,
                                color: VFTheme.text,
                              ),
                            ),
                            SizedBox(height: 1 * scale),
                            Text(
                              setting.subtitle,
                              style: TextStyle(
                                fontSize: VFTheme.font(context, 11),
                                fontWeight: FontWeight.w500,
                                color: VFTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16 * scale,
                        color: VFTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12 * scale),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 14 * scale,
            ),
            decoration: BoxDecoration(
              color: VFTheme.accentBg,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 18 * scale,
                  color: VFTheme.accent,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đánh giá lại',
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 13),
                          fontWeight: FontWeight.w700,
                          color: VFTheme.accent,
                        ),
                      ),
                      SizedBox(height: 1 * scale),
                      Text(
                        'Kiểm tra form sau mỗi 2 tuần',
                        style: TextStyle(
                          fontSize: VFTheme.font(context, 11),
                          fontWeight: FontWeight.w500,
                          color: VFTheme.accentText.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
