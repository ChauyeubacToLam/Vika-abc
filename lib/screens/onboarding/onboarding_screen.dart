import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/utils/exercise_logger.dart';

import 'onboarding_data.dart';
import 'pages/analyzing_page.dart';
import 'pages/assessment_intro_page.dart';
import 'pages/body_schedule_page.dart';
import 'pages/goal_page.dart';
import 'pages/level_issue_page.dart';
import 'pages/program_page.dart';
import 'pages/signup_page.dart';
import 'pages/squat_result_page.dart';
import 'pages/trust_page.dart';
import 'pages/welcome_page.dart';
import 'pages/why_page.dart';
import 'vf_theme.dart';

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
    if (_page == 6) {
      _pc.animateToPage(
        4,
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

  Future<void> _launchSquatAssessment() async {
    final result = await Navigator.of(context).pushNamed(
      '/exercise',
      arguments: squatAssessmentDefinition,
    ) as Map<String, dynamic>?;

    if (result != null && result['logger'] != null) {
      _data.onSquatComplete(result['logger'] as ExerciseLogger);
      _next();
    }
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('user_goal', _data.goal ?? '');
    await prefs.setString('user_freq', _data.trainingDuration ?? '');
    await prefs.setString('user_experience', _data.trainingDuration ?? '');
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
    if (_data.detectedIssues.isNotEmpty) {
      await prefs.setStringList('detected_issues', _data.detectedIssues);
    }
    if (_data.painAreas.isNotEmpty) {
      await prefs.setStringList('pain_areas', _data.painAreas);
    }
    if (_data.painOtherText?.isNotEmpty == true) {
      await prefs.setString('pain_other_text', _data.painOtherText!);
    }
    if (_data.issueAnswer != null) {
      await prefs.setString('issue_answer', _data.issueAnswer!);
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'onboarding_complete': true,
        }, onConflict: 'id');
      } catch (_) {}
    }

    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  List<Widget> get _pages => [
        SignupPage(data: _data, onNext: _next, onBack: _back),
        WelcomePage(onStart: _next),
        WhyPage(data: _data, onNext: _next),
        GoalPage(data: _data, onNext: _next, onBack: _back),
        TrustPage(onNext: _next, onBack: _back),
        AssessmentIntroPage(
          data: _data,
          onNext: _launchSquatAssessment,
          onBack: _back,
        ),
        AnalyzingPage(active: _page == 6, onNext: _next),
        SquatResultPage(data: _data, onNext: _next, onBack: _back),
        LevelIssuePage(data: _data, onNext: _next, onBack: _back),
        BodySchedulePage(data: _data, onNext: _next, onBack: _back),
        ProgramPage(data: _data, onComplete: _complete),
      ];

  SystemUiOverlayStyle get _overlayStyle {
    final lightPages = <int>{0, 1, 3, 5, 7};
    final light = lightPages.contains(_page);
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.light : Brightness.dark,
      statusBarBrightness: light ? Brightness.dark : Brightness.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Theme(
        data: VF.lightTheme,
        child: Scaffold(
          backgroundColor: VF.bg,
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

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }
}
