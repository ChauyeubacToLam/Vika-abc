// DashboardHomeScreen — the Home tab. Premium Ivory v1.
//
// Mirrors HomeScreen in vika-main-app-ivory-v1.jsx:
//   • Wordmark header
//   • Greeting block
//   • §01 Hôm nay — horizontal HeroDayCard rail (today's card + tomorrow peek)
//   • §02 Đang tiến bộ — StreakRing + FormWeekChart side-by-side
//   • Journal entry quote
//   • BrowseShortcut → opens Library sheet
//   • Editorial closer
//
// Class name DashboardHomeScreen kept for MainShell compatibility; the
// content is fully new.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/home_mock.dart';
import '../models/exercise_lookup.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/recommendation/weekly_check_in_service.dart';
import '../services/user_program_service.dart';
import '../theme/app_colors.dart';
import '../utils/orientation_lock.dart';
import 'weekly_check_in_screen.dart';
import '../widgets/home/browse_shortcut.dart';
import '../widgets/home/form_week_chart.dart';
import '../widgets/home/greeting_block.dart';
import '../widgets/home/hero_day_card.dart';
import '../widgets/home/journal_entry.dart';
import '../widgets/home/streak_ring.dart';
import '../widgets/plan/editorial_closer.dart';
import '../widgets/plan/section_mark.dart';
import '../widgets/plan/wordmark_header.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({
    super.key,
    required this.bottomPadding,
    required this.onOpenBrowser,
    this.program,
  });

  final double bottomPadding;
  final VoidCallback onOpenBrowser;

  /// Real program data passed from MainShell. Currently unused — the new
  /// design runs on `homeMock*` constants. Wiring notes in the report.
  final UserProgramData? program;

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final _recommendations = RecommendationService();
  final _checkIns = WeeklyCheckInService();
  _CheckInPrompt? _checkInPrompt;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    unawaited(_loadCheckInPrompt());
  }

  Future<void> _loadCheckInPrompt() async {
    final snapshot =
        await _recommendations.fetchLatestPlanSnapshotForCurrentUser();
    final plan = snapshot?.plan;
    if (snapshot == null || plan == null) return;
    final weekNumber = snapshot.currentWeekNumber;
    if (!plan.weeklyCheckInWeeks.contains(weekNumber)) return;
    final due = await _checkIns.isDue(
      recommendationId: plan.recommendationId,
      weekNumber: weekNumber,
    );
    if (!mounted || !due) return;
    setState(() {
      _checkInPrompt = _CheckInPrompt(
        recommendationId: plan.recommendationId,
        weekNumber: weekNumber,
      );
    });
  }

  Future<void> _openCheckIn() async {
    final prompt = _checkInPrompt;
    if (prompt == null) return;
    final completed = await Navigator.of(context).pushNamed(
      '/weekly-check-in',
      arguments: WeeklyCheckInLaunchArgs(
        recommendationId: prompt.recommendationId,
        weekNumber: prompt.weekNumber,
      ),
    );
    if (!mounted) return;
    if (completed == true) {
      setState(() => _checkInPrompt = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Status-bar overlay flips per theme. Light theme = dark icons on
    // cream; dark theme = light icons on warm-dark.
    final overlayStyle = c.isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Container(
        color: c.bg,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: widget.bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WordmarkHeader(
                trailingIcon: Icons.notifications_none_rounded,
              ),
              GreetingBlock(
                userName: homeMockUser.name,
                dayLabel: homeMockUser.dayLabel,
                sessionLabel: homeMockUser.sessionLabel,
              ),
              if (_checkInPrompt != null)
                _WeeklyCheckInBanner(
                  weekNumber: _checkInPrompt!.weekNumber,
                  onTap: _openCheckIn,
                ),
              const SectionMark(num: '01', label: 'Hôm nay', total: '02'),
              const SizedBox(height: 18),
              _HeroDayRail(onCta: () => _startTodayWorkout(context)),
              const SectionMark(num: '02', label: 'Đang tiến bộ', total: '02'),
              const _ProgressRow(),
              JournalEntry(
                dateLabel: homeMockJournalDate,
                quote: homeMockJournalQuote,
              ),
              BrowseShortcut(onTap: widget.onOpenBrowser),
              const EditorialCloser(
                section: 'TRANG CHỦ',
                tagline: 'Thứ Sáu · 8/5.',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Start today's workout. Defaults to the Squat ExerciseDefinition until
  /// per-day workout sequences are wired (see PREMIUM_IVORY_WIRING.md).
  /// Fires light haptic feedback on tap so the press registers physically
  /// — important for a fitness app where the user is bracing to start.
  void _startTodayWorkout(BuildContext context) {
    HapticFeedback.lightImpact();
    final def = lookupExerciseDefinition('Squat');
    if (def != null) {
      Navigator.of(context).pushNamed('/exercise', arguments: def);
    } else {
      debugPrint('[Home] No ExerciseDefinition for Squat — stubbed.');
    }
  }
}

class _CheckInPrompt {
  const _CheckInPrompt({
    required this.recommendationId,
    required this.weekNumber,
  });

  final String recommendationId;
  final int weekNumber;
}

class _WeeklyCheckInBanner extends StatelessWidget {
  const _WeeklyCheckInBanner({
    required this.weekNumber,
    required this.onTap,
  });

  final int weekNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Material(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 17,
                    color: c.yellowInk,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check-in tuần $weekNumber',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '30 giây để Vika hiểu cơ thể bạn hơn.',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDayRail extends StatelessWidget {
  const _HeroDayRail({required this.onCta});

  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Stack draws bottom-up. Cards sit underneath; the sticker is drawn
    // LAST so it floats over the top edge of the first card — matches
    // the JSX intent (sticker overlaps the top of the today card).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Cards rail.
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: SizedBox(
            height: 470,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const PageScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: homeMockHeroDays.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final mock = homeMockHeroDays[idx];
                return HeroDayCard(
                  eyebrow: mock.eyebrow,
                  titleLine1: mock.titleLine1,
                  titleLine2: mock.titleLine2,
                  stats: mock.stats,
                  cta: mock.cta,
                  isToday: mock.isToday,
                  onCta: mock.isToday ? onCta : null,
                );
              },
            ),
          ),
        ),
        // 2. Bottom dots.
        Positioned(
          bottom: -2,
          left: 0,
          right: 0,
          child: _RailDots(
            count: homeMockHeroDays.length,
            activeIndex: 0,
          ),
        ),
        // 3. "Gợi ý cho bạn" sticker — drawn LAST so it floats over the
        // top edge of the today card. Slightly rotated for a "stuck on"
        // feel; the shadow gives it a paper-tag pop.
        Positioned(
          top: -8,
          left: 36,
          child: Transform.rotate(
            angle: -0.026, // -1.5°
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: c.yellow,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'GỢI Ý CHO BẠN',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: c.yellowInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailDots extends StatelessWidget {
  const _RailDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            width: i == activeIndex ? 22 : 4,
            height: 4,
            decoration: BoxDecoration(
              color: i == activeIndex ? c.ink : c.inkGhost,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreakRing(
            days: homeMockStreakDays,
            weekDots: homeMockWeekDots,
          ),
          const SizedBox(width: 24),
          const Expanded(
            child: FormWeekChart(
              todayPercent: homeMockFormToday,
              delta: homeMockFormDelta,
              weekValues: homeMockFormWeek,
            ),
          ),
        ],
      ),
    );
  }
}
