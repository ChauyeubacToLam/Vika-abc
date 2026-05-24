// ExerciseInsight — editorial card showing one exercise's progress
// for the period. Each card answers four questions in one glance:
//
//   1. WHAT is being measured?    →  metric label  ("Độ sâu khi xuống")
//   2. WHICH WAY is "better"?      →  direction hint ("Càng thấp = càng sâu")
//   3. HOW MUCH did it improve?    →  improvement headline ("Sâu hơn 12°")
//   4. HOW did the user get here?  →  before-→-after timeline bar
//
// Replaces the prior sparkline-and-numbers treatment (which read like
// a stock chart) with a more meaningful before/after visual + plain
// Vietnamese context. A user who doesn't know what "118°" means can
// still read this card and understand: "Squat got deeper. 12° better."

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';

class ExerciseInsight extends StatelessWidget {
  const ExerciseInsight({super.key, required this.mock});

  final ExerciseInsightMock mock;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final rank = int.tryParse(mock.idx) ?? 0;
    final isTopRank = rank <= 3 && rank > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TitleRow(
            idx: mock.idx,
            name: mock.name,
            metric: mock.metric,
            isTopRank: isTopRank,
            cYellow: c.yellow,
            cYellowGhost: c.yellowGhost,
            cYellowInk: c.yellowInk,
            cInk: c.ink,
            cInkSoft: c.inkSoft,
          ),
          const SizedBox(height: 20),
          _ImprovementHero(
            improvement: mock.improvement,
            directionHint: mock.directionHint,
          ),
          const SizedBox(height: 20),
          _BeforeAfterTimeline(from: mock.from, to: mock.to),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CoachMark(small: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mock.coach,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.1,
                      height: 1.5,
                      color: c.inkSoft,
                    ),
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

// ═══════════════════════════════════════════════════════════════
// TITLE ROW — ranking medallion + exercise name + metric subtitle
// ═══════════════════════════════════════════════════════════════

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.idx,
    required this.name,
    required this.metric,
    required this.isTopRank,
    required this.cYellow,
    required this.cYellowGhost,
    required this.cYellowInk,
    required this.cInk,
    required this.cInkSoft,
  });

  final String idx;
  final String name;
  final String metric;
  final bool isTopRank;
  final Color cYellow;
  final Color cYellowGhost;
  final Color cYellowInk;
  final Color cInk;
  final Color cInkSoft;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isTopRank ? cYellow : cYellowGhost,
            shape: BoxShape.circle,
            boxShadow: isTopRank
                ? [
                    BoxShadow(
                      color: cYellow.withValues(alpha: 0.36),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            idx,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.4,
              height: 1,
              color: isTopRank ? cYellowInk : cInk,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PlanH1(
                name,
                size: 26,
                letterSpacing: -0.9,
                height: 1,
              ),
              const SizedBox(height: 6),
              Text(
                metric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.1,
                  height: 1.2,
                  color: cInkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// IMPROVEMENT HERO — big italic delta + direction explainer
// ═══════════════════════════════════════════════════════════════

class _ImprovementHero extends StatelessWidget {
  const _ImprovementHero({
    required this.improvement,
    required this.directionHint,
  });

  final String improvement;
  final String directionHint;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Yellow up-arrow medallion — universal "got better" signal,
        // regardless of which numeric direction means improvement.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.36),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.trending_up_rounded,
            size: 22,
            color: c.yellowInk,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                improvement,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.8,
                  height: 1.05,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                directionHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: c.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BEFORE → AFTER TIMELINE — clear visual journey
// ═══════════════════════════════════════════════════════════════
//
// Two endpoints on a horizontal track, with the start dot at ~8%
// and the today dot at ~92%. Yellow gradient connects them. Labels
// stack: small uppercase "TRƯỚC / HÔM NAY" eyebrow, then the actual
// measurement value below. Reads as a "you were here → now here"
// journey — no axis confusion, no inverted-good/bad ambiguity.

class _BeforeAfterTimeline extends StatelessWidget {
  const _BeforeAfterTimeline({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _EndpointLabel(eyebrow: 'TRƯỚC', value: from, alignEnd: false),
              const Spacer(),
              _EndpointLabel(
                  eyebrow: 'HÔM NAY', value: to, alignEnd: true, isToday: true),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 18,
            child: LayoutBuilder(
              builder: (context, bc) {
                final width = bc.maxWidth;
                const startPct = 0.06;
                const endPct = 0.94;
                final leftX = startPct * width;
                final rightX = endPct * width;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Track.
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Yellow improvement segment between the two dots.
                    Positioned(
                      top: 6,
                      left: leftX,
                      width: rightX - leftX,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              c.yellow.withValues(alpha: 0.35),
                              c.yellow,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: c.yellow.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Start dot — faint ring.
                    Positioned(
                      top: 3,
                      left: leftX - 6,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: c.bgRaised,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.inkFaint,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Today dot — bright yellow with glow.
                    Positioned(
                      top: 1,
                      left: rightX - 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: c.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.bgRaised,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: c.yellow.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointLabel extends StatelessWidget {
  const _EndpointLabel({
    required this.eyebrow,
    required this.value,
    required this.alignEnd,
    this.isToday = false,
  });

  final String eyebrow;
  final String value;
  final bool alignEnd;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: c.inkFaint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: isToday ? 18 : 14,
            fontWeight: FontWeight.w800,
            fontStyle: isToday ? FontStyle.italic : FontStyle.normal,
            letterSpacing: -0.3,
            height: 1,
            color: isToday ? c.ink : c.inkSoft,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      ],
    );
  }
}
