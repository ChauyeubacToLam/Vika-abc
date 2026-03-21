import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_data.dart';
import 'vf_theme.dart';
import 'pages/welcome_page.dart';
import 'pages/goal_page.dart';
import 'pages/medical_page.dart';
// import 'pages/transition_page.dart';
import 'pages/facts_page.dart';
import 'pages/level_issue_page.dart';
import 'pages/signup_page.dart';
import 'pages/body_schedule_page.dart';
import 'pages/program_page.dart';
import 'package:vinafit_mobile/models/exercise_definition.dart';
import 'package:vinafit_mobile/utils/exercise_logger.dart';

/* =========================================================================
   ONBOARDING SCREEN

   Flow (10 visible steps, camera steps launch externally):
     0. Welcome
     1. Goal
     2. Medical + assessment intro
        → launches squat ExerciseScreen (camera)
     3. Transition (squat done, wall push-up next)
        → launches wall push-up ExerciseScreen (camera)
     4. Facts (raw results)
     5. Level picker + issue spotlight
     6. Signup
     7. Body info + schedule + BMI
     8. Done → navigate to home

   Camera steps are NOT PageView pages. They launch via Navigator.push
   and return results via Navigator.pop.
   ========================================================================= */

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  final OnboardingData _data = OnboardingData();
  int _page = 0;

  void _next() {
    if (_page < _pages.length - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_page > 0) {
      _pc.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _launchSquatAssessment() async {
    final result = await Navigator.of(context).pushNamed(
      '/exercise',
      arguments: squatAssessmentDefinition,
    ) as Map<String, dynamic>?;

    if (result != null && result['logger'] != null) {
      _data.onSquatComplete(result['logger'] as ExerciseLogger);
    }

    _next();
  }

  /*
  Future<void> _launchWallPushupAssessment() async {
    final result = await Navigator.of(context).pushNamed(
      '/exercise',
      arguments: wallPushupAssessmentDefinition,
    ) as Map<String, dynamic>?;

    // if (result != null && result['logger'] != null) {
    //   _data.onPushUpComplete(result['logger'] as ExerciseLogger);
    // }

    _next();
  }
  */

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('user_goal', _data.goal ?? '');
    await prefs.setString('user_level', _data.confirmedLevel ?? 'beginner');
    await prefs.setString('user_name', _data.displayName ?? '');
    await prefs.setString('user_email', _data.email ?? '');
    await prefs.setString('user_preferred_time', _data.preferredTime ?? '');
    await prefs.setStringList(
      'user_workout_days',
      _data.workoutDays.map((d) => d.toString()).toList(),
    );
    if (_data.heightCm != null) {
      await prefs.setDouble('user_height', _data.heightCm!);
    }
    if (_data.weightKg != null) {
      await prefs.setDouble('user_weight', _data.weightKg!);
    }
    if (_data.bmi != null) {
      await prefs.setDouble('user_bmi', _data.bmi!);
    }
    if (_data.issueAnswer != null) {
      await prefs.setStringList('detected_issues', _data.detectedIssues);
      await prefs.setString('issue_answer', _data.issueAnswer!);
    }

    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  List<Widget> get _pages => [
        // 0: Welcome
        WelcomePage(onStart: _next),

        // 1: Goal
        GoalPage(data: _data, onNext: _next, onBack: _back),

        // 2: Medical → then launches squat camera externally
        MedicalPage(
          onNext: _launchSquatAssessment,
          onBack: _back,
        ),

        // 3: Transition → then launches wall push-up camera externally
        // TransitionPage(onNext: _launchWallPushupAssessment),

        // 4: Facts
        FactsPage(data: _data, onNext: _next),

        // 5: Level + issue
        LevelIssuePage(data: _data, onNext: _next),

        // 6: Signup
        SignupPage(data: _data, onNext: _next),

        // 7: Body + schedule + BMI
        BodySchedulePage(data: _data, onComplete: _complete),
        // 8: Your program (the payoff)
        ProgramPage(data: _data, onComplete: _complete),
      ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VF.lightTheme,
      child: Scaffold(
        backgroundColor: VF.bg,
        body: SafeArea(
          child: PageView(
            controller: _pc,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: _pages,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }
}
