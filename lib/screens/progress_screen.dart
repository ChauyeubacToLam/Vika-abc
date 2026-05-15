// ProgressScreen — the Tiến bộ tab. Premium Ivory v1.
//
// Mirrors ProgressScreen in vika-main-app-ivory-v1.jsx:
//   • §01 Tiến bộ section mark
//   • Editorial header (eyebrow + italic "Khoẻ hơn rõ rệt." headline + meta)
//   • Period tabs (week / month / program)
//   • HeadlineHero (warm-dark, big +14, fromTo bar, coach line)
//   • BodyHeatMap section
//   • RankedInsights section
//   • ProgressStreakCard section
//   • Editorial closer

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/plan_mock.dart' show phaseWeeksMock, planTotalCompleted, planTotalSessions;
import '../data/progress_mock.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/plan/editorial_closer.dart';
import '../widgets/plan/plan_typography.dart';
import '../widgets/plan/section_mark.dart';
import '../widgets/progress/body_heat_map.dart';
import '../widgets/progress/headline_hero.dart';
import '../widgets/progress/period_tabs.dart';
import '../widgets/progress/progress_streak_card.dart';
import '../widgets/progress/ranked_insights.dart';
import '../theme/app_colors.dart';
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.bottomPadding});

  final double bottomPadding;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  PeriodTab _period = PeriodTab.program;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final periodKey = switch (_period) {
      PeriodTab.week => 'week',
      PeriodTab.month => 'month',
      PeriodTab.program => 'program',
    };
    final headline = progressMockHeadline[periodKey]!;
    final totalDone = planTotalCompleted(phaseWeeksMock);
    final totalSessions = planTotalSessions(phaseWeeksMock);

    return Container(
      color: c.bg,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionMark(num: '01', label: 'Tiến bộ'),
            // Editorial header.
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlanEyebrow(
                    'TỪ 21/4 · 4 TUẦN · PHASE 1',
                    size: 10,
                    letterSpacing: 2,
                    tabular: true,
                  ),
                  SizedBox(height: 10),
                  PlanH1(
                    'Khoẻ hơn rõ rệt.',
                    size: 36,
                    letterSpacing: -1.8,
                    height: 0.95,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Text(
                '$totalDone / $totalSessions buổi đã xong · Đang ở Tuần 03',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: c.inkSoft,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ),
            // Period tabs.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: PeriodTabs(
                value: _period,
                onChanged: (v) => setState(() => _period = v),
              ),
            ),
            // Headline hero.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: HeadlineHero(data: headline),
            ),
            // Body heatmap.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: PlanEyebrow(
                          'Vùng cơ thể đang khoẻ lên',
                          size: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '4 vùng',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: c.inkFaint,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const BodyHeatMap(
                    areas: progressMockBodyAreas,
                    gender: BodyGender.male,
                  ),
                ],
              ),
            ),
            // Ranked insights.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: PlanEyebrow(
                          'Bài tập nổi bật',
                          size: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '${progressMockInsights.length} đo được · 3 nổi bật',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: c.inkFaint,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RankedInsights(ranked: progressMockInsights),
                ],
              ),
            ),
            // Streak.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: PlanEyebrow('Chuỗi liên tiếp',
                            size: 10, letterSpacing: 2),
                      ),
                      Text(
                        '$progressMockStreakDays ngày',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: c.inkFaint,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ProgressStreakCard(
                    days: progressMockStreakDays,
                    bars: progressMockStreakBars,
                    summary: progressMockStreakSummary,
                  ),
                ],
              ),
            ),
            const EditorialCloser(
              section: 'TIẾN BỘ',
              tagline: 'Tuần 04 sắp tới.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
