// DashboardHomeScreen — polished Stage Home (Premium Ivory v5).
//
// Two registers, one cohesive page:
//
//   ┌─ DARK STAGE HERO (bleeds to top edge, owns the fold)
//   │     • Inverted WordmarkHeader
//   │     • Sparkle eyebrow ('HÔM NAY · BUỔI 03')
//   │     • Italic display headline (2 lines)
//   │     • Stat row with breathing yellow live dot
//   │     • SESSION BRIEF card:
//   │         - vertical-timeline exercise list (uniform gold dots, AI
//   │           as inline yellow accent on the detail line)
//   │         - inner hairline
//   │         - coach voice quote + attribution (embedded — no separate
//   │           coach card stacked below)
//   │     • Halo CTA pill
//   │
//   ├─ WEEKLY CHECK-IN BANNER (when due, real data)
//   │
//   └─ VITALS SPREAD (cream, NO CARD — magazine typography spread)
//         • Header rail: TUẦN 03 ─── NỀN TẢNG
//         • Drop-cap sessions hero: BIG italic 3 + /4 + progress dots +
//           label + italic standfirst
//         • Hairline divider
//         • Streak + form supporting metrics (vertical hairline between)
//         • Sign-off colophon
//
// The previous v4 stacked TWO raised cards below the hero (vitals panel
// + coach card) — that read as "lazy stacking". v5 absorbs coach into
// the hero (cohesive action surface) and renders vitals as naked
// typography on cream (editorial, no card chrome). One card surface
// total below the hero, only when a weekly check-in is actually due.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/home_mock.dart';
import '../data/library_mock.dart';
import '../screens/exercise/exercise_launch_args.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/recommendation/weekly_check_in_service.dart';
import '../services/session_persistence.dart';
import '../services/streak_tier.dart';
import '../services/user_program_service.dart';
import '../services/user_profile_service.dart';
import '../services/workout_launch_service.dart';
import '../theme/app_colors.dart';
import '../utils/orientation_lock.dart';
import '../widgets/home/home_signoff.dart';
import '../widgets/home/home_stage_hero.dart';
import '../widgets/home/home_vitals_spread.dart';
import 'weekly_check_in_screen.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({
    super.key,
    required this.bottomPadding,
    required this.onOpenBrowser,
    this.program,
    this.userProfile,
    this.onProfileChanged,
  });

  final double bottomPadding;
  final VoidCallback onOpenBrowser;

  /// Real program data passed from MainShell. The CTA launches the
  /// first available program exercise. Vitals (session counts, streak,
  /// form 7-day) are wired to real data; the hero headline copy still
  /// renders from `homeMock*` constants.
  // TODO(wiring): derive today's session headline copy (titleLine1/2) from
  // `program` + RecommendationService.
  final UserProgramData? program;
  final AppUserProfile? userProfile;
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final _recommendations = RecommendationService();
  final _checkIns = WeeklyCheckInService();
  final _launches = WorkoutLaunchService();
  late Future<WorkoutLaunchHomeState> _launchStateFuture;
  late Future<int> _streakFuture;
  late Future<({int? percent, int? delta, List<int> week})> _formSummaryFuture;
  _CheckInPrompt? _checkInPrompt;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _launchStateFuture = _launches.resolveHomeState();
    _streakFuture = SessionPersistence().currentStreak();
    _formSummaryFuture = SessionPersistence().homeFormSummary();
    unawaited(_loadCheckInPrompt());
  }

  Future<void> _loadCheckInPrompt() async {
    final snapshot =
        await _recommendations.fetchLatestPlanSnapshotForCurrentUser();
    final plan = snapshot?.plan;
    final position = snapshot?.currentPosition;
    if (snapshot == null || plan == null || position == null) return;
    final weekNumber = position.$1;
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

  void _reloadLaunchTarget() {
    setState(() {
      _launchStateFuture = _launches.resolveHomeState();
      _streakFuture = SessionPersistence().currentStreak();
      _formSummaryFuture = SessionPersistence().homeFormSummary();
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
    return Container(
      color: c.bg,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: widget.bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<WorkoutLaunchHomeState>(
                future: _launchStateFuture,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final target = state?.target;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeHeroFromTarget(
                        state: state,
                        target: target,
                        loading:
                            snapshot.connectionState == ConnectionState.waiting,
                        onStretch: widget.onOpenBrowser,
                        profile: widget.userProfile,
                        onStart: target == null
                            ? null
                            : () => _startWorkoutTarget(target),
                      ),
                    ],
                  );
                },
              ),
              if (_checkInPrompt != null)
                _WeeklyCheckInAlert(
                  weekNumber: _checkInPrompt!.weekNumber,
                  onTap: _openCheckIn,
                ),
              FutureBuilder<WorkoutLaunchHomeState>(
                future: _launchStateFuture,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  // While the structural session data is in flight, shimmer
                  // the vitals spread rather than seeding it with mock counts.
                  final Widget vitals = snapshot.connectionState ==
                          ConnectionState.waiting
                      ? const HomeVitalsSkeleton(key: ValueKey('vitals-skeleton'))
                      : KeyedSubtree(
                          key: const ValueKey('vitals-real'),
                          child: FutureBuilder<int>(
                            future: _streakFuture,
                            builder: (context, streakSnapshot) {
                              return FutureBuilder<
                                  ({int? percent, int? delta, List<int> week})>(
                                future: _formSummaryFuture,
                                builder: (context, formSnapshot) {
                                  final form = formSnapshot.data;
                                  return HomeVitalsSpread(
                                    weekLabel: homeMockWeekLabel,
                                    phaseLabel: homeMockPhaseLabel,
                                    sessionsDone:
                                        state?.completedSessionsThisWeek ??
                                            homeMockSessionsDone,
                                    sessionsTotal: state?.sessionsThisWeek ??
                                        homeMockSessionsTotal,
                                    statusLine: homeMockVitalsStandfirst,
                                    streakLabel: streakTierLabel(
                                      streakSnapshot.data ??
                                          widget.userProfile?.streakWeeks ??
                                          homeMockStreakWeeks,
                                    ),
                                    formPercent: form?.percent,
                                    formDelta: form?.delta,
                                    formWeek: form?.week ?? const <int>[],
                                  );
                                },
                              );
                            },
                          ),
                        );
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: vitals,
                  );
                },
              ),
              const HomeSignoff(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startWorkoutTarget(WorkoutLaunchTarget target) async {
    HapticFeedback.lightImpact();
    final base = target.firstLaunchArgs();
    if (base == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Buổi này chưa có bài camera phù hợp.'),
          ),
        );
      return;
    }
    String? workoutSessionId;
    if (base.recommendationId != null) {
      workoutSessionId = await SessionPersistence().startWorkoutSession(
        recommendationId: base.recommendationId!,
        weekNumber: base.weekNumber!,
        sessionIndex: base.sessionIndex!,
      );
    }
    final first = target.firstLaunchArgs(workoutSessionId: workoutSessionId);
    final completedWorkout = await _runWorkoutSequence(first!);
    if (completedWorkout) {
      final profile = await UserProfileService().fetchCurrentProfile();
      if (profile != null) widget.onProfileChanged?.call(profile);
    }
    if (!mounted) return;
    _reloadLaunchTarget();
  }

  Future<bool> _runWorkoutSequence(ExerciseLaunchArgs first) async {
    ExerciseLaunchArgs? next = first;
    var completedFinalSlot = false;
    while (mounted && next != null) {
      final result = await Navigator.of(context).pushNamed(
        '/exercise',
        arguments: next,
      );
      if (!mounted) return false;
      if (result is Map && result['next'] is ExerciseLaunchArgs) {
        next = result['next'] as ExerciseLaunchArgs;
      } else {
        completedFinalSlot = result is Map && result['completed'] == true;
        next = null;
      }
    }
    return completedFinalSlot;
  }
}

