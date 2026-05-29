// TodayCard — the warm-dark hero card for today's workout in the current
// week. Yellow "HÔM NAY" pill in the top-right, italic display title, three
// stat row, yellow CTA "Bắt đầu Buổi NN".
//
// Mirrors `TodayCard` in vika-main-app-ivory-v1.jsx. Note: the JSX does NOT
// place FigureSkeleton inside TodayCard (that's the Home-screen HeroDayCard);
// TodayCard on Plan is a clean editorial card without it.
//
// CTA opens /exercise with a default ExerciseDefinition (Squat) when no
// onStart override is provided. As soon as the today's-workout data
// includes a list of exercises, this default should be replaced with
// "first exercise of today's workout".

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/plan_mock.dart';
import '../../models/exercise_lookup.dart';
import 'plan_typography.dart';
import '../../theme/app_colors.dart';

class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.day,
    required this.weekNum,
    this.onStart,
  });

  final PlanDay day;
  final int weekNum;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final dayLong = day.weekdayLong.isNotEmpty
        ? day.weekdayLong
        : _longFromShort(day.weekday);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(22),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.55, -1),
            end: Alignment(0.55, 1),
            colors: [c.bgInverse, c.bgInverseHi],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // "HÔM NAY" badge, top-right.
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'HÔM NAY',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: c.yellowInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Card body.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlanEyebrow(
                  '${dayLong.toUpperCase()} · ${day.date}',
                  size: 9,
                  letterSpacing: 1.8,
                  dark: true,
                ),
                const SizedBox(height: 14),
                PlanH1(day.title, size: 34, dark: true, letterSpacing: -2),
                const SizedBox(height: 14),
                // Stat row: 15 phút | 4 bài | 3 có camera AI
                Row(
                  children: [
                    _Stat(
                      icon: Icons.access_time_rounded,
                      label: day.duration.isEmpty ? '15 phút' : day.duration,
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 1,
                      height: 14,
                      color: c.borderDark,
                    ),
                    const SizedBox(width: 14),
                    _Stat(
                      icon: Icons.check_circle_outline_rounded,
                      label: '${day.count} bài',
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 1,
                      height: 14,
                      color: c.borderDark,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '3 có camera AI',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: c.invInkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                // Yellow CTA. Default behaviour: push /exercise with the
                // first available real ExerciseDefinition (Squat). Caller
                // can override via `onStart` to launch a different
                // exercise once per-day workout sequences are wired.
                _StartButton(
                  label: 'Bắt đầu Buổi ${weekNum.toString().padLeft(2, '0')}',
                  onTap: onStart ??
                      () {
                        final def = lookupExerciseDefinition('Squat');
                        if (def != null) {
                          Navigator.of(context)
                              .pushNamed('/exercise', arguments: def);
                          return;
                        }
                        if (kDebugMode) {
                          debugPrint(
                            '[Plan] No ExerciseDefinition for fallback '
                            'Squat — start CTA stubbed. (week $weekNum, '
                            '${day.title})',
                          );
                        }
                      },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _longFromShort(String s) {
    const map = {
      'T2': 'Thứ Hai',
      'T3': 'Thứ Ba',
      'T4': 'Thứ Tư',
      'T5': 'Thứ Năm',
      'T6': 'Thứ Sáu',
      'T7': 'Thứ Bảy',
      'CN': 'Chủ Nhật',
    };
    return map[s] ?? s;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.yellow),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: c.invInk,
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: c.yellowInk,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: c.yellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
