import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/models/exercise_definition.dart';
import 'package:vika/services/analytics_service.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/utils/orientation_lock.dart';
import 'package:vika/services/onboarding_persistence.dart';
import 'package:vika/services/recommendation/recommendation_service.dart';

import '../onboarding_data.dart';
import 'screens/s01_welcome.dart';
import 'screens/s02_mirror.dart';
import 'screens/s03_barrier.dart';
import 'screens/s03_goal.dart';
import 'screens/s04_resolution.dart';
import 'screens/s04_pain_check.dart';
import 'screens/s05_fork.dart';
import 'screens/s06_trust.dart';
import 'screens/s07_assessment_intro.dart';
import 'screens/s08_analyzing.dart';
import 'screens/s09_phase1.dart';
import 'screens/s10_level_issue.dart';
import 'screens/s11_body_info.dart';
import 'screens/s12_schedule.dart';
import 'screens/s13_signup.dart';
import 'screens/s15_journey.dart';
import 'screens/s16_closer.dart';
import 'v5_theme.dart';

/// 17-screen v5 onboarding host. Owns [OnboardingData], threads next/back,
/// launches the live squat assessment between S07 and S08, and persists the
/// collected profile on the S16 CTA.
class V5OnboardingNavigator extends StatefulWidget {
  const V5OnboardingNavigator({
    super.key,
    required this.onRequestLogin,
    this.onSignupAuthStarted,
  });

  final VoidCallback onRequestLogin;

  /// Called the instant the S13 signup step begins a sign-in attempt, so the
  /// app entry gate can stand down and let this navigator own the flow.
  final VoidCallback? onSignupAuthStarted;

  @override
  State<V5OnboardingNavigator> createState() => _V5OnboardingNavigatorState();
}

class _V5OnboardingNavigatorState extends State<V5OnboardingNavigator> {
  final PageController _pc = PageController();
  final OnboardingData _data = OnboardingData();
  int _page = 0;
  bool _completing = false;
  bool _onboardingSignalsPersisted = false;
  Future<PlanSnapshot?>? _onboardingPlanFuture;

  // S13 auto-skip: when the user reaches the signup step already authenticated
  // (routed in from the standalone login because their account hadn't finished
  // onboarding), skip it instead of asking them to sign in again.
  // `_signupSkipping` makes S13 render a loader during the pass-through;
  // `_signupAutoSkipped` keeps it to a single forward skip.
  bool _signupAutoSkipped = false;
  bool _signupSkipping = false;

  bool get _hasAuthSession =>
      Supabase.instance.client.auth.currentSession?.user != null;

  // Page indices used for special-case logic.
  static const _idxAssessmentIntro = 8; // S07
  static const _idxAnalyzing = 9; // S08
  static const _idxLevel = 11; // S10
  static const _idxSignup = 14; // S13

  // True when the user skipped the live assessment from S07. Drives the
  // back gesture on the level picker (S10) so it returns to the intro over
  // the bypassed Analyzing + Phase1 screens.
  bool _assessmentSkipped = false;