class _HomeHeroFromTarget extends StatelessWidget {
  const _HomeHeroFromTarget({
    required this.state,
    required this.target,
    required this.loading,
    required this.profile,
    required this.onStart,
    required this.onStretch,
  });

  final WorkoutLaunchHomeState? state;
  final WorkoutLaunchTarget? target;
  final bool loading;
  final AppUserProfile? profile;
  final VoidCallback? onStart;
  final VoidCallback onStretch;

  @override
  Widget build(BuildContext context) {
    final currentTarget = target;
    final userInitial = profile?.initial ?? homeMockUser.initial;
    final avatarUrl = profile?.avatarUrl;

    final Widget hero;
    if (loading) {
      // While today's session resolves, show the shimmering stage skeleton
      // instead of mock data that would visibly change once the real plan
      // lands.
      hero = HomeStageHeroSkeleton(
        key: const ValueKey('home-hero-skeleton'),
        userInitial: userInitial,
        avatarUrl: avatarUrl,
      );
    } else if (currentTarget == null || !currentTarget.hasLaunchableSlots) {
      hero = HomeStageHero(
        key: const ValueKey('home-hero-rest'),
        eyebrow: 'CHƯA CÓ BUỔI TẬP',
        titleLine1: 'Nghỉ',
        titleLine2: 'hôm nay.',
        duration: '0 phút',
        totalCount: 0,
        aiCount: 0,
        exercises: [],
        coachQuote: 'Nghỉ ngơi nhé — để cơ thể hồi lại cho buổi tới.',
        coachAttribution: homeMockCoachAttribution,
        ctaLabel: '',
        onCta: null,
        userInitial: userInitial,
        avatarUrl: avatarUrl,
      );
    } else {
      hero = HomeStageHero(
        key: const ValueKey('home-hero-active'),
        eyebrow:
            'HÔM NAY · BUỔI ${(currentTarget.session.sessionIndex + 1).toString().padLeft(2, '0')}',
        titleLine1: homeMockToday.titleLine1,
        titleLine2: homeMockToday.titleLine2,
        duration: _durationFor(currentTarget),
        totalCount: currentTarget.sequence.length,
        aiCount: currentTarget.sequence.length,
        exercises: _exerciseRows(currentTarget),
        coachQuote: homeMockCoachQuote,
        coachAttribution: homeMockCoachAttribution,
        ctaLabel: homeMockToday.cta,
        onCta: onStart,
        userInitial: userInitial,
        avatarUrl: avatarUrl,
      );
    }

    // Cross-fade the skeleton → real content so the swap doesn't jump.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: hero,
    );
  }

  static String _durationFor(WorkoutLaunchTarget target) {
    final minutes = (target.sequence.length * 5).clamp(12, 35);
    return '$minutes phút';
  }

  static List<HomeStageExercise> _exerciseRows(WorkoutLaunchTarget target) {
    return target.sequence
        .map(
          (item) => HomeStageExercise(
            name: item.definition.name,
            detail: item.prescription == null
                ? ''
                : workoutVolumeLabel(item.prescription!),
            hasAi: true,
            thumbnailAsset: exerciseThumbnailForId(item.definition.id),
          ),
        )
        .toList(growable: false);
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

/// Editorial-style weekly check-in alert. Hairline-bordered band instead
/// of a raised card — matches the typography-first vibe of the vitals
/// spread so we don't reintroduce a "card" right where we just removed
/// them.
class _WeeklyCheckInAlert extends StatelessWidget {
  const _WeeklyCheckInAlert({
    required this.weekNumber,
    required this.onTap,
  });

  final int weekNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.border),
                bottom: BorderSide(color: c.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 12,
                    color: c.yellowInk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        letterSpacing: -0.1,
                      ),
                      children: [
                        TextSpan(
                          text: 'Check-in tuần $weekNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                        TextSpan(
                          text: '   ·   30 giây',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: c.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: c.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
