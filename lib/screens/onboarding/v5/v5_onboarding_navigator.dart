import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/models/exercise_definition.dart';
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
  });

  final VoidCallback onRequestLogin;

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

  // Page indices used for special-case logic.
  static const _idxAssessmentIntro = 8; // S07
  static const _idxAnalyzing = 9; // S08

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

  void _back() {
    if (!_pc.hasClients) return;
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

  /// S07 CTA: launch the real squat assessment for the home-workout fork,
  /// then advance to S08. For the yoga fork the squat path doesn't apply yet
  /// (Warrior I + Forward Fold interpreters aren't built), so we just advance
  /// and S09 Phase1 falls back to the yoga mock.
  Future<void> _launchSquatAssessment() async {
    if (_data.fork == 'yoga') {
      _next();
      return;
    }

    final result = await Navigator.of(context).pushNamed(
      '/exercise',
      arguments: squatAssessmentDefinition,
    ) as Map<String, dynamic>?;

    if (result != null && result['logger'] is ExerciseLogger) {
      _data.onSquatComplete(result['logger'] as ExerciseLogger);
    }
    if (mounted) _next();
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
          onNext: _launchSquatAssessment,
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
          onNext: _next,
          onBack: _back,
          onAuthenticated: () async {
            await _ensureOnboardingPlan(markComplete: true);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_complete', true);
          },
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
          // S13 has a TextField — let the keyboard resize the body so the field
          // stays visible above it.
          resizeToAvoidBottomInset: true,
          body: PageView(
            controller: _pc,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: _pages,
          ),
        ),
      ),
    );
  }
}
