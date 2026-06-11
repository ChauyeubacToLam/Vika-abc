// PlanScreen — the completion-anchored Plan tab ("Progress Ledger on a Spine").
//
// THE MODEL SHIFT: progression advances by COMPLETING sessions, never by the
// calendar. There are no dates, no weekday pins, no "this week = 7 dates". A
// "block" is a progression unit (shown as "TUẦN N · <phase>"); its sessions
// are an ordered sequence ("Buổi 1 / 2 / 3"). Every status — block, session,
// retest — is derived ONLY from completion (done · current · upcoming), and the
// single NEXT session is the one unmistakable thing to tap.
//
// Composition, top → bottom:
//   • ProgramStageHero      dark stage: completion bezel + current block +
//                           NEXT-up entry + the one halo CTA
//   • ProgramSessionLedger  §SỔ BUỔI — selected block's sessions (done show
//                           form + difficulty; done rows expand per-exercise)
//   • ProgramBlockSequence  §CHẶNG ĐƯỜNG — the 7 blocks on a continuous spine
//   • ProgramRetestBeat     end-of-program retest (completion-gated lock)
//   • EditorialCloser
//
// DATA: a real ProgramPlan, mapped from the engine snapshot + completion
// records via ProgramPlanMapper.fromSnapshot. Loaded async in _loadProgram
// (active plan snapshot + catalog name/AI lookup + logged session results),
// and reloaded after a completed workout so the ledger reflects the session
// just finished. The prior mock-only presentation is preserved in
// plan_screen_legacy.dart.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/program_mock.dart';
import '../services/recommendation/program_plan_mapper.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/session_persistence.dart';
import '../services/user_profile_service.dart';
import '../services/user_program_service.dart';
import '../services/workout_launch_service.dart';
import '../theme/app_colors.dart';
import '../theme/responsive.dart';
import '../utils/orientation_lock.dart';
import '../widgets/ivory/skeleton.dart';
import '../widgets/plan/editorial_closer.dart';
import '../widgets/plan/program/program_session_ledger.dart';
import '../widgets/plan/program/program_stage_hero.dart';
import '../widgets/plan/wordmark_header.dart';
import 'exercise/exercise_launch_args.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
    this.program,
    this.refreshListenable,
    this.onProfileChanged,
  });

  final double bottomPadding;

  /// Real assigned-program data from MainShell. Not consumed directly — the
  /// screen loads its own PlanSnapshot via RecommendationService and maps it.
  /// Kept so MainShell's existing wiring compiles unchanged.
  final UserProgramData? program;

  /// Bumped by MainShell when the Plan tab becomes visible.
  final Listenable? refreshListenable;

  /// Forwarded on workout completion so MainShell can refresh streak/profile.
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _recommendations = RecommendationService();
  final _launches = WorkoutLaunchService();
  final _sessions = SessionPersistence();

  /// null = still loading. Non-null with empty blocks = no active plan.
  ProgramPlan? _program;
  int _selectedBlockIndex = 0;
  int? _expandedSessionIndex;
  bool _loadingProgram = false;
  bool _programReloadQueued = false;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    widget.refreshListenable?.addListener(_handleRefreshNudge);
    unawaited(_loadProgram());
  }

  @override
  void didUpdateWidget(covariant PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_handleRefreshNudge);
      widget.refreshListenable?.addListener(_handleRefreshNudge);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_handleRefreshNudge);
    super.dispose();
  }

  void _handleRefreshNudge() {
    unawaited(_loadProgram());
  }

  /// Loads (or reloads) the real plan + completion state and maps it to a
  /// ProgramPlan. Safe to call again after a workout to refresh status.
  Future<void> _loadProgram() async {
    if (_loadingProgram) {
      _programReloadQueued = true;
      return;
    }
    _loadingProgram = true;
    try {
      final snapshot =
          await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();

      if (snapshot == null) {
        if (!mounted) return;
        setState(() => _program = const ProgramPlan(blocks: [], retest: null));
        return;
      }

      // Every exercise_id in the plan (slots + retest) needs a name + AI flag.
      final ids = <String>{
        for (final w in snapshot.plan.weeks)
          for (final s in w.sessions)
            for (final slot in s.slots) slot.exerciseId,
        for (final e in snapshot.plan.endOfPlanRetest?.exercises ?? const [])
          e.exerciseId,
      };
      final catalogFuture =
          _recommendations.fetchLaunchCatalogInfoForExerciseIds(ids);
      final ledgerResultsFuture = _sessions.ledgerResultsForPlan(
        recommendationId: snapshot.plan.recommendationId,
      );

      final catalog = await catalogFuture;
      final ledgerResults = await ledgerResultsFuture;

      if (!mounted) return;
      final mapped = ProgramPlanMapper.fromSnapshot(
        snapshot,
        catalogById: catalog,
        ledgerResults: ledgerResults,
      );
      setState(() {
        _program = mapped;
        // Re-point to the current block (advances after a completed session).
        _selectedBlockIndex =
            mapped.blocks.isEmpty ? 0 : mapped.currentBlockIndex;
        _expandedSessionIndex = null;
      });
    } finally {
      _loadingProgram = false;
      if (_programReloadQueued && mounted) {
        _programReloadQueued = false;
        unawaited(_loadProgram());
      }
    }
  }

  ProgramBlock get _selectedBlock => _program!.blocks[_selectedBlockIndex];

  void _selectBlock(int index) {
    if (index == _selectedBlockIndex) return;
    setState(() {
      _selectedBlockIndex = index;
      // Expansion is per-block; don't carry an open row across blocks.
      _expandedSessionIndex = null;
    });
  }

  void _toggleSessionExpand(int sessionIndex) {
    setState(() {
      _expandedSessionIndex =
          _expandedSessionIndex == sessionIndex ? null : sessionIndex;
    });
  }

  Future<void> _startNextSession() async {
    final target = await _launches.resolveTodayOrNextInCurrentWeek();
    if (!mounted) return;
    if (target == null || !target.hasLaunchableSlots) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Buổi này chưa có bài camera phù hợp.'),
        ));
      return;
    }

    final base = target.firstLaunchArgs();
    if (base == null) return;

    String? workoutSessionId;
    if (base.recommendationId != null) {
      workoutSessionId = await _sessions.startWorkoutSession(
        recommendationId: base.recommendationId!,
        weekNumber: base.weekNumber!,
        sessionIndex: base.sessionIndex!,
      );
    }

    final first = target.firstLaunchArgs(workoutSessionId: workoutSessionId);
    final completed = await _runWorkoutSequence(first!);
    if (completed) {
      final profile = await UserProfileService().fetchCurrentProfile();
      if (profile != null) widget.onProfileChanged?.call(profile);
    }
    if (!mounted) return;
    // Refresh the ledger so the just-completed session flips to done.
    await _loadProgram();
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

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);

    final program = _program;

    // Loading: snapshot/catalog fetch in flight — shimmer a stand-in plan
    // (hero + ledger) instead of a bare spinner.
    if (program == null) {
      return _PlanSkeleton(bottomPadding: widget.bottomPadding);
    }

    // No active plan (e.g. onboarding not finished). Graceful, never crashes
    // the block indexing below.
    if (program.blocks.isEmpty) {
      return Container(
        color: c.bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Chưa có lộ trình. Hoàn tất phần thiết lập để Vika dựng kế hoạch cho bạn nhé.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.inkSoft, height: 1.5),
        ),
      );
    }

    // The retest is folded into the session ledger as the final beat of the
    // LAST block (no separate card); show it only when that block is selected.
    final isLastBlock = _selectedBlockIndex == program.blocks.length - 1;

    return Container(
      color: c.bg,
      child: MediaQuery.removePadding(
        // Defeat MainShell's top SafeArea so the dark hero bleeds into the
        // status-bar area, then re-apply the inset inside the hero — same
        // trick as Home.
        context: context,
        removeTop: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: widget.bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProgramStageHero(
                program: program,
                selectedIndex: _selectedBlockIndex,
                onSelectBlock: _selectBlock,
                onStartNext: _startNextSession,
                userInitial: 'N',
              ),
              SizedBox(height: r.gap(34)),
              ProgramSessionLedger(
                block: _selectedBlock,
                expandedIndex: _expandedSessionIndex,
                onToggleExpand: _toggleSessionExpand,
                onStartNext: _startNextSession,
                retest: isLastBlock ? program.retest : null,
                retestUnlocked: program.allBlocksDone,
                onStartRetest: program.allBlocksDone ? _startNextSession : null,
              ),
              SizedBox(height: r.gap(38)),
              const EditorialCloser(
                section: 'LỘ TRÌNH',
                tagline: 'Tiến từng buổi, không vội.',
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOADING SKELETON — mirrors the program hero + session ledger so the
// swap to the real plan lands without a layout jump.
// ═══════════════════════════════════════════════════════════════

class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton({required this.bottomPadding});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      color: c.bg,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dark stage hero
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(36)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-0.7, -1),
                      end: const Alignment(0.7, 1),
                      colors: [c.bgInverse, c.bgInverseHi],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.22),
                        blurRadius: 48,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        WordmarkHeader(
                          inverted: true,
                          userInitial: 'N',
                          trailingIcon: Icons.menu_book_rounded,
                          trailingTooltip: 'Sổ tập',
                        ),
                        SizedBox(height: 22),
                        Padding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
                          child: Shimmer(
                            inverted: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Eyebrow
                                SkeletonBox(
                                    width: 130, height: 12, inverted: true),
                                SizedBox(height: 20),
                                // Headline — two lines
                                SkeletonBox(
                                    width: 240,
                                    height: 38,
                                    radius: 9,
                                    inverted: true),
                                SizedBox(height: 11),
                                SkeletonBox(
                                    width: 170,
                                    height: 38,
                                    radius: 9,
                                    inverted: true),
                                SizedBox(height: 24),
                                // Completion bezel — block selector chips
                                Row(
                                  children: [
                                    Expanded(
                                        child: SkeletonBox(
                                            height: 56,
                                            radius: 16,
                                            inverted: true)),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: SkeletonBox(
                                            height: 56,
                                            radius: 16,
                                            inverted: true)),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: SkeletonBox(
                                            height: 56,
                                            radius: 16,
                                            inverted: true)),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: SkeletonBox(
                                            height: 56,
                                            radius: 16,
                                            inverted: true)),
                                  ],
                                ),
                                SizedBox(height: 22),
                                // Stat row
                                Row(
                                  children: [
                                    SkeletonBox(
                                        width: 78, height: 12, inverted: true),
                                    SizedBox(width: 14),
                                    SkeletonBox(
                                        width: 58, height: 12, inverted: true),
                                    SizedBox(width: 14),
                                    SkeletonBox(
                                        width: 68, height: 12, inverted: true),
                                  ],
                                ),
                                SizedBox(height: 20),
                                // CTA pill
                                SkeletonBox(
                                    height: 54, radius: 999, inverted: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              // Session ledger
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Shimmer(
                  child: Column(
                    children: [
                      _LedgerRowSkeleton(),
                      SizedBox(height: 12),
                      _LedgerRowSkeleton(),
                      SizedBox(height: 12),
                      _LedgerRowSkeleton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single session-ledger row stand-in: index medallion + title/meta + a
/// trailing chevron block.
class _LedgerRowSkeleton extends StatelessWidget {
  const _LedgerRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: const Row(
        children: [
          SkeletonCircle(size: 38),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(width: 150, height: 13),
                SizedBox(height: 9),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 18, height: 18, radius: 5),
        ],
      ),
    );
  }
}
