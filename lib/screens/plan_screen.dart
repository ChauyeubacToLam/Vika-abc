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
// (active plan snapshot + catalog name/AI lookup), and reloaded after a
// completed workout so the ledger reflects the session just finished. The
// prior mock-only presentation is preserved in plan_screen_legacy.dart.
//
// STILL STUBBED (session-summary pass): per-session and per-exercise
// formScore/difficulty come back null from the mapper, so done rows render
// without form numbers until those aggregators land.

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
import '../widgets/plan/editorial_closer.dart';
import '../widgets/plan/program/program_session_ledger.dart';
import '../widgets/plan/program/program_stage_hero.dart';
import 'exercise/exercise_launch_args.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
    this.program,
    this.onProfileChanged,
  });

  final double bottomPadding;

  /// Real assigned-program data from MainShell. Not consumed directly — the
  /// screen loads its own PlanSnapshot via RecommendationService and maps it.
  /// Kept so MainShell's existing wiring compiles unchanged.
  final UserProgramData? program;

  /// Forwarded on workout completion so MainShell can refresh streak/profile.
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _recommendations = RecommendationService();
  final _launches = WorkoutLaunchService();

  /// null = still loading. Non-null with empty blocks = no active plan.
  ProgramPlan? _program;
  int _selectedBlockIndex = 0;
  int? _expandedSessionIndex;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    unawaited(_loadProgram());
  }

  /// Loads (or reloads) the real plan + completion state and maps it to a
  /// ProgramPlan. Safe to call again after a workout to refresh status.
  Future<void> _loadProgram() async {
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
    final catalog =
        await _recommendations.fetchLaunchCatalogInfoForExerciseIds(ids);

    if (!mounted) return;
    final mapped =
        ProgramPlanMapper.fromSnapshot(snapshot, catalogById: catalog);
    setState(() {
      _program = mapped;
      // Re-point to the current block (advances after a completed session).
      _selectedBlockIndex =
          mapped.blocks.isEmpty ? 0 : mapped.currentBlockIndex;
      _expandedSessionIndex = null;
    });
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
      workoutSessionId = await SessionPersistence().startWorkoutSession(
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

    // Loading: snapshot/catalog fetch in flight.
    if (program == null) {
      return Container(
        color: c.bg,
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: c.yellow, strokeWidth: 2.4),
      );
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
