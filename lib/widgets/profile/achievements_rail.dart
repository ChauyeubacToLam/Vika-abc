// AchievementsRail — horizontal rail of editorial achievement
// medallions. Reads like a magazine spread of awards, not a video-
// game trophy tree.
//
// Each medallion:
//   ┌────────────┐
//   │   01.      │  ← italic chapter numeral
//   │            │
//   │ ┌────┐     │
//   │ │ ⭐ │     │  ← small icon medallion
//   │ └────┘     │
//   │            │
//   │ NGÀY 7.    │  ← italic display headline
//   │ Tuần đầu   │  ← italic subtitle
//   │            │
//   │ ✓ 03 / 5   │  ← date earned (or 'CHƯA MỞ' if locked)
//   └────────────┘
//
// Unlocked = yellow filled accent + ink text.
// Locked   = cream-ghost background + faint text + lock icon.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/profile_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class AchievementsRail extends StatelessWidget {
  const AchievementsRail({
    super.key,
    required this.achievements,
    this.cardWidth = 156,
    this.gutter = 20,
  });

  final List<Achievement> achievements;
  final double cardWidth;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
        itemCount: achievements.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _Medallion(
          achievement: achievements[i],
          index: i,
          width: cardWidth,
        ),
      ),
    );
  }
}

class _Medallion extends StatefulWidget {
  const _Medallion({
    required this.achievement,
    required this.index,
    required this.width,
  });
  final Achievement achievement;
  final int index;
  final double width;

  @override
  State<_Medallion> createState() => _MedallionState();
}

class _MedallionState extends State<_Medallion> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final a = widget.achievement;
    final unlocked = a.unlocked;

    final surface = unlocked ? c.bgRaised : c.powder;
    final borderColor = unlocked ? c.yellow.withValues(alpha: 0.35) : c.border;
    final borderWidth = unlocked ? 1.2 : 1.0;
    final shadowAlpha = unlocked ? 0.12 : 0.04;

    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: unlocked
                      ? c.yellow.withValues(alpha: shadowAlpha)
                      : c.ink.withValues(alpha: shadowAlpha),
                  blurRadius: unlocked ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Yellow halo top-right on unlocked medallions.
                if (unlocked)
                  Positioned(
                    top: -50,
                    right: -50,
                    child: IgnorePointer(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.yellow.withValues(alpha: 0.26),
                              c.yellow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Big italic chapter numeral watermark, bottom-right.
                Positioned(
                  bottom: -22,
                  right: -8,
                  child: IgnorePointer(
                    child: Text(
                      '${(widget.index + 1).toString().padLeft(2, '0')}.',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 96,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -4,
                        height: 1,
                        color: (unlocked ? c.yellow : c.ink)
                            .withValues(alpha: unlocked ? 0.08 : 0.05),
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top: small icon medallion (lock / star).
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: unlocked
                              ? c.yellow
                              : c.inkGhost.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          boxShadow: unlocked
                              ? [
                                  BoxShadow(
                                    color: c.yellow.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          unlocked
                              ? Icons.workspace_premium_rounded
                              : Icons.lock_outline_rounded,
                          size: 15,
                          color: unlocked ? c.yellowInk : c.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Italic display headline.
                      Text(
                        '${a.headline}.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.7,
                          height: 1.0,
                          color: unlocked ? c.ink : c.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Italic subtitle.
                      Text(
                        a.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                          color: unlocked
                              ? c.inkSoft
                              : c.inkFaint.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      // Footer: date earned or "CHƯA MỞ".
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: unlocked
                              ? c.yellowGhost
                              : c.bg.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: unlocked
                                ? c.yellow.withValues(alpha: 0.3)
                                : c.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              unlocked
                                  ? Icons.check_rounded
                                  : Icons.schedule_rounded,
                              size: 11,
                              color: unlocked ? c.ink : c.inkFaint,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              unlocked ? (a.unlockedOn ?? '✓') : 'CHƯA MỞ',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: unlocked ? c.ink : c.inkFaint,
                                fontFeatures: VikaIvoryMain.tabularFigures,
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
          ),
        ),
      ),
    );
  }
}
