// HeadlineHero — warm-dark hero card on Progress. Big italic +14 in yellow,
// "Form chuẩn trung bình" eyebrow with period delimiter, fromTo bar
// (0–100 scale with start dot + today dot + yellow segment), coach line.
//
// Mirrors `ProgressHeadlineHero` and `FromToBar` in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';

class HeadlineHero extends StatelessWidget {
  const HeadlineHero({super.key, required this.data});

  final HeadlineForPeriod data;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Yellow radial wash, top-right.
          Positioned(
            top: -50,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.20),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlanEyebrow(
                    'FORM CHUẨN TRUNG BÌNH',
                    size: 9,
                    letterSpacing: 2,
                    color: c.yellow,
                    tabular: true,
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.yellow.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: PlanEyebrow(
                      data.label,
                      size: 9,
                      letterSpacing: 2,
                      color: c.invInkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    data.delta,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 80,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -4,
                      height: 0.85,
                      color: c.yellow,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'điểm form',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: c.invInkSoft,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _FromToBar(from: data.from, to: data.to),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: c.borderDark),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CoachMark(small: true),
                        const SizedBox(width: 8),
                        PlanEyebrow(
                          'HUẤN LUYỆN VIÊN GHI',
                          size: 9,
                          letterSpacing: 1.6,
                          dark: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PlanP(
                      data.coach,
                      dark: true,
                      italic: true,
                      size: 14,
                      letterSpacing: -0.2,
                      height: 1.45,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FromToBar extends StatelessWidget {
  const _FromToBar({required this.from, required this.to});

  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PlanEyebrow('BẮT ĐẦU', size: 9, letterSpacing: 1.2, dark: true),
            PlanEyebrow('HÔM NAY', size: 9, letterSpacing: 1.2, dark: true),
          ],
        ),
        const SizedBox(height: 8),
        // 0–100 bar
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (context, bc) {
              final width = bc.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.invInk.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Yellow segment from→to
                  Positioned(
                    top: 4,
                    left: (from / 100) * width,
                    width: ((to - from) / 100) * width,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.35),
                            c.yellow,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Start dot
                  Positioned(
                    top: 1,
                    left: (from / 100) * width - 7,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: c.bgInverse,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.invInk.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Today dot
                  Positioned(
                    top: 0,
                    left: (to / 100) * width - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.bgInverse,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$from',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c.invInkSoft,
                letterSpacing: -0.2,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            Text(
              '$to',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: c.invInk,
                letterSpacing: -0.2,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