  // Screens with dark/inverted backgrounds — drives the status bar overlay.
  static const _darkPages = <int>{0, 9, 16}; // S01, S08, S16

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (!_pc.hasClients) return;
    if (_page < 16) {
      // Reached the signup step (S13) already authenticated — e.g. routed in
      // from the standalone login because the account hadn't finished
      // onboarding. Skip it so they aren't asked to sign in twice.
      if (_page == _idxSignup - 1 && !_signupAutoSkipped && _hasAuthSession) {
        unawaited(_autoSkipSignup());
        return;
      }
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<PlanSnapshot?> _ensureOnboardingPlan({bool markComplete = false}) {
    final existing = _onboardingPlanFuture;
    if (existing != null) return existing;

    final future = _persistAndGenerateOnboardingPlan(
      markComplete: markComplete,
    ).then((snapshot) {
      if (snapshot == null) {
        _onboardingPlanFuture = null;
      }
      return snapshot;
    });
    _onboardingPlanFuture = future;
    return future;
  }

  Future<PlanSnapshot?> _persistAndGenerateOnboardingPlan({
    required bool markComplete,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final persisted = await OnboardingPersistence().persist(
      _data,
      markComplete: markComplete,
      writeSignals: !_onboardingSignalsPersisted,
    );
    if (!persisted) return null;
    _onboardingSignalsPersisted = true;

    return RecommendationService().ensurePlanForCurrentUser(
      trigger: 'onboarding',
    );
  }

  /// The S13 sign-in checkpoint: persist the profile + generate the plan
  /// (marking onboarding complete) and set the local flag. Shared by the S13
  /// sign-in callback and the already-authenticated auto-skip below.
  Future<void> _persistSignupCheckpoint() async {
    await _ensureOnboardingPlan(markComplete: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  /// Skip the S13 signup step for a user who is already authenticated: record
  /// the checkpoint (best-effort — S15 retries plan generation) and slide
  /// straight to S15. S13 shows a loader via [_signupSkipping] during the
  /// pass-through so its sign-in form never appears.
  Future<void> _autoSkipSignup() async {
    _signupAutoSkipped = true;
    setState(() => _signupSkipping = true);
    unawaited(_persistSignupCheckpoint().catchError((Object _) {}));
    await _pc.animateToPage(
      _idxSignup + 1, // S15 Journey
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() => _signupSkipping = false);
  }

  void _back() {
    if (!_pc.hasClients) return;
    // Reached the level picker by skipping the assessment — back returns to
    // the assessment intro, over the bypassed Analyzing + Phase1 screens.
    if (_page == _idxLevel && _assessmentSkipped) {
      _assessmentSkipped = false;
      _pc.jumpToPage(_idxAssessmentIntro);
      return;
    }
    // Skip back across S08 Analyzing — it's a transition screen, not a stop.
    if (_page == _idxAnalyzing) {
      _pc.animateToPage(
        _idxAssessmentIntro - 1, // back to S06 Trust
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_page > 0) {
      _pc.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// S07 CTA: run the live assessment legs for the chosen fork, then advance to
  /// S08 — but only once **every** leg is captured. Home runs squat + wall
  /// push-up; yoga runs Warrior I + Seated Forward Fold.
  ///
  /// Each leg is launched only if it isn't already done, and a leg the user
  /// backs out of (the `/exercise` route pops null instead of a logger) aborts
  /// the run *without* advancing — so the user lands back on S07 with finished
  /// legs kept. Re-tapping the CTA resumes at the first unfinished leg. This is
  /// the gate: Analyzing (S08) is unreachable until both legs exist.
  Future<void> _launchAssessment() async {
    if (_data.fork == 'yoga') {
      if (!_data.hasWarriorAssessment) {
        final logger = await _launchExerciseAssessment(
          warriorOneAssessmentDefinition,
        );
        if (!mounted) return;
        if (logger == null) return; // backed out → stay on S07, keep prior legs
        _data.onWarriorOneComplete(logger);
      }
      if (!_data.hasForwardFoldAssessment) {
        final logger = await _launchExerciseAssessment(
          seatedForwardFoldAssessmentDefinition,
        );
        if (!mounted) return;
        if (logger == null) return; // backed out → stay on S07, keep prior legs
        _data.onForwardFoldComplete(logger);
      }
      _next();
      return;
    }

    if (!_data.hasSquatAssessment) {
      final logger = await _launchExerciseAssessment(
        squatAssessmentDefinition,
      );
      if (!mounted) return;
      if (logger == null) return; // backed out → stay on S07, keep prior legs
      _data.onSquatComplete(logger);
    }
    if (!_data.hasWallPushUpAssessment) {
      final logger = await _launchExerciseAssessment(
        wallPushupAssessmentDefinition,
      );
      if (!mounted) return;
      if (logger == null) return; // backed out → stay on S07, squat kept
      _data.onWallPushUpComplete(logger);
    }
    _next();
  }

  /// S07 secondary action: skip the live assessment. The level picker (S10)
  /// still suggests a level — [FitnessTestScorer] falls back to the
  /// training-history band when no loggers exist. Jump straight there,
  /// bypassing S08 Analyzing + S09 Phase1 (both presuppose captured data);
  /// jumpToPage (not animate) so S08's `active` timer never fires in transit.
  void _skipAssessment() {
    if (!_pc.hasClients) return;
    _assessmentSkipped = true;
    _pc.jumpToPage(_idxLevel);
  }

  Future<ExerciseLogger?> _launchExerciseAssessment(
    ExerciseDefinition definition,
  ) async {
    final result = await Navigator.of(context).pushNamed(
      '/exercise',
      arguments: definition,
    ) as Map<String, dynamic>?;

    if (result != null && result['logger'] is ExerciseLogger) {
      return result['logger'] as ExerciseLogger;
    }
    return null;
  }

  /// S16 CTA. Persists everything OnboardingData carries to SharedPreferences +
  /// the Supabase `profiles` row, then routes back through `/` so the entry
  /// gate switches to home.
  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      // Onboarding finished (S16 CTA). No-op without consent.
      unawaited(AnalyticsService.instance.capture('onboarding_completed'));

      // Why
      await prefs.setStringList(
        'user_problem_resonance',
        _data.problemResonance,
      );
      if (_data.whyStep1 != null) {
        await prefs.setString('user_why_primary', _data.whyStep1!);
      }
      if (_data.whyStep2 != null) {
        await prefs.setString('user_why_secondary', _data.whyStep2!);
      }
      if (_data.whyCustomText.isNotEmpty) {
        await prefs.setString('user_why_custom', _data.whyCustomText);
      }

      // Plan + body
      await prefs.setString('user_goal', _data.goal ?? '');
      await prefs.setString('user_freq', _data.trainingDuration ?? '');
      await prefs.setString('user_experience', _data.trainingDuration ?? '');
      await prefs.setString('user_level', _data.confirmedLevel ?? 'beginner');
      await prefs.setString('user_fork', _data.fork ?? 'home');
      await prefs.setString('user_email', _data.email ?? '');
      await prefs.setString('user_gender', _data.gender ?? '');
      if (_data.heightCm != null) {
        await prefs.setDouble('user_height', _data.heightCm!);
      }
      if (_data.weightKg != null) {
        await prefs.setDouble('user_weight', _data.weightKg!);
      }
      if (_data.age != null) {
        await prefs.setInt('user_age', _data.age!);
      }
      if (_data.bmi != null) {
        await prefs.setDouble('user_bmi', _data.bmi!);
      }

      // Schedule (v5 replaces the old separate days+time fields)
      if (_data.scheduleSessions.isNotEmpty) {
        await prefs.setStringList(
          'user_schedule_sessions',
          _data.scheduleSessions,
        );
      }

      // Pain
      if (_data.painAreas.isNotEmpty) {
        await prefs.setStringList('pain_areas', _data.painAreas);
      }
      await prefs.setBool('no_pain', _data.noPain);
      if (_data.painOtherText?.isNotEmpty == true) {
        await prefs.setString('pain_other_text', _data.painOtherText!);
      }

      // Assessment-driven
      if (_data.detectedIssues.isNotEmpty) {
        await prefs.setStringList('detected_issues', _data.detectedIssues);
      }
      if (_data.feedbackByExercise.isNotEmpty) {
        for (final entry in _data.feedbackByExercise.entries) {
          if (entry.value.isEmpty) continue;
          await prefs.setStringList(
            'feedback_${entry.key}',
            entry.value,
          );
        }
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          // Conservative upsert — only fields we're sure exist on `profiles`.
          // Everything else stays in SharedPreferences until columns ship.
          // See BACKEND-GAP list in the migration notes.
          final persisted = await OnboardingPersistence().persist(
            _data,
            writeSignals: !_onboardingSignalsPersisted,
          );
          if (persisted) _onboardingSignalsPersisted = true;
          await _ensureOnboardingPlan(markComplete: true);
        } catch (_) {
          // Non-fatal — continue to home even if profile sync fails. The
          // SharedPreferences flag is enough for the entry gate.
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/',
        arguments: const {'onboardingComplete': true},
      );
    } finally {
      _completing = false;
    }
  }

  SystemUiOverlayStyle get _overlayStyle {
    final dark = _darkPages.contains(_page);
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    );
  }

  List<Widget> get _pages => [
        S01Welcome(onNext: _next, onLogin: widget.onRequestLogin),
        S02Mirror(data: _data, onNext: _next, onBack: _back),
        S03Barrier(onNext: _next, onBack: _back),
        S04Resolution(onNext: _next, onBack: _back),
        S03Goal(data: _data, onNext: _next, onBack: _back),
        S04PainCheck(data: _data, onNext: _next, onBack: _back),
        S05Fork(data: _data, onNext: _next, onBack: _back),
        S06Trust(onNext: _next, onBack: _back),
        S07AssessmentIntro(
          data: _data,
          onNext: _launchAssessment,
          onSkip: _skipAssessment,
          onBack: _back,
        ),
        S08Analyzing(
          data: _data,
          active: _page == _idxAnalyzing,
          onNext: _next,
          onBack: _back,
        ),
        S09Phase1(data: _data, onNext: _next, onBack: _back),
        S10LevelIssue(data: _data, onNext: _next, onBack: _back),
        S11BodyInfo(data: _data, onNext: _next, onBack: _back),
        S12Schedule(data: _data, onNext: _next, onBack: _back),
        S13Signup(
          data: _data,
          skipping: _signupSkipping,
          onNext: _next,
          onBack: _back,
          onAuthStarted: widget.onSignupAuthStarted,
          onAuthenticated: _persistSignupCheckpoint,
        ),
        S15Journey(
          data: _data,
          onNext: _next,
          onBack: _back,
          loadPlan: _ensureOnboardingPlan,
        ),
        S16Closer(
          data: _data,
          onComplete: _complete,
          onBack: _back,
          busy: _completing,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Clamp text scaling for the whole onboarding flow. Respects user's
    // accessibility preference but prevents 1.5×+ scales from blowing
    // apart hand-tuned editorial layouts.
    return MediaQuery(
      data: mq.copyWith(textScaler: V5.clampedTextScaler(context)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlayStyle,
        child: Scaffold(
          backgroundColor: V5.bg,
          // Must stay false: resizing this shared Scaffold would shrink the
          // ENTIRE PageView when the keyboard opens, squeezing sibling pages
          // (e.g. S15's week cards) into overflow. S13 — the only page with a
          // TextField — owns its own keyboard resize via V5KeyboardForm's
          // nested Scaffold, so the field stays visible without touching siblings.
          resizeToAvoidBottomInset: false,
          body: PageView(
            controller: _pc,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _page = i);
              // Steps before S06 never fire — consent is granted on the S06
              // accept, so the first captured view is the step right after it.
              unawaited(
                AnalyticsService.instance
                    .capture('onboarding_step_viewed', props: {'step': i}),
              );
            },
            children: _pages,
          ),
        ),
      ),
    );
  }
}
