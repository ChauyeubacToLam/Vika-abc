import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/exercise_definition.dart';
import 'onboarding_data.dart';
import 'pages/welcome_page.dart';
import 'pages/goal_page.dart';
import 'pages/time_page.dart';
import 'pages/assessment_intro_page.dart';
import 'pages/results_page.dart';
import 'pages/signup_page.dart';
import 'pages/body_info_page.dart';

/* =========================================================================
   ONBOARDING SCREEN
   
   Manages the full onboarding flow using a PageView.
   
   Flow:
     0. Welcome
     1. Goal selection
     2. Time commitment
     3. Medical disclaimer + assessment intro
     4. [Squat assessment — launches ExerciseScreen externally]
     5. Results
     6. Account creation
     7. Weight & height
   
   HOW TO ADD A NEW QUESTION PAGE:
   ─────────────────────────────────
   1. Create a new file in pages/ (copy goal_page.dart as template)
   2. Your page widget must accept:
      - OnboardingData data
      - VoidCallback onNext
      - VoidCallback onBack  (optional, for back button)
   3. Add it to the _pages list below at the position you want
   4. Update _totalSteps if it should count toward progress bar
   5. That's it — the PageView and progress bar handle everything
   
   Example: Adding a "preferred workout days" page after time:
   
     // In pages/workout_days_page.dart:
     class WorkoutDaysPage extends StatelessWidget {
       final OnboardingData data;
       final VoidCallback onNext;
       const WorkoutDaysPage({required this.data, required this.onNext});
       // ... build your UI, call onNext() when user selects
     }
   
     // In this file, add to _pages list at index 3:
     WorkoutDaysPage(data: _data, onNext: _next),
   ========================================================================= */

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingData _data = OnboardingData();
  int _currentPage = 0;

  // Pages that count toward the progress bar (excludes welcome & results)
  // Adjust this if you add/remove question pages
  static const int _firstProgressPage = 1; // goal
  static const int _lastProgressPage = 3; // assessment intro
  static const int _totalSteps = 3; // goal, time, assessment intro

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Called when onboarding is fully complete.
  void _onOnboardingComplete() async {
    // Save completion flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    // TODO: Save _data to your backend or local DB
    // Example: save to shared prefs for now
    await prefs.setString('user_goal', _data.goal ?? '');
    await prefs.setString('user_time', _data.timeCommitment ?? '');
    await prefs.setString('user_name', _data.displayName ?? '');
    await prefs.setString('user_email', _data.email ?? '');
    if (_data.heightCm != null) {
      await prefs.setDouble('user_height', _data.heightCm!);
    }
    if (_data.weightKg != null) {
      await prefs.setDouble('user_weight', _data.weightKg!);
    }
    await prefs.setString('user_fitness_level', _data.fitnessLevel);

    // Navigate to home
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  // ── Page list ──
  // Add new pages here. Order matters.
  List<Widget> get _pages => [
        // 0: Welcome
        WelcomePage(onStart: _next),

        // 1: Goal
        GoalPage(data: _data, onNext: _next, onBack: _back),

        // 2: Time commitment
        TimePage(data: _data, onNext: _next, onBack: _back),

        // 3: Medical + Assessment intro
        AssessmentIntroPage(
          data: _data,
          onNext: () async {
            // Launch squat exercise for assessment
            // You'll need to create an assessment-mode ExerciseDefinition
            // or pass a flag to your existing squat definition
            final result = await Navigator.of(context).pushNamed(
              '/exercise',
              arguments:
                  squatAssessmentDefinition, // assessment version with 5 rep max
            );

            // When ExerciseScreen pops, extract results
            if (result is Map<String, dynamic>) {
              _data.totalReps = result['totalReps'] ?? 5;
              _data.goodReps = result['goodReps'] ?? 0;
              _data.avgDepthAngle = result['avgDepthAngle'];
              _data.maxTrunkLean = result['maxTrunkLean'];
              _data.heelRiseCount = result['heelRiseCount'] ?? 0;
              _data.avgDescentTime = result['avgDescentTime'];
              _data.avgAscentTime = result['avgAscentTime'];
            }
            _next();
          },
          onBack: _back,
        ),

        // 4: Results
        ResultsPage(data: _data, onNext: _next),

        // 5: Account creation
        SignupPage(data: _data, onNext: _next),

        // 6: Body info (weight + height)
        BodyInfoPage(data: _data, onComplete: _onOnboardingComplete),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Scaffold(
      backgroundColor: const Color(0xFF080C1A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar (only visible on question pages) ──
            if (_currentPage >= _firstProgressPage &&
                _currentPage <= _lastProgressPage)
              _buildProgressBar(),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: pages,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentPage - _firstProgressPage + 1) / _totalSteps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: _back,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white54,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Bar
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Step indicator
          Text(
            '${_currentPage - _firstProgressPage + 1}/$_totalSteps',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
