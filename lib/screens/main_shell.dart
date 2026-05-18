// MainShell — top-level scaffold for the main app tabs (Trang chủ, Lộ
// trình, Tiến bộ, Hồ sơ) plus the Library sheet that slides up from the
// central FAB. Premium Ivory v1.
//
// Replaces the legacy jade-green VFTheme shell. The new shell:
//   • Background = c.bg (#F4EEE2 cream)
//   • Frosted-glass IvoryBottomNav with 4 tabs + central yellow FAB
//   • IndexedStack so each tab keeps its scroll state
//   • Library sheet animates up via AnimatedSlide / AnimatedOpacity
//
// UserProgramService is still loaded at startup and forwarded into Plan
// (and Home, currently unused). When real wiring lands per the Wiring
// Report, the screens will start consuming the program data.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_definition.dart';
import '../services/user_program_service.dart';
import '../utils/orientation_lock.dart';
import '../widgets/ivory/bottom_nav.dart';
import 'dashboard_home_screen.dart';
import 'exercise_browser.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import '../theme/app_colors.dart';
import '../theme/responsive.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _browserOpen = false;
  UserProgramData? _program;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _loadProgram();
  }

  Future<void> _loadProgram() async {
    final program = await UserProgramService.loadAssignedProgram();
    if (!mounted) return;
    setState(() => _program = program);
  }

  void _toggleBrowser() {
    setState(() => _browserOpen = !_browserOpen);
  }

  void _openExerciseFromBrowser(ExerciseDefinition definition) {
    setState(() => _browserOpen = false);
    Navigator.of(context).pushNamed('/exercise', arguments: definition);
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    // Capsule height (~76) + drop shadow + capsule top margin.
    final navCapsule = r.w(100);
    final contentBottomPadding = navCapsule + bottomInset + r.w(8);

    final screens = [
      DashboardHomeScreen(
        bottomPadding: contentBottomPadding,
        onOpenBrowser: _toggleBrowser,
        program: _program,
      ),
      PlanScreen(
        bottomPadding: contentBottomPadding,
        program: _program,
      ),
      ProgressScreen(bottomPadding: contentBottomPadding),
      ProfileScreen(bottomPadding: contentBottomPadding),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: c.bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
            // Library sheet (slides up over content).
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_browserOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _browserOpen ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    offset: _browserOpen ? Offset.zero : const Offset(0, 1),
                    child: ExerciseBrowser(
                      bottomPadding: contentBottomPadding,
                      onClose: _toggleBrowser,
                      onSelectExercise: _openExerciseFromBrowser,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          offset: _browserOpen ? const Offset(0, 1.1) : Offset.zero,
          child: IvoryBottomNav(
            currentIndex: _currentIndex,
            bottomInset: bottomInset,
            onTap: (idx) {
              setState(() {
                _currentIndex = idx;
                _browserOpen = false;
              });
            },
            onBrowse: _toggleBrowser,
          ),
        ),
      ),
    );
  }
}
