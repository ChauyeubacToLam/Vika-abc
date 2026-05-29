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
// DATA SEAM: this screen is driven ENTIRELY by `loadMockProgramPlan()` (see
// lib/data/program_mock.dart). It deliberately calls NO backend — no Supabase,
// no RecommendationService, no WorkoutLaunchService, no SessionPersistence.
// Swapping the mock for real data is a single provider change: replace
// `loadMockProgramPlan()` with a `ProgramPlan` mapper over the engine snapshot
// + completion records. The previous real-data loading + workout-launch wiring
// is preserved intact in plan_screen_legacy.dart for that work.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/program_mock.dart';
import '../services/user_profile_service.dart';
import '../services/user_program_service.dart';
import '../theme/app_colors.dart';
import '../theme/responsive.dart';
import '../utils/orientation_lock.dart';
import '../widgets/plan/editorial_closer.dart';
import '../widgets/plan/program/program_session_ledger.dart';
import '../widgets/plan/program/program_stage_hero.dart';
import '../services/workout_launch_service.dart';
import '../services/session_persistence.dart';
import 'exercise/exercise_launch_args.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
    this.program,
    this.onProfileChanged,
  });

  final double bottomPadding;

  /// Real assigned-program data from MainShell. UNUSED by this mock-driven
  /// presentation — kept as the wiring seam: a future `ProgramPlan` mapper
  /// would consume `program` (+ the engine snapshot) instead of the mock.
  // TODO(wiring): map `program` / PlanSnapshot → ProgramPlan and feed it here.
  final UserProgramData? program;

  /// Forwarded on workout completion once real launching is wired. Unused in
  /// the mock path (no session is actually launched).
  // TODO(wiring): call onProfileChanged after a real session completes
  // (see plan_screen_legacy.dart for the streak + profile refresh flow).
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  // TODO(wiring): replace loadMockProgramPlan() with the real mapper. This is
  // the ONLY line that changes to go from mock → real data.
  final ProgramPlan _program = loadMockProgramPlan();

  late int _selectedBlockIndex;
  int? _expandedSessionIndex;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _selectedBlockIndex = _program.currentBlockIndex;
  }

  ProgramBlock get _selectedBlock => _program.blocks[_selectedBlockIndex];

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

  /// CTA handler for the single next session. M// add near the other fields
  final _launches = WorkoutLaunchService();

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
      await SessionPersistence().updateStreak();
      final profile = await UserProfileService().fetchCurrentProfile();
      if (profile != null) widget.onProfileChanged?.call(profile);
    }
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
    // The retest is folded into the session ledger as the final session of the
    // LAST block (no separate card); show it only when that block is selected.
    final isLastBlock = _selectedBlockIndex == _program.blocks.length - 1;

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
                program: _program,
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
                retest: isLastBlock ? _program.retest : null,
                retestUnlocked: _program.allBlocksDone,
                // Locked in the mid-program mock; the unlocked launch is wired
                // alongside the real session-launch flow.
                onStartRetest:
                    _program.allBlocksDone ? _startNextSession : null,
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
