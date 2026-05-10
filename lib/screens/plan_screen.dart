// PlanScreen — the Lộ Trình tab. Premium Ivory v1, mirroring the layout
// from vika-main-app-ivory-v1.jsx (specifically the Plan tab page).
//
// Structure:
//   • WordmarkHeader (pinned)
//   • SectionMark "§01 · Lộ trình 4 tuần" (pinned)
//   • PageHero — italic "Tuần 03" + dates + StatusSwipeDots (pinned, updates
//     as the swiper changes)
//   • PageView with one WeekPage per week (4 weeks; horizontally swipable)
//   • EditorialCloser pinned at the bottom (above the nav bar)
//
// The JSX uses a unified vertical scroll containing a horizontal pager. In
// Flutter that translates poorly (PageView wants a fixed height; nested
// scrolls fight each other), so we pin the chrome and let each week page
// scroll internally. Visually identical to the prototype on screen — only
// the scroll containment differs.
//
// Data: all from `phaseWeeksMock`. The "Bắt đầu Buổi NN" CTA is stubbed
// (debugPrint) until real exercise wiring lands; see the user's design
// decision in the Plan v3 implementation thread.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/plan_mock.dart';
import '../services/user_program_service.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/plan/editorial_closer.dart';
import '../widgets/plan/page_hero.dart';
import '../widgets/plan/section_mark.dart';
import '../widgets/plan/week_page.dart';
import '../widgets/plan/wordmark_header.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
    this.program,
  });

  final double bottomPadding;

  /// The legacy real-data program from MainShell. Currently unused — the new
  /// Plan v3 layout runs on `phaseWeeksMock` per the spec. Kept on the
  /// constructor so MainShell doesn't need to change.
  final UserProgramData? program;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  /// 1-based active week index. Defaults to the current week (3) — the
  /// pager initialises pointing at it on first frame.
  late int _activeWeek;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());

    // Find the current week in the mock and use it as the initial page.
    final currentIdx = phaseWeeksMock
        .indexWhere((w) => w.status == WeekStatus.current);
    final initialIdx = currentIdx == -1 ? 0 : currentIdx;
    _activeWeek = initialIdx + 1;
    _controller = PageController(initialPage: initialIdx);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VikaIvoryMain.bg,
      child: Column(
        children: [
          const WordmarkHeader(),
          const SectionMark(
            num: '01',
            label: 'Lộ trình 4 tuần',
            // total intentionally null — only one "section" on this page,
            // so the "01 / 02" index would just say "01 / 01".
          ),
          PageHero(
            weeks: phaseWeeksMock,
            activeWeek: _activeWeek,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (idx) {
                setState(() => _activeWeek = idx + 1);
              },
              itemCount: phaseWeeksMock.length,
              itemBuilder: (context, idx) {
                final week = phaseWeeksMock[idx];
                final next = idx + 1 < phaseWeeksMock.length
                    ? phaseWeeksMock[idx + 1]
                    : null;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: widget.bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WeekPage(
                          week: week,
                          isActive: week.num == _activeWeek,
                          nextWeek: next,
                        ),
                        // Closer rides at the bottom of each week's
                        // scroll content — feels like a magazine page break
                        // between weeks rather than a single fixed footer.
                        const EditorialCloser(
                          section: 'LỘ TRÌNH',
                          tagline: '4 tuần · Phase 1.',
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
